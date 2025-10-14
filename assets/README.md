# LiveSvelteGettext

TypeScript client library for runtime translations in Svelte components. Part of the [LiveSvelteGettext](https://github.com/xnilsson/live_svelte_gettext) project.

## Installation

This library is typically installed automatically by the `live_svelte_gettext` Elixir package. If you need to install it manually:

```bash
npm install live-svelte-gettext
```

Or copy `translations.ts` directly into your Phoenix project at `assets/js/translations.ts`.

## Usage

### Basic Setup

```typescript
import { initTranslations, gettext } from './translations';

// Initialize with translations from server
initTranslations({
  "Hello": "Hej",
  "Goodbye": "Hejdå",
  "Welcome, %{name}": "Välkommen, %{name}"
});

// Use translations
gettext("Hello"); // Returns "Hej"
```

### In a Svelte Component

```svelte
<script lang="ts">
  import { initTranslations, gettext, ngettext } from './translations';

  // Receive translations from LiveView
  export let translations: Record<string, string>;

  // Initialize on mount
  initTranslations(translations);

  let username = "Anna";
  let itemCount = 5;
</script>

<h1>{gettext("Welcome, %{name}", { name: username })}</h1>
<p>{ngettext("1 item", "%{count} items", itemCount)}</p>
```

### With Phoenix LiveView

In your LiveView, pass translations to the Svelte component:

```elixir
def render(assigns) do
  ~H"""
  <YourComponent
    translations={YourApp.SvelteStrings.all_translations()}
    {assigns}
  />
  """
end
```

## API Reference

### `initTranslations(data)`

Initialize the translation system with data from the server.

**Parameters:**
- `data: Record<string, string>` - Translation key-value pairs

**Example:**
```typescript
initTranslations({
  "Hello": "Hej",
  "Goodbye": "Hejdå"
});
```

### `gettext(key, vars?)`

Get a translated string with optional variable interpolation.

**Parameters:**
- `key: string` - The translation key (usually the English string)
- `vars?: Record<string, string | number>` - Optional variables for interpolation

**Returns:** `string` - Translated string with variables replaced, or the key if not found

**Examples:**
```typescript
gettext("Hello");
// Returns: "Hej"

gettext("Welcome, %{name}", { name: "Anna" });
// Returns: "Välkommen, Anna"

gettext("Missing key");
// Returns: "Missing key" (fallback)
```

### `ngettext(singular, plural, count, vars?)`

Get a translated string with plural handling.

**Parameters:**
- `singular: string` - Singular form (e.g., "1 item")
- `plural: string` - Plural form (e.g., "%{count} items")
- `count: number` - Number to determine singular/plural
- `vars?: Record<string, string | number>` - Optional additional variables

**Returns:** `string` - Translated string with count and variables interpolated

**Examples:**
```typescript
ngettext("1 item", "%{count} items", 1);
// Returns: "1 objekt"

ngettext("1 item", "%{count} items", 5);
// Returns: "5 objekt"

ngettext("%{user} has 1 item", "%{user} has %{count} items", 3, { user: "Anna" });
// Returns: "Anna har 3 objekt"
```

### `isInitialized()`

Check if translations have been initialized.

**Returns:** `boolean` - true if initTranslations has been called

**Example:**
```typescript
if (!isInitialized()) {
  console.warn("Translations not loaded yet");
}
```

### `resetTranslations()`

Reset translations to empty state (useful for testing).

**Example:**
```typescript
// In tests
beforeEach(() => {
  resetTranslations();
});
```

## Interpolation

Variable interpolation uses the `%{varname}` syntax:

```typescript
gettext("Hello %{first} %{last}", { first: "Anna", last: "Andersson" });
// Returns: "Hej Anna Andersson"
```

**Features:**
- Supports both string and number values
- Handles missing variables gracefully (leaves placeholder)
- Escapes regex special characters in variable names
- Replaces all occurrences of the same variable

## Plural Rules

Currently uses simple English plural rules:
- `count === 1` → singular form
- `count !== 1` → plural form

Future versions will support CLDR plural rules for other languages.

## TypeScript Support

Full TypeScript definitions included:

```typescript
import type { TranslationVars } from './translations';

const vars: TranslationVars = {
  name: "Anna",
  count: 42
};

gettext("Hello %{name}, you have %{count}", vars);
```

## Testing

Run tests:
```bash
npm test
```

Run tests with coverage:
```bash
npm run test:coverage
```

Build TypeScript:
```bash
npm run build
```

## Edge Cases Handled

- Escaped quotes (`\"`, `\'`)
- Special characters in translations
- Newlines in translation strings
- Multiple occurrences of same variable
- Regex special characters in variable names
- Empty strings
- Missing translations (fallback to key)
- Swedish characters (åäö) and UTF-8

## Browser Support

Requires ES2020 support:
- Chrome 80+
- Firefox 72+
- Safari 13.1+
- Edge 80+

## License

MIT

## Contributing

Part of the [LiveSvelteGettext](https://github.com/xnilsson/live_svelte_gettext) project.
See the main repository for contribution guidelines.

## Related Projects

- [live_svelte_gettext](https://hex.pm/packages/live_svelte_gettext) - Elixir library
- [live_svelte](https://hex.pm/packages/live_svelte) - Svelte integration for Phoenix LiveView
- [gettext](https://hex.pm/packages/gettext) - Elixir internationalization library
