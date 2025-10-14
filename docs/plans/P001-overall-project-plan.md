# LiveSvelteGettext - Elixir Library Project Plan

**Project Type:** Elixir Library (Hex Package)
**Goal:** Create a zero-maintenance i18n solution for Phoenix + Svelte applications using compile-time extraction and macro magic
**Status:** Planning Phase
**Created:** 2025-10-13

---

## Executive Summary

Build `live_svelte_gettext` - an Elixir library that automatically extracts translation strings from Svelte components at compile time, integrates seamlessly with Phoenix Gettext, and provides a TypeScript client library for runtime translations. No generated files to commit, no manual maintenance, just pure compile-time magic.

**Key Innovation:** Uses Elixir macros and `@external_resource` to scan Svelte files at compile time, generating `gettext()` calls that standard Gettext extraction can discover, while also providing a runtime `all_translations()` function - all without committing generated code.

---

## Project Goals

### Primary Goals
1. **Zero Manual Maintenance** - Developers add `gettext()` in Svelte, everything else is automatic
2. **Compile-Time Extraction** - No generated files to version control
3. **Standard Gettext Integration** - Works with existing `mix gettext.extract` workflow
4. **Type-Safe Client** - TypeScript library with full type safety
5. **Easy Installation** - One-command setup via Igniter installer

### Success Criteria
- [ ] Library published to Hex.pm
- [ ] Comprehensive documentation with examples
- [ ] Test coverage > 90%
- [ ] Igniter installer working in fresh Phoenix apps
- [ ] TypeScript types published to npm
- [ ] Adoption by at least 3 external projects

---

## Technical Architecture

### Core Components

```
live_svelte_gettext/
├── lib/
│   ├── live_svelte_gettext.ex              # Main `use` macro
│   └── live_svelte_gettext/
│       ├── extractor.ex                   # String extraction from Svelte files
│       ├── compiler.ex                    # Compile-time macro magic
│       ├── runtime.ex                     # Runtime translation helpers
│       └── config.ex                      # Configuration validation
├── priv/
│   └── templates/
│       ├── translations.ts.eex            # TypeScript client template
│       └── igniter/
│           └── setup.ex.eex               # Igniter installer template
├── assets/
│   └── js/
│       ├── translations.ts                # TypeScript client source
│       └── package.json                   # npm package metadata
├── test/
│   ├── live_svelte_gettext_test.exs
│   ├── extractor_test.exs
│   └── fixtures/
│       └── example_components/            # Test Svelte files
├── mix.exs                                # Library configuration
├── README.md                              # Primary documentation
├── CHANGELOG.md                           # Version history
├── LICENSE                                # MIT License
└── .formatter.exs                         # Code formatting config
```

### Macro-Based Architecture (Option 2)

**Key Insight:** Macros run at compile time, so we can:
1. Scan Svelte files during compilation
2. Generate AST nodes with `gettext()` calls
3. Provide runtime `all_translations()` function
4. Use `@external_resource` for automatic recompilation

**User Code:**
```elixir
# In user's Phoenix app
defmodule MyAppWeb.Gettext.SvelteStrings do
  use LiveSvelteGettext,
    gettext_backend: MyAppWeb.Gettext,
    svelte_path: "assets/svelte/**/*.svelte"
end
```

**What the macro does:**
```elixir
defmacro __using__(opts) do
  backend = Keyword.fetch!(opts, :gettext_backend)
  svelte_path = Keyword.fetch!(opts, :svelte_path)

  # This runs at COMPILE TIME
  svelte_files = Path.wildcard(svelte_path)

  # Extract all strings from Svelte files
  strings = LiveSvelteGettext.Extractor.extract_all(svelte_files)

  quote do
    use Gettext, backend: unquote(backend)

    # Mark Svelte files as external resources (triggers recompilation)
    unquote(
      for file <- svelte_files do
        quote do: @external_resource unquote(file)
      end
    )

    # Generate gettext calls for extraction
    unquote(
      for {msgid, _meta} <- strings do
        quote do: gettext(unquote(msgid))
      end
    )

    # Generate ngettext calls for plurals
    unquote(
      for {singular, plural, _meta} <- extract_ngettext(strings) do
        quote do: ngettext(unquote(singular), unquote(plural), 1)
      end
    )

    # Runtime function
    def all_translations do
      unquote(
        Macro.escape(
          for {msgid, _meta} <- strings, into: %{} do
            # This will be executed at RUNTIME with current locale
            quote do: {unquote(msgid), gettext(unquote(msgid))}
          end
        )
      )
    end
  end
end
```

