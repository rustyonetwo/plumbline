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
end
