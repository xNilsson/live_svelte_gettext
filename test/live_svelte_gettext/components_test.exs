defmodule LiveSvelteGettext.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import LiveSvelteGettext.Components

  # Test Gettext backend module
  defmodule TestGettext do
    use Gettext.Backend, otp_app: :live_svelte_gettext

    # Mock SvelteStrings module
    defmodule SvelteStrings do
      def all_translations("en") do
        %{
          "Hello" => "Hello",
          "Welcome" => "Welcome",
          "Goodbye" => "Goodbye"
        }
      end

      def all_translations("es") do
        %{
          "Hello" => "Hola",
          "Welcome" => "Bienvenido",
          "Goodbye" => "Adiós"
        }
      end
    end
  end

  setup do
    # Set default locale
    Gettext.put_locale(TestGettext, "en")

    :ok
  end

  describe "svelte_translations/1" do
    test "renders script tag with translations from application config" do
      # Configure application config
      original_config = Application.get_env(:live_svelte_gettext, :gettext)

      try do
        Application.put_env(:live_svelte_gettext, :gettext, TestGettext)

        assigns = %{}

        html =
          rendered_to_string(~H"""
          <.svelte_translations />
          """)

        assert html =~ ~s(<script id="svelte-translations" type="application/json">)
        assert html =~ ~s("Hello":"Hello")
        assert html =~ ~s("Welcome":"Welcome")
        assert html =~ ~s("Goodbye":"Goodbye")
      after
        # Restore original config
        if original_config do
          Application.put_env(:live_svelte_gettext, :gettext, original_config)
        else
          Application.delete_env(:live_svelte_gettext, :gettext)
        end
      end
    end

    test "renders script tag with translations from explicit gettext_module attribute" do
      # Don't set application config - use explicit module
      original_config = Application.get_env(:live_svelte_gettext, :gettext)

      try do
        Application.delete_env(:live_svelte_gettext, :gettext)

        assigns = %{}

        html =
          rendered_to_string(~H"""
          <.svelte_translations gettext_module={TestGettext} />
          """)

        assert html =~ ~s(<script id="svelte-translations" type="application/json">)
        assert html =~ ~s("Hello":"Hello")
        assert html =~ ~s("Welcome":"Welcome")
      after
        # Restore original config
        if original_config do
          Application.put_env(:live_svelte_gettext, :gettext, original_config)
        end
      end
    end

    test "explicit gettext_module overrides application config" do
      # Set config to a different module (which doesn't exist)
      original_config = Application.get_env(:live_svelte_gettext, :gettext)

      try do
        Application.put_env(:live_svelte_gettext, :gettext, :some_other_module)

        assigns = %{}

        html =
          rendered_to_string(~H"""
          <.svelte_translations gettext_module={TestGettext} />
          """)

        # Should use TestGettext translations, not config
        assert html =~ ~s("Hello":"Hello")
      after
        # Restore original config
        if original_config do
          Application.put_env(:live_svelte_gettext, :gettext, original_config)
        else
          Application.delete_env(:live_svelte_gettext, :gettext)
        end
      end
    end

    test "respects explicit locale attribute" do
      original_config = Application.get_env(:live_svelte_gettext, :gettext)

      try do
        Application.put_env(:live_svelte_gettext, :gettext, TestGettext)

        assigns = %{}

        html =
          rendered_to_string(~H"""
          <.svelte_translations locale="es" />
          """)

        # Should have Spanish translations
        assert html =~ ~s("Hello":"Hola")
        assert html =~ ~s("Welcome":"Bienvenido")
        assert html =~ ~s("Goodbye":"Adiós")
      after
        # Restore original config
        if original_config do
          Application.put_env(:live_svelte_gettext, :gettext, original_config)
        else
          Application.delete_env(:live_svelte_gettext, :gettext)
        end
      end
    end

    test "uses current locale from Gettext when no explicit locale" do
      original_config = Application.get_env(:live_svelte_gettext, :gettext)

      try do
        Application.put_env(:live_svelte_gettext, :gettext, TestGettext)

        # Set locale to Spanish
        Gettext.put_locale(TestGettext, "es")

        assigns = %{}

        html =
          rendered_to_string(~H"""
          <.svelte_translations />
          """)

        # Should have Spanish translations
        assert html =~ ~s("Hello":"Hola")
      after
        # Restore original config and locale
        Gettext.put_locale(TestGettext, "en")

        if original_config do
          Application.put_env(:live_svelte_gettext, :gettext, original_config)
        else
          Application.delete_env(:live_svelte_gettext, :gettext)
        end
      end
    end

    test "respects custom id attribute" do
      original_config = Application.get_env(:live_svelte_gettext, :gettext)

      try do
        Application.put_env(:live_svelte_gettext, :gettext, TestGettext)

        assigns = %{}

        html =
          rendered_to_string(~H"""
          <.svelte_translations id="custom-translations" />
          """)

        assert html =~ ~s(<script id="custom-translations" type="application/json">)
      after
        # Restore original config
        if original_config do
          Application.put_env(:live_svelte_gettext, :gettext, original_config)
        else
          Application.delete_env(:live_svelte_gettext, :gettext)
        end
      end
    end

    test "includes Phoenix hook div for auto-initialization" do
      original_config = Application.get_env(:live_svelte_gettext, :gettext)

      try do
        Application.put_env(:live_svelte_gettext, :gettext, TestGettext)

        assigns = %{}

        html =
          rendered_to_string(~H"""
          <.svelte_translations />
          """)

        # Should have the JSON script tag
        assert html =~ ~s(<script id="svelte-translations" type="application/json">)

        # Should have the Phoenix hook div
        assert html =~ ~s(phx-hook="LiveSvelteGettextInit")
        assert html =~ ~s(data-translations-id="svelte-translations")
        assert html =~ ~s(style="display:none;")
      after
        # Restore original config
        if original_config do
          Application.put_env(:live_svelte_gettext, :gettext, original_config)
        else
          Application.delete_env(:live_svelte_gettext, :gettext)
        end
      end
    end

    test "hook div uses custom id attribute" do
      original_config = Application.get_env(:live_svelte_gettext, :gettext)

      try do
        Application.put_env(:live_svelte_gettext, :gettext, TestGettext)

        assigns = %{}

        html =
          rendered_to_string(~H"""
          <.svelte_translations id="my-custom-id" />
          """)

        # Should reference custom ID in hook data attribute
        assert html =~ ~s(data-translations-id="my-custom-id")
        # Hook div should have unique ID based on translations ID
        assert html =~ ~s(id="my-custom-id-init")
      after
        # Restore original config
        if original_config do
          Application.put_env(:live_svelte_gettext, :gettext, original_config)
        else
          Application.delete_env(:live_svelte_gettext, :gettext)
        end
      end
    end

    test "raises helpful error when no gettext_module configured or provided" do
      # Remove application config
      original_config = Application.get_env(:live_svelte_gettext, :gettext)

      try do
        Application.delete_env(:live_svelte_gettext, :gettext)

        assigns = %{}

        assert_raise RuntimeError, ~r/No Gettext module configured/, fn ->
          rendered_to_string(~H"""
          <.svelte_translations />
          """)
        end
      after
        # Restore original config
        if original_config do
          Application.put_env(:live_svelte_gettext, :gettext, original_config)
        end
      end
    end

    test "raises helpful error when SvelteStrings module not found" do
      # Create a module without SvelteStrings
      defmodule BadGettext do
        use Gettext.Backend, otp_app: :live_svelte_gettext
      end

      original_config = Application.get_env(:live_svelte_gettext, :gettext)

      try do
        Application.put_env(:live_svelte_gettext, :gettext, BadGettext)

        assigns = %{}

        assert_raise RuntimeError,
                     ~r/Module LiveSvelteGettext\.ComponentsTest\.BadGettext\.SvelteStrings not found/,
                     fn ->
                       rendered_to_string(~H"""
                       <.svelte_translations />
                       """)
                     end
      after
        # Restore original config
        if original_config do
          Application.put_env(:live_svelte_gettext, :gettext, original_config)
        else
          Application.delete_env(:live_svelte_gettext, :gettext)
        end
      end
    end
  end

  # Helper to render component to string
  defp rendered_to_string(rendered) do
    rendered
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end
