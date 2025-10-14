# LiveSvelteGettext

**Status:** Proof of Concept

A compile-time solution for using Phoenix Gettext translations in Svelte components.

## The Problem

When using [live_svelte](https://github.com/woutdp/live_svelte) with Phoenix, there's no straightforward way to use gettext translations in Svelte components. This issue was raised in [live_svelte#120](https://github.com/woutdp/live_svelte/issues/120).

The challenges:
- Svelte components need access to translations at runtime
- `mix gettext.extract` needs to discover translation strings in `.svelte` files
- `.po` file references should point to the actual Svelte source file:line for maintainability
- Ideally, no generated files to commit or manually maintain

## The Solution

This library uses Elixir macros at compile time to:
1. Scan `.svelte` files for `gettext()` and `ngettext()` calls
2. Generate Elixir code that `mix gettext.extract` can discover
3. Inject accurate source references into `.pot` files via custom extractor
4. Provide runtime translation functions for Svelte via a TypeScript library

No generated files are committed - everything happens at compile time using `@external_resource` for automatic recompilation.

## Key Features

- **Compile-Time Extraction**: Scans Svelte files during compilation
- **Phoenix Gettext Compatible**: Works with existing `mix gettext.extract` workflow
- **Accurate Source References**: `.pot` files show `assets/svelte/Button.svelte:42` instead of generated code locations
- **Type-Safe Client**: TypeScript library for runtime translations
- **Simple Setup**: Igniter installer handles configuration
- **Automatic Initialization**: Phoenix LiveView hook injects translations on page load

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
- Provide usage instructions for installing the npm package and registering the hook

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

### 1. Import the component helper

To use the `<.svelte_translations />` component in your templates, add this import to your view helpers:

```elixir
# lib/my_app_web.ex
def html do
  quote do
    # ... existing imports ...
    import LiveSvelteGettext.Components
  end
end
```

### 2. Inject translations into your template

Add the `<.svelte_translations />` component in your layout or LiveView template. This component renders a `<script>` tag containing translations as JSON:

```heex
<!-- In your layout or LiveView template -->
<.svelte_translations />

<.svelte name="MyComponent" props={%{...}} />
```

The component renders a `<script>` tag with translations as JSON. The `LiveSvelteGettextInit` hook (registered in step 5 of installation) automatically reads this data when the page loads and initializes the translation store for your Svelte components.

**How it works:**
- Component fetches translations for the current locale from your Gettext backend
- Renders them as JSON in a `<script id="svelte-translations">` tag
- The Phoenix hook reads the JSON and initializes the translation functions
- Your Svelte components can now call `gettext()` and `ngettext()`

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

That's it! No manual initialization needed - the hook handles everything automatically.

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

This POC uses a compile-time macro approach to bridge Elixir's gettext and Svelte's runtime:

### Compile Time

1. **File Scanning**: When you compile, the `use LiveSvelteGettext` macro runs and scans all `.svelte` files
2. **String Extraction**: Regex patterns extract `gettext()` and `ngettext()` calls with their file:line locations
3. **Code Generation**: The macro generates Elixir code in your module with:
   - `@external_resource` attributes (triggers recompilation when Svelte files change)
   - Calls to `CustomExtractor.extract_with_location/8` (preserves accurate source references)
   - An `all_translations/1` function for runtime access
4. **Gettext Discovery**: When you run `mix gettext.extract`, it discovers the generated extraction calls
5. **Accurate References**: The `CustomExtractor` modifies `Macro.Env` to inject the actual Svelte file:line into `.pot` files

### Runtime

1. **Server Side**: The `<.svelte_translations />` component fetches translations and renders them as JSON in a `<script>` tag
2. **Client Side**: The `LiveSvelteGettextInit` Phoenix hook reads the JSON and initializes the TypeScript translation store
3. **Svelte Components**: Call `gettext()` and `ngettext()` - interpolation and pluralization happen in the browser

### No Generated Files

Everything is generated at compile time in memory. No intermediate files to commit or maintain.

## Architectural Decisions

These are the key design choices made in this POC and the reasoning behind them:

### 1. Script Tag for Translation Injection (Not Props)

**Decision**: Pass translations via a `<script>` tag with JSON rather than as props to each Svelte component.

**Reasoning**:
- **Performance**: Avoids serializing potentially large translation objects multiple times per page
- **Global Access**: All Svelte components can access translations without prop drilling
- **Separation of Concerns**: Translation data is separate from component props
- **Caching**: The browser can cache the inline script across LiveView updates

This is a preference based on architectural feel rather than hard performance data.

### 2. Compile-Time Macro Generation

**Decision**: Use Elixir macros to generate code at compile time rather than runtime discovery or generated files.

**Reasoning**:
- **No Committed Files**: Avoids generated `.ex` or `.json` files in version control
- **Phoenix Integration**: Generated code naturally integrates with `mix gettext.extract`
- **Automatic Updates**: `@external_resource` triggers recompilation when Svelte files change
- **Zero Runtime Cost**: All extraction work happens once at compile time

This keeps the developer workflow simple: write `gettext()` in Svelte, run `mix compile` and `mix gettext.extract`.

### 3. Full .po File Compatibility

**Decision**: Ensure complete compatibility with Phoenix's gettext toolchain, including accurate source references.

**Reasoning**:
- **Existing Tools**: Developers can use their existing translation workflows
- **Reference Accuracy**: `.pot` files showing `assets/svelte/Button.svelte:42` helps translators understand context
- **CLI Tool Integration**: Makes it possible to use tools like [poflow](https://github.com/xNilsson/poflow) for AI-assisted translation. `poflow` is a tool built by me to make .po files changes more efficiently with llms.
- **No Learning Curve**: Developers already know `mix gettext.extract` and `.po` file workflows

The `CustomExtractor` was necessary to solve the "all references point to the macro invocation line" problem.

### 4. NPM Package for TypeScript Client

**Decision**: Create a standalone npm package (`live-svelte-gettext`) for the runtime translation functions.

**Reasoning**:
- **Minimal Setup**: Developers can `import { gettext } from 'live-svelte-gettext'` immediately
- **Type Safety**: Full TypeScript types for better DX
- **Reusability**: The runtime library could work with other backends in the future
- **Familiar Pattern**: Follows standard npm package conventions

The package will be published to npm for easy installation.

## Architecture

### Compile Time (Elixir)

When you run `mix compile`:

1. **Scan Svelte files** - `LiveSvelteGettext.Extractor` scans all `.svelte` files in your configured path
2. **Extract strings** - Regex patterns find `gettext()` and `ngettext()` calls with file:line metadata
3. **Generate code** - `LiveSvelteGettext.Compiler` generates:
   - `@external_resource` attributes (triggers recompilation when files change)
   - Calls to `CustomExtractor.extract_with_location/8` (preserves source locations)
   - An `all_translations/1` function for runtime use
   - A `__lsg_metadata__/0` debug function

↓

### Translation Extraction

When you run `mix gettext.extract`:

4. **Discover strings** - Gettext finds the generated extraction calls
5. **Inject references** - `CustomExtractor` modifies `Macro.Env` to inject actual Svelte file:line
6. **Write POT files** - Creates/updates `priv/gettext/default.pot` with accurate references:
   ```
   #: assets/svelte/components/Button.svelte:42
   msgid "Save Profile"
   ```

↓

### Runtime (Server)

When a page loads:

7. **Fetch translations** - The `<.svelte_translations />` component calls `YourModule.all_translations(locale)`
8. **Render JSON** - Translations are rendered in a `<script id="svelte-translations">` tag
9. **Register hook** - The `LiveSvelteGettextInit` Phoenix hook is mounted

↓

### Runtime (Client/Browser)

10. **Initialize** - The hook reads the JSON and calls `initTranslations(data)`
11. **Use translations** - Svelte components call `gettext()` and `ngettext()`
12. **Interpolate** - The TypeScript library handles variable substitution and pluralization

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

## Project Status & Future

### Current Status

This is a **proof of concept** extracted from a real project where it solves a practical need. It works well for the use case it was designed for, but has not been widely tested across different Phoenix/Svelte setups.

**What's working:**
- Compile-time extraction from Svelte files
- Integration with `mix gettext.extract`
- Accurate source references in `.pot` files
- Runtime translations with interpolation and pluralization
- Automatic initialization via Phoenix LiveView hooks
- Igniter-based installation

**Known limitations:**
- Simple English plural rules only (no CLDR plural forms for other languages)
- Regex-based extraction (won't handle all edge cases like template literals or computed strings)
- Not tested with domains (`dgettext`) or contexts (`pgettext`)

### Sharing with live_svelte Community

This POC was created in response to [live_svelte#120](https://github.com/woutdp/live_svelte/issues/120). The goal is to:

1. **Share the approach** - Show that compile-time macro extraction can work
2. **Get feedback** - Learn if this solves the problem for others
3. **Discuss integration** - Potentially merge concepts into live_svelte or keep as separate library

If you're interested in using this or have ideas for improvement, please open an issue or discussion!

### Possible Future Directions

**If this POC proves useful:**
- CLDR plural rules for accurate pluralization across languages
- Domain and context support (dgettext, pgettext)
- More robust parsing (proper Svelte AST instead of regex)
- Published npm package
- Support for other frontend frameworks (React, Vue, etc.)

**Alternative approaches to consider:**
- Babel/SWC plugin for extraction (more accurate than regex)
- Build-time JSON generation (simpler but requires committing files)
- Integration directly into live_svelte (would benefit all users)

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
