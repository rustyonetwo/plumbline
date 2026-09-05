defmodule Plumbline.Dynamics.HCWTest do
  @moduledoc """
  Unit tests for `Plumbline.Dynamics.HCW`.

  These sit *below* `livebooks/hcw_orbital_mechanics.livemd` and descend
  from it. The notebook guards the invariants — properties that hold for
  every valid input; these guard specific cases the invariants do not
  naturally reach: the entries of the `A` matrix one at a time, the
  endpoints and error paths of `propagate/4`, the oracle at `t = 0`, and
  the known failure mode the notebook derives but does not execute.

  Nothing here replaces the notebook. An implementation can pass every
  test in this file and still spiral over one orbit.
  """

  use ExUnit.Case, async: true

  alias Plumbline.Dynamics.HCW
  alias Plumbline.Dynamics.HCW.State

  # The notebook's scenario: a 400 km circular LEO, deputy offset 1 km
  # radially. Repeated rather than shared, because the library must not
  # read the notebook and the notebook must not read the tests.
  @mu 398_600.4418
  @a 6378.137 + 400.0
  @n :math.sqrt(@mu / (@a * @a * @a))
  @period 2 * :math.pi() / @n
  @x0 1.0

  defp drift_free do
    %State{x: @x0, y: 0.0, z: 0.0, vx: 0.0, vy: -2 * @n * @x0, vz: 0.0}
  end

  describe "derivative/2 — the A matrix, entry by entry" do
    test "position derivatives are the velocities" do
      state = %State{x: 1.0, y: 2.0, z: 3.0, vx: 0.1, vy: 0.2, vz: 0.3}
      d = HCW.derivative(state, @n)

      assert d.x == 0.1
      assert d.y == 0.2
      assert d.z == 0.3
    end

    test "a pure radial offset accelerates radially at 3n²x, and nowhere else" do
      d = HCW.derivative(%State{x: 2.0}, @n)

      assert_in_delta d.vx, 3 * @n * @n * 2.0, 1.0e-18
      assert d.vy == 0.0
      assert d.vz == 0.0
    end

    test "Coriolis: along-track velocity drives radial acceleration at 2n·vy" do
      d = HCW.derivative(%State{vy: 0.5}, @n)

      assert_in_delta d.vx, 2 * @n * 0.5, 1.0e-18
      assert d.vy == 0.0
    end

    test "Coriolis: radial velocity drives along-track acceleration at -2n·vx" do
      d = HCW.derivative(%State{vx: 0.5}, @n)

      assert_in_delta d.vy, -2 * @n * 0.5, 1.0e-18
      assert d.vx == 0.0
    end

    test "cross-track is a restoring force at -n²z and touches nothing else" do
      d = HCW.derivative(%State{z: 3.0}, @n)

      assert_in_delta d.vz, -(@n * @n) * 3.0, 1.0e-18
      assert d.vx == 0.0
      assert d.vy == 0.0
    end

    test "along-track position appears in no derivative — y is cyclic" do
      assert HCW.derivative(%State{y: 1000.0}, @n) == %State{}
    end

    test "the zero state is a fixed point" do
      assert HCW.derivative(%State{}, @n) == %State{}
    end
  end

  describe "step/3" do
    test "a zero-length step returns the state unchanged" do
      state = %State{x: 1.0, y: 2.0, z: 3.0, vx: 0.1, vy: 0.2, vz: 0.3}

      assert HCW.step(state, @n, 0.0) == state
    end

    test "one step agrees with the closed-form oracle to RK4 truncation order" do
      dt = @period / 5_000
      initial = drift_free()

      stepped = HCW.step(initial, @n, dt)
      exact = HCW.analytic(initial, @n, dt)

      assert_in_delta stepped.x, exact.x, 1.0e-12
      assert_in_delta stepped.y, exact.y, 1.0e-12
      assert_in_delta stepped.vx, exact.vx, 1.0e-12
      assert_in_delta stepped.vy, exact.vy, 1.0e-12
    end

    test "a backward step undoes a forward one" do
      dt = @period / 5_000
      initial = drift_free()

      round_trip = initial |> HCW.step(@n, dt) |> HCW.step(@n, -dt)

      assert_in_delta round_trip.x, initial.x, 1.0e-12
      assert_in_delta round_trip.y, initial.y, 1.0e-12
      assert_in_delta round_trip.vy, initial.vy, 1.0e-12
    end
  end

  describe "propagate/4 — endpoints and grid" do
    test "the first sample is t = 0 and the initial state itself" do
      initial = drift_free()

      assert [{+0.0, ^initial} | _] = HCW.propagate(initial, @n, @period / 100, @period)
    end

    test "an exactly dividing dt gives steps + 1 samples, the last exactly at t_final" do
      trajectory = HCW.propagate(drift_free(), @n, @period / 500, @period)

      assert length(trajectory) == 501
      assert {@period, _state} = List.last(trajectory)
    end

    test "a dt that does not divide t_final still lands exactly on t_final" do
      # 1000 s of a ~5554 s period: 33 whole steps of 30 s and a short one.
      trajectory = HCW.propagate(drift_free(), @n, 30.0, 1000.0)

      assert length(trajectory) == 35
      assert {1000.0, _state} = List.last(trajectory)
    end

    test "sample times are strictly increasing" do
      times = HCW.propagate(drift_free(), @n, 30.0, 1000.0) |> Enum.map(&elem(&1, 0))

      assert times == Enum.sort(times)
      assert length(Enum.uniq(times)) == length(times)
    end

    test "t_final = 0 gives exactly one sample" do
      initial = drift_free()

      assert HCW.propagate(initial, @n, 1.0, 0.0) == [{0.0, initial}]
    end

    test "a dt larger than t_final gives one short step to t_final" do
      trajectory = HCW.propagate(drift_free(), @n, 10_000.0, 60.0)

      assert [{+0.0, _}, {60.0, final}] = trajectory
      assert_in_delta final.x, HCW.analytic(drift_free(), @n, 60.0).x, 1.0e-6
    end

    test "a non-positive dt is an error, not an infinite loop" do
      assert_raise ArgumentError, ~r/dt must be positive/, fn ->
        HCW.propagate(drift_free(), @n, 0.0, @period)
      end

      assert_raise ArgumentError, ~r/dt must be positive/, fn ->
        HCW.propagate(drift_free(), @n, -1.0, @period)
      end
    end

    test "a negative t_final is an error" do
      assert_raise ArgumentError, ~r/t_final must be non-negative/, fn ->
        HCW.propagate(drift_free(), @n, 1.0, -@period)
      end
    end
  end

  describe "analytic/3 — the oracle" do
    test "at t = 0 it is the identity" do
      state = %State{x: 1.0, y: -2.0, z: 0.5, vx: 0.01, vy: -0.02, vz: 0.003}
      exact = HCW.analytic(state, @n, 0.0)

      assert_in_delta exact.x, state.x, 1.0e-15
      assert_in_delta exact.y, state.y, 1.0e-15
      assert_in_delta exact.z, state.z, 1.0e-15
      assert_in_delta exact.vx, state.vx, 1.0e-15
      assert_in_delta exact.vy, state.vy, 1.0e-15
      assert_in_delta exact.vz, state.vz, 1.0e-15
    end

    test "it satisfies the equations of motion, by finite difference" do
      # The oracle is only worth something if it is the solution of the
      # same system derivative/2 encodes. Differentiating it numerically
      # and comparing against derivative/2 checks exactly that, without
      # either function calling the other.
      state = %State{x: 1.0, y: -2.0, z: 0.5, vx: 0.01, vy: -0.02, vz: 0.003}
      t = 900.0
      h = 1.0e-3

      before = HCW.analytic(state, @n, t - h)
      later = HCW.analytic(state, @n, t + h)
      expected = HCW.derivative(HCW.analytic(state, @n, t), @n)

      for field <- [:x, :y, :z, :vx, :vy, :vz] do
        measured = (Map.fetch!(later, field) - Map.fetch!(before, field)) / (2 * h)
        assert_in_delta measured, Map.fetch!(expected, field), 1.0e-9
      end
    end

    test "the drift-free condition closes the orbit after exactly one period" do
      initial = drift_free()
      exact = HCW.analytic(initial, @n, @period)

      assert_in_delta exact.x, initial.x, 1.0e-12
      assert_in_delta exact.y, initial.y, 1.0e-12
      assert_in_delta exact.vy, initial.vy, 1.0e-12
    end

    test "the transposed condition drifts 12π·x₀ per orbit — the documented trap" do
      # vx₀ = -2n·x₀ instead of vy₀. This is the one-character error the
      # notebook derives; it is asserted here so a regression toward it
      # fails loudly rather than looking plausible for a few minutes.
      transposed = %State{x: @x0, vx: -2 * @n * @x0}
      after_one_orbit = HCW.analytic(transposed, @n, @period)

      assert_in_delta abs(after_one_orbit.y - transposed.y), 12 * :math.pi() * @x0, 1.0e-9
      assert_in_delta abs(after_one_orbit.y - transposed.y), 37.699, 1.0e-3
    end

    test "the 2:1 ellipse has along-track extent exactly twice the radial one" do
      samples =
        for i <- 0..2_000 do
          HCW.analytic(drift_free(), @n, i * @period / 2_000)
        end

      radial = samples |> Enum.map(&abs(&1.x)) |> Enum.max()
      along_track = samples |> Enum.map(&abs(&1.y)) |> Enum.max()

      assert_in_delta radial, @x0, 1.0e-6
      assert_in_delta along_track, 2 * @x0, 1.0e-6
    end
  end

  describe "integral/2 — the conserved quantity J" do
    test "the zero state has J = 0" do
      assert HCW.integral(%State{}, @n) == 0.0
    end

    test "the sign of the x term is negative — J is not orbital energy" do
      assert HCW.integral(%State{x: 1.0}, @n) < 0.0
    end

    test "the sign of the z term is positive" do
      assert HCW.integral(%State{z: 1.0}, @n) > 0.0
    end

    test "on the 2:1 ellipse it equals the predicted ½n²x₀²" do
      predicted = 0.5 * @n * @n * @x0 * @x0
      measured = HCW.integral(drift_free(), @n)

      assert_in_delta measured / predicted, 1.0, 1.0e-12
    end

    test "it is conserved on a NON-periodic trajectory too" do
      # The notebook checks conservation on the drift-free orbit. J is
      # conserved for every initial condition, so the drifting case is
      # the one that distinguishes a genuine integral of motion from a
      # quantity that happens to be constant on closed orbits.
      drifting = %State{x: @x0, y: 0.0, z: 0.4, vx: 0.001, vy: 0.0, vz: -0.0005}

      values =
        drifting
        |> HCW.propagate(@n, @period / 2_000, @period)
        |> Enum.map(fn {_t, s} -> HCW.integral(s, @n) end)

      spread = (Enum.max(values) - Enum.min(values)) / abs(HCW.integral(drifting, @n))

      assert spread < 1.0e-9
    end
  end

  describe "cross-track decoupling (I2) in both directions" do
    test "in-plane motion introduces no cross-track motion, exactly" do
      for {_t, s} <- HCW.propagate(drift_free(), @n, @period / 500, @period) do
        assert s.z == 0.0
        assert s.vz == 0.0
      end
    end

    test "pure cross-track motion introduces no in-plane motion, exactly" do
      cross_track = %State{z: 1.0, vz: 0.0}

      for {_t, s} <- HCW.propagate(cross_track, @n, @period / 500, @period) do
        assert s.x == 0.0
        assert s.y == 0.0
        assert s.vx == 0.0
        assert s.vy == 0.0
      end
    end
  end
end
