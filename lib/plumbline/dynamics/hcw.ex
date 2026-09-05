defmodule Plumbline.Dynamics.HCW do
  @moduledoc """
  Hill–Clohessy–Wiltshire relative orbital motion.

  **The specification for this module is not in this file.** It is
  `livebooks/hcw_orbital_mechanics.livemd`, which states the equations
  of motion, derives the invariants, and asserts them executably. This
  module is written to satisfy that notebook; the dependency runs one
  way and this module must never reference it.

  Read the notebook first. It explains the physics, the LVLH frame, and
  the three invariants (I1 periodicity, I2 cross-track decoupling,
  I3 conservation of the rotating-frame integral) that any correct
  implementation must satisfy.

  ## Conventions

  Positions in kilometres, velocities in kilometres per second, mean
  motion `n` in radians per second, times in seconds. The frame is the
  chief's LVLH frame: `x` radial (outward), `y` along-track, `z`
  cross-track.

  ## Validity envelope

  HCW assumes a circular chief orbit, separations small enough for the
  differential gravity field to be linearised, and no perturbations
  (no J2, drag, solar radiation pressure, or thrust). The invariants
  hold only inside that envelope.
  """

  defmodule State do
    @moduledoc """
    Relative state of the deputy in the chief's LVLH frame.

    Positions in km, velocities in km/s.
    """

    @type t :: %__MODULE__{
            x: float(),
            y: float(),
            z: float(),
            vx: float(),
            vy: float(),
            vz: float()
          }

    defstruct x: 0.0, y: 0.0, z: 0.0, vx: 0.0, vy: 0.0, vz: 0.0
  end

  # A step count is derived from `t_final / dt`, which is a float
  # division and so lands a hair either side of a whole number when the
  # caller intended an exact grid. A leftover smaller than this fraction
  # of a step is treated as the rounding it is, rather than as a real
  # final step of near-zero length.
  @grid_tolerance 1.0e-9

  @doc """
  The instantaneous time-derivative of `state`.

  This is the matrix `A` of the notebook's section 2 applied to the
  state vector. The returned `State` carries velocity in its position
  fields and acceleration in its velocity fields:

      x'  = vx
      y'  = vy
      z'  = vz
      vx' = 3n²x + 2n·vy
      vy' = -2n·vx
      vz' = -n²z

  A reader verifying this implementation should be able to place those
  six lines beside the matrix in the notebook and check them entry by
  entry. That legibility is the point of the exercise.
  """
  @spec derivative(State.t(), float()) :: State.t()
  def derivative(%State{} = state, n) do
    %State{
      x: state.vx,
      y: state.vy,
      z: state.vz,
      vx: 3 * n * n * state.x + 2 * n * state.vy,
      vy: -2 * n * state.vx,
      vz: -(n * n) * state.z
    }
  end

  @doc """
  One classical fourth-order Runge–Kutta step of size `dt`.

  RK4 rather than the closed-form state transition matrix: with the
  exact solution, periodicity would hold to machine epsilon by
  construction and the notebook's assertions would have no teeth.
  Numerical integration makes the tolerances load-bearing.

  Note that RK4 is *not* symplectic — it does not conserve the integral
  of motion exactly, and the notebook checks a relative tolerance
  accordingly.
  """
  @spec step(State.t(), float(), float()) :: State.t()
  def step(%State{} = state, n, dt) do
    k1 = derivative(state, n)
    k2 = state |> offset(k1, dt / 2) |> derivative(n)
    k3 = state |> offset(k2, dt / 2) |> derivative(n)
    k4 = state |> offset(k3, dt) |> derivative(n)

    weight = dt / 6

    %State{
      x: state.x + weight * slope(k1.x, k2.x, k3.x, k4.x),
      y: state.y + weight * slope(k1.y, k2.y, k3.y, k4.y),
      z: state.z + weight * slope(k1.z, k2.z, k3.z, k4.z),
      vx: state.vx + weight * slope(k1.vx, k2.vx, k3.vx, k4.vx),
      vy: state.vy + weight * slope(k1.vy, k2.vy, k3.vy, k4.vy),
      vz: state.vz + weight * slope(k1.vz, k2.vz, k3.vz, k4.vz)
    }
  end

  # `state + h · derivative` — where the RK4 stages are evaluated.
  defp offset(%State{} = state, %State{} = d, h) do
    %State{
      x: state.x + h * d.x,
      y: state.y + h * d.y,
      z: state.z + h * d.z,
      vx: state.vx + h * d.vx,
      vy: state.vy + h * d.vy,
      vz: state.vz + h * d.vz
    }
  end

  # The classical RK4 weighting of the four stage slopes, k₁ + 2k₂ + 2k₃ + k₄.
  defp slope(k1, k2, k3, k4), do: k1 + 2 * k2 + 2 * k3 + k4

  @doc """
  Repeated application of `step/3` from `t = 0` to `t = t_final`.

  Returns `[{t, state}]` inclusive of both endpoints, so the caller can
  compare the final state against the initial one directly.

  When `dt` does not divide `t_final` exactly, the trajectory ends with
  one shorter step that lands on `t_final` — the final sample is always
  at `t_final`, never short of it and never past it. Sample times are
  computed as multiples of `dt` rather than accumulated, so the grid
  does not drift over a long run.

  Raises `ArgumentError` unless `dt > 0` and `t_final >= 0`.
  """
  @spec propagate(State.t(), float(), float(), float()) :: [{float(), State.t()}]
  def propagate(%State{} = state, n, dt, t_final) do
    unless dt > 0, do: raise(ArgumentError, "dt must be positive, got: #{inspect(dt)}")

    unless t_final >= 0 do
      raise ArgumentError, "t_final must be non-negative, got: #{inspect(t_final)}"
    end

    steps = trunc(t_final / dt)
    leftover = t_final - steps * dt
    remainder = if leftover > dt * @grid_tolerance, do: leftover, else: 0.0

    {samples, last} =
      Enum.map_reduce(1..steps//1, state, fn i, current ->
        next = step(current, n, dt)
        {{i * dt, next}, next}
      end)

    finish([{0.0, state} | samples], last, n, remainder, t_final)
  end

  # Land the trajectory exactly on t_final: either with a short final
  # step, or — when dt divided t_final — by naming the last sample's
  # time t_final, since steps·dt can differ from it in the last bits.
  defp finish(samples, last, n, remainder, t_final) when remainder > 0.0 do
    samples ++ [{t_final, step(last, n, remainder)}]
  end

  defp finish(samples, _last, _n, _remainder, t_final) do
    List.update_at(samples, -1, fn {_t, s} -> {t_final, s} end)
  end

  @doc """
  The closed-form HCW solution evaluated at time `t`.

  This is an **independent oracle**, not the implementation. It must be
  derived from the analytic solution in the notebook and must not call
  `derivative/2` or `step/3` — the notebook cross-checks the numerical
  trajectory against this at every sample, and that check is worthless
  if the two share code.
  """
  @spec analytic(State.t(), float(), float()) :: State.t()
  def analytic(%State{} = state0, n, t) do
    %State{x: x0, y: y0, z: z0, vx: vx0, vy: vy0, vz: vz0} = state0

    nt = n * t
    cos = :math.cos(nt)
    sin = :math.sin(nt)

    %State{
      x: (4 - 3 * cos) * x0 + sin / n * vx0 + 2 / n * (1 - cos) * vy0,
      y: 6 * (sin - nt) * x0 + y0 - 2 / n * (1 - cos) * vx0 + (4 * sin - 3 * nt) / n * vy0,
      z: z0 * cos + vz0 / n * sin,
      vx: 3 * n * sin * x0 + cos * vx0 + 2 * sin * vy0,
      vy: 6 * n * (cos - 1) * x0 - 2 * sin * vx0 + (4 * cos - 3) * vy0,
      vz: -n * z0 * sin + vz0 * cos
    }
  end

  @doc """
  The conserved quantity of invariant I3.

      J = ½(vx² + vy² + vz²) - (3/2)n²x² + ½n²z²

  Constant along every HCW trajectory, not only the periodic ones. Note
  the negative sign on the `x` term — it mirrors the destabilising
  `+3n²x` in the equations of motion. This is not orbital energy; it is
  the rotating-frame integral, analogous to a Jacobi constant.
  """
  @spec integral(State.t(), float()) :: float()
  def integral(%State{} = state, n) do
    %State{x: x, z: z, vx: vx, vy: vy, vz: vz} = state
    n2 = n * n

    0.5 * (vx * vx + vy * vy + vz * vz) - 1.5 * n2 * x * x + 0.5 * n2 * z * z
  end
end
