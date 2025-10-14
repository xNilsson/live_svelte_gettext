# Test fixture: Gettext backend
defmodule TestAppWeb.Gettext do
  @moduledoc false

  use Gettext.Backend, otp_app: :test_app
end
