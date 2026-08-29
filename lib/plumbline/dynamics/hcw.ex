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

  @stub "not implemented — see livebooks/hcw_orbital_mechanics.livemd"

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
  def derivative(%State{} = _state, _n), do: raise(@stub)

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
  def step(%State{} = _state, _n, _dt), do: raise(@stub)

  @doc """
  Repeated application of `step/3` from `t = 0` to `t = t_final`.

  Returns `[{t, state}]` inclusive of both endpoints, so the caller can
  compare the final state against the initial one directly.
  """
  @spec propagate(State.t(), float(), float(), float()) :: [{float(), State.t()}]
  def propagate(%State{} = _state, _n, _dt, _t_final), do: raise(@stub)

  @doc """
  The closed-form HCW solution evaluated at time `t`.

  This is an **independent oracle**, not the implementation. It must be
  derived from the analytic solution in the notebook and must not call
  `derivative/2` or `step/3` — the notebook cross-checks the numerical
  trajectory against this at every sample, and that check is worthless
  if the two share code.
  """
  @spec analytic(State.t(), float(), float()) :: State.t()
  def analytic(%State{} = _state0, _n, _t), do: raise(@stub)

  @doc """
  The conserved quantity of invariant I3.

      J = ½(vx² + vy² + vz²) - (3/2)n²x² + ½n²z²

  Constant along every HCW trajectory, not only the periodic ones. Note
  the negative sign on the `x` term — it mirrors the destabilising
  `+3n²x` in the equations of motion. This is not orbital energy; it is
  the rotating-frame integral, analogous to a Jacobi constant.
  """
  @spec integral(State.t(), float()) :: float()
  def integral(%State{} = _state, _n), do: raise(@stub)
end
