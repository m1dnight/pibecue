now = DateTime.utc_now()

for s <- 1..1000 do
  now = DateTime.add(now, -1 * s, :hour)

  for i <- 1..5 do
    time = DateTime.add(now, -1 * i, :second) |> DateTime.truncate(:second)

    %Barbecue.Storage.State{
      temperature: i * 1.0,
      fan_speed: i * 1.0,
      inserted_at: time,
      target_temperature: 123.0
    }
    |> Barbecue.Repo.insert()
  end
end
