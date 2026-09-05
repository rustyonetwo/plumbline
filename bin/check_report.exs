#!/usr/bin/env elixir
# Reads a checkpoint report (one JSON object per line) written by the
# HCW notebook's Checkpoint helper and turns it into a process exit
# code. See bin/run_checkpoint for how this gets invoked, and
# AGENTS.md's "Verifying your work" section for the contract this
# implements: a run passes only if the completion sentinel is present,
# every declared check is recorded, and every check is true.
#
# Usage: elixir bin/check_report.exs <path-to-report.jsonl>

[report_path] = System.argv()

lines =
  if File.exists?(report_path) do
    report_path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&JSON.decode!/1)
  else
    []
  end

manifest =
  Enum.find_value(lines, [], fn
    %{"manifest" => names} -> names
    _ -> nil
  end)

complete? = Enum.any?(lines, &match?(%{"complete" => true}, &1))

results =
  lines
  |> Enum.filter(&Map.has_key?(&1, "check"))
  |> Map.new(fn %{"check" => name} = r -> {name, r} end)

missing = manifest -- Map.keys(results)
failed = for {name, %{"ok" => false} = r} <- results, do: {name, r}

IO.puts("")
IO.puts("=== Checkpoint report ===")
IO.puts("manifest: #{inspect(manifest)}")
IO.puts("sentinel present: #{complete?}")
IO.puts("checks recorded: #{map_size(results)}/#{length(manifest)}")

for {name, r} <- results do
  status = if r["ok"], do: "PASS", else: "FAIL"
  IO.puts("  #{status}  #{name}  #{inspect(Map.drop(r, ["check", "ok"]))}")
end

cond do
  manifest == [] ->
    IO.puts(
      "\nFAIL — no manifest found in report (notebook may not have started, " <>
        "or PLUMBLINE_REPORT_PATH was never read)."
    )

    System.halt(1)

  not complete? ->
    IO.puts(
      "\nFAIL — no completion sentinel. Evaluation was aborted (uncaught " <>
        "exception, timeout, or the server never finished) before every cell ran."
    )

    System.halt(1)

  missing != [] ->
    IO.puts("\nFAIL — checks declared in the manifest never ran: #{inspect(missing)}")
    System.halt(1)

  failed != [] ->
    IO.puts(
      "\nFAIL — #{length(failed)} check(s) recorded ok:false: " <>
        inspect(Enum.map(failed, &elem(&1, 0)))
    )

    System.halt(1)

  true ->
    IO.puts("\nPASS — all #{length(manifest)} checks present and true.")
    System.halt(0)
end
