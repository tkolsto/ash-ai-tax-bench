# Run: elixir analyze.exs results/pilot.jsonl
[path | _] = System.argv()

all_rows =
  path
  |> File.stream!()
  |> Enum.map(&String.trim/1)
  |> Enum.reject(&(&1 == ""))
  |> Enum.map(&:json.decode/1)

# Only completed (green) runs are token-comparable; incomplete runs under-count.
rows = Enum.filter(all_rows, & &1["completed"])
excluded = length(all_rows) - length(rows)
if excluded > 0, do: IO.puts("(excluded #{excluded} non-green run(s) from the comparison)")

cells = Enum.group_by(rows, &{&1["agent"], &1["framework"]})
mean = fn xs -> if xs == [], do: 0.0, else: Enum.sum(xs) / length(xs) end

summary =
  for {{agent, fw}, rs} <- cells, into: %{} do
    {{agent, fw},
     %{
       n: length(rs),
       mean_total: mean.(Enum.map(rs, & &1["total"])),
       mean_turns: mean.(Enum.map(rs, & &1["turns"])),
       completed: Enum.count(rs, & &1["completed"])
     }}
  end

IO.puts("\n== Per-cell (only completed=green runs should be trusted) ==")

for {{agent, fw}, m} <- Enum.sort(summary) do
  :io.format("~-8s ~-5s n=~p mean_total=~.0f mean_turns=~.1f green=~p/~p~n",
    [agent, fw, m.n, m.mean_total, m.mean_turns, m.completed, m.n])
end

IO.puts("\n== Within-agent Ash-vs-Ecto delta (the headline metric) ==")
agents = rows |> Enum.map(& &1["agent"]) |> Enum.uniq()

for agent <- agents do
  ash = summary[{agent, "ash"}]
  ecto = summary[{agent, "ecto"}]

  if ash && ecto && ecto.mean_total > 0 do
    delta = (ash.mean_total - ecto.mean_total) / ecto.mean_total * 100
    :io.format("~-8s Ash uses ~+.1f% tokens vs Ecto (ash=~.0f, ecto=~.0f)~n",
      [agent, delta, ash.mean_total, ecto.mean_total])
  end
end

IO.puts("")
