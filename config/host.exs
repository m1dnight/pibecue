import Config

config :barbecue,
  thermocouple: Barbecue.IO.Thermocouple.Mock,
  fan_speed: Barbecue.IO.Fanspeed.Mock

config :barbecue,
  ecto_repos: [Barbecue.Repo]

config :barbecue, Barbecue.Repo,
  database: ".db/barbecue.db",
  show_sensitive_data_on_connection_error: false,
  journal_mode: :wal,
  cache_size: -64000,
  temp_store: :memory,
  pool_size: 1
