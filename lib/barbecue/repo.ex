defmodule Barbecue.Repo do
  use Ecto.Repo, otp_app: :barbecue, adapter: Ecto.Adapters.SQLite3
end