---

## Implementation Phases

### Phase 1: Core Extraction Engine (Week 1-2)

**Objective:** Build the Svelte string extraction logic

**Deliverables:**
- [ ] `LiveSvelteGettext.Extractor` module
  - [ ] Extract `gettext("string")` calls
  - [ ] Extract `gettext("string", %{vars})` with interpolation
  - [ ] Extract `ngettext("singular", "plural", count)` calls
  - [ ] Handle single and double quotes
  - [ ] Handle escaped quotes
  - [ ] Track file:line metadata
- [ ] Deduplication logic
  - [ ] Group by msgid
  - [ ] Preserve all file:line references
  - [ ] Handle singular/plural pairs
- [ ] Comprehensive tests
  - [ ] Unit tests for regex patterns
  - [ ] Integration tests with fixture Svelte files
  - [ ] Edge cases (multiline, comments, nested strings)

**Implementation Details:**

```elixir
defmodule LiveSvelteGettext.Extractor do
  @moduledoc """
  Extracts translation strings from Svelte component files.
  """

  @type extraction :: %{
    msgid: String.t(),
    type: :gettext | :ngettext,
    plural: String.t() | nil,
    references: [{file :: String.t(), line :: integer()}]
  }

  @doc """
  Extracts all translation strings from a list of Svelte files.
  Returns deduplicated extractions with metadata.
  """
  @spec extract_all([Path.t()]) :: [extraction()]
  def extract_all(files) do
    files
    |> Enum.flat_map(&extract_from_file/1)
    |> deduplicate()
  end

  @doc """
  Extracts translation strings from a single Svelte file.
  """
  @spec extract_from_file(Path.t()) :: [extraction()]
  def extract_from_file(file) do
    case File.read(file) do
      {:ok, content} ->
        gettext = extract_gettext(content, file)
        ngettext = extract_ngettext(content, file)
        gettext ++ ngettext

      {:error, _reason} ->
        []
    end
  end

  # Extract gettext("string") and gettext("string", {...})
  defp extract_gettext(content, file) do
    # Regex: matches gettext with single or double quotes
    regex = ~r/gettext\s*\(\s*["']([^"'\\]*(\\.[^"'\\]*)*)["']\s*(?:,\s*\{[^}]*\})?\s*\)/

    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_number} ->
      Regex.scan(regex, line, capture: :all_but_first)
      |> Enum.map(fn [msgid | _] ->
        %{
          msgid: unescape_string(msgid),
          type: :gettext,
          plural: nil,
          references: [{file, line_number}]
        }
      end)
    end)
  end

  # Extract ngettext("singular", "plural", count)
  defp extract_ngettext(content, file) do
    regex = ~r/ngettext\s*\(\s*["']([^"'\\]*(\\.[^"'\\]*)*)["']\s*,\s*["']([^"'\\]*(\\.[^"'\\]*)*)["']\s*,/

    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_number} ->
      Regex.scan(regex, line, capture: :all_but_first)
      |> Enum.map(fn [singular, _, plural | _] ->
        %{
          msgid: unescape_string(singular),
          type: :ngettext,
          plural: unescape_string(plural),
          references: [{file, line_number}]
        }
      end)
    end)
  end

  # Deduplicate extractions, merging references
  defp deduplicate(extractions) do
    extractions
    |> Enum.group_by(fn %{msgid: msgid, type: type, plural: plural} ->
      {msgid, type, plural}
    end)
    |> Enum.map(fn {_key, group} ->
      references = Enum.flat_map(group, & &1.references)
      %{List.first(group) | references: references}
    end)
  end

  defp unescape_string(str) do
    str
    |> String.replace(~r/\\(.)/, "\\1")
  end
end
```

