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

  @stub "not implemented — see livebooks/hcw_orbital_mechanics.livemd"

  @spec derivative(State.t(), float()) :: State.t()
  def derivative(%State{} = _state, _n), do: raise(@stub)

  @spec step(State.t(), float(), float()) :: State.t()
  def step(%State{} = _state, _n, _dt), do: raise(@stub)

  @spec propagate(State.t(), float(), float(), float()) :: [{float(), State.t()}]
  def propagate(%State{} = _state, _n, _dt, _t_final), do: raise(@stub)

  @spec analytic(State.t(), float(), float()) :: State.t()
  def analytic(%State{} = _state0, _n, _t), do: raise(@stub)

  @spec integral(State.t(), float()) :: float()
  def integral(%State{} = _state, _n), do: raise(@stub)
end
