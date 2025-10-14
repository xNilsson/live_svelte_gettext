# Test fixture: Phoenix web module that USES Gettext (as a consumer, not a backend)
# This simulates a typical MyAppWeb module that should NOT be detected as a Gettext backend
defmodule TestAppWeb do
  @moduledoc false

  def controller do
    quote do
      use Phoenix.Controller

      use Gettext, backend: TestAppWeb.Gettext

      import Plug.Conn
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Translation helpers
      use Gettext, backend: TestAppWeb.Gettext

      import Phoenix.HTML
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      use Gettext, backend: TestAppWeb.Gettext
    end
  end
end
