defmodule LiveSvelteGettext.InstallerTest do
  use ExUnit.Case

  alias Mix.Tasks.LiveSvelteGettext.Install

  @moduletag :tmp_dir

  describe "module name generation" do
    test "creates proper submodule of Gettext backend", %{tmp_dir: _tmp_dir} do
      # Issue 4: Should create MyAppWeb.Gettext.SvelteStrings, not MyAppWeb.SvelteStrings
      backend = MonsterConstructionWeb.Gettext

      result = Install.derive_module_name_test(backend)

      # Should be a submodule
      assert result == MonsterConstructionWeb.Gettext.SvelteStrings

      # Should NOT replace the last part
      refute result == MonsterConstructionWeb.SvelteStrings
    end

    test "works with different backend naming patterns", %{tmp_dir: _tmp_dir} do
      test_cases = [
        {MyApp.Gettext, MyApp.Gettext.SvelteStrings},
        {MyAppWeb.Gettext, MyAppWeb.Gettext.SvelteStrings},
        {MyOrg.MyApp.Gettext, MyOrg.MyApp.Gettext.SvelteStrings}
      ]

      for {backend, expected} <- test_cases do
        result = Install.derive_module_name_test(backend)

        assert result == expected,
               "Expected #{inspect(backend)} -> #{inspect(expected)}, got #{inspect(result)}"
      end
    end

    test "handles nil gracefully", %{tmp_dir: _tmp_dir} do
      result = Install.derive_module_name_test(nil)
      assert is_nil(result)
    end
  end

  describe "LiveView import functionality" do
    test "adds import to both html and live_view functions", %{tmp_dir: _tmp_dir} do
      # Issue 3: Import should be in BOTH functions
      fixture_content = File.read!("test/fixtures/elixir/test_web_simple.ex")

      result = Install.add_component_import_test(fixture_content)

      # Should have import in html function
      assert result =~
               ~r/def\s+html\s+do\s+quote\s+do[^\n]*\n\s+import LiveSvelteGettext\.Components/

      # Should have import in live_view function
      assert result =~
               ~r/def\s+live_view\s+do\s+quote\s+do[^\n]*\n\s+import LiveSvelteGettext\.Components/
    end

    test "does not duplicate imports", %{tmp_dir: _tmp_dir} do
      fixture_content = File.read!("test/fixtures/elixir/test_web_simple.ex")

      # Apply the transformation twice
      result1 = Install.add_component_import_test(fixture_content)
      result2 = Install.add_component_import_test(result1)

      # Count occurrences of the import
      import_count =
        result2
        |> String.split("\n")
        |> Enum.count(fn line ->
          String.contains?(line, "import LiveSvelteGettext.Components")
        end)

      # Should appear exactly twice (once in html, once in live_view)
      assert import_count == 2
    end

    test "preserves existing imports", %{tmp_dir: _tmp_dir} do
      fixture_content = File.read!("test/fixtures/elixir/test_web_simple.ex")

      result = Install.add_component_import_test(fixture_content)

      # Original imports should still be present
      assert result =~ "use Phoenix.Component"
      assert result =~ "import Phoenix.Controller"
      assert result =~ "use Phoenix.LiveView"
    end
  end

  describe "Gettext backend detection" do
    @tag :tmp_dir
    test "detects actual Gettext backend, not web modules that use Gettext", %{tmp_dir: tmp_dir} do
      # Issue 7: Web modules often use "use Gettext, backend: MyAppWeb.Gettext"
      # We should NOT detect these as backends, only modules with "use Gettext.Backend"

      # Create a temporary project structure in tmp_dir
      lib_dir = Path.join(tmp_dir, "lib")
      File.mkdir_p!(lib_dir)

      # Create actual Gettext backend
      backend_content = """
      defmodule TestAppWeb.Gettext do
        use Gettext.Backend, otp_app: :test_app
      end
      """

      File.write!(Path.join(lib_dir, "test_app_web_gettext.ex"), backend_content)

      # Create web module that USES Gettext (consumer, not backend)
      web_content = File.read!("test/fixtures/elixir/test_web_consumer.ex")
      File.write!(Path.join(lib_dir, "test_app_web.ex"), web_content)

      # Change working directory to tmp_dir for the test
      original_dir = File.cwd!()

      try do
        File.cd!(tmp_dir)

        # Call the detection function
        backends = Install.find_gettext_backends_test(nil)

        # Should only find the actual backend, not the web module
        assert length(backends) == 1, "Should find exactly 1 backend, found: #{inspect(backends)}"
        assert backends == [TestAppWeb.Gettext], "Should find TestAppWeb.Gettext, not TestAppWeb"
      after
        # Restore working directory
        File.cd!(original_dir)
      end
    end

    @tag :tmp_dir
    test "handles projects with no Gettext backend", %{tmp_dir: tmp_dir} do
      lib_dir = Path.join(tmp_dir, "lib")
      File.mkdir_p!(lib_dir)

      # Create a file with no Gettext usage
      File.write!(Path.join(lib_dir, "my_module.ex"), """
      defmodule MyModule do
        def hello, do: "world"
      end
      """)

      original_dir = File.cwd!()

      try do
        File.cd!(tmp_dir)
        backends = Install.find_gettext_backends_test(nil)
        assert backends == [], "Should find no backends in project without Gettext"
      after
        File.cd!(original_dir)
      end
    end

    @tag :tmp_dir
    test "finds multiple Gettext backends when they exist", %{tmp_dir: tmp_dir} do
      lib_dir = Path.join(tmp_dir, "lib")
      File.mkdir_p!(lib_dir)

      # Create two backends
      File.write!(Path.join(lib_dir, "gettext1.ex"), """
      defmodule MyApp.Gettext do
        use Gettext.Backend, otp_app: :my_app
      end
      """)

      File.write!(Path.join(lib_dir, "gettext2.ex"), """
      defmodule MyAppAdmin.Gettext do
        use Gettext.Backend, otp_app: :my_app
      end
      """)

      original_dir = File.cwd!()

      try do
        File.cd!(tmp_dir)
        backends = Install.find_gettext_backends_test(nil)

        assert length(backends) == 2, "Should find both backends"
        assert MyApp.Gettext in backends
        assert MyAppAdmin.Gettext in backends
      after
        File.cd!(original_dir)
      end
    end
  end

  describe "full installer workflow" do
    test "derive_module_name matches what Components expects" do
      # This is the critical bug fix - Components does Module.concat(gettext_module, SvelteStrings)
      # So our derive_module_name must do the same thing

      backend = TestApp.Gettext
      derived = Install.derive_module_name_test(backend)

      # What Components.svelte_translations/1 will look for
      expected = Module.concat(backend, SvelteStrings)

      assert derived == expected,
             "Module name mismatch! Installer creates #{inspect(derived)} but Components expects #{inspect(expected)}"
    end
  end
end
