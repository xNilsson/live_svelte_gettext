# LiveSvelte Gettext

Zero-maintenance internationalization for Phoenix + Svelte applications.

## Features

- ✨ **Compile-Time Extraction** - No generated files to commit
- 🔄 **Automatic Recompilation** - Changes to Svelte files trigger rebuild
- 🌍 **Standard Gettext** - Works with existing `mix gettext.extract`
- 💪 **Type-Safe Client** - Full TypeScript support
- 🚀 **One-Command Install** - Igniter-based setup

## Installation

### Automatic Installation (Recommended)

```elixir
# mix.exs
def deps do
  [
    {:livesvelte_gettext, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix igniter.install livesvelte_gettext
```

The installer will:
- Detect your Gettext backend automatically
- Find your Svelte directory
- Create a `SvelteStrings` module with the correct configuration
- Copy the TypeScript translation library to `assets/js/translations.ts`
- Provide usage instructions

### Manual Installation

If the automatic installer doesn't work for your project:

1. **Add the dependency** to your `mix.exs`:

```elixir
def deps do
  [
    {:livesvelte_gettext, "~> 0.1.0"}
  ]
end
```

2. **Create a module** that uses `LiveSvelteGettext`:

```elixir
# lib/my_app_web/svelte_strings.ex
defmodule MyAppWeb.SvelteStrings do
  @moduledoc """
  Translation strings extracted from Svelte components.
  """

  use Gettext.Backend, otp_app: :my_app
  use LiveSvelteGettext,
    gettext_backend: MyAppWeb.Gettext,
    svelte_path: "assets/svelte"
end
```

3. **Copy the TypeScript library** from the package:

```bash
# Find the library in your deps
cp deps/livesvelte_gettext/priv/static/translations.ts assets/js/translations.ts
```

Or download it directly:
```bash
curl -o assets/js/translations.ts https://raw.githubusercontent.com/xnilsson/livesvelte_gettext/main/assets/js/translations.ts
```

## Quick Start

Once installed, you can start using translations in your Svelte components immediately.

### 1. Use translations in your Svelte components

```svelte
<script>
  import { gettext, ngettext } from './translations.ts'
  export let translations

  // Initialize translations when they arrive from the server
  $: if (translations) {
    initTranslations(translations)
  }

  let itemCount = 5
</script>

<div>
  <h1>{gettext("Welcome to our app")}</h1>
  <p>{gettext("Hello, %{name}", { name: "World" })}</p>
  <p>{ngettext("1 item", "%{count} items", itemCount)}</p>
</div>
```

### 2. Pass translations from your LiveView

```elixir
defmodule MyAppWeb.PageLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    # Get translations for the current locale
    locale = Gettext.get_locale(MyAppWeb.Gettext)
    translations = MyAppWeb.SvelteStrings.all_translations(locale)

    {:ok, assign(socket, :translations, translations)}
  end
end
```

### 3. Extract and translate

```bash
# Extract translation strings from both Elixir and Svelte files
mix gettext.extract

# Merge into locale files
mix gettext.merge priv/gettext

# Edit your .po files to add translations
# Then your Svelte components will automatically use the translated strings!
```

## How It Works

LiveSvelte Gettext uses a compile-time approach to make i18n seamless:

### Compile Time (Zero Maintenance)

1. **Extraction**: When you compile your app, `LiveSvelteGettext` scans all `.svelte` files in your configured directory
2. **Code Generation**: It generates Elixir `gettext()` and `ngettext()` calls in your `SvelteStrings` module
3. **Discovery**: When you run `mix gettext.extract`, these generated calls are discovered just like regular Gettext usage
4. **Recompilation**: Uses `@external_resource` to automatically recompile when Svelte files change

### Runtime (Fast and Simple)

1. **Translation Map**: Your `SvelteStrings` module has an `all_translations/1` function that returns a map of all translations
2. **Server → Client**: You pass this map from your LiveView to your Svelte component
3. **Client-Side**: The TypeScript library handles interpolation and pluralization in the browser

### No Generated Files

Unlike other i18n solutions, there are no intermediate JSON or JavaScript files to commit. Everything is extracted and compiled at build time.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Compile Time (Elixir)                                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  1. Scan *.svelte files                                      │
│     └─ Extract gettext() and ngettext() calls                │
│                                                               │
│  2. Generate Elixir code                                     │
│     ├─ gettext("string") calls for extraction                │
│     └─ all_translations/1 runtime function                   │
│                                                               │
│  3. Set @external_resource                                   │
│     └─ Recompile when Svelte files change                    │
│                                                               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ mix gettext.extract                                          │
├─────────────────────────────────────────────────────────────┤
│  Discovers generated gettext() calls                         │
│  Writes to priv/gettext/default.pot                          │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ Runtime (Server)                                             │
├─────────────────────────────────────────────────────────────┤
│  SvelteStrings.all_translations("en")                        │
│  └─ Returns: %{"Hello" => "Hello", ...}                      │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ Runtime (Client/Browser)                                     │
├─────────────────────────────────────────────────────────────┤
│  TypeScript functions handle:                                │
│  ├─ String interpolation (%{name})                           │
│  └─ Plural forms (count-based)                               │
└─────────────────────────────────────────────────────────────┘
```

## API Documentation

Full API documentation is available on [HexDocs](https://hexdocs.pm/livesvelte_gettext).

### Key Modules

- **`LiveSvelteGettext`** - Main module to `use` in your Gettext backend
- **`LiveSvelteGettext.Extractor`** - Extracts translation strings from Svelte files
- **`LiveSvelteGettext.Compiler`** - Generates code at compile time

### TypeScript API

```typescript
// Initialize translations (call once with data from server)
initTranslations(translations: Record<string, string>): void