**Testing Strategy:**

```elixir
defmodule LiveSvelteGettext.ExtractorTest do
  use ExUnit.Case, async: true

  alias LiveSvelteGettext.Extractor

  describe "extract_gettext/2" do
    test "extracts simple gettext call" do
      content = ~s|<button>{gettext("Save")}</button>|
      result = Extractor.extract_from_file_content(content, "test.svelte")

      assert [%{msgid: "Save", type: :gettext}] = result
    end

    test "extracts gettext with variables" do
      content = ~s|{gettext("Step %{n} of %{total}", {n: 1, total: 10})}|
      result = Extractor.extract_from_file_content(content, "test.svelte")

      assert [%{msgid: "Step %{n} of %{total}", type: :gettext}] = result
    end

    test "handles escaped quotes" do
      content = ~s|{gettext("It's \"great\"")}|
      result = Extractor.extract_from_file_content(content, "test.svelte")

      assert [%{msgid: ~s|It's "great"|, type: :gettext}] = result
    end
  end

  describe "extract_ngettext/2" do
    test "extracts ngettext plural forms" do
      content = ~s|{ngettext("%{n} item", "%{n} items", count)}|
      result = Extractor.extract_from_file_content(content, "test.svelte")

      assert [%{msgid: "%{n} item", plural: "%{n} items", type: :ngettext}] = result
    end
  end

  describe "deduplicate/1" do
    test "merges references for duplicate strings" do
      extractions = [
        %{msgid: "Save", type: :gettext, plural: nil, references: [{"a.svelte", 1}]},
        %{msgid: "Save", type: :gettext, plural: nil, references: [{"b.svelte", 5}]}
      ]

      result = Extractor.deduplicate(extractions)

      assert [%{msgid: "Save", references: refs}] = result
      assert length(refs) == 2
    end
  end
end
```

---

### Phase 2: Compile-Time Macro System (Week 2-3)

**Objective:** Build the `use LiveSvelteGettext` macro that generates code at compile time

**Deliverables:**
- [ ] `LiveSvelteGettext` main module with `__using__/1` macro
- [ ] `LiveSvelteGettext.Compiler` for AST generation
- [ ] Configuration validation
- [ ] `@external_resource` integration
- [ ] Runtime `all_translations()` function generation
- [ ] Tests for generated code

**Implementation:**

```elixir
defmodule LiveSvelteGettext do
  @moduledoc """
  Automatic translation extraction from Svelte components for Phoenix Gettext.

  ## Usage

      defmodule MyAppWeb.Gettext.SvelteStrings do
        use LiveSvelteGettext,
          gettext_backend: MyAppWeb.Gettext,
          svelte_path: "assets/svelte/**/*.svelte"
      end

  ## How it works

  1. At compile time, scans all Svelte files matching `svelte_path`
  2. Extracts `gettext()` and `ngettext()` calls
  3. Generates Elixir `gettext()` calls that `mix gettext.extract` can discover
  4. Provides `all_translations()` function for runtime use
  5. Uses `@external_resource` to recompile when Svelte files change

  ## Configuration

  - `gettext_backend` (required) - Your Gettext backend module
  - `svelte_path` (required) - Glob pattern for Svelte files (e.g., "assets/svelte/**/*.svelte")
  - `warn_on_missing` (optional, default: true) - Warn about missing translations at compile time
  """

  defmacro __using__(opts) do
    # Validate options
    backend = Keyword.fetch!(opts, :gettext_backend)
    svelte_path = Keyword.fetch!(opts, :svelte_path)
    warn_on_missing = Keyword.get(opts, :warn_on_missing, true)

    # Extract at compile time
    svelte_files = Path.wildcard(svelte_path)
    extractions = LiveSvelteGettext.Extractor.extract_all(svelte_files)

    # Generate AST
    LiveSvelteGettext.Compiler.generate(
      backend: backend,
      extractions: extractions,
      svelte_files: svelte_files,
      warn_on_missing: warn_on_missing
    )
  end
end
```

