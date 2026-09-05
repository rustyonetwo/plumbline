defmodule Plumbline.Dynamics.HCW do
  @moduledoc false

  defmodule State do
    @moduledoc false

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

  @spec derivative(State.t(), float()) :: State.t()
  def derivative(%State{x: x, y: _y, z: z, vx: vx, vy: vy, vz: vz}, n) do
    n_sq = n * n
    two_n = 2 * n
    three_n_sq = 3 * n_sq

    %State{
      x: vx,
      y: vy,
      z: vz,
      vx: three_n_sq * x + two_n * vy,
      vy: -two_n * vx,
      vz: -n_sq * z
    }
  end

  @spec step(State.t(), float(), float()) :: State.t()
  def step(%State{} = state, n, dt) do
    k1 = derivative(state, n)

    state_k2 = %State{
      x: state.x + dt / 2 * k1.x,
      y: state.y + dt / 2 * k1.y,
      z: state.z + dt / 2 * k1.z,
      vx: state.vx + dt / 2 * k1.vx,
      vy: state.vy + dt / 2 * k1.vy,
      vz: state.vz + dt / 2 * k1.vz
    }

    k2 = derivative(state_k2, n)

    state_k3 = %State{
      x: state.x + dt / 2 * k2.x,
      y: state.y + dt / 2 * k2.y,
      z: state.z + dt / 2 * k2.z,
      vx: state.vx + dt / 2 * k2.vx,
      vy: state.vy + dt / 2 * k2.vy,
      vz: state.vz + dt / 2 * k2.vz
    }

    k3 = derivative(state_k3, n)

    state_k4 = %State{
      x: state.x + dt * k3.x,
      y: state.y + dt * k3.y,
      z: state.z + dt * k3.z,
      vx: state.vx + dt * k3.vx,
      vy: state.vy + dt * k3.vy,
      vz: state.vz + dt * k3.vz
    }

    k4 = derivative(state_k4, n)

    dt_6 = dt / 6

    %State{
      x: state.x + dt_6 * (k1.x + 2 * k2.x + 2 * k3.x + k4.x),
      y: state.y + dt_6 * (k1.y + 2 * k2.y + 2 * k3.y + k4.y),
      z: state.z + dt_6 * (k1.z + 2 * k2.z + 2 * k3.z + k4.z),
      vx: state.vx + dt_6 * (k1.vx + 2 * k2.vx + 2 * k3.vx + k4.vx),
      vy: state.vy + dt_6 * (k1.vy + 2 * k2.vy + 2 * k3.vy + k4.vy),
      vz: state.vz + dt_6 * (k1.vz + 2 * k2.vz + 2 * k3.vz + k4.vz)
    }
  end

  @spec propagate(State.t(), float(), float(), float()) :: [{float(), State.t()}]
  def propagate(%State{} = state, n, dt, t_final) do
    steps = round(t_final / dt)

    propagate_steps(state, n, dt, steps, 0.0, [{0.0, state}])
  end

  defp propagate_steps(_state, _n, _dt, 0, _t, results) do
    Enum.reverse(results)
  end

  defp propagate_steps(state, n, dt, steps, t, results) do
    new_state = step(state, n, dt)
    new_t = t + dt

    propagate_steps(new_state, n, dt, steps - 1, new_t, [{new_t, new_state} | results])
  end

  @spec analytic(State.t(), float(), float()) :: State.t()
  def analytic(
        %State{x: x0, y: y0, z: z0, vx: vx0, vy: vy0, vz: vz0},
        n,
        t
      ) do
    nt = n * t
    cos_nt = :math.cos(nt)
    sin_nt = :math.sin(nt)
    n_inv = 1 / n

    x =
      (4 - 3 * cos_nt) * x0 + sin_nt * n_inv * vx0 +
        2 * n_inv * (1 - cos_nt) * vy0

    y =
      6 * (sin_nt - nt) * x0 + y0 - 2 * n_inv * (1 - cos_nt) * vx0 +
        n_inv * (4 * sin_nt - 3 * nt) * vy0

    z = z0 * cos_nt + vz0 * n_inv * sin_nt

    vx = 3 * n * sin_nt * x0 + cos_nt * vx0 + 2 * sin_nt * vy0

    vy =
      6 * n * (cos_nt - 1) * x0 - 2 * sin_nt * vx0 +
        (4 * cos_nt - 3) * vy0

    vz = -n * z0 * sin_nt + vz0 * cos_nt

    %State{x: x, y: y, z: z, vx: vx, vy: vy, vz: vz}
  end

  @spec integral(State.t(), float()) :: float()
  def integral(%State{x: x, z: z, vx: vx, vy: vy, vz: vz}, n) do
    n_sq = n * n

    0.5 * (vx * vx + vy * vy + vz * vz) - 1.5 * n_sq * x * x +
      0.5 * n_sq * z * z
  end
end