// Get translated string
gettext(key: string, vars?: Record<string, string | number>): string

// Get translated string with pluralization
ngettext(singular: string, plural: string, count: number, vars?: Record<string, string | number>): string

// Check if initialized
isInitialized(): boolean

// Reset (useful for testing)
resetTranslations(): void
```

## Troubleshooting

### Translations not updating after changing Svelte files

Make sure your Svelte files are being watched for changes. Run:

```bash
mix clean
mix compile
```

The module should recompile automatically when Svelte files change due to `@external_resource`.

### TypeScript library not found

If the installer didn't copy the TypeScript library, you can manually download it:

```bash
curl -o assets/js/translations.ts https://raw.githubusercontent.com/xnilsson/livesvelte_gettext/main/assets/js/translations.ts
```

### Gettext.extract not finding Svelte strings

Make sure your `SvelteStrings` module is compiling successfully. Check for compilation errors:

```bash
mix compile
```

If there are no errors, verify that strings are being extracted:

```elixir
# In IEx
iex> MyAppWeb.SvelteStrings.__lsg_metadata__()
%{
  extractions: [...],  # Should list your strings
  svelte_files: [...], # Should list your .svelte files
  gettext_backend: MyAppWeb.Gettext
}
```

### Translations showing keys instead of translated text

This usually means:

1. You haven't run `mix gettext.extract` and `mix gettext.merge` yet
2. The translations haven't been added to your `.po` files
3. The locale isn't set correctly

Check your locale:

```elixir
Gettext.get_locale(MyAppWeb.Gettext)
```

### Escaped quotes not working in Svelte

Use the appropriate escape sequence:

```svelte
{gettext("She said, \"Hello\"")}  <!-- Double quotes inside double quotes -->
{gettext('He\'s here')}            <!-- Single quote inside single quotes -->
```

### Module not recompiling when expected

Force a recompilation:

```bash
mix clean
mix deps.clean livesvelte_gettext
mix deps.get
mix compile
```

## Contributing

Contributions are welcome! Here's how you can help:

1. **Report bugs**: Open an issue with a minimal reproduction case
2. **Suggest features**: Open an issue describing the use case and proposed API
3. **Submit pull requests**:
   - Fork the repository
   - Create a feature branch
   - Add tests for new functionality
   - Ensure all tests pass with `mix test`
   - Run `mix format` before committing
   - Open a PR with a clear description

### Development Setup

```bash
# Clone the repository
git clone https://github.com/xnilsson/livesvelte_gettext.git
cd livesvelte_gettext

# Install dependencies
mix deps.get

# Run tests
mix test

# Run tests with coverage
mix coveralls.html

# Format code
mix format

# Type checking
mix dialyzer
```

### Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/livesvelte_gettext/extractor_test.exs

# Run with coverage
mix coveralls.html
open cover/excoveralls.html
```

## For Library Authors

If you're building a compile-time i18n extractor for a non-Elixir templating system (like Svelte, Surface, Temple, etc.), you may encounter the same challenge we faced: all extracted translation strings reference the macro invocation line instead of the original source file locations.

**The Problem:**

```elixir
# lib/my_app_web/template_strings.ex:39
use MyI18nExtractor  # <-- All strings reference this line

# In POT file:
#: lib/my_app_web/template_strings.ex:39
msgid "Save Profile"
#: lib/my_app_web/template_strings.ex:39
msgid "Delete Account"
```

**Our Solution:**

We solved this by creating a custom extractor that modifies `Macro.Env` before calling `Gettext.Extractor.extract/6`. See `lib/livesvelte_gettext/custom_extractor.ex` for the implementation.

The key insight:

```elixir
def extract_with_location(env, backend, domain, msgctxt, msgid, extracted_comments, file, line) do
  # Create a modified environment with custom file and line
  modified_env = %{env | file: file, line: line}

  # Gettext reads env.file and env.line
  Gettext.Extractor.extract(
    modified_env,
    backend,
    domain,
    msgctxt,
    msgid,
    extracted_comments
  )
end
```

This produces accurate references in POT files:

```
#: assets/svelte/components/Button.svelte:42
msgid "Save Profile"
#: assets/templates/settings.sface:18
msgid "Delete Account"
```

Feel free to copy this pattern for your own compile-time extraction needs!

## License

MIT License - see [LICENSE](LICENSE) file for details.

Copyright (c) 2025 Christopher Nilsson