```elixir
defmodule LiveSvelteGettext.Compiler do
  @moduledoc false
  # Generates the AST for the using module

  def generate(opts) do
    backend = Keyword.fetch!(opts, :backend)
    extractions = Keyword.fetch!(opts, :extractions)
    svelte_files = Keyword.fetch!(opts, :svelte_files)

    quote do
      use Gettext, backend: unquote(backend)

      # Mark all Svelte files as external resources
      unquote_splicing(
        for file <- svelte_files do
          quote do: @external_resource unquote(file)
        end
      )

      # Generate gettext calls for extraction
      unquote_splicing(
        for %{type: :gettext, msgid: msgid} <- extractions do
          quote do
            @compile {:inline, __lsg_marker__: 0}
            defp __lsg_marker__, do: gettext(unquote(msgid))
          end
        end
      )

      # Generate ngettext calls for extraction
      unquote_splicing(
        for %{type: :ngettext, msgid: singular, plural: plural} <- extractions do
          quote do
            @compile {:inline, __lsg_marker__: 0}
            defp __lsg_marker__, do: ngettext(unquote(singular), unquote(plural), 1)
          end
        end
      )

      # Runtime translation function
      @doc """
      Returns a map of all Svelte translation strings for the current locale.

      Keys are English strings, values are translated strings.
      """
      def all_translations do
        unquote(build_translations_map(extractions))
      end

      @doc """
      Returns metadata about extracted strings (for debugging).
      """
      def __lsg_metadata__ do
        unquote(Macro.escape(extractions))
      end
    end
  end

  defp build_translations_map(extractions) do
    # Build a map at runtime
    entries =
      for extraction <- extractions do
        case extraction do
          %{type: :gettext, msgid: msgid} ->
            quote do: {unquote(msgid), gettext(unquote(msgid))}

          %{type: :ngettext, msgid: singular, plural: plural} ->
            [
              quote do: {unquote(singular), gettext(unquote(singular))},
              quote do: {unquote(plural), gettext(unquote(plural))}
            ]
        end
      end
      |> List.flatten()

    quote do
      Map.new(unquote(entries))
    end
  end
end
```

**Testing:**

```elixir
defmodule LiveSvelteGettext.CompilerTest do
  use ExUnit.Case, async: false

  # Create a test module at compile time
  defmodule TestGettext do
    use Gettext, otp_app: :live_svelte_gettext
  end

  test "generates module with all_translations/0" do
    # Create test Svelte file
    content = ~s|<button>{gettext("Save")}</button>|
    path = Path.join(System.tmp_dir!(), "test_component.svelte")
    File.write!(path, content)

    # Define module using our macro
    defmodule TestModule do
      use LiveSvelteGettext,
        gettext_backend: LiveSvelteGettext.CompilerTest.TestGettext,
        svelte_path: path
    end

    # Verify it has the expected functions
    assert function_exported?(TestModule, :all_translations, 0)
    assert function_exported?(TestModule, :__lsg_metadata__, 0)

    # Verify translations work
    translations = TestModule.all_translations()
    assert is_map(translations)
    assert translations["Save"] == "Save"
  end

  test "recompiles when Svelte files change" do
    # This is tricky to test - may need integration test
    # Verify @external_resource is set correctly
  end
end
```

---

### Phase 3: TypeScript Client Library (Week 3-4)

**Objective:** Create a type-safe TypeScript library for Svelte components

**Deliverables:**
- [ ] `translations.ts` with gettext/ngettext functions
- [ ] Initialization from server-injected JSON
- [ ] Variable interpolation (`%{var}` syntax)
- [ ] Plural forms support
- [ ] TypeScript type definitions
- [ ] Vitest tests
- [ ] npm package configuration

