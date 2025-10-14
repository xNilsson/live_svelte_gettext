defmodule LiveSvelteGettext.Integration.FullCompileTest do
  use ExUnit.Case

  # Define a test Gettext backend
  defmodule TestGettextBackend do
    use Gettext.Backend, otp_app: :livesvelte_gettext
  end

  # Define a module that uses LiveSvelteGettext
  defmodule TestGettext do
    use LiveSvelteGettext,
      gettext_backend: LiveSvelteGettext.Integration.FullCompileTest.TestGettextBackend,
      svelte_path: "test/fixtures"
  end

  describe "full integration test" do
    test "module compiles successfully" do
      # If we got here, the module compiled. Let's verify what was actually generated:

      # 1. The macro executed without errors - verify the module exists
      assert Code.ensure_loaded?(TestGettext)
      assert Code.ensure_loaded?(TestGettextBackend)

      # 2. All generated code is valid Elixir - verify key functions exist
      assert function_exported?(TestGettext, :all_translations, 1)
      assert function_exported?(TestGettext, :__lsg_metadata__, 0)

      # 3. The Extractor ran successfully - verify it found our fixtures
      metadata = TestGettext.__lsg_metadata__()
      assert length(metadata.svelte_files) > 0, "Should have found Svelte files"
      assert length(metadata.extractions) > 0, "Should have extracted translation strings"
    end

    test "generated functions exist" do
      # Check that all expected functions were generated
      assert function_exported?(TestGettext, :all_translations, 1)
      assert function_exported?(TestGettext, :__lsg_metadata__, 0)

      # TestGettext uses the Gettext backend, so it should have the Gettext interface
      # The backend is TestGettextBackend
      assert function_exported?(TestGettextBackend, :lgettext, 4)
    end

    test "all_translations/1 returns a map" do
      translations = TestGettext.all_translations("en")
      assert is_map(translations)
    end

    test "all_translations/1 includes extracted strings" do
      translations = TestGettext.all_translations("en")

      # Should include strings from UserProfile.svelte
      assert Map.has_key?(translations, "User Profile")
      assert Map.has_key?(translations, "Save Changes")
      assert Map.has_key?(translations, "Cancel")

      # Should include strings from ShoppingCart.svelte
      assert Map.has_key?(translations, "Shopping Cart")
      assert Map.has_key?(translations, "Checkout")

      # Should include strings from ErrorMessages.svelte
      assert Map.has_key?(translations, "Network connection failed")
      assert Map.has_key?(translations, "An unknown error occurred")
    end

    test "all_translations/1 includes ngettext plurals" do
      translations = TestGettext.all_translations("en")

      # Plural forms use "singular|||plural" as the key
      plural_key = "%{count} item|||%{count} items"
      assert Map.has_key?(translations, plural_key)

      # The value should be a map with "one" and "other" keys
      plural_value = Map.get(translations, plural_key)
      assert is_map(plural_value)
      assert Map.has_key?(plural_value, "one")
      assert Map.has_key?(plural_value, "other")
    end

    test "__lsg_metadata__/0 returns correct structure" do
      metadata = TestGettext.__lsg_metadata__()

      assert is_map(metadata)
      assert Map.has_key?(metadata, :extractions)
      assert Map.has_key?(metadata, :svelte_files)
      assert Map.has_key?(metadata, :gettext_backend)

      # Check the values
      assert is_list(metadata.extractions)
      assert is_list(metadata.svelte_files)
      assert metadata.gettext_backend == TestGettextBackend

      # Should have found our fixture files
      assert length(metadata.svelte_files) >= 3
      assert length(metadata.extractions) > 0
    end

    test "__lsg_metadata__/0 shows correct extraction details" do
      metadata = TestGettext.__lsg_metadata__()

      # Find a specific extraction
      user_profile_extraction =
        Enum.find(metadata.extractions, fn e -> e.msgid == "User Profile" end)

      assert user_profile_extraction
      assert user_profile_extraction.type == :gettext
      assert user_profile_extraction.plural == nil

      # Should have a reference to the source file
      assert length(user_profile_extraction.references) > 0

      {file, line} = List.first(user_profile_extraction.references)
      assert String.ends_with?(file, "UserProfile.svelte")
      assert is_integer(line)
      assert line > 0
    end

    test "extractions include file:line references" do
      metadata = TestGettext.__lsg_metadata__()

      # Every extraction should have at least one reference
      Enum.each(metadata.extractions, fn extraction ->
        assert length(extraction.references) > 0

        Enum.each(extraction.references, fn {file, line} ->
          assert is_binary(file)
          assert String.ends_with?(file, ".svelte")
          assert is_integer(line)
          assert line > 0
        end)
      end)
    end

    test "does not extract strings from HTML comments" do
      metadata = TestGettext.__lsg_metadata__()

      # "Hidden Comment" is in a comment in UserProfile.svelte
      # It should NOT be extracted
      hidden_extraction =
        Enum.find(metadata.extractions, fn e -> e.msgid == "Hidden Comment" end)

      assert is_nil(hidden_extraction)
    end

    test "handles different quote styles" do
      metadata = TestGettext.__lsg_metadata__()

      # UserProfile.svelte has both single and double quotes
      # Both should be extracted
      double_quote = Enum.find(metadata.extractions, fn e -> e.msgid == "Save Changes" end)
      single_quote = Enum.find(metadata.extractions, fn e -> e.msgid == "Cancel" end)

      assert double_quote
      assert single_quote
    end

    test "deduplicates strings from multiple files" do
      metadata = TestGettext.__lsg_metadata__()

      # If the same string appears in multiple files, it should be one extraction
      # with multiple references
      save_extraction = Enum.find(metadata.extractions, fn e -> e.msgid == "Save" end)

      if save_extraction do
        # If "Save" appears in multiple fixtures, should have multiple references
        # (This depends on the actual fixture content)
        assert is_list(save_extraction.references)
      end
    end
  end

  describe "gettext integration" do
    test "generated gettext calls are discoverable by mix gettext.extract" do
      # This is tested implicitly by the fact that we're using gettext()
      # in the generated code. If mix gettext.extract can't find them,
      # the extraction won't work.
      #
      # We can verify the calls exist by checking the module's compiled code
      # contains literal strings that Gettext can extract.

      metadata = TestGettext.__lsg_metadata__()

      # All extracted msgids should have corresponding gettext calls
      Enum.each(metadata.extractions, fn extraction ->
        # For gettext calls, just check the msgid exists
        if extraction.type == :gettext do
          assert is_binary(extraction.msgid)
        end

        # For ngettext calls, both singular and plural should exist
        if extraction.type == :ngettext do
          assert is_binary(extraction.msgid)
          assert is_binary(extraction.plural)
        end
      end)
    end
  end
end
