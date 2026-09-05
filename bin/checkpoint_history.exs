#!/usr/bin/env elixir
# Renders the history of checkpoint reports written by bin/run_checkpoint,
# so convergence on the invariants — or regression away from them — is
# readable at a glance.
#
# Rows are invariants, columns are runs, oldest on the left. That
# orientation is deliberate: it makes a single invariant's trajectory
# across runs the thing you read horizontally, which is the question
# actually being asked ("is this one getting better or worse?").
#
# Usage: elixir bin/checkpoint_history.exs [reports_dir] [--limit N]

{opts, args, _} = OptionParser.parse(System.argv(), strict: [limit: :integer])

root = Path.dirname(Path.dirname(Path.expand(__ENV__.file)))

# Reports are kept per notebook, under reports/<notebook name>/, so a
# second notebook checking some further invariant gets its own history
# rather than interleaving with this one. The argument may be a notebook
# name or a path to a reports directory.
reports_dir =
  case args do
    [arg | _] ->
      if File.dir?(arg), do: arg, else: Path.join([root, "reports", arg])

    [] ->
      Path.join([root, "reports", "hcw_orbital_mechanics"])
  end

limit = Keyword.get(opts, :limit, 12)

defmodule History do
  def load(path) do
    lines =
      path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&JSON.decode!/1)

    manifest = Enum.find_value(lines, [], fn %{} = l -> Map.get(l, "manifest") end)
    complete? = Enum.any?(lines, &match?(%{"complete" => true}, &1))

    results =
      lines
      |> Enum.filter(&Map.has_key?(&1, "check"))
      |> Map.new(fn %{"check" => name} = r -> {name, r} end)

    %{
      label: path |> Path.basename() |> Path.rootname(),
      manifest: manifest,
      complete?: complete?,
      results: results
    }
  end

  def verdict(%{manifest: []}), do: "no manifest"
  def verdict(%{complete?: false}), do: "aborted"

  def verdict(%{manifest: manifest, results: results}) do
    missing = manifest -- Map.keys(results)
    failed = for {_, %{"ok" => false}} <- results, do: 1

    cond do
      missing != [] -> "#{length(missing)} missing"
      failed != [] -> "#{length(manifest) - length(failed)}/#{length(manifest)}"
      true -> "PASS"
    end
  end

  def glyph(run, check) do
    case run.results[check] do
      %{"ok" => true} -> "  ok"
      %{"ok" => false} -> "FAIL"
      nil -> "   ."
    end
  end

  def detail(run, check) do
    case run.results[check] do
      %{"ok" => false} = r ->
        parts =
          for k <- ["actual", "expected", "tolerance", "unit"],
              v = r[k],
              do: "#{k}=#{inspect(v)}"

        "    #{check}: #{Enum.join(parts, " ")}"

      _ ->
        nil
    end
  end
end

files =
  reports_dir
  |> Path.join("*.jsonl")
  |> Path.wildcard()
  |> Enum.sort()

if files == [] do
  IO.puts("No reports in #{reports_dir}. Run bin/run_checkpoint first.")
  System.halt(0)
end

runs = files |> Enum.take(-limit) |> Enum.map(&History.load/1)

checks =
  runs
  |> Enum.flat_map(& &1.manifest)
  |> Enum.uniq()

name_width =
  checks
  |> Enum.map(&String.length/1)
  |> Enum.max(fn -> 10 end)

IO.puts("\n#{length(files)} report(s) in #{reports_dir}, showing last #{length(runs)}\n")

# Column headers: run labels are long timestamps, so number them and
# print the legend underneath rather than wrapping the table.
header =
  runs
  |> Enum.with_index(1)
  |> Enum.map_join(" ", fn {_, i} -> String.pad_leading("##{i}", 4) end)

IO.puts("#{String.pad_trailing("invariant", name_width)}  #{header}")
IO.puts(String.duplicate("-", name_width + 2 + String.length(header)))

for check <- checks do
  row = Enum.map_join(runs, " ", &History.glyph(&1, check))
  IO.puts("#{String.pad_trailing(check, name_width)}  #{row}")
end

IO.puts(String.duplicate("-", name_width + 2 + String.length(header)))

verdict_row =
  Enum.map_join(runs, " ", fn run ->
    short =
      case History.verdict(run) do
        "aborted" -> "abrt"
        "no manifest" -> "  ??"
        other -> other
      end

    String.pad_leading(short, 4)
  end)

IO.puts("#{String.pad_trailing("verdict", name_width)}  #{verdict_row}")

IO.puts("\nruns:")

for {run, i} <- Enum.with_index(runs, 1) do
  IO.puts("  ##{i}  #{run.label}  #{History.verdict(run)}")
end

failures =
  runs
  |> List.last()
  |> then(fn last -> for c <- checks, d = History.detail(last, c), do: d end)

if failures != [] do
  IO.puts("\nmost recent run, failing checks:")
  Enum.each(failures, &IO.puts/1)
end

IO.puts("")