**Implementation:**

```typescript
// assets/js/translations.ts

/**
 * Translation map from server
 */
let translations: Record<string, string> = {};

/**
 * Initialize translations from server-provided data.
 * Should be called once at app startup with data from the server.
 *
 * @example
 * ```typescript
 * const data = document.getElementById('svelte-translations')?.textContent;
 * if (data) {
 *   initTranslations(JSON.parse(data));
 * }
 * ```
 */
export function initTranslations(data: Record<string, string>): void {
  translations = data;
}

/**
 * Get current translations (for debugging)
 */
export function getTranslations(): Readonly<Record<string, string>> {
  return translations;
}

/**
 * Translate a string with optional variable interpolation.
 *
 * Variables use Phoenix Gettext syntax: %{variable_name}
 *
 * @param key - English string used as translation key
 * @param vars - Optional variables for interpolation
 * @returns Translated string, or key if translation not found
 *
 * @example
 * ```typescript
 * gettext("Save Profile")  // => "Spara profil" (sv)
 * gettext("Step %{current} of %{total}", { current: 1, total: 10 })
 * ```
 */
export function gettext(
  key: string,
  vars?: Record<string, string | number>
): string {
  let text = translations[key] ?? key;

  if (vars) {
    for (const [name, value] of Object.entries(vars)) {
      // Replace all occurrences of %{name} with value
      const regex = new RegExp(`%\\{${escapeRegex(name)}\\}`, 'g');
      text = text.replace(regex, String(value));
    }
  }

  return text;
}

/**
 * Translate a string with plural forms.
 *
 * @param singular - Singular form (e.g., "%{count} item")
 * @param plural - Plural form (e.g., "%{count} items")
 * @param count - Number to determine which form to use
 * @param vars - Optional additional variables (count is automatically included)
 * @returns Translated string in appropriate plural form
 *
 * @example
 * ```typescript
 * ngettext("%{count} item", "%{count} items", 1)  // => "1 item"
 * ngettext("%{count} item", "%{count} items", 5)  // => "5 items"
 * ```
 */
export function ngettext(
  singular: string,
  plural: string,
  count: number,
  vars?: Record<string, string | number>
): string {
  // Determine which form to use (simple English plural rules)
  const key = count === 1 ? singular : plural;

  // Merge count into vars
  const allVars = { count, ...vars };

  return gettext(key, allVars);
}

/**
 * Escape special regex characters in a string
 */
function escapeRegex(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Check if translations are initialized
 */
export function isInitialized(): boolean {
  return Object.keys(translations).length > 0;
}

/**
 * Reset translations (useful for testing)
 */
export function resetTranslations(): void {
  translations = {};
}
```

**Package Configuration:**

```json
{
  "name": "live-svelte-gettext",
  "version": "0.1.0",
  "description": "Type-safe translations for Svelte + Phoenix",
  "type": "module",
  "main": "./dist/translations.js",
  "types": "./dist/translations.d.ts",
  "exports": {
    ".": {
      "types": "./dist/translations.d.ts",
      "import": "./dist/translations.js"
    }
  },
  "files": [
    "dist"
  ],
  "scripts": {
    "build": "tsc",
    "test": "vitest",
    "prepublishOnly": "npm run build"
  },
  "keywords": [
    "svelte",
    "phoenix",
    "elixir",
    "i18n",
    "gettext",
    "translations"
  ],
  "author": "Your Name",
  "license": "MIT",
  "devDependencies": {
    "typescript": "^5.3.0",
    "vitest": "^1.0.0"
  }
}
```

**Testing:**

