defmodule LiveSvelteGettext do
  @moduledoc """
  Zero-maintenance i18n for Phoenix + Svelte applications.

  This module provides compile-time extraction of translation strings from
  Svelte components and generates the necessary code to make translations
  available at runtime.

  ## Usage

  In your Gettext backend module:

      defmodule MyAppWeb.Gettext do
        use Gettext.Backend, otp_app: :my_app
        use LiveSvelteGettext,
          gettext_backend: __MODULE__,
          svelte_path: "assets/svelte"
      end

  This will:
  1. Scan all `.svelte` files in `svelte_path` at compile time
  2. Extract translation strings using `gettext()` and `ngettext()` calls
  3. Generate code that `mix gettext.extract` can discover
  4. Generate an `all_translations/1` function for runtime use
  5. Set up `@external_resource` to recompile when Svelte files change

  ## Configuration Options

  - `:gettext_backend` (required) - The Gettext backend module to use
  - `:svelte_path` (required) - Path to the directory containing Svelte files (relative to project root)

  ## Runtime API

  After using this module, you'll have access to:

  - `all_translations(locale)` - Returns a map of all translations for the given locale
  - `__lsg_metadata__/0` - Debug function showing extracted strings and source files

  ## Example

      # In your LiveView or component:
      def mount(_params, _session, socket) do
        translations = MyAppWeb.Gettext.all_translations("en")
        {:ok, assign(socket, :translations, translations)}
      end

      # In your Svelte component:
      import { setTranslations } from 'livesvelte-gettext'
      export let translations
      setTranslations(translations)
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
