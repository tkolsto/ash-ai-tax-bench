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
commas = fn n ->
  n |> round() |> Integer.to_string() |> String.reverse()
  |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
end
pad = fn s, n -> String.pad_trailing(to_string(s), n) end

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
  IO.puts(
    "#{pad.(agent, 7)} #{pad.(fw, 5)} n=#{m.n}  mean_total=#{pad.(commas.(m.mean_total), 11)}" <>
      " mean_turns=#{Float.round(m.mean_turns, 1)}  green=#{m.completed}/#{m.n}"
  )
end

IO.puts("\n== Within-agent Ash-vs-Ecto delta (the headline metric) ==")
agents = rows |> Enum.map(& &1["agent"]) |> Enum.uniq()

for agent <- agents do
  ash = summary[{agent, "ash"}]
  ecto = summary[{agent, "ecto"}]

  if ash && ecto && ecto.mean_total > 0 do
    delta = (ash.mean_total - ecto.mean_total) / ecto.mean_total * 100
    sign = if delta >= 0, do: "+", else: ""
    IO.puts(
      "#{pad.(agent, 7)} Ash uses #{sign}#{Float.round(delta, 1)}% tokens vs Ecto " <>
        "(ash=#{commas.(ash.mean_total)}, ecto=#{commas.(ecto.mean_total)})"
    )
  end
end

IO.puts("")
