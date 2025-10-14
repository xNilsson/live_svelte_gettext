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

[Step-by-step guide]

## How It Works

[Architecture explanation]

## API Documentation

[Link to HexDocs]

## Contributing

[Guidelines]

## License

MIT License - see LICENSE file
