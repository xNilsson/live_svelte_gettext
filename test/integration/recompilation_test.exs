defmodule LiveSvelteGettext.Integration.RecompilationTest do
  use ExUnit.Case

  @moduledoc """
  Tests for @external_resource recompilation behavior.

  Note: Automatically testing recompilation is very difficult in ExUnit because
  it requires modifying files during the test run and triggering a recompile.
  Instead, we verify that:

  1. @external_resource attributes are generated for all Svelte files
  2. The metadata tracks which files were scanned
  3. The module compiles successfully with all resources

  Manual verification of recompilation:
  1. Modify a Svelte file in test/fixtures
  2. Run `mix compile`
  3. Verify the module recompiles (you'll see it in the compilation output)
  """

  # Define a test Gettext backend
  defmodule TestGettextBackend do
    use Gettext.Backend, otp_app: :live_svelte_gettext
  end

  # Define a module that uses LiveSvelteGettext
  defmodule TestModule do
    use LiveSvelteGettext,
      gettext_backend: LiveSvelteGettext.Integration.RecompilationTest.TestGettextBackend,
      svelte_path: "test/fixtures"
  end

  describe "@external_resource integration" do
    test "module tracks all Svelte files in metadata" do
      metadata = TestModule.__lsg_metadata__()

      # Should have tracked multiple files
      assert length(metadata.svelte_files) >= 3

      # All should be .svelte files
      Enum.each(metadata.svelte_files, fn file ->
        assert String.ends_with?(file, ".svelte")
        assert File.exists?(file), "File should exist: #{file}"
      end)
    end

    test "all tracked files are absolute paths" do
      metadata = TestModule.__lsg_metadata__()

      Enum.each(metadata.svelte_files, fn file ->
        assert Path.type(file) == :absolute,
               "Expected absolute path, got: #{file}"
      end)
    end

    test "module has external resources set" do
      # This verifies the @external_resource attributes were set
      # If they weren't, the module_info won't include them
      # (Note: In Elixir, we can't directly query @external_resource at runtime,
      # but we can verify the module compiled successfully with all files tracked)
      metadata = TestModule.__lsg_metadata__()

      # If all files are in metadata and module compiled, @external_resource worked
      assert length(metadata.svelte_files) > 0
    end

    test "changing a Svelte file would trigger recompilation" do
      # This is a documentation test - we can't easily test auto-recompilation
      # in ExUnit without external tooling, but we document the behavior

      metadata = TestModule.__lsg_metadata__()

      # Document the expected behavior
      explanation = """
      When any of these files change:
      #{Enum.map_join(metadata.svelte_files, "\n", &"  - #{&1}")}

      The module should automatically recompile due to @external_resource.

      To verify manually:
      1. touch #{List.first(metadata.svelte_files)}
      2. mix compile
      3. Should see module recompiling
      """

      # Just verify we have the files tracked
      assert length(metadata.svelte_files) > 0, explanation
    end
  end

  describe "recompilation behavior with non-existent directory" do
    defmodule EmptyDirModule do
      use LiveSvelteGettext,
        gettext_backend: LiveSvelteGettext.Integration.RecompilationTest.TestGettextBackend,
        svelte_path: "test/fixtures/nonexistent"
    end

    test "module compiles even if directory doesn't exist" do
      # Should compile without errors
      metadata = EmptyDirModule.__lsg_metadata__()

      # Should have empty file list
      assert metadata.svelte_files == []
      assert metadata.extractions == []
    end

    test "all_translations works with no extractions" do
      translations = EmptyDirModule.all_translations("en")

      # Should return empty map
      assert translations == %{}
    end
  end
end
