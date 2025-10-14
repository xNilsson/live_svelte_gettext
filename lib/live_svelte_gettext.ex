defmodule LiveSvelteGettext do
  @moduledoc """
  Compile-time translation extraction for Phoenix + Svelte applications.

  This module provides a proof-of-concept solution for using Phoenix Gettext
  in Svelte components. It was extracted from a real project and addresses
  the challenge raised in [live_svelte#120](https://github.com/woutdp/live_svelte/issues/120).

  ## The Approach

  Uses Elixir macros at compile time to:
  - Scan `.svelte` files for `gettext()` and `ngettext()` calls
  - Generate Elixir code that integrates with `mix gettext.extract`
  - Preserve accurate source references (e.g., `assets/svelte/Button.svelte:42`)
  - Runtime translations:
    - `LiveSvelteGettextInit` hook and `.svelte_translation` components adds translations to svelte files.
    - Translation access via `all_translations/1`

  No generated files are committed - everything happens at compile time using
  `@external_resource` for automatic recompilation when Svelte files change.

  ## Quick Start

  ### 1. Setup (using Igniter installer)

      mix igniter.install live_svelte_gettext

  This automatically configures your Gettext module:

      defmodule MyAppWeb.Gettext do
        use Gettext.Backend, otp_app: :my_app
        use LiveSvelteGettext,
          gettext_backend: __MODULE__,
          svelte_path: "assets/svelte"
      end

  ### 2. Register the Phoenix hook (required)

  In your `assets/js/app.js`:

      import { LiveSvelteGettextInit } from "live-svelte-gettext"

      const liveSocket = new LiveSocket("/live", Socket, {
        hooks: {
          ...getHooks(Components),
          LiveSvelteGettextInit,  // Add this line
        }
      })

  ### 3. Add translations to your template

  In your LiveView or layout:

      <.svelte_translations />
      <.svelte name="MyComponent" props={%{...}} />

  ### 4. Use translations in Svelte (zero boilerplate!)

      <script>
        import { gettext } from 'live-svelte-gettext'
      </script>

      <h1>{gettext("Welcome to our app")}</h1>
      <p>{gettext("Hello, %{name}", { name: "World" })}</p>

  That's it! Translations are automatically initialized when the page loads.

  ## How It Works

  **Compile time** (when you run `mix compile`):
  1. The `use LiveSvelteGettext` macro scans all `.svelte` files in `svelte_path`
  2. Regex patterns extract `gettext()` and `ngettext()` calls with file:line metadata
  3. Generated Elixir code includes:
     - `@external_resource` attributes (triggers recompilation on file changes)
     - Calls to `CustomExtractor.extract_with_location/8` (preserves Svelte source locations)
     - An `all_translations/1` function for runtime
  4. When you run `mix gettext.extract`, it discovers these generated calls
  5. The `CustomExtractor` modifies `Macro.Env` to inject accurate Svelte file:line into `.pot` files

  **Runtime** (when the page loads):
  1. The `<.svelte_translations />` component fetches translations and renders JSON in a `<script>` tag
  2. The `LiveSvelteGettextInit` Phoenix hook reads the JSON and initializes translations
  3. Svelte components call `gettext()` and `ngettext()` - interpolation happens in the browser

  ## Configuration Options

  - `:gettext_backend` (required) - The Gettext backend module to use
  - `:svelte_path` (required) - Path to the directory containing Svelte files (relative to project root)

  ## Runtime API

  After using this module, you'll have access to:

  - `all_translations(locale)` - Returns a map of all translations for the given locale
  - `__lsg_metadata__/0` - Debug function showing extracted strings and source files

  ## Advanced Usage

  ### Manual Initialization (for edge cases)

  If you need more control (e.g., multi-tenant apps, custom loading logic), you can
  manually pass translations to Svelte components:

      # In your LiveView:
      def mount(_params, _session, socket) do
        translations = MyAppWeb.Gettext.all_translations("en")
        {:ok, assign(socket, :translations, translations)}
      end

      # In your Svelte component:
      <script>
        import { initTranslations, gettext } from 'live-svelte-gettext'
        export let translations
        initTranslations(translations)
      </script>

      <h1>{gettext("Welcome")}</h1>

  Note: Most users should use the automatic Phoenix hook approach shown in Quick Start.
  """

  @doc """
  Macro for setting up LiveSvelteGettext in your Gettext backend.

  See module documentation for usage examples.
  """
  defmacro __using__(opts) do
    # Validate options at compile time
    LiveSvelteGettext.Compiler.validate_options!(opts)

    # Extract configuration
    gettext_backend = Keyword.fetch!(opts, :gettext_backend)
    svelte_path = Keyword.fetch!(opts, :svelte_path)

    # Generate the module code
    LiveSvelteGettext.Compiler.generate(
      __CALLER__.module,
      gettext_backend,
      svelte_path
    )
  end
end
