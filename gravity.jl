#!/usr/bin/env julia

using Plots

"""
    Body(m, x, y, z, v)

Create a celestial body object with mass `m` kilograms, position `x` `y` `z`,
and 3-component velocity vector `v` (m/s).
"""
mutable struct Body{T <: Float64}
	# The mass of the body
	m::T

	# Its coords
	x::T
	y::T
	z::T

	# Its velocity as a vector of x y z values
	v::Vector{T}
end

"""
    getforce(b1, b2) -> float

Return the magnitude of the force between Body objects `b1` and `b2`.

Uses the standard gravitational equation.

See also: [`getforcevector`](@ref)
"""
function getforce(b1::Body, b2::Body)::Float64
	a = b1.x - b2.x
	b = b1.y - b2.y
	c = b1.z - b2.z

	r2 = a^2 + b^2 + c^2

	# G \frac{m_1 m_2}{r^2}
	(6.674e-11 * b1.m * b2.m) / r2
end

"""
    getforcevector(b1, b2) -> [float, float, float]

Return the 3D vector of the force from Body object `b1` towards `b2`.

Expressed as a 3-component vector. Magnitude can be computed
by `getforce(b1, b2)`. Angles must be computed separately.

See also: [`getforce`](@ref)
"""
function getforcevector(b1::Body, b2::Body)::Vector{Float64}
	# azimuth is the angle on the x-y plane
	Δx = b2.x - b1.x
	Δy = b2.y - b1.y

	azimuth = atan(Δy, Δx)

	# altitude is the angle from the x-y plane in the z axis
	hyp = sqrt(Δx^2 + Δy^2)
	Δz = b2.z - b1.z
	altitude = atan(Δz, hyp)

	F = getforce(b1, b2)

	# We use F to compute the z component and the new hypotenuse to use
	# for computing the x and y components
	vec_z = F * sin(altitude)
	xy_plane_hyp = F * cos(altitude)

	# We then do some more trig to compute the x and y components
	vec_y = xy_plane_hyp * sin(azimuth)
	vec_x = xy_plane_hyp * cos(azimuth)

	[vec_x, vec_y, vec_z]
end

"""
    step!(b1, b2, Δt)

Apply forces between Body objects `b1` and `b2` over time step `Δt` seconds.
"""
function step!(bodies::Vector{Body{Float64}}, Δt::Float64)
	for i in 1:length(bodies)
		b = bodies[i]

		forceonbody = b.v
		# We loop over every body and if it's not the same one, we add the add the force
		for j in 1:length(bodies)
			if j != i
				# We add the body's velocity to the force applied by gravity
				# to get the resultant force
				forceonbody += getforcevector(b, bodies[j])
			end
			
		end

		# Update the velocity of the body

		# a = (v - u)/t and F = ma ⟹  v F = m * (v - u)/t
		# ⟹  v = Ft/m + u

		# Since u is the initial value, we can just use +=
		b.v += ((forceonbody * Δt) / b.m)

		# Then we update the position of the body using its velocity
		b.x += Δt * b.v[1]
		b.y += Δt * b.v[2]
		b.z += Δt * b.v[3]
	end
end

# I'm not going to give this function a docstring because I want to
# get rid of it. It's only here to test things with hard coded parameters
function draw_gif(Δt::Float64)
	# Right now, this function has hard coded parameters
	# but in the future, I want to factor everything out
	# and make all parameter able to be specified by the
	# user with command line arguments

	bodies = [
		Body(6e24, 0.0, 0.0, 0.0, [0.0, 0.0, 50.0]),
		Body(3e23, 375e6, 0.0, 0.0, [0.0, 250.0, 0.0]),
		Body(5e22, 200e6, 0.0, 0.0, [100.0, 0.0, 0.0])
	]

	# Initialize a 3D plot with 1 empty series for each body
	plt = plot3d(
		length(bodies),
		xlim = (-100e6, 400e6),
		ylim = (-100e6, 100e6),
		zlim = (-10e3, 100e6),
		title = "$(length(bodies)) Body Gravity Sim",
		marker = 1,
		legend = false,
	)

	# Build an animated gif by pushing new points to the plot, saving every 10th frame
	@gif for i in 1:5200
		step!(bodies, Δt)
		# Add the new positions of every Body to the plot
		for i in 1:length(bodies)
			push!(plt, i, bodies[i].x, bodies[i].y, bodies[i].z)
		end
	end every 10
end

if abspath(PROGRAM_FILE) == @__FILE__
	draw_gif(360.0)
end
