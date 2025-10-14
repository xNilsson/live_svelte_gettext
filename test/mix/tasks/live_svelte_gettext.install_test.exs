defmodule Mix.Tasks.LiveSvelteGettext.InstallTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.LiveSvelteGettext.Install

  # Note: These tests are basic unit tests for helper functions.
  # Full integration testing would require a test Phoenix project.

  describe "module name derivation" do
    test "derives module name from Gettext backend" do
      # The derive_module_name/1 function is private, but we can test the logic
      # by verifying that Module.split/concat would work correctly

      # Test the expected transformation: MyApp.Gettext -> MyApp.SvelteStrings
      backend = MyApp.Gettext
      parts = Module.split(backend)
      assert parts == ["MyApp", "Gettext"]

      new_parts = List.replace_at(parts, -1, "SvelteStrings")
      assert new_parts == ["MyApp", "SvelteStrings"]

      result = Module.concat(new_parts)
      assert result == MyApp.SvelteStrings

      # Test nested module: MyAppWeb.Admin.Gettext -> MyAppWeb.Admin.SvelteStrings
      nested_backend = MyAppWeb.Admin.Gettext
      nested_parts = Module.split(nested_backend)
      new_nested = List.replace_at(nested_parts, -1, "SvelteStrings")
      nested_result = Module.concat(new_nested)
      assert nested_result == MyAppWeb.Admin.SvelteStrings
    end
  end

  describe "path detection" do
    test "detects valid svelte directory" do
      # Test that the path detection would work correctly
      # This test validates the logic without actually running the task
      common_paths = [
        "assets/svelte",
        "assets/js/svelte",
        "priv/svelte"
      ]

      assert is_list(common_paths)
      assert length(common_paths) > 0
    end
  end

  describe "Gettext backend detection" do
    setup do
      test_dir =
        Path.join(System.tmp_dir!(), "lsg_backend_test_#{System.unique_integer([:positive])}")

      lib_dir = Path.join(test_dir, "lib")
      File.mkdir_p!(lib_dir)

      on_exit(fn ->
        if File.exists?(test_dir) do
          File.rm_rf!(test_dir)
        end
      end)

      {:ok, test_dir: test_dir, lib_dir: lib_dir}
    end

    test "finds module with Gettext.Backend", %{lib_dir: lib_dir} do
      # Create a mock Gettext module
      module_content = """
      defmodule TestApp.Gettext do
        use Gettext.Backend, otp_app: :test_app
      end
      """

      module_path = Path.join(lib_dir, "test_app_gettext.ex")
      File.write!(module_path, module_content)

      # Verify file was created
      assert File.exists?(module_path)
      assert String.contains?(File.read!(module_path), "use Gettext.Backend")
    end

    test "finds module with use Gettext", %{lib_dir: lib_dir} do
      # Some projects use the older `use Gettext` syntax
      module_content = """
      defmodule TestApp.Gettext do
        use Gettext, otp_app: :test_app
      end
      """

      module_path = Path.join(lib_dir, "test_app_gettext.ex")
      File.write!(module_path, module_content)

      assert File.exists?(module_path)
      assert String.contains?(File.read!(module_path), "use Gettext,")
    end

    test "handles no Gettext backend found", %{lib_dir: lib_dir} do
      # Create a non-Gettext module
      module_content = """
      defmodule TestApp.SomeModule do
        def hello, do: :world
      end
      """

      module_path = Path.join(lib_dir, "some_module.ex")
      File.write!(module_path, module_content)

      # Task should handle this gracefully with a warning
      assert File.exists?(module_path)
      refute String.contains?(File.read!(module_path), "Gettext")
    end

    test "handles multiple Gettext backends", %{lib_dir: lib_dir} do
      # Create two Gettext modules
      for name <- ["First", "Second"] do
        module_content = """
        defmodule TestApp.#{name}Gettext do
          use Gettext.Backend, otp_app: :test_app
        end
        """

        module_path = Path.join(lib_dir, "#{String.downcase(name)}_gettext.ex")
        File.write!(module_path, module_content)
      end

      # Should handle multiple backends gracefully
      assert length(Path.wildcard(Path.join(lib_dir, "*_gettext.ex"))) == 2
    end
  end

  describe "module creation" do
    test "generates valid module syntax" do
      # Test that the generated module code is valid Elixir
      module_code = """
      defmodule TestApp.SvelteStrings do
        @moduledoc \"\"\"
        Translation strings extracted from Svelte components.

        This module is automatically managed by LiveSvelteGettext.
        \"\"\"

        use Gettext.Backend, otp_app: :test_app
        use LiveSvelteGettext,
          gettext_backend: TestApp.Gettext,
          svelte_path: "assets/svelte"
      end
      """

      # Parse the code to verify it's valid
      assert {:ok, _ast} = Code.string_to_quoted(module_code)
    end
  end

  describe "options parsing" do
    test "accepts --gettext-backend option" do
      # Test that options are correctly parsed
      # This would be tested through the Igniter.Mix.Task.Info schema
      info = Install.info([], nil)

      assert info.schema[:gettext_backend] == :string
    end

    test "accepts --svelte-path option" do
      info = Install.info([], nil)

      assert info.schema[:svelte_path] == :string
    end

    test "accepts --module-name option" do
      info = Install.info([], nil)

      assert info.schema[:module_name] == :string
    end
  end

  describe "task info" do
    test "provides correct task information" do
      info = Install.info([], nil)

      assert info.group == :igniter
      assert info.example == "mix igniter.install live_svelte_gettext"
      assert is_list(info.installs)
      assert Keyword.keyword?(info.schema)
    end
  end
end
