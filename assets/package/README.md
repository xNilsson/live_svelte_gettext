# live-svelte-gettext

Runtime translation functions for using Phoenix Gettext in Svelte components.

## What is this?

This is the JavaScript/TypeScript runtime library for [LiveSvelteGettext](https://github.com/xnilsson/live_svelte_gettext) - a POC for integrating Phoenix Gettext with Svelte components in LiveView applications.

The Elixir side handles compile-time extraction and translation loading. This package provides:
- `gettext()` and `ngettext()` functions for use in Svelte components
- A Phoenix LiveView hook for automatic initialization
- TypeScript type definitions

## Installation

```bash
# Copy from your Hex dependency (recommended for now)
cp -r deps/live_svelte_gettext/assets/package node_modules/live-svelte-gettext

# Or once published to npm:
npm install live-svelte-gettext
```

## Usage

### 1. Register the Phoenix hook in `app.js`:

```javascript
import { LiveSvelteGettextInit } from "live-svelte-gettext";

const liveSocket = new LiveSocket("/live", Socket, {
  hooks: {
    ...getHooks(Components),
    LiveSvelteGettextInit,  // Required for translations to work
  }
});
```

### 2. Use in your Svelte components:

```svelte
<script>
  import { gettext, ngettext } from 'live-svelte-gettext'

  let count = 5
</script>

<h1>{gettext("Welcome")}</h1>
<p>{gettext("Hello, %{name}", { name: "World" })}</p>
<p>{ngettext("1 item", "%{count} items", count)}</p>
```

## API

### `gettext(key, vars?)`

Get a translated string with optional variable interpolation.

```javascript
gettext("Save")
gettext("Hello, %{name}", { name: "Anna" })
```

### `ngettext(singular, plural, count, vars?)`

Get a translated string with plural handling.

```javascript
ngettext("1 item", "%{count} items", 1)      // "1 item"
ngettext("1 item", "%{count} items", 5)      // "5 items"
```

### `LiveSvelteGettextInit`

Phoenix LiveView hook that automatically initializes translations when the page loads. Must be registered in your LiveSocket hooks.

### Other exports

- `initTranslations(data)` - Manually initialize (usually not needed)
- `isInitialized()` - Check if translations are loaded
- `resetTranslations()` - Reset state (useful for testing)

## How it works

1. The Elixir side renders translations as JSON in a `<script>` tag
2. The `LiveSvelteGettextInit` hook reads this JSON on page load
3. Svelte components can immediately use `gettext()` and `ngettext()`
4. Interpolation and pluralization happen in the browser

## Full Documentation

See the main [LiveSvelteGettext repository](https://github.com/xnilsson/live_svelte_gettext) for complete documentation, including:
- Installation guide
- Elixir configuration
- Extracting translations with `mix gettext.extract`
- Architectural decisions

## License

MIT - see LICENSE file
