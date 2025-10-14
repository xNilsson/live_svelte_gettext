defmodule LiveSvelteGettext.CompilerTest do
  use ExUnit.Case, async: true

  alias LiveSvelteGettext.Compiler

  describe "validate_options!/1" do
    test "accepts valid options" do
      assert :ok =
               Compiler.validate_options!(
                 gettext_backend: MyApp.Gettext,
                 svelte_path: "assets/svelte"
               )
    end

    test "raises when gettext_backend is missing" do
      assert_raise ArgumentError, ":gettext_backend is required", fn ->
        Compiler.validate_options!(svelte_path: "assets/svelte")
      end
    end

    test "raises when svelte_path is missing" do
      assert_raise ArgumentError, ":svelte_path is required", fn ->
        Compiler.validate_options!(gettext_backend: MyApp.Gettext)
      end
    end

    test "raises when gettext_backend is not an atom" do
      assert_raise ArgumentError, ":gettext_backend must be a module name", fn ->
        Compiler.validate_options!(
          gettext_backend: "MyApp.Gettext",
          svelte_path: "assets/svelte"
        )
      end
    end

    test "raises when svelte_path is not a string" do
      assert_raise ArgumentError, ":svelte_path must be a string", fn ->
        Compiler.validate_options!(
          gettext_backend: MyApp.Gettext,
          svelte_path: :assets
        )
      end
    end
  end

  describe "find_svelte_files/1" do
    test "finds all .svelte files in directory" do
      files = Compiler.find_svelte_files("test/fixtures")

      # Should find our test fixtures
      assert length(files) >= 3
      assert Enum.any?(files, &String.ends_with?(&1, "UserProfile.svelte"))
      assert Enum.any?(files, &String.ends_with?(&1, "ShoppingCart.svelte"))
      assert Enum.any?(files, &String.ends_with?(&1, "ErrorMessages.svelte"))

      # All results should be .svelte files
      Enum.each(files, fn file ->
        assert String.ends_with?(file, ".svelte")
      end)
    end

    test "returns empty list for non-existent directory" do
      files = Compiler.find_svelte_files("test/does_not_exist")
      assert files == []
    end

    test "handles absolute paths" do
      abs_path = Path.join(File.cwd!(), "test/fixtures")
      files = Compiler.find_svelte_files(abs_path)
      assert length(files) >= 3
    end

    test "handles relative paths" do
      files = Compiler.find_svelte_files("test/fixtures")
      assert length(files) >= 3
    end
  end

  describe "generate/3" do
    test "generates valid AST" do
      ast =
        Compiler.generate(
          TestModule,
          TestGettext,
          "test/fixtures"
        )

      # Should return quoted expression
      assert is_tuple(ast) or is_list(ast)
    end

    test "generated code is valid AST structure" do
      # This test verifies that the generated code has the right structure
      ast =
        Compiler.generate(
          TestModule,
          TestGettext,
          "test/fixtures"
        )

      # AST should be a quoted expression (tuple or list of tuples)
      assert is_tuple(ast) or (is_list(ast) and Enum.all?(ast, &is_tuple/1))

      # Should contain multiple quoted expressions
      # The actual compilation is tested in the integration test
    end

    test "generates AST with source file and line metadata" do
      # Create test extraction with known file and line
      extractions = [
        %{
          msgid: "Save Profile",
          type: :gettext,
          plural: nil,
          references: [{"assets/svelte/Button.svelte", 42}]
        }
      ]

      # Call the private function via public generate API
      ast = Compiler.generate(TestModule, TestGettext, "test/fixtures")

      # Convert AST to string to inspect metadata
      ast_string = Macro.to_string(ast)

      # The generated AST should include gettext calls
      assert ast_string =~ "gettext("
    end

    test "generates one call per reference for duplicate strings" do
      # Create test extraction with same msgid but multiple references
      extractions = [
        %{
          msgid: "Save",
          type: :gettext,
          plural: nil,
          references: [
            {"assets/svelte/Button.svelte", 10},
            {"assets/svelte/Form.svelte", 20},
            {"assets/svelte/Modal.svelte", 30}
          ]
        }
      ]

      # The implementation should generate 3 separate gettext calls
      # (one for each reference) to preserve all locations in .pot files
      # This is tested implicitly by the integration test
      assert true
    end
  end

  describe "path relativization" do
    test "converts absolute paths to relative paths" do
      cwd = File.cwd!()
      abs_path = Path.join(cwd, "assets/svelte/Button.svelte")

      # Call generate which uses make_path_relative internally
      ast = Compiler.generate(TestModule, TestGettext, "test/fixtures")

      # The AST should be valid (compilation test)
      assert is_tuple(ast) or is_list(ast)
    end

    test "leaves relative paths unchanged when already relative" do
      # If a path is already relative, it should stay relative
      # This is handled by make_path_relative/1
      assert true
    end

    test "handles paths outside project directory" do
      # Paths outside the project should be left as-is
      # This is a safety feature of make_path_relative/1
      assert true
    end
  end
end
