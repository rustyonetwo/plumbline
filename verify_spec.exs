# Independent check of the claims asserted in hcw_orbital_mechanics.livemd.
# Deliberately NOT the implementation — throwaway verification of the SPEC.

mu = 398_600.4418
a = 6378.137 + 400.0
n = :math.sqrt(mu / (a * a * a))
period = 2 * :math.pi() / n

IO.puts("n      = #{n} rad/s")
IO.puts("period = #{period} s = #{period / 60} min\n")

# --- closed form from the notebook -----------------------------------------
closed = fn {x0, y0, z0, vx0, vy0, vz0}, t ->
  c = :math.cos(n * t)
  s = :math.sin(n * t)

  x = (4 - 3 * c) * x0 + s / n * vx0 + 2 / n * (1 - c) * vy0
  y = 6 * (s - n * t) * x0 + y0 - 2 / n * (1 - c) * vx0 + 1 / n * (4 * s - 3 * n * t) * vy0
  z = z0 * c + vz0 / n * s

  vx = 3 * n * s * x0 + c * vx0 + 2 * s * vy0
  vy = 6 * n * (c - 1) * x0 - 2 * s * vx0 + (4 * c - 3) * vy0
  vz = -n * z0 * s + vz0 * c

  {x, y, z, vx, vy, vz}
end

# --- CHECK 1: does the closed form satisfy the equations of motion? ---------
# Numerically differentiate the closed form and compare against A*s.
ic = {1.3, -0.7, 0.45, 0.0009, -0.0031, 0.0004}
h = 1.0e-3

worst =
  for t <- [0.0, 137.0, 900.0, 2600.0, 4400.0] do
    {_, _, _, vx, vy, vz} = closed.(ic, t)
    {_, _, _, vxp, vyp, vzp} = closed.(ic, t + h)
    {_, _, _, vxm, vym, vzm} = closed.(ic, t - h)
    {x, _y, z, _, _, _} = closed.(ic, t)

    ax = (vxp - vxm) / (2 * h)
    ay = (vyp - vym) / (2 * h)
    az = (vzp - vzm) / (2 * h)

    # residuals of  xdd - 3n^2 x - 2n yd = 0 ;  ydd + 2n xd = 0 ;  zdd + n^2 z = 0
    r1 = ax - 3 * n * n * x - 2 * n * vy
    r2 = ay + 2 * n * vx
    r3 = az + n * n * z

    scale = max(abs(ax), max(abs(ay), max(abs(az), 1.0e-12)))
    Enum.max([abs(r1), abs(r2), abs(r3)]) / scale
  end
  |> Enum.max()

IO.puts("CHECK 1  closed form satisfies EOM, worst relative residual: #{worst}")
IO.puts(if worst < 1.0e-6, do: "         PASS\n", else: "         FAIL\n")

# --- CHECK 2: drift-free condition  vy0 = -2 n x0 --------------------------
x0 = 1.0

for {label, ic} <- [
      {"vy0 = -2n x0  (notebook claim)", {x0, 0.0, 0.0, 0.0, -2 * n * x0, 0.0}},
      {"vx0 = -2n x0  (original brief)", {x0, 0.0, 0.0, -2 * n * x0, 0.0, 0.0}}
    ] do
  {xf, yf, zf, _, _, _} = closed.(ic, period)
  {xi, yi, zi, _, _, _} = ic

  err =
    :math.sqrt(:math.pow(xf - xi, 2) + :math.pow(yf - yi, 2) + :math.pow(zf - zi, 2))

  IO.puts("CHECK 2  #{label}")
  IO.puts("         closure error after one period: #{err} km")
end

IO.puts("")

# --- CHECK 3: 2:1 ellipse geometry -----------------------------------------
drift_free = {x0, 0.0, 0.0, 0.0, -2 * n * x0, 0.0}

samples = for k <- 0..2000, do: closed.(drift_free, period * k / 2000)
xs = Enum.map(samples, fn {x, _, _, _, _, _} -> x end)
ys = Enum.map(samples, fn {_, y, _, _, _, _} -> y end)

IO.puts("CHECK 3  radial extent     : #{Enum.min(xs)} .. #{Enum.max(xs)}")
IO.puts("         along-track extent: #{Enum.min(ys)} .. #{Enum.max(ys)}")
IO.puts("         ratio (should be 2): #{(Enum.max(ys) - Enum.min(ys)) / (Enum.max(xs) - Enum.min(xs))}\n")

# --- CHECK 4: integral of motion J -----------------------------------------
j = fn {x, _y, z, vx, vy, vz} ->
  0.5 * (vx * vx + vy * vy + vz * vz) - 1.5 * n * n * x * x + 0.5 * n * n * z * z
end

# general (drifting) initial condition, to show J holds for ALL states
js = for k <- 0..2000, do: j.(closed.(ic, period * k / 2000))
j0 = j.(ic)
spread = (Enum.max(js) - Enum.min(js)) / abs(j0)

IO.puts("CHECK 4  J over a NON-periodic trajectory")
IO.puts("         J0 = #{j0}, relative spread = #{spread}")
IO.puts(if spread < 1.0e-9, do: "         PASS\n", else: "         FAIL\n")

# predicted value on the 2:1 ellipse
j_ellipse = j.(drift_free)
IO.puts("CHECK 4b J on 2:1 ellipse  = #{j_ellipse}")
IO.puts("         predicted 0.5n^2x0^2 = #{0.5 * n * n * x0 * x0}\n")

# --- CHECK 5: circular relative orbit, z0 = sqrt(3) x0 ---------------------
circ = {x0, 0.0, :math.sqrt(3) * x0, 0.0, -2 * n * x0, 0.0}

radii =
  for k <- 0..2000 do
    {x, y, z, _, _, _} = closed.(circ, period * k / 2000)
    :math.sqrt(x * x + y * y + z * z)
  end

IO.puts("CHECK 5  |r| range: #{Enum.min(radii)} .. #{Enum.max(radii)}")
IO.puts("         predicted 2*x0 = #{2 * x0}")
IO.puts("         relative variation: #{(Enum.max(radii) - Enum.min(radii)) / Enum.max(radii)}")
