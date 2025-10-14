# Test fixture: Simple Phoenix web module
defmodule TestAppWeb do
  def html do
    quote do
      use Phoenix.Component
      import Phoenix.Controller
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView
      import Phoenix.Component
    end
  end
end
