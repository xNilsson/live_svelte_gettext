defmodule LiveSvelteGettext.Integration.FixturesTest do
  use ExUnit.Case, async: true

  alias LiveSvelteGettext.Extractor

  @fixtures_path Path.expand("../fixtures", __DIR__)

  describe "realistic Svelte component extraction" do
    test "extracts from UserProfile.svelte fixture" do
      file = Path.join(@fixtures_path, "UserProfile.svelte")
      result = Extractor.extract_from_file(file)

      # Should extract all gettext calls
      assert Enum.any?(result, &(&1.msgid == "User Profile"))
      assert Enum.any?(result, &(&1.msgid == "Welcome back, %{name}!"))
      assert Enum.any?(result, &(&1.msgid == "Step %{current} of %{total}"))
      assert Enum.any?(result, &(&1.msgid == "Save Changes"))
      assert Enum.any?(result, &(&1.msgid == "Cancel"))
      assert Enum.any?(result, &(&1.msgid == "Edit"))
      assert Enum.any?(result, &(&1.msgid == "Delete"))
      assert Enum.any?(result, &(&1.msgid == "Share"))
      assert Enum.any?(result, &(&1.msgid == "Copyright © 2025"))
      assert Enum.any?(result, &(&1.msgid == "All rights reserved"))

      # Should extract ngettext calls
      assert Enum.any?(result, fn extraction ->
               extraction.msgid == "%{count} item" &&
                 extraction.type == :ngettext &&
                 extraction.plural == "%{count} items"
             end)

      # Should NOT extract from comments
      refute Enum.any?(result, &(&1.msgid == "Hidden Comment"))

      # Verify line numbers are tracked
      save_changes = Enum.find(result, &(&1.msgid == "Save Changes"))

      assert save_changes.references
             |> Enum.any?(fn {file_path, line} ->
               String.ends_with?(file_path, "UserProfile.svelte") && line == 26
             end)
    end

    test "extracts from ShoppingCart.svelte fixture" do
      file = Path.join(@fixtures_path, "ShoppingCart.svelte")
      result = Extractor.extract_from_file(file)

      assert Enum.any?(result, &(&1.msgid == "Shopping Cart"))
      assert Enum.any?(result, &(&1.msgid == "Your cart is empty"))
      assert Enum.any?(result, &(&1.msgid == "Total: %{amount}"))
      assert Enum.any?(result, &(&1.msgid == "Checkout"))
      assert Enum.any?(result, &(&1.msgid == "Continue Shopping"))
      assert Enum.any?(result, &(&1.msgid == "Need help?"))

      # Check ngettext extraction
      assert Enum.any?(result, fn extraction ->
               extraction.msgid == "%{n} item in cart" &&
                 extraction.type == :ngettext &&
                 extraction.plural == "%{n} items in cart"
             end)
    end

    test "extracts from ErrorMessages.svelte with special characters" do
      file = Path.join(@fixtures_path, "ErrorMessages.svelte")
      result = Extractor.extract_from_file(file)

      assert Enum.any?(result, &(&1.msgid == "Network connection failed"))
      assert Enum.any?(result, &(&1.msgid == "Authentication error - please log in again"))
      assert Enum.any?(result, &(&1.msgid == "Please check your input"))
      assert Enum.any?(result, &(&1.msgid == "An unknown error occurred"))

      # Special characters and escaping
      assert Enum.any?(result, &(&1.msgid == "It's working!"))
      assert Enum.any?(result, &(&1.msgid == ~s|The "system" is operational|))
      assert Enum.any?(result, &(&1.msgid == "Path: C:\\Users\\Documents"))
    end

    test "extracts from all fixtures with deduplication" do
      files = [
        Path.join(@fixtures_path, "UserProfile.svelte"),
        Path.join(@fixtures_path, "ShoppingCart.svelte"),
        Path.join(@fixtures_path, "ErrorMessages.svelte")
      ]

      result = Extractor.extract_all(files)

      # Should have deduplicated results
      assert length(result) > 0

      # Each msgid should appear only once
      msgids = Enum.map(result, & &1.msgid)
      assert length(msgids) == length(Enum.uniq(msgids))

      # All results should have file references
      assert Enum.all?(result, fn extraction ->
               is_list(extraction.references) && length(extraction.references) > 0
             end)

      # Verify structure of extractions
      assert Enum.all?(result, fn extraction ->
               is_binary(extraction.msgid) &&
                 extraction.type in [:gettext, :ngettext] &&
                 (extraction.plural == nil || is_binary(extraction.plural))
             end)
    end

    test "counts expected extractions from all fixtures" do
      files = [
        Path.join(@fixtures_path, "UserProfile.svelte"),
        Path.join(@fixtures_path, "ShoppingCart.svelte"),
        Path.join(@fixtures_path, "ErrorMessages.svelte")
      ]

      result = Extractor.extract_all(files)

      # Count gettext vs ngettext
      gettext_count = Enum.count(result, &(&1.type == :gettext))
      ngettext_count = Enum.count(result, &(&1.type == :ngettext))

      # UserProfile: 10 gettext + 1 ngettext = 11
      # ShoppingCart: 5 gettext + 1 ngettext = 6
      # ErrorMessages: 8 gettext + 0 ngettext = 8
      # Total: 23 gettext, 2 ngettext (with deduplication if any overlap)

      assert gettext_count >= 20
      assert ngettext_count == 2
    end
  end
end
