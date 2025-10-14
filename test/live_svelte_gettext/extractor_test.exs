defmodule LiveSvelteGettext.ExtractorTest do
  use ExUnit.Case, async: true

  alias LiveSvelteGettext.Extractor

  describe "extract_from_content/2" do
    test "extracts simple gettext call with double quotes" do
      content = ~s|<button>{gettext("Save")}</button>|
      result = Extractor.extract_from_content(content, "test.svelte")

      assert [%{msgid: "Save", type: :gettext, plural: nil}] = result
      assert [%{references: [{"test.svelte", 1}]}] = result
    end

    test "extracts simple gettext call with single quotes" do
      content = ~s|<button>{gettext('Save')}</button>|
      result = Extractor.extract_from_content(content, "test.svelte")

      assert [%{msgid: "Save", type: :gettext, plural: nil}] = result
    end

    test "extracts gettext with interpolation variables" do
      content = ~s|{gettext("Step %{n} of %{total}", {n: 1, total: 10})}|
      result = Extractor.extract_from_content(content, "test.svelte")

      assert [%{msgid: "Step %{n} of %{total}", type: :gettext}] = result
    end

    test "extracts gettext with object-style variables" do
      content = ~s|{gettext("Hello %{name}", { name })}|
      result = Extractor.extract_from_content(content, "test.svelte")

      assert [%{msgid: "Hello %{name}", type: :gettext}] = result
    end

    test "handles escaped double quotes" do
      content = ~s|{gettext("It\\"s \\"great\\"")}|
      result = Extractor.extract_from_content(content, "test.svelte")

      assert [%{msgid: ~s|It"s "great"|, type: :gettext}] = result
    end

    test "handles escaped single quotes" do
      content = ~s|{gettext('It\\'s \\'great\\'')}|
      result = Extractor.extract_from_content(content, "test.svelte")

      assert [%{msgid: ~s|It's 'great'|, type: :gettext}] = result
    end

    test "handles backslashes" do
      content = ~s|{gettext("Path: C:\\\\Users\\\\name")}|
      result = Extractor.extract_from_content(content, "test.svelte")

      assert [%{msgid: "Path: C:\\Users\\name", type: :gettext}] = result
    end

    test "extracts ngettext with double quotes" do
      content = ~s|{ngettext("%{count} item", "%{count} items", count)}|
      result = Extractor.extract_from_content(content, "test.svelte")

      assert [
               %{
                 msgid: "%{count} item",
                 type: :ngettext,
                 plural: "%{count} items"
               }
             ] = result
    end

    test "extracts ngettext with single quotes" do
      content = ~s|{ngettext('%{n} file', '%{n} files', n)}|
      result = Extractor.extract_from_content(content, "test.svelte")

      assert [
               %{
                 msgid: "%{n} file",
                 type: :ngettext,
                 plural: "%{n} files"
               }
             ] = result
    end

    test "tracks correct line numbers" do
      content = """
      <script>
        const text = gettext("Line 2");
      </script>
      <div>
        {gettext("Line 5")}
      </div>
      """

      result = Extractor.extract_from_content(content, "test.svelte")

      assert length(result) == 2

      assert Enum.any?(result, fn %{msgid: msg, references: refs} ->
               msg == "Line 2" && refs == [{"test.svelte", 2}]
             end)

      assert Enum.any?(result, fn %{msgid: msg, references: refs} ->
               msg == "Line 5" && refs == [{"test.svelte", 5}]
             end)
    end

    test "extracts multiple gettext calls on same line" do
      content = ~s|{gettext("First")} and {gettext("Second")}|
      result = Extractor.extract_from_content(content, "test.svelte")

      assert length(result) == 2
      assert Enum.any?(result, &(&1.msgid == "First"))
      assert Enum.any?(result, &(&1.msgid == "Second"))
    end

    test "handles whitespace variations" do
      content = ~s|{gettext(  "Spaces"  )}|
      result = Extractor.extract_from_content(content, "test.svelte")

      assert [%{msgid: "Spaces"}] = result
    end

    test "ignores gettext in comments" do
      content = """
      <!-- {gettext("Commented")} -->
      {gettext("Not commented")}
      """

      result = Extractor.extract_from_content(content, "test.svelte")

      # Should only extract the non-commented one
      assert [%{msgid: "Not commented"}] = result
    end

    test "returns empty list for non-existent file" do
      result = Extractor.extract_from_file("/non/existent/file.svelte")

      assert result == []
    end
  end

  describe "extract_from_file/1" do
    setup do
      # Create a temporary test file
      dir = System.tmp_dir!()
      path = Path.join(dir, "test_component_#{System.unique_integer([:positive])}.svelte")

      content = """
      <script>
        import { gettext } from '../translations';
      </script>

      <button>{gettext("Save Profile")}</button>
      <p>{ngettext("%{n} item", "%{n} items", count)}</p>
      """

      File.write!(path, content)

      on_exit(fn -> File.rm(path) end)

      {:ok, path: path}
    end

    test "extracts from actual file", %{path: path} do
      result = Extractor.extract_from_file(path)

      assert length(result) == 2
      assert Enum.any?(result, &(&1.msgid == "Save Profile" && &1.type == :gettext))

      assert Enum.any?(result, &(&1.msgid == "%{n} item" && &1.type == :ngettext))
    end
  end

  describe "extract_all/1" do
    setup do
      dir = System.tmp_dir!()
      subdir = Path.join(dir, "svelte_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(subdir)

      file1 = Path.join(subdir, "component1.svelte")
      file2 = Path.join(subdir, "component2.svelte")

      File.write!(file1, ~s|{gettext("Hello")}|)
      File.write!(file2, ~s|{gettext("Hello")}\n{gettext("World")}|)

      on_exit(fn ->
        File.rm(file1)
        File.rm(file2)
        File.rmdir(subdir)
      end)

      {:ok, files: [file1, file2]}
    end

    test "extracts from multiple files", %{files: files} do
      result = Extractor.extract_all(files)

      assert length(result) == 2
      assert Enum.any?(result, &(&1.msgid == "Hello"))
      assert Enum.any?(result, &(&1.msgid == "World"))
    end

    test "deduplicates across files", %{files: [file1, file2]} do
      result = Extractor.extract_all([file1, file2])

      # "Hello" appears in both files
      hello_entry = Enum.find(result, &(&1.msgid == "Hello"))
      assert length(hello_entry.references) == 2

      assert Enum.any?(hello_entry.references, fn {file, _line} ->
               String.ends_with?(file, "component1.svelte")
             end)

      assert Enum.any?(hello_entry.references, fn {file, _line} ->
               String.ends_with?(file, "component2.svelte")
             end)
    end
  end

  describe "deduplicate/1" do
    test "merges references for duplicate gettext strings" do
      extractions = [
        %{msgid: "Save", type: :gettext, plural: nil, references: [{"a.svelte", 1}]},
        %{msgid: "Save", type: :gettext, plural: nil, references: [{"b.svelte", 5}]},
        %{msgid: "Save", type: :gettext, plural: nil, references: [{"c.svelte", 10}]}
      ]

      result = Extractor.deduplicate(extractions)

      assert [%{msgid: "Save", references: refs}] = result
      assert length(refs) == 3
      assert {"a.svelte", 1} in refs
      assert {"b.svelte", 5} in refs
      assert {"c.svelte", 10} in refs
    end

    test "merges references for duplicate ngettext strings" do
      extractions = [
        %{
          msgid: "%{n} item",
          type: :ngettext,
          plural: "%{n} items",
          references: [{"a.svelte", 1}]
        },
        %{
          msgid: "%{n} item",
          type: :ngettext,
          plural: "%{n} items",
          references: [{"b.svelte", 2}]
        }
      ]

      result = Extractor.deduplicate(extractions)

      assert [%{msgid: "%{n} item", plural: "%{n} items", references: refs}] = result
      assert length(refs) == 2
    end

    test "keeps different strings separate" do
      extractions = [
        %{msgid: "Save", type: :gettext, plural: nil, references: [{"a.svelte", 1}]},
        %{msgid: "Cancel", type: :gettext, plural: nil, references: [{"a.svelte", 2}]}
      ]

      result = Extractor.deduplicate(extractions)

      assert length(result) == 2
      assert Enum.any?(result, &(&1.msgid == "Save"))
      assert Enum.any?(result, &(&1.msgid == "Cancel"))
    end

    test "treats gettext and ngettext as different types" do
      extractions = [
        %{msgid: "Item", type: :gettext, plural: nil, references: [{"a.svelte", 1}]},
        %{msgid: "Item", type: :ngettext, plural: "Items", references: [{"a.svelte", 2}]}
      ]

      result = Extractor.deduplicate(extractions)

      assert length(result) == 2
      assert Enum.any?(result, &(&1.type == :gettext && &1.msgid == "Item"))
      assert Enum.any?(result, &(&1.type == :ngettext && &1.msgid == "Item"))
    end
  end

  describe "path relativization" do
    test "converts absolute paths to relative paths" do
      # Create a temp file in the project directory
      cwd = File.cwd!()
      rel_path = "test/fixtures/test_path.svelte"
      abs_path = Path.join(cwd, rel_path)

      # Create the file
      File.write!(abs_path, ~s|{gettext("Test")}|)

      on_exit(fn -> File.rm(abs_path) end)

      # Extract from the absolute path
      result = Extractor.extract_from_file(abs_path)

      # The references should contain relative paths, not absolute
      assert [%{references: [{file, _line}]}] = result
      assert file == rel_path
      refute String.starts_with?(file, cwd)
    end

    test "leaves relative paths unchanged" do
      # Use an existing fixture file
      rel_path = "test/fixtures/UserProfile.svelte"

      result = Extractor.extract_from_file(rel_path)

      # All references should remain relative
      Enum.each(result, fn %{references: refs} ->
        Enum.each(refs, fn {file, _line} ->
          # Should be relative (no leading slash on Unix, no drive letter on Windows)
          refute String.starts_with?(file, "/")
          refute String.match?(file, ~r/^[A-Z]:/)
        end)
      end)
    end

    test "handles paths outside project directory" do
      # Create a temp file outside the project
      temp_dir = System.tmp_dir!()
      temp_file = Path.join(temp_dir, "outside_#{System.unique_integer([:positive])}.svelte")

      File.write!(temp_file, ~s|{gettext("Outside")}|)

      on_exit(fn -> File.rm(temp_file) end)

      result = Extractor.extract_from_file(temp_file)

      # Paths outside the project should be kept as absolute
      assert [%{references: [{file, _line}]}] = result
      assert file == temp_file
      assert String.starts_with?(file, temp_dir)
    end
  end
end
