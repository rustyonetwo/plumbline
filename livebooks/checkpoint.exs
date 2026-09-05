# Checkpoint reporting for hcw_orbital_mechanics.livemd.
#
# This is notebook infrastructure, deliberately kept out of `lib/` —
# `lib/` is one struct and one propagator, and this is neither. The
# notebook loads it with a single `Code.require_file/1`.
#
# Two jobs:
#
#   * Record each invariant check as it runs — printed for a human, and
#     (when PLUMBLINE_REPORT_PATH is set) appended as one JSON line to
#     that path for bin/check_report.exs to turn into an exit code.
#   * Make a failure impossible to miss, without stopping the run at the
#     first one. `check/3` never raises, so every invariant is reported
#     in a single pass; `complete/0` writes the completion sentinel and
#     *then* raises if anything failed.
#
# The sentinel is written before the raise deliberately. A run whose
# physics is wrong must look different from a run whose evaluation broke
# partway through: the first has a sentinel and an `"ok": false`, the
# second has no sentinel at all.

defmodule Checkpoint do
  @moduledoc """
  Records the notebook's invariant checks. See the comment block at the
  top of this file for the design, and the notebook's section 5 for how
  it is used.
  """

  @report_path System.get_env("PLUMBLINE_REPORT_PATH")
  @failures {__MODULE__, :failures}

  @doc """
  Call once, before any checks, with every check name that will run.

  The manifest lives in the notebook rather than here on purpose: it is
  what catches an assertion cell being deleted without the deletion
  being noticed, so it has to sit next to the assertions it describes.
  """
  def init(check_names) do
    :persistent_term.put(@failures, [])

    if @report_path do
      # This write truncates, where check/3 appends. That asymmetry is
      # deliberate and load-bearing, not an inconsistency to tidy away.
      #
      # It guarantees a report describes exactly ONE run. The wrapper's
      # contract is: sentinel present, AND every declared check present,
      # AND every one true. If records accumulated across runs, a check
      # that had stopped running could still be "present" and green from
      # a previous pass — which would quietly gut the completeness half
      # of that contract.
      #
      # Under bin/run_checkpoint this can never bite, because every run
      # gets a fresh timestamped path. It bites interactively, when the
      # notebook is re-evaluated in Livebook against a fixed
      # PLUMBLINE_REPORT_PATH — the one path with no automated gate on
      # it, which is the worst place for a silent failure to live.
      #
      # Truncating would destroy that earlier run, so it is moved aside
      # first: reports are kept in full, and a run displaced by a re-run
      # is still a run.
      archive_existing(@report_path)
      File.write!(@report_path, JSON.encode!(%{"manifest" => check_names}) <> "\n")
    end

    :ok
  end

  @doc """
  Records one check's result and returns `ok?` unchanged.

  Never raises, so a failed invariant does not prevent the remaining
  ones from being checked and reported. `details` may include
  `:expected`, `:actual`, `:tolerance`, `:unit` and `:message` —
  whatever makes the result diagnosable without re-running the notebook.
  """
  def check(name, ok?, details \\ []) do
    status = if ok?, do: "PASS", else: "FAIL"

    detail_str =
      details
      |> Enum.map(fn {k, v} -> "#{k}=#{inspect(v)}" end)
      |> Enum.join(" ")

    IO.puts("#{name}  #{status}  #{detail_str}")

    if @report_path do
      record = Map.merge(%{"check" => name, "ok" => ok?}, stringify_keys(details))
      File.write!(@report_path, JSON.encode!(record) <> "\n", [:append])
    end

    unless ok? do
      :persistent_term.put(@failures, [name | :persistent_term.get(@failures, [])])
    end

    ok?
  end

  @doc """
  Call once, as the very last cell, after every check has run.

  Writes the completion sentinel, then raises if any check failed.
  """
  def complete do
    if @report_path do
      File.write!(@report_path, JSON.encode!(%{"complete" => true}) <> "\n", [:append])
    end

    case Enum.reverse(:persistent_term.get(@failures, [])) do
      [] ->
        IO.puts("\nAll invariants hold.")
        :ok

      failed ->
        raise """
        #{length(failed)} invariant(s) failed: #{Enum.join(failed, ", ")}

        The implementation does not satisfy this notebook. Scroll up for
        each failing check's expected and actual values. Fix the
        implementation — not the assertion.
        """
    end
  end

  defp stringify_keys(details), do: Map.new(details, fn {k, v} -> {to_string(k), v} end)

  # Move a previous report out of the way rather than overwriting it.
  #
  # The suffix uses a hyphen rather than a dot so the archived run sorts
  # *before* the live one ("-" < "." in byte order) — bin/
  # checkpoint_history.exs sorts report filenames to order the series,
  # and the displaced run is the older of the two. Zero-padded so the
  # tenth re-run does not sort between the first and the second.
  #
  # Never raises. Failing to archive must not fail a run, and a run that
  # cannot write its report has a much louder problem than this.
  defp archive_existing(path) do
    case File.stat(path) do
      {:ok, %{size: size}} when size > 0 ->
        dest = free_archive_name(path, 1)

        case File.rename(path, dest) do
          :ok ->
            IO.puts("previous report displaced to #{Path.basename(dest)}")

          {:error, reason} ->
            IO.puts("WARNING: could not archive #{path} (#{reason}); it will be overwritten")
        end

      _ ->
        :ok
    end
  end

  defp free_archive_name(path, n) do
    suffix = String.pad_leading(to_string(n), 2, "0")
    candidate = "#{Path.rootname(path)}-superseded-#{suffix}#{Path.extname(path)}"

    if File.exists?(candidate), do: free_archive_name(path, n + 1), else: candidate
  end
end
