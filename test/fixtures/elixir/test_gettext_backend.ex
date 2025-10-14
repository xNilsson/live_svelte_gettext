# Test fixture: Gettext backend
defmodule TestAppWeb.Gettext do
  use Gettext.Backend, otp_app: :test_app
end
