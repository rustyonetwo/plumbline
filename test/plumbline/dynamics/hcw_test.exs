defmodule Plumbline.Dynamics.HCWTest do
  use ExUnit.Case

  alias Plumbline.Dynamics.HCW
  alias Plumbline.Dynamics.HCW.State

  # Scenario parameters for 400 km LEO
  @mu 398_600.4418
  @altitude 400.0
  @earth_radius 6378.137
  @a @earth_radius + @altitude
  @n :math.sqrt(@mu / (@a * @a * @a))
  @period 2 * :math.pi() / @n
  @x0 1.0

  describe "derivative/2" do
    test "returns a State struct" do
      state = %State{x: 1.0, y: 0.0, z: 0.0, vx: 0.5, vy: 0.0, vz: 0.0}
      result = HCW.derivative(state, @n)

      assert is_struct(result, State)
    end

    test "position fields hold velocities" do
      state = %State{x: 0.0, y: 0.0, z: 0.0, vx: 1.5, vy: 2.0, vz: 0.5}
      result = HCW.derivative(state, @n)

      assert result.x == 1.5
      assert result.y == 2.0
      assert result.z == 0.5
    end

    test "zero state has zero derivative" do
      state = %State{}
      result = HCW.derivative(state, @n)

      assert result.x == 0.0
      assert result.y == 0.0
      assert result.z == 0.0
      assert result.vx == 0.0
      assert result.vy == 0.0
      assert result.vz == 0.0
    end

    test "cross-track decoupling: z initial condition doesn't affect in-plane derivatives" do
      state_z0 = %State{x: 1.0, y: 0.0, z: 0.0, vx: 0.5, vy: 0.0, vz: 0.0}
      state_z1 = %State{x: 1.0, y: 0.0, z: 1.0, vx: 0.5, vy: 0.0, vz: 0.0}

      deriv_z0 = HCW.derivative(state_z0, @n)
      deriv_z1 = HCW.derivative(state_z1, @n)

      assert deriv_z0.vx == deriv_z1.vx
      assert deriv_z0.vy == deriv_z1.vy
    end
  end

  describe "step/3" do
    test "returns a State struct" do
      state = %State{x: 1.0, y: 0.0, z: 0.0, vx: 0.0, vy: -2 * @n * @x0, vz: 0.0}
      result = HCW.step(state, @n, 0.1)

      assert is_struct(result, State)
    end

    test "small step size gives small changes" do
      state = %State{x: 1.0, y: 0.0, z: 0.0, vx: 0.0, vy: -2 * @n * @x0, vz: 0.0}
      dt = 0.001
      result = HCW.step(state, @n, dt)

      # Changes should be O(dt)
      max_change =
        max(
          abs(result.x - state.x),
          max(
            abs(result.y - state.y),
            max(abs(result.z - state.z), max(abs(result.vx - state.vx), 1.0e-8))
          )
        )

      assert max_change < 1.0
    end

    test "zero state remains zero" do
      state = %State{}
      result = HCW.step(state, @n, 1.0)

      assert result.x == 0.0
      assert result.y == 0.0
      assert result.z == 0.0
      assert result.vx == 0.0
      assert result.vy == 0.0
      assert result.vz == 0.0
    end
  end

  describe "propagate/4" do
    test "returns a list of tuples" do
      state = %State{x: 1.0, y: 0.0, z: 0.0, vx: 0.0, vy: -2 * @n * @x0, vz: 0.0}
      result = HCW.propagate(state, @n, 1.0, 10.0)

      assert is_list(result)
      assert length(result) == 11

      Enum.each(result, fn {t, s} ->
        assert is_float(t)
        assert is_struct(s, State)
      end)
    end

    test "starts at t=0 with initial state" do
      state = %State{x: 1.0, y: 0.0, z: 0.0, vx: 0.0, vy: -2 * @n * @x0, vz: 0.0}
      result = HCW.propagate(state, @n, 0.1, 1.0)

      {t0, s0} = List.first(result)
      assert t0 == 0.0
      assert s0.x == 1.0
      assert s0.y == 0.0
      assert s0.vy == -2 * @n * @x0
    end

    test "ends at t_final" do
      state = %State{x: 1.0, y: 0.0, z: 0.0, vx: 0.0, vy: -2 * @n * @x0, vz: 0.0}
      t_final = 100.0
      dt = 1.0
      result = HCW.propagate(state, @n, dt, t_final)

      {t_end, _s_end} = List.last(result)
      # Allow for floating point rounding
      assert_in_delta(t_end, t_final, 1.0e-10)
    end

    test "time values increase monotonically" do
      state = %State{x: 1.0, y: 0.0, z: 0.0, vx: 0.0, vy: -2 * @n * @x0, vz: 0.0}
      result = HCW.propagate(state, @n, 1.0, 50.0)

      times = Enum.map(result, fn {t, _} -> t end)

      Enum.each(0..(length(times) - 2), fn i ->
        assert Enum.at(times, i) <= Enum.at(times, i + 1)
      end)
    end

    test "I1: periodic orbit closes after one period" do
      state = %State{
        x: @x0,
        y: 0.0,
        z: 0.0,
        vx: 0.0,
        vy: -2 * @n * @x0,
        vz: 0.0
      }

      steps = 5000
      dt = @period / steps
      result = HCW.propagate(state, @n, dt, @period)

      {_t_final, final} = List.last(result)

      position_error =
        :math.sqrt(
          (final.x - state.x) ** 2 +
            (final.y - state.y) ** 2 +
            (final.z - state.z) ** 2
        )

      assert position_error < 1.0e-3
    end

    test "I2: cross-track stays zero if initial z and vz are zero" do
      state = %State{
        x: 1.0,
        y: 0.5,
        z: 0.0,
        vx: 0.1,
        vy: -2 * @n * @x0 + 0.5,
        vz: 0.0
      }

      dt = 0.1
      result = HCW.propagate(state, @n, dt, 100.0)

      Enum.each(result, fn {_t, s} ->
        assert s.z == 0.0
        assert s.vz == 0.0
      end)
    end
  end

  describe "analytic/3" do
    test "returns a State struct" do
      state = %State{x: 1.0, y: 0.0, z: 0.0, vx: 0.0, vy: 0.0, vz: 0.0}
      result = HCW.analytic(state, @n, 1.0)

      assert is_struct(result, State)
    end

    test "at t=0, returns initial state" do
      state = %State{x: 1.0, y: 2.0, z: 3.0, vx: 0.1, vy: 0.2, vz: 0.3}
      result = HCW.analytic(state, @n, 0.0)

      assert_in_delta(result.x, state.x, 1.0e-12)
      assert_in_delta(result.y, state.y, 1.0e-12)
      assert_in_delta(result.z, state.z, 1.0e-12)
      assert_in_delta(result.vx, state.vx, 1.0e-12)
      assert_in_delta(result.vy, state.vy, 1.0e-12)
      assert_in_delta(result.vz, state.vz, 1.0e-12)
    end

    test "zero state remains zero" do
      state = %State{}
      result = HCW.analytic(state, @n, 100.0)

      assert result.x == 0.0
      assert result.y == 0.0
      assert result.z == 0.0
      assert result.vx == 0.0
      assert result.vy == 0.0
      assert result.vz == 0.0
    end

    test "2:1 ellipse is periodic with period T" do
      state = %State{
        x: @x0,
        y: 0.0,
        z: 0.0,
        vx: 0.0,
        vy: -2 * @n * @x0,
        vz: 0.0
      }

      result_0 = HCW.analytic(state, @n, 0.0)
      result_at_period = HCW.analytic(state, @n, @period)

      assert_in_delta(result_at_period.x, result_0.x, 1.0e-12)
      assert_in_delta(result_at_period.y, result_0.y, 1.0e-12)
      assert_in_delta(result_at_period.z, result_0.z, 1.0e-12)
      assert_in_delta(result_at_period.vx, result_0.vx, 1.0e-12)
      assert_in_delta(result_at_period.vy, result_0.vy, 1.0e-12)
      assert_in_delta(result_at_period.vz, result_0.vz, 1.0e-12)
    end
  end

  describe "integral/2" do
    test "returns a float" do
      state = %State{x: 1.0, y: 0.0, z: 0.0, vx: 0.5, vy: 0.0, vz: 0.0}
      result = HCW.integral(state, @n)

      assert is_float(result)
    end

    test "zero state has zero integral" do
      state = %State{}
      result = HCW.integral(state, @n)

      assert result == 0.0
    end

    test "I3: conserved along periodic orbit" do
      state = %State{
        x: @x0,
        y: 0.0,
        z: 0.0,
        vx: 0.0,
        vy: -2 * @n * @x0,
        vz: 0.0
      }

      steps = 5000
      dt = @period / steps
      result = HCW.propagate(state, @n, dt, @period)

      j_values = Enum.map(result, fn {_t, s} -> HCW.integral(s, @n) end)

      j_min = Enum.min(j_values)
      j_max = Enum.max(j_values)
      j_initial = HCW.integral(state, @n)

      relative_drift = (j_max - j_min) / abs(j_initial)

      assert relative_drift < 1.0e-6
    end

    test "matches analytic prediction on 2:1 ellipse" do
      state = %State{
        x: @x0,
        y: 0.0,
        z: 0.0,
        vx: 0.0,
        vy: -2 * @n * @x0,
        vz: 0.0
      }

      j_computed = HCW.integral(state, @n)
      j_predicted = 0.5 * @n * @n * @x0 * @x0

      relative_error = abs(j_computed - j_predicted) / abs(j_predicted)

      assert relative_error < 1.0e-9
    end
  end

  describe "RK4 vs analytic oracle" do
    test "propagate and analytic agree over one period" do
      state = %State{
        x: @x0,
        y: 0.0,
        z: 0.0,
        vx: 0.0,
        vy: -2 * @n * @x0,
        vz: 0.0
      }

      steps = 5000
      dt = @period / steps
      trajectory = HCW.propagate(state, @n, dt, @period)

      max_deviation =
        trajectory
        |> Enum.map(fn {t, numeric} ->
          exact = HCW.analytic(state, @n, t)

          :math.sqrt(
            (numeric.x - exact.x) ** 2 +
              (numeric.y - exact.y) ** 2 +
              (numeric.z - exact.z) ** 2
          )
        end)
        |> Enum.max()

      # Must be small but nonzero
      assert max_deviation > 0.0
      assert max_deviation < 1.0e-3
    end
  end

  describe "boundary conditions and edge cases" do
    test "purely radial initial condition (no along-track coupling)" do
      state = %State{
        x: 1.0,
        y: 0.0,
        z: 0.0,
        vx: 0.0,
        vy: 0.0,
        vz: 0.0
      }

      dt = 0.1
      result = HCW.propagate(state, @n, dt, 10.0)

      {_t, final} = List.last(result)

      # Without coupling, y drifts by ~6*n*x0*T = ~37.7 km per period
      # Over 10 seconds, should be noticeable drift
      assert final.y != 0.0
    end

    test "purely along-track initial condition" do
      state = %State{
        x: 0.0,
        y: 1.0,
        z: 0.0,
        vx: 0.0,
        vy: 0.5,
        vz: 0.0
      }

      dt = 0.1
      result = HCW.propagate(state, @n, dt, 50.0)

      Enum.each(result, fn {_t, s} ->
        assert is_float(s.x)
        assert is_float(s.y)
      end)
    end

    test "purely cross-track initial condition" do
      state = %State{
        x: 0.0,
        y: 0.0,
        z: 1.0,
        vx: 0.0,
        vy: 0.0,
        vz: 0.0
      }

      dt = 0.1
      result = HCW.propagate(state, @n, dt, @period)

      # Over one full period, z oscillates but returns to initial state
      {_t, final} = List.last(result)

      assert_in_delta(final.z, state.z, 1.0e-3)
      assert_in_delta(final.vz, state.vz, 1.0e-3)
    end

    test "circular relative orbit (sqrt(3) condition)" do
      state = %State{
        x: @x0,
        y: 0.0,
        z: :math.sqrt(3) * @x0,
        vx: 0.0,
        vy: -2 * @n * @x0,
        vz: 0.0
      }

      steps = 5000
      dt = @period / steps
      result = HCW.propagate(state, @n, dt, @period)

      radii =
        Enum.map(result, fn {_t, s} ->
          :math.sqrt(s.x * s.x + s.y * s.y + s.z * s.z)
        end)

      r_min = Enum.min(radii)
      r_max = Enum.max(radii)

      relative_variation = (r_max - r_min) / r_max

      assert relative_variation < 1.0e-6
      assert_in_delta(r_min, 2.0, 0.01)
    end
  end
end