```typescript
// assets/js/translations.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import {
  initTranslations,
  gettext,
  ngettext,
  resetTranslations,
  isInitialized
} from './translations';

describe('translations', () => {
  beforeEach(() => {
    resetTranslations();
  });

  describe('initTranslations', () => {
    it('initializes with translation data', () => {
      initTranslations({ 'Save': 'Spara' });
      expect(isInitialized()).toBe(true);
    });
  });

  describe('gettext', () => {
    it('returns translated string', () => {
      initTranslations({ 'Save Profile': 'Spara profil' });
      expect(gettext('Save Profile')).toBe('Spara profil');
    });

    it('returns key if translation missing', () => {
      initTranslations({});
      expect(gettext('Unknown')).toBe('Unknown');
    });

    it('interpolates variables', () => {
      initTranslations({ 'Step %{n} of %{total}': 'Steg %{n} av %{total}' });
      const result = gettext('Step %{n} of %{total}', { n: 1, total: 10 });
      expect(result).toBe('Steg 1 av 10');
    });

    it('handles special characters in variable names', () => {
      initTranslations({ 'Value: %{my_var}': 'Värde: %{my_var}' });
      const result = gettext('Value: %{my_var}', { my_var: 42 });
      expect(result).toBe('Värde: 42');
    });
  });

  describe('ngettext', () => {
    beforeEach(() => {
      initTranslations({
        '%{count} item': '%{count} artikel',
        '%{count} items': '%{count} artiklar'
      });
    });

    it('uses singular form for count=1', () => {
      const result = ngettext('%{count} item', '%{count} items', 1);
      expect(result).toBe('1 artikel');
    });

    it('uses plural form for count≠1', () => {
      const result = ngettext('%{count} item', '%{count} items', 5);
      expect(result).toBe('5 artiklar');
    });

    it('supports additional variables', () => {
      initTranslations({
        '%{count} item in %{container}': '%{count} artikel i %{container}'
      });

      const result = ngettext(
        '%{count} item in %{container}',
        '%{count} items in %{container}',
        1,
        { container: 'cart' }
      );

      expect(result).toBe('1 artikel i cart');
    });
  });
});
```

---

### Phase 4: Igniter Installer (Week 4-5)

**Objective:** Create one-command installation for Phoenix projects

**Deliverables:**
- [ ] `mix igniter.install live_svelte_gettext` task
- [ ] Automatic file generation
- [ ] Configuration prompts
- [ ] Integration tests with fresh Phoenix app
- [ ] Documentation

**Implementation:**

