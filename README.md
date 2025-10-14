# LiveSvelteGettext

Zero-maintenance internationalization for Phoenix + Svelte applications.

## Features

- ✨ **Compile-Time Extraction** - No generated files to commit
- 🔄 **Automatic Recompilation** - Changes to Svelte files trigger rebuild
- 🌍 **Standard Gettext** - Works with existing `mix gettext.extract`
- 📍 **Accurate Source References** - POT files show actual Svelte file:line numbers
- 💪 **Type-Safe Client** - Full TypeScript support
- 🚀 **One-Command Install** - Igniter-based setup
- ⚡ **Auto-Initialization** - Zero boilerplate via Phoenix LiveView hooks

## Installation

### Automatic Installation (Recommended)

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

The installer will:
- Detect your Gettext backend automatically
- Find your Svelte directory
- Configure your Gettext module in `config/config.exs`
- Create a `SvelteStrings` module with the correct configuration
- Copy the TypeScript translation library to `assets/js/translations.ts`
- Provide usage instructions

### Manual Installation

If the automatic installer doesn't work for your project:

1. **Add the dependency** to your `mix.exs`:

```elixir
def deps do
  [
    {:live_svelte_gettext, "~> 0.1.0"}
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

3. **Configure the Gettext module** in `config/config.exs`:

```elixir
# config/config.exs
config :live_svelte_gettext,
  gettext: MyAppWeb.Gettext
```

4. **Copy the NPM package** from the dependency:

```bash
# Copy the NPM package to your project
cp -r deps/live_svelte_gettext/assets/package node_modules/live-svelte-gettext
```

Or install from npm (once published):
```bash
npm install live-svelte-gettext
```

5. **Register the Phoenix hook** in `assets/js/app.js` (**required**):

```javascript
import { getHooks } from "live-svelte";
import { LiveSvelteGettextInit } from "live-svelte-gettext";

const liveSocket = new LiveSocket("/live", Socket, {
  hooks: {
    ...getHooks(Components),
    LiveSvelteGettextInit,  // Required - initializes translations automatically
  }
});
```

> ⚠️ **Important**: The `LiveSvelteGettextInit` hook is **required** for translations to work. It automatically initializes translations when the page loads, eliminating the need for manual setup in Svelte components.

## Quick Start

Once installed, you can start using translations in your Svelte components immediately.

### 1. Import the component in your view helpers

```elixir
# lib/my_app_web.ex
def html do
  quote do
    # ... existing imports ...
    import LiveSvelteGettext.Components
  end
end
```

### 2. Add translation injection to your template

Add the `svelte_translations` component before your Svelte components:

```heex
<!-- In your layout or LiveView template -->
<.svelte_translations />

<.svelte name="MyComponent" props={%{...}} />
```

The component will automatically:
- Use the Gettext module configured in `config/config.exs`
- Fetch translations for the current locale
- Inject them as JSON in a `<script>` tag
- Trigger the `LiveSvelteGettextInit` hook to initialize translations when the page loads

**Advanced usage:**

```heex
<!-- Override locale -->
<.svelte_translations locale="es" />

<!-- Explicit Gettext module (for multi-tenant apps) -->
<.svelte_translations gettext_module={@tenant.gettext_module} />

<!-- Custom script tag ID -->
<.svelte_translations id="custom-translations" />
```

### 3. Use translations in your Svelte components

```svelte
<script>
  import { gettext, ngettext } from 'live-svelte-gettext'

  let itemCount = 5
</script>

<div>
  <h1>{gettext("Welcome to our app")}</h1>
  <p>{gettext("Hello, %{name}", { name: "World" })}</p>
  <p>{ngettext("1 item", "%{count} items", itemCount)}</p>
</div>
```

That's it! Translations are automatically initialized via the Phoenix hook when the page loads.

### 4. Extract and translate

```bash
# Extract translation strings from both Elixir and Svelte files
mix gettext.extract

# Merge into locale files
mix gettext.merge priv/gettext

# Edit your .po files to add translations
# Then your Svelte components will automatically use the translated strings!
```

## How It Works

LiveSvelteGettext uses a compile-time approach to make i18n seamless:

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

Full API documentation is available on [HexDocs](https://hexdocs.pm/live_svelte_gettext).

### Key Modules

- **`LiveSvelteGettext`** - Main module to `use` in your Gettext backend
- **`LiveSvelteGettext.Components`** - Phoenix components for injecting translations
- **`LiveSvelteGettext.Extractor`** - Extracts translation strings from Svelte files
- **`LiveSvelteGettext.Compiler`** - Generates code at compile time

### TypeScript API

```typescript
// Get translated string
gettext(key: string, vars?: Record<string, string | number>): string

// Get translated string with pluralization
ngettext(singular: string, plural: string, count: number, vars?: Record<string, string | number>): string

// Initialize translations manually (automatically called by LiveSvelteGettextInit hook)
initTranslations(translations: Record<string, string>): void

// Check if initialized
isInitialized(): boolean

// Reset (useful for testing)
resetTranslations(): void

// Phoenix LiveView Hook (register in app.js)
LiveSvelteGettextInit: PhoenixHook
```

## Troubleshooting

### Translations not updating after changing Svelte files

Make sure your Svelte files are being watched for changes. Run:

```bash
mix clean
mix compile
```

The module should recompile automatically when Svelte files change due to `@external_resource`.

### NPM package not found / Import errors

If you get import errors for `live-svelte-gettext`, make sure the package is properly installed:

```bash
# Copy from the Hex dependency
cp -r deps/live_svelte_gettext/assets/package node_modules/live-svelte-gettext

# Or once published to npm:
npm install live-svelte-gettext
```

Also verify that you've registered the hook in `assets/js/app.js`:

```javascript
import { LiveSvelteGettextInit } from "live-svelte-gettext";

const liveSocket = new LiveSocket("/live", Socket, {
  hooks: {
    ...getHooks(Components),
    LiveSvelteGettextInit,  // This line is required!
  }
});
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
mix deps.clean live_svelte_gettext
mix deps.get
mix compile
```

### POT files showing incorrect Svelte file references

As of v0.1.0, LiveSvelteGettext automatically injects correct Svelte file:line references during `mix gettext.extract` via `CustomExtractor`. You should see references like:

```
#: assets/svelte/components/Button.svelte:42
msgid "Save Profile"
```

If you see incorrect references (like `lib/my_app_web/svelte_strings.ex:39` for all strings), this usually means:

1. **Migration from older version**: Run `mix live_svelte_gettext.fix_references` to update existing POT files
2. **CustomExtractor not working**: This is likely a bug - please report it!

The `fix_references` task is primarily a fallback tool and shouldn't be needed for normal operation.

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
git clone https://github.com/xnilsson/live_svelte_gettext.git
cd live_svelte_gettext

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
mix test test/live_svelte_gettext/extractor_test.exs

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

We solved this by creating a custom extractor that modifies `Macro.Env` before calling `Gettext.Extractor.extract/6`. See `lib/live_svelte_gettext/custom_extractor.ex` for the implementation.

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
