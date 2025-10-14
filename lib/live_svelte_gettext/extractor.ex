defmodule LiveSvelteGettext.Extractor do
  @moduledoc """
  Extracts translation strings from Svelte component files.

  Scans `.svelte` files for `gettext()` and `ngettext()` calls and extracts
  the translation strings with their file and line number metadata.

  ## Supported Patterns

  - `gettext("string")` - Simple translation
  - `gettext("string", {...})` - Translation with interpolation variables
  - `ngettext("singular", "plural", count)` - Plural forms
  - Both single (`'`) and double (`"`) quotes
  - Escaped quotes (`\\'` and `\\"`)
  - Multiple calls per line

  ## Examples

      iex> content = ~s|<button>{gettext("Save")}</button>|
      iex> LiveSvelteGettext.Extractor.extract_from_content(content, "button.svelte")
      [%{
        msgid: "Save",
        type: :gettext,
        plural: nil,
        references: [{"button.svelte", 1}]
      }]

  """

  @type extraction :: %{
          msgid: String.t(),
          type: :gettext | :ngettext,
          plural: String.t() | nil,
          references: [{file :: String.t(), line :: integer()}]
        }

  @doc """
  Extracts all translation strings from a list of Svelte files.

  Returns deduplicated extractions with all file:line references merged.

  ## Examples

      iex> files = ["component1.svelte", "component2.svelte"]
      iex> LiveSvelteGettext.Extractor.extract_all(files)
      [%{msgid: "Save", type: :gettext, plural: nil, references: [...]}, ...]

  """
  @spec extract_all([Path.t()]) :: [extraction()]
  def extract_all(files) do
    files
    |> Enum.flat_map(&extract_from_file/1)
    |> deduplicate()
  end

  @doc """
  Extracts translation strings from a single Svelte file.

  Returns an empty list if the file cannot be read.

  ## Examples

      iex> LiveSvelteGettext.Extractor.extract_from_file("component.svelte")
      [%{msgid: "Hello", type: :gettext, ...}]

  """
  @spec extract_from_file(Path.t()) :: [extraction()]
  def extract_from_file(file) do
    case File.read(file) do
      {:ok, content} ->
        # Convert to relative path for storage
        relative_file = make_path_relative(file)
        extract_from_content(content, relative_file)

      {:error, _reason} ->
        []
    end
  end

  # Convert absolute file paths to relative paths
  defp make_path_relative(file_path) do
    cwd = File.cwd!()

    case String.starts_with?(file_path, cwd) do
      true -> Path.relative_to(file_path, cwd)
      false -> file_path
    end
  end

  @doc """
  Extracts translation strings from Svelte file content.

  ## Examples

      iex> content = ~s|{gettext("Save")}|
      iex> LiveSvelteGettext.Extractor.extract_from_content(content, "test.svelte")
      [%{msgid: "Save", type: :gettext, plural: nil, references: [{"test.svelte", 1}]}]

  """
  @spec extract_from_content(String.t(), String.t()) :: [extraction()]
  def extract_from_content(content, file) do
    # Remove HTML comments to avoid extracting from commented code
    content_without_comments = remove_html_comments(content)

    gettext = extract_gettext(content_without_comments, file)
    ngettext = extract_ngettext(content_without_comments, file)

    gettext ++ ngettext
  end

  @doc """
  Deduplicates extractions by merging references for identical msgid/type/plural combinations.

  ## Examples

      iex> extractions = [
      ...>   %{msgid: "Save", type: :gettext, plural: nil, references: [{"a.svelte", 1}]},
      ...>   %{msgid: "Save", type: :gettext, plural: nil, references: [{"b.svelte", 5}]}
      ...> ]
      iex> LiveSvelteGettext.Extractor.deduplicate(extractions)
      [%{msgid: "Save", type: :gettext, plural: nil, references: [{"a.svelte", 1}, {"b.svelte", 5}]}]

  """
  @spec deduplicate([extraction()]) :: [extraction()]
  def deduplicate(extractions) do
    extractions
    |> Enum.group_by(fn %{msgid: msgid, type: type, plural: plural} ->
      {msgid, type, plural}
    end)
    |> Enum.map(fn {_key, group} ->
      # Merge all references from the group
      all_references =
        group
        |> Enum.flat_map(& &1.references)
        |> Enum.uniq()

      # Take the first entry as template and merge references
      %{List.first(group) | references: all_references}
    end)
    |> Enum.sort_by(& &1.msgid)
  end

  # Private functions

  # Extract gettext("string") and gettext("string", {...})
  defp extract_gettext(content, file) do
    # Match gettext with either single or double quotes
    # Captures: msgid (with possible escaped characters)
    # Optional: second argument with interpolation object
    regex = ~r/gettext\s*\(\s*(['"])([^\1]*?(?:\\.[^\1]*?)*)\1(?:\s*,\s*\{[^}]*\})?\s*\)/

    extract_with_regex(content, file, regex, fn [quote_char, msgid] ->
      %{
        msgid: unescape_string(msgid, quote_char),
        type: :gettext,
        plural: nil
      }
    end)
  end

  # Extract ngettext("singular", "plural", count)
  defp extract_ngettext(content, file) do
    # Match ngettext with two string arguments
    # Captures: singular (with quote), singular string, plural (with quote), plural string
    regex =
      ~r/ngettext\s*\(\s*(['"])([^\1]*?(?:\\.[^\1]*?)*)\1\s*,\s*(['"])([^\3]*?(?:\\.[^\3]*?)*)\3\s*,/

    extract_with_regex(content, file, regex, fn [
                                                  singular_quote,
                                                  singular,
                                                  plural_quote,
                                                  plural
                                                ] ->
      %{
        msgid: unescape_string(singular, singular_quote),
        type: :ngettext,
        plural: unescape_string(plural, plural_quote)
      }
    end)
  end

  # Generic extraction with a regex pattern
  defp extract_with_regex(content, file, regex, transform_fn) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_number} ->
      Regex.scan(regex, line)
      |> Enum.map(fn [_full_match | captures] ->
        extraction = transform_fn.(captures)
        Map.put(extraction, :references, [{file, line_number}])
      end)
    end)
  end

  # Unescape string literals (handles \", \', \\, etc.)
  defp unescape_string(str, _quote_char) do
    str
    |> String.replace(~r/\\(.)/, fn match ->
      # Extract the character after the backslash
      <<_backslash, char::binary>> = match
      char
    end)
  end

  # Remove HTML comments to avoid extracting from commented code
  defp remove_html_comments(content) do
    String.replace(content, ~r/<!--.*?-->/s, "")
  end
end