```elixir
defmodule Mix.Tasks.Igniter.Install.LiveSvelteGettext do
  use Igniter.Mix.Task

  @shortdoc "Installs LiveSvelteGettext in your Phoenix application"
  @moduledoc """
  #{@shortdoc}

  ## Example

      mix igniter.install live_svelte_gettext

  ## What it does

  1. Detects your Gettext backend module
  2. Creates SvelteStrings module with LiveSvelteGettext
  3. Copies TypeScript translations library to assets/
  4. Updates your dependencies
  5. Provides usage instructions
  """

  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :igniter,
      installs: [{:live_svelte_gettext, "~> 0.1.0"}],
      example: "mix igniter.install live_svelte_gettext"
    }
  end

  def igniter(igniter) do
    igniter
    |> detect_configuration()
    |> create_svelte_strings_module()
    |> copy_typescript_library()
    |> add_usage_instructions()
  end

  defp detect_configuration(igniter) do
    # Find Gettext backend
    gettext_backend = find_gettext_backend(igniter)

    # Find Svelte directory
    svelte_dir = find_svelte_directory(igniter)

    # Store in igniter assigns
    igniter
    |> Igniter.assign(:gettext_backend, gettext_backend)
    |> Igniter.assign(:svelte_dir, svelte_dir)
  end

  defp create_svelte_strings_module(igniter) do
    backend = Igniter.get_assign(igniter, :gettext_backend)
    svelte_path = Igniter.get_assign(igniter, :svelte_dir)

    # Determine module name
    web_module = Module.concat([backend, :SvelteStrings])

    # Generate module code
    code = """
    defmodule #{inspect(web_module)} do
      @moduledoc \"\"\"
      Automatic translation extraction from Svelte components.

      Extracts strings at compile time - no manual maintenance needed.
      Recompiles automatically when Svelte files change.
      \"\"\"

      use LiveSvelteGettext,
        gettext_backend: #{inspect(backend)},
        svelte_path: "#{svelte_path}/**/*.svelte"
    end
    """

    # Create the module
    Igniter.Project.Module.create_module(igniter, web_module, code)
  end

  defp copy_typescript_library(igniter) do
    # Copy translations.ts to assets directory
    source = Application.app_dir(:live_svelte_gettext, "priv/templates/translations.ts.eex")
    dest = "assets/js/translations.ts"

    Igniter.Project.IgniterConfig.add_extension(
      igniter,
      source,
      dest
    )
  end

  defp add_usage_instructions(igniter) do
    backend = Igniter.get_assign(igniter, :gettext_backend)

    Mix.shell().info("""

    ✅ LiveSvelteGettext installed successfully!

    ## Next Steps

    1. In your LiveView, inject translations:

        def render(assigns) do
          assigns = assign(assigns, :translations, #{inspect(Module.concat([backend, :SvelteStrings]))}.all_translations())

          ~H\"\"\"
          <script id="svelte-translations" type="application/json">
            <%= raw Jason.encode!(@translations) %>
          </script>

          <.svelte name="YourComponent" props={...} />
          \"\"\"
        end

    2. In your Svelte component, initialize translations:

        <script>
          import { gettext, initTranslations } from '../js/translations';

          const el = document.getElementById('svelte-translations');
          if (el) initTranslations(JSON.parse(el.textContent));
        </script>

        <button>{gettext("Save Profile")}</button>

    3. Extract translations:

        mix gettext.extract
        mix gettext.merge priv/gettext --locale sv

    4. Translate in .po files and recompile!

    📚 Docs: https://hexdocs.pm/live_svelte_gettext
    """)

    igniter
  end

  defp find_gettext_backend(igniter) do
    # Search for modules using Gettext
    # This is simplified - real implementation would use Igniter's module search
    Application.get_env(:phoenix, :gettext_backend) ||
      raise "Could not detect Gettext backend"
  end

  defp find_svelte_directory(_igniter) do
    cond do
      File.dir?("assets/svelte") -> "assets/svelte"
      File.dir?("assets/js/svelte") -> "assets/js/svelte"
      true ->
        Mix.shell().prompt("Enter Svelte directory path:")
    end
  end
end
```

---

### Phase 5: Documentation & Publishing (Week 5-6)

**Objective:** Comprehensive docs and Hex package publication

**Deliverables:**
- [ ] README.md with quick start guide
- [ ] ExDoc documentation for all modules
- [ ] Usage examples
- [ ] Migration guide from manual approach
- [ ] CHANGELOG.md
- [ ] Contributing guidelines
- [ ] GitHub Actions CI
- [ ] Publish to Hex.pm
- [ ] Publish TypeScript to npm (optional)

**README Structure:**

