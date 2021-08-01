#!/usr/bin/env julia

using Plots

mutable struct Body{T<:Float64}
	# The mass of the body
	m::T

	# Its coords
	x::T
	y::T
	z::T

	# Its velocity as a vector of x y z values
	s::Vector{T}
end

function getforce(b1::Body, b2::Body)::Float64
	a = b1.x - b2.x
	b = b1.y - b2.y
	c = b1.z - b2.z

	r2 = a^2 + b^2 + c^2

	# G \frac{m_1 m_2}{r^2}
	(6.674e-11 * b1.m * b2.m) / r2
end

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

addvectors(v1::Vector{Float64}, v2::Vector{Float64})::Vector{Float64} = [v1[1] + v2[1], v1[2] + v2[2], v1[3] + v2[3]]

function updatevelocity!(b::Body, force::Vector{Float64}, Δt::Float64)
	for i = 1:3
		# From a = \frac{v - u}{t} and F = ma, we get v = \frac{Ft}{m} + u
		b.s[i] += ((force[i] * Δt) / b.m)
	end
end

function step!(b1::Body, b2::Body, Δt::Float64)
	# We add the body's velocity to the force applied by gravity
	# to get the resultant force
	forceonb1 = addvectors(b1.s, getforcevector(b1, b2))

	updatevelocity!(b1, forceonb1, Δt)

	# We then adjust the position of the body to reflect this force
	b1.x += Δt * b1.s[1]
	b1.y += Δt * b1.s[2]
	b1.z += Δt * b1.s[3]

	forceonb2 = addvectors(b2.s, getforcevector(b2, b1))
	updatevelocity!(b2, forceonb2, Δt)
	b2.x += Δt * b2.s[1]
	b2.y += Δt * b2.s[2]
	b2.z += Δt * b2.s[3]
end

function draw_gif(Δt::Float64)
	# Right now, this function has hard coded parameters
	# but in the future, I want to factor everything out
	# and make all parameter able to be specified by the
	# user with command line arguments

	largebody = Body(6e24, 0.0, 0.0, 0.0, [0.0, 0.0, 50.0])
	smallbody = Body(7.3e22, 375e6, 0.0, 0.0, [0.0, 500, 0.0])

	plotbound = 400e6

	# Initialize a 3D plot with 1 empty series
	plt = plot3d(
		1,
		xlim = (-1 * plotbound, plotbound),
		ylim = (-1 * plotbound, plotbound),
		zlim = (-1 * plotbound, plotbound),
		title = "2 Body Gravity Sim",
		marker = 2,
		legend = false,
	)

	push!(plt, smallbody.x, smallbody.y, smallbody.z)

	# Build an animated gif by pushing new points to the plot, saving every 10th frame
	@gif for i=1:6000
		step!(largebody, smallbody, Δt)
		push!(plt, smallbody.x, smallbody.y, smallbody.z)
	end every 10
end

if abspath(PROGRAM_FILE) == @__FILE__
	draw_gif(720.0)
end
