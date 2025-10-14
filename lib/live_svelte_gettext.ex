defmodule LiveSvelteGettext do
  @moduledoc """
  Zero-maintenance i18n for Phoenix + Svelte applications.

  This module provides compile-time extraction of translation strings from
  Svelte components and generates the necessary code to make translations
  available at runtime.

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

  At compile time:
  1. Scans all `.svelte` files in `svelte_path`
  2. Extracts translation strings using `gettext()` and `ngettext()` calls
  3. Generates code that `mix gettext.extract` can discover
  4. Generates an `all_translations/1` function for runtime use
  5. Sets up `@external_resource` to recompile when Svelte files change

  At runtime:
  1. `<.svelte_translations />` component fetches translations from your Gettext module
  2. Renders them as JSON in a `<script>` tag
  3. `LiveSvelteGettextInit` Phoenix hook reads the JSON and initializes translations
  4. Your Svelte components can immediately use `gettext()` and `ngettext()`

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
