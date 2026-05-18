case File.read("muex-report.json") do
  {:ok, raw} ->
    data = Jason.decode!(raw)
    s = data["summary"]

    IO.puts("\n=== MUTATION TESTING RESULTS ===")
    IO.puts("  Total:    #{s["total"]}")
    IO.puts("  Killed:   #{s["killed"]} (caught by tests)")
    IO.puts("  Survived: #{s["survived"]} (not caught — weak tests)")
    IO.puts("  Timeout:  #{s["timeout"]}")
    IO.puts("  Invalid:  #{s["invalid"]} (compilation errors)")

    low = s["mutation_score_low"]
    high = s["mutation_score_high"]
    score = if low == high, do: "#{low}%", else: "#{low}%..#{high}%"
    IO.puts("  Score:    #{score}")

    for {label, key} <- [{"SURVIVED", "survived"}, {"TIMED OUT", "timeout"}] do
      items = Enum.filter(data["mutations"], &(&1["status"] == key))
      IO.puts("\n=== #{label} MUTATIONS (#{length(items)}) ===")

      for m <- items do
        loc = m["location"]
        IO.puts("  #{loc["file"]}:#{loc["line"]} — #{m["mutator"]}: #{m["description"]} (#{m["duration_ms"]}ms)")
      end
    end

  {:error, _} ->
    :ok
end
