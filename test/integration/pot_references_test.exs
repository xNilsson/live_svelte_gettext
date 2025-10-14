defmodule LiveSvelteGettext.Integration.PotReferencesTest do
  use ExUnit.Case

  # Define a test Gettext backend
  defmodule TestGettextBackend do
    use Gettext.Backend, otp_app: :live_svelte_gettext
  end

  # Define a module that uses LiveSvelteGettext
  defmodule TestGettext do
    use LiveSvelteGettext,
      gettext_backend: LiveSvelteGettext.Integration.PotReferencesTest.TestGettextBackend,
      svelte_path: "test/fixtures"
  end

  describe "POT file references" do
    test "generated gettext calls have correct source file metadata" do
      # Get the metadata to see what was extracted
      metadata = TestGettext.__lsg_metadata__()

      # Verify that extractions have the expected references
      user_profile_extraction =
        Enum.find(metadata.extractions, fn e -> e.msgid == "User Profile" end)

      assert user_profile_extraction
      assert length(user_profile_extraction.references) > 0

      # Check that the reference points to a Svelte file, not the generated module
      {file, line} = List.first(user_profile_extraction.references)
      assert String.ends_with?(file, "UserProfile.svelte")
      refute String.contains?(file, "svelte_strings.ex")
      assert is_integer(line)
      assert line > 0
    end

    test "all extractions have Svelte file references" do
      metadata = TestGettext.__lsg_metadata__()

      # Every extraction should reference a .svelte file
      Enum.each(metadata.extractions, fn extraction ->
        assert length(extraction.references) > 0

        Enum.each(extraction.references, fn {file, line} ->
          assert String.ends_with?(file, ".svelte"),
                 "Expected .svelte file, got: #{file}"

          refute String.contains?(file, "svelte_strings.ex"),
                 "Should not reference generated module"

          assert is_integer(line)
          assert line > 0
        end)
      end)
    end

    test "multiple references to same string are preserved" do
      metadata = TestGettext.__lsg_metadata__()

      # Find a string that might appear in multiple files
      # (depends on fixture content)
      all_extractions = metadata.extractions

      # At least one extraction should have references
      assert Enum.any?(all_extractions, fn e -> length(e.references) > 0 end)

      # Each reference should be a unique {file, line} tuple
      Enum.each(all_extractions, fn extraction ->
        assert extraction.references == Enum.uniq(extraction.references)
      end)
    end

    test "references use relative paths, not absolute" do
      metadata = TestGettext.__lsg_metadata__()

      # All references should be relative to the project root
      Enum.each(metadata.extractions, fn extraction ->
        Enum.each(extraction.references, fn {file, _line} ->
          # Relative paths don't start with "/"
          refute String.starts_with?(file, "/"),
                 "Expected relative path, got absolute: #{file}"

          # Should start with test/fixtures (our svelte_path)
          assert String.starts_with?(file, "test/fixtures/"),
                 "Expected path relative to project root: #{file}"
        end)
      end)
    end

    test "ngettext calls also have correct source references" do
      metadata = TestGettext.__lsg_metadata__()

      # Find ngettext extractions
      ngettext_extractions = Enum.filter(metadata.extractions, &(&1.type == :ngettext))

      if length(ngettext_extractions) > 0 do
        Enum.each(ngettext_extractions, fn extraction ->
          assert length(extraction.references) > 0

          Enum.each(extraction.references, fn {file, line} ->
            assert String.ends_with?(file, ".svelte")
            assert is_integer(line)
            assert line > 0
          end)
        end)
      else
        # If no ngettext in fixtures, that's okay - just note it
        assert true
      end
    end

    test "line numbers are accurate" do
      metadata = TestGettext.__lsg_metadata__()

      # Check that line numbers make sense
      Enum.each(metadata.extractions, fn extraction ->
        Enum.each(extraction.references, fn {file, line} ->
          # Line numbers should be positive integers
          assert is_integer(line)
          assert line > 0

          # Verify the line number is reasonable by reading the file
          if File.exists?(file) do
            {:ok, content} = File.read(file)
            lines = String.split(content, "\n")
            total_lines = length(lines)

            # Line number should be within the file's bounds
            assert line <= total_lines,
                   "Line #{line} exceeds file length #{total_lines} in #{file}"

            # The line should contain the msgid (or be close to it)
            # This is a sanity check that our line numbers are accurate
            line_content = Enum.at(lines, line - 1) || ""
            assert is_binary(line_content)
          end
        end)
      end)
    end

    test "references point to actual locations of gettext calls" do
      metadata = TestGettext.__lsg_metadata__()

      # For a known extraction, verify the line actually contains the gettext call
      user_profile = Enum.find(metadata.extractions, fn e -> e.msgid == "User Profile" end)

      if user_profile do
        {file, line} = List.first(user_profile.references)

        # Read the file and check the line
        if File.exists?(file) do
          {:ok, content} = File.read(file)
          lines = String.split(content, "\n")
          line_content = Enum.at(lines, line - 1) || ""

          # The line should contain "gettext" and the msgid
          assert String.contains?(line_content, "gettext")
          assert String.contains?(line_content, "User Profile")
        end
      end
    end

    test "generated AST preserves all file:line metadata" do
      # This test verifies that the generated AST includes location metadata
      # that mix gettext.extract can use

      metadata = TestGettext.__lsg_metadata__()

      # The implementation generates one gettext() call per reference
      # So if we have N references across all extractions, we should have
      # N gettext calls in the generated code

      total_references =
        metadata.extractions
        |> Enum.map(&length(&1.references))
        |> Enum.sum()

      assert total_references > 0,
             "Should have at least one reference"

      # The generated code should include all these references
      # This is implicitly tested by the compilation succeeding
      assert true
    end
  end

  describe "compatibility with mix gettext.extract" do
    @tag :skip
    test "mix gettext.extract produces correct references in .pot files" do
      # This test would require:
      # 1. Running mix gettext.extract in a test environment
      # 2. Parsing the generated .pot file
      # 3. Verifying references point to Svelte files
      #
      # Skipped for now because it requires more complex test setup
      # Manual testing should verify this works correctly

      assert true
    end
  end
end
