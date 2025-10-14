defmodule Mix.Tasks.LiveSvelteGettext.FixReferences do
  @moduledoc """
  Fixes POT/PO file references to point to original Svelte files.

  > ⚠️ **Note**: As of v0.1.0, LiveSvelteGettext uses `CustomExtractor` to automatically
  > inject correct Svelte file references during `mix gettext.extract`. This task is now
  > primarily a **fallback/troubleshooting tool** for edge cases where automatic extraction
  > doesn't work as expected.

  ## When to Use This Task

  You typically **don't need** this task because:
  - `CustomExtractor` automatically handles references during extraction
  - POT files will already contain correct Svelte file paths

  Use this task only if:
  - You're migrating from an older version with incorrect references
  - You have existing POT files that need reference fixing
  - CustomExtractor isn't working in your specific setup (please report as bug!)
  - You're troubleshooting reference issues

  ## Usage

      mix live_svelte_gettext.fix_references

  Or run both extraction and fixing in one command:

      mix gettext.extract && mix live_svelte_gettext.fix_references

  ## How it works

  1. Finds all modules that use LiveSvelteGettext
  2. Reads the extraction metadata from each module
  3. Builds a mapping of msgid -> original Svelte file:line references
  4. Updates all .pot and .po files, replacing module references with Svelte references

  ## Options

    * `--gettext-path` - Path to gettext directory (default: "priv/gettext")
    * `--dry-run` - Show what would be changed without making changes
  """

  use Mix.Task

  @shortdoc "Fixes POT/PO file references to point to Svelte source files"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")

    {opts, _} =
      OptionParser.parse!(args,
        strict: [gettext_path: :string, dry_run: :boolean],
        aliases: [n: :dry_run]
      )

    gettext_path = opts[:gettext_path] || "priv/gettext"
    dry_run = opts[:dry_run] || false

    announce_dry_run_if_needed(dry_run)

    modules = find_and_validate_modules()
    reference_map = build_and_announce_reference_map(modules)
    po_files = find_and_validate_po_files(gettext_path)

    {total_replacements, files_modified} =
      Enum.reduce(po_files, {0, 0}, fn file, acc ->
        process_and_report_file(file, reference_map, dry_run, acc)
      end)

    report_final_results(dry_run, total_replacements, files_modified)
  end

  defp announce_dry_run_if_needed(true) do
    Mix.shell().info("Running in dry-run mode - no files will be modified")
  end

  defp announce_dry_run_if_needed(false), do: :ok

  defp find_and_validate_modules do
    modules = find_lsg_modules()

    if Enum.empty?(modules) do
      Mix.shell().error("No modules found that use LiveSvelteGettext")
      exit({:shutdown, 1})
    end

    Mix.shell().info("Found #{length(modules)} LiveSvelteGettext module(s)")
    modules
  end

  defp build_and_announce_reference_map(modules) do
    reference_map = build_reference_map(modules)
    Mix.shell().info("Built reference map with #{map_size(reference_map)} entries")
    reference_map
  end

  defp find_and_validate_po_files(gettext_path) do
    po_files = find_po_files(gettext_path)

    if Enum.empty?(po_files) do
      Mix.shell().error("No .pot or .po files found in #{gettext_path}")
      exit({:shutdown, 1})
    end

    Mix.shell().info("Found #{length(po_files)} PO/POT files to update")
    po_files
  end

  defp report_final_results(true, total, files) do
    Mix.shell().info("\nDry run complete: would have fixed #{total} references in #{files} files")
  end

  defp report_final_results(false, total, files) do
    Mix.shell().info("\nSuccessfully fixed #{total} references in #{files} files")
  end

  defp process_and_report_file(file, reference_map, dry_run, {total_count, file_count}) do
    {replacements, modified?} = process_po_file(file, reference_map, dry_run)

    if replacements > 0 do
      action = if dry_run, do: "Would update", else: "Updated"
      Mix.shell().info("  #{action} #{file} (#{replacements} references)")
      {total_count + replacements, file_count + if(modified?, do: 1, else: 0)}
    else
      {total_count, file_count}
    end
  end

  # Find all compiled modules that use LiveSvelteGettext
  defp find_lsg_modules do
    :code.all_loaded()
    |> Enum.map(&elem(&1, 0))
    |> Enum.filter(fn module ->
      function_exported?(module, :__lsg_metadata__, 0)
    end)
  end

  # Build a map of msgid+type -> list of references
  defp build_reference_map(modules) do
    Enum.reduce(modules, %{}, fn module, acc ->
      metadata = module.__lsg_metadata__()

      Enum.reduce(metadata.extractions, acc, fn extraction, map_acc ->
        key = build_key(extraction)
        Map.put(map_acc, key, extraction.references)
      end)
    end)
  end

  # Build a unique key for each extraction (msgid + type + plural)
  defp build_key(extraction) do
    case extraction.type do
      :gettext -> {:gettext, extraction.msgid}
      :ngettext -> {:ngettext, extraction.msgid, extraction.plural}
    end
  end

  # Find all .pot and .po files in the gettext directory
  defp find_po_files(gettext_path) do
    Path.join([gettext_path, "**", "*.{pot,po}"])
    |> Path.wildcard()
    |> Enum.sort()
  end

  # Process a single .pot or .po file
  defp process_po_file(file, reference_map, dry_run) do
    content = File.read!(file)
    {new_content, replacements} = fix_references_in_content(content, reference_map, file)

    modified? = content != new_content

    unless dry_run or not modified? do
      File.write!(file, new_content)
    end

    {replacements, modified?}
  end

  # Fix all references in PO file content
  defp fix_references_in_content(content, reference_map, _file) do
    # Parse the content line by line, tracking current entry
    lines = String.split(content, "\n")
    {new_lines, replacements} = process_lines(lines, reference_map, nil, [], 0)

    {Enum.join(new_lines, "\n"), replacements}
  end

  # Process lines, tracking the current msgid being parsed
  # Note: We need to buffer reference lines until we know if it's gettext or ngettext
  defp process_lines([], _reference_map, _current_msgid, acc, count) do
    {Enum.reverse(acc), count}
  end

  defp process_lines([line | rest], reference_map, current_msgid, acc, count) do
    cond do
      # Track msgid (singular gettext or ngettext)
      String.starts_with?(line, "msgid ") and line != ~s(msgid "") ->
        msgid = extract_string(line)
        # Look ahead to see if there's a msgid_plural
        {plural, remaining_lines} = look_for_plural(rest)

        if plural do
          # ngettext - fix any buffered references
          new_msgid = {:msgid, msgid, plural}
          {fixed_acc, new_count} = fix_buffered_references(acc, new_msgid, reference_map, count)
          # Continue processing after the msgid_plural line
          process_lines(remaining_lines, reference_map, new_msgid, [line | fixed_acc], new_count)
        else
          # Simple gettext
          new_msgid = {:msgid, msgid, nil}
          {fixed_acc, new_count} = fix_buffered_references(acc, new_msgid, reference_map, count)
          process_lines(rest, reference_map, new_msgid, [line | fixed_acc], new_count)
        end

      # Skip msgid_plural here since we handle it in look-ahead
      String.starts_with?(line, "msgid_plural ") ->
        process_lines(rest, reference_map, current_msgid, [line | acc], count)

      # Buffer reference lines (don't fix yet - we need to know if it's ngettext)
      String.starts_with?(line, "#: ") ->
        process_lines(rest, reference_map, current_msgid, [line | acc], count)

      # Reset current_msgid on empty line (start of new entry)
      String.trim(line) == "" ->
        process_lines(rest, reference_map, nil, [line | acc], count)

      # Keep other lines as-is
      true ->
        process_lines(rest, reference_map, current_msgid, [line | acc], count)
    end
  end

  # Look ahead in the lines to find msgid_plural (if it exists)
  defp look_for_plural([]), do: {nil, []}

  defp look_for_plural([line | rest] = lines) do
    cond do
      String.starts_with?(line, "msgid_plural ") ->
        {extract_string(line), rest}

      String.starts_with?(line, "msgid ") or String.trim(line) == "" ->
        # Hit next entry or empty line - no plural
        {nil, lines}

      true ->
        # Keep looking
        look_for_plural(rest)
    end
  end

  # Fix any buffered reference lines now that we know the full msgid+plural
  defp fix_buffered_references(acc, msgid_info, reference_map, count) do
    {new_acc, new_count} =
      Enum.reduce(acc, {[], count}, fn line, {lacc, lcount} ->
        if String.starts_with?(line, "#: ") do
          {new_line, replaced?} = fix_reference_line(line, msgid_info, reference_map)
          {[new_line | lacc], if(replaced?, do: lcount + 1, else: lcount)}
        else
          {[line | lacc], lcount}
        end
      end)

    {Enum.reverse(new_acc), new_count}
  end

  # Fix a single reference line
  defp fix_reference_line(line, current_msgid, reference_map) do
    # Only fix lines that reference svelte_strings.ex (generated module)
    # Leave other references (from .ex, .heex files) untouched
    if String.contains?(line, "svelte_strings.ex") do
      do_fix_reference_line(line, current_msgid, reference_map)
    else
      {line, false}
    end
  end

  defp do_fix_reference_line(line, {:msgid, msgid, nil}, reference_map) do
    # Simple gettext
    key = {:gettext, msgid}
    apply_reference_replacement(line, reference_map, key)
  end

  defp do_fix_reference_line(line, {:msgid, msgid, plural}, reference_map)
       when is_binary(plural) do
    # ngettext with plural
    key = {:ngettext, msgid, plural}
    apply_reference_replacement(line, reference_map, key)
  end

  defp apply_reference_replacement(line, reference_map, key) do
    case Map.get(reference_map, key) do
      nil -> {line, false}
      references -> {build_reference_line(references), true}
    end
  end

  # Build a new reference line from a list of {file, line} tuples
  defp build_reference_line(references) do
    refs_str = Enum.map_join(references, " ", fn {file, line} -> "#{file}:#{line}" end)
    "#: #{refs_str}"
  end

  # Extract string from msgid or msgid_plural line
  # Note: This is a simplified parser that assumes strings fit on one line
  # For multiline strings, PO files use continuation, but our generated strings
  # from Svelte are typically single-line
  defp extract_string(line) do
    case Regex.run(~r/^msgid(?:_plural)?\s+"(.*)"/, line) do
      [_, captured] -> unescape_string(captured)
      nil -> ""
    end
  end

  # Unescape PO file string escapes
  defp unescape_string(str) do
    str
    |> String.replace(~r/\\n/, "\n")
    |> String.replace(~r/\\t/, "\t")
    |> String.replace(~r/\\"/, "\"")
    |> String.replace(~r/\\\\/, "\\")
  end
end