```markdown
# LiveSvelteGettext

Zero-maintenance internationalization for Phoenix + Svelte applications.

## Features

- ✨ **Compile-Time Extraction** - No generated files to commit
- 🔄 **Automatic Recompilation** - Changes to Svelte files trigger rebuild
- 🌍 **Standard Gettext** - Works with existing `mix gettext.extract`
- 💪 **Type-Safe Client** - Full TypeScript support
- 🚀 **One-Command Install** - Igniter-based setup

## Installation

```elixir
# mix.exs
def deps do
  [
    {:live_svelte_gettext, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix igniter.install live_svelte_gettext
```

## Quick Start

[Step-by-step guide]

## How It Works

[Architecture explanation]

## API Documentation

[Link to HexDocs]

## Contributing

[Guidelines]

## License

MIT License - see LICENSE file
```

---

## Testing Strategy

### Unit Tests
- [ ] Extractor regex patterns
- [ ] String escaping/unescaping
- [ ] Deduplication logic
- [ ] Configuration validation

### Integration Tests
- [ ] Full compile cycle
- [ ] `@external_resource` behavior
- [ ] Generated code correctness
- [ ] Igniter installer in fresh Phoenix app

### Property-Based Tests
- [ ] Regex patterns with StreamData
- [ ] Interpolation edge cases

### Manual Testing
- [ ] Install in Monster Construction
- [ ] Install in fresh Phoenix 1.7 app
- [ ] Test with live_svelte versions

---

## Release Checklist

### Version 0.1.0 (Initial Release)
- [ ] All Phase 1-5 deliverables complete
- [ ] Test coverage > 90%
- [ ] Documentation complete
- [ ] CI passing
- [ ] Manual testing in 2+ projects
- [ ] CHANGELOG.md up to date
- [ ] Tag `v0.1.0` in git
- [ ] Publish to Hex: `mix hex.publish`
- [ ] Announce on Elixir Forum
- [ ] Share on Twitter/X, Reddit

### Future Versions

**v0.2.0 - Enhanced Features**
- [ ] Domain support (`dgettext`)
- [ ] Context support (`pgettext`)
- [ ] Locale-specific plural rules
- [ ] Custom interpolation patterns

**v1.0.0 - Stable Release**
- [ ] Proven in 5+ production apps
- [ ] No breaking changes for 6+ months
- [ ] Complete test coverage
- [ ] Performance benchmarks

---

## Project Setup Instructions

See the next section for step-by-step instructions to create the Elixir library project.

---

## Success Metrics

### Adoption Metrics
- **Week 1-2:** 50+ Hex downloads
- **Month 1:** 3+ external projects using it
- **Month 3:** 500+ Hex downloads
- **Month 6:** Featured in Elixir Radar/newsletter

### Quality Metrics
- **Test Coverage:** > 90%
- **Documentation:** 100% of public functions
- **CI:** < 2 minutes build time
- **Issues:** < 1 week response time

### Community Metrics
- **GitHub Stars:** 50+ in first 3 months
- **Forum Discussion:** Active thread on Elixir Forum
- **Contributions:** 2+ external contributors

---

## Risk Management

### Technical Risks

**Risk:** Macro complexity makes debugging difficult
**Mitigation:** Provide `__lsg_metadata__/0` debug function, comprehensive docs

**Risk:** Breaking changes in Gettext API
**Mitigation:** Pin to stable Gettext versions, test across versions

**Risk:** Performance impact of file scanning
**Mitigation:** Only runs at compile time, cached by BEAM

### Project Risks

**Risk:** Maintainer burnout
**Mitigation:** Good docs, welcoming to contributors, clear scope

**Risk:** Low adoption
**Mitigation:** Blog post, Elixir Forum announcement, live_svelte issue comment

**Risk:** Competing solutions emerge
**Mitigation:** Focus on simplicity and zero-maintenance DX

---

## Community Engagement

### Launch Plan

1. **Week 1:** Publish to Hex, share on Elixir Forum
2. **Week 2:** Blog post explaining implementation
3. **Week 3:** Comment on live_svelte issue #120
4. **Week 4:** Share on Reddit, Twitter/X
5. **Ongoing:** Respond to issues, support users

### Content Strategy

- **Blog Post:** "Building a Compile-Time Translation Library for Phoenix + Svelte"
- **Video Tutorial:** Installing and using live_svelte_gettext (optional)
- **Case Study:** Migration from manual approach (Monster Construction)

---

## Resources

### Learning Resources
- [Elixir Macros Guide](https://elixir-lang.org/getting-started/meta/macros.html)
- [Igniter Documentation](https://hexdocs.pm/igniter)
- [Gettext Documentation](https://hexdocs.pm/gettext)
- [Publishing Hex Packages](https://hex.pm/docs/publish)

### Similar Projects
- [gettext](https://github.com/elixir-gettext/gettext) - Core Gettext library
- [ex_cldr](https://github.com/elixir-cldr/cldr) - CLDR-based i18n
- [linguist](https://github.com/change/linguist) - Alternative i18n solution

