defmodule LiveSvelteGettext.Components do
  @moduledoc """
  Phoenix components for LiveSvelteGettext.

  This module provides reusable components for injecting Svelte translations
  into your Phoenix templates.

  ## Usage

  Import this module in your component helpers or directly in templates:

      import LiveSvelteGettext.Components

  Then use the `svelte_translations` component to inject translations:

      <.svelte_translations />

  ## Configuration

  By default, the component reads the Gettext module from application config:

      # config/config.exs
      config :live_svelte_gettext,
        gettext: MyAppWeb.Gettext

  This is automatically configured when you run:

      mix igniter.install live_svelte_gettext

  You can also pass the Gettext module explicitly:

      <.svelte_translations gettext_module={MyAppWeb.Gettext} />

  ## Examples

      # Basic usage (uses config)
      <.svelte_translations />

      # With explicit locale
      <.svelte_translations locale="fr" />

      # With explicit Gettext module (for multi-tenant apps)
      <.svelte_translations gettext_module={TenantA.Gettext} />

      # Custom script tag ID
      <.svelte_translations id="my-translations" />
  """

  use Phoenix.Component
  import Phoenix.HTML, only: [raw: 1]

  @doc """
  Injects Svelte translations into the page and sets up auto-initialization.

  This component must be placed in your template before any LiveSvelte
  components that need translations. It's recommended to place it in your
  root layout or at the top of LiveView templates that use Svelte components.

  ## Attributes

  - `:gettext_module` - The Gettext module to use. Defaults to the module
    configured in `:live_svelte_gettext, :gettext` application config.

  - `:locale` - Explicit locale override. Defaults to the current locale
    from `Gettext.get_locale/1`.

  - `:id` - HTML id attribute for the script tag. Defaults to `"svelte-translations"`.

  ## How It Works

  1. Fetches all translations from the configured Gettext module's `SvelteStrings`
     submodule (which is generated at compile time)
  2. Encodes them as JSON and injects a `<script type="application/json">` tag
  3. Adds an invisible div with a Phoenix LiveView hook (`phx-hook="LiveSvelteGettextInit"`)
     that automatically reads the JSON and initializes translations when the page mounts

  ## Setup Required

  To use auto-initialization, you must register the `LiveSvelteGettextInit` hook
  in your `assets/js/app.js`:

      import { LiveSvelteGettextInit } from "live-svelte-gettext"

      const liveSocket = new LiveSocket("/live", Socket, {
        hooks: {
          ...getHooks(Components),
          LiveSvelteGettextInit,  // Add this line
        }
      })

  The hook is exported from the `live-svelte-gettext` NPM package.

  ## Examples

      # Minimal usage - uses application config for Gettext module
      <.svelte_translations />

      # Override locale (useful for previewing translations)
      <.svelte_translations locale="es" />

      # Multi-tenant app with different Gettext modules
      <.svelte_translations gettext_module={@current_tenant.gettext_module} />

      # Custom script tag ID (if you have multiple translation sets)
      <.svelte_translations id="admin-translations" />

  ## Placement

  Place this component before your Svelte components:

      <.svelte_translations />

      <.svelte name="MyComponent" props={%{...}} />

  Or in your root layout for site-wide availability:

      # lib/my_app_web/components/layouts/root.html.heex
      <.svelte_translations />
      <%= @inner_content %>
  """
  attr(:gettext_module, :atom,
    default: nil,
    doc: "Gettext module (defaults to :live_svelte_gettext :gettext config)"
  )

  attr(:locale, :string,
    default: nil,
    doc: "Locale override (defaults to current locale)"
  )

  attr(:id, :string,
    default: "svelte-translations",
    doc: "HTML id attribute for the script tag"
  )

  def svelte_translations(assigns) do
    # Get Gettext module from assigns or application config
    gettext_module =
      assigns.gettext_module ||
        Application.get_env(:live_svelte_gettext, :gettext) ||
        raise_configuration_error()

    # Get locale (explicit or from Gettext.get_locale)
    locale = assigns.locale || Gettext.get_locale(gettext_module)

    # Get translations from the generated SvelteStrings module
    svelte_strings_module = Module.concat(gettext_module, SvelteStrings)

    unless Code.ensure_loaded?(svelte_strings_module) do
      raise """
      LiveSvelteGettext: Module #{inspect(svelte_strings_module)} not found!

      Make sure you have added `use LiveSvelteGettext` to your Gettext module:

          defmodule #{inspect(gettext_module)} do
            use Gettext.Backend, otp_app: :my_app
            use LiveSvelteGettext,
              gettext_backend: __MODULE__,
              svelte_path: "assets/svelte"
          end
      """
    end

    translations = svelte_strings_module.all_translations(locale)

    assigns = assign(assigns, :translations, translations)

    ~H"""
    <script id={@id} type="application/json">
      <%= raw Jason.encode!(@translations) %>
    </script>
    <div
      id={"#{@id}-init"}
      phx-hook="LiveSvelteGettextInit"
      data-translations-id={@id}
      style="display:none;"
    >
    </div>
    """
  end

  defp raise_configuration_error do
    raise """
    LiveSvelteGettext: No Gettext module configured!

    You need to configure your Gettext module in one of two ways:

    1. Application config (recommended):

       # config/config.exs
       config :live_svelte_gettext,
         gettext: MyAppWeb.Gettext

       This is automatically added when you run:
       mix igniter.install live_svelte_gettext

    2. Pass explicitly to the component:

       <.svelte_translations gettext_module={MyAppWeb.Gettext} />

    For more information, see: https://hexdocs.pm/live_svelte_gettext
    """
  end
end
