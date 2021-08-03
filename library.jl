using Plots
using StaticArrays

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
	v::MVector{3, T}
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
function getforcevector(b1::Body, b2::Body)::MVector{3, Float64}
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

	MVector{3, Float64}(vec_x, vec_y, vec_z)
end

"""
    step!(b1, b2, Δt)

Apply forces between Body objects `b1` and `b2` over time step `Δt` seconds.
"""
function step!(bodies::Vector{Body{Float64}}, Δt::Float64)
	# Calculate the force on each body and update its velocity accordingly
	for i in 1:length(bodies)
		b = bodies[i]

		forceonbody = copy(b.v)
		# We loop over every body and if it's not the same one, we add the add the force
		for j in 1:length(bodies)
			if j != i
				# We add the body's velocity to the force applied by gravity
				# to get the resultant force
				forceonbody .+= getforcevector(b, bodies[j])
			end
			
		end

		# Update the velocity of the body

		# a = (v - u)/t and F = ma ⟹  F = m * (v - u)/t
		# ⟹  v = Ft/m + u

		# Since u is the initial value, we can just use +=
		# We actually need .+= here to broadcast over the MVector
		b.v .+= ((forceonbody * Δt) / b.m)
	end

	# We need to wait until we've calculated all the forces before we start to change the positions,
	# otherwise we would change a position and then calculate a force based on the new position,
	# rather than the old one
	for i in 1:length(bodies)
		b = bodies[i]

		# Then we update the position of the body using its velocity
		b.x += Δt * b.v[1]
		b.y += Δt * b.v[2]
		b.z += Δt * b.v[3]
	end
end

"""
    drawframes(bodies, framecount, Δt)

Return frame data for the list of Body objects `bodies` with time step `Δt`.

This frame data is a Vector{Vector{Vector{Float64}}}. It can be thought of as a list of frames,
where each frame has a list of bodies, and each body has a list of x y z coordinates.

See also: [`drawgif`](@ref), [`creategif`](@ref)
"""
function drawframes(bodies::Vector{Body{Float64}}, framecount::Int64, Δt::Float64)::Vector{Vector{SVector{3, Float64}}}
	frames::Vector{Vector{SVector{3, Float64}}} = []

	for _ in 1:framecount
		step!(bodies, Δt)

		# We build the position data for this frame
		thisframe::Vector{SVector{3, Float64}} = [SVector{3, Float64}(bodies[i].x, bodies[i].y, bodies[i].z) for i in 1:length(bodies)]

		push!(frames, thisframe)
	end

	return frames
end

"""
    drawgif(positions)

Draw a GIF using the position data.

`positions` is a Vector{Vector{Vector{Float64}}}. It can be thought of as a list of frames,
where each frame has a list of bodies, and each body has a list of x y z coordinates.

See also: [`drawframes`](@ref), [`creategif`](@ref)
"""
function drawgif(positions::Vector{Vector{SVector{3, Float64}}}, cube::Bool)
	# This is a multiplier to make th bounding box just a bit bigger than strictly necessary,
	# just to make it look a bit nicer
	multiplier = 1.05

	if cube
		# This line gets absolute value of every float in positions and then gets the max
		# Because we're dealing with a nested vector, we have to flatten it, and then
		# flatten the result, and then splat it for max
		maxbound = multiplier * max(abs.(Iterators.flatten(Iterators.flatten(positions)))...)

		xlimits = (-1 * maxbound, maxbound)
		ylimits = (-1 * maxbound, maxbound)
		zlimits = (-1 * maxbound, maxbound)
	else
		# These list comprehensions loop through the list to get the coords
		# i is every frame in the positions list, and j is every body in each frame
		# We only need to check length(positions[1]) to get j because the length of
		# every sub-list is the same because every frame has the same number of bodies
		xs = [positions[i][j][1] for i in 1:length(positions) for j in 1:length(positions[1])]
		ys = [positions[i][j][2] for i in 1:length(positions) for j in 1:length(positions[1])]
		zs = [positions[i][j][3] for i in 1:length(positions) for j in 1:length(positions[1])]

		xlimits = (multiplier * min(xs...), multiplier * max(xs...))
		ylimits = (multiplier * min(ys...), multiplier * max(ys...))
		zlimits = (multiplier * min(zs...), multiplier * max(zs...))
	end

	# This is just the number of bodies
	n = length(positions[1])

	plt = plot3d(
		n, # This is n series so we can plot each body
		xlim = xlimits,
		ylim = ylimits,
		zlim = zlimits,
		title = "$n Body Gravity Sim",
		marker = 1,
		legend = false,
	)

	# For each frame
	@gif for i in 1:length(positions)
		# For each body in this frame
		for j in 1:length(positions[i])
			bodydata = positions[i][j]
			push!(plt, j, bodydata[1], bodydata[2], bodydata[3])
		end
	end every 10
end

"""
    creategif(bodies, framecount, Δt)

Generate a GIF from the list of Body objects `bodies`, with `framecount` frames and a time step of `Δt` seconds.

See also: [`drawgif`](@ref), [`drawframes`](@ref)
"""
creategif(bodies::Vector{Body{Float64}}, framecount::Int64, Δt::Float64, cube::Bool=false) = drawgif(drawframes(bodies, framecount, Δt), cube)

if abspath(PROGRAM_FILE) == @__FILE__
	@time creategif([
		# Body(6e24, 0.0, 0.0, 0.0, MVector{3, Float64}(0.0, 0.0, 50.0)),
		# Body(2e23, 375e6, 0.0, 0.0, MVector{3, Float64}(0.0, 250.0, 0.0)),
		Body(50.0, 0.0, 0.0, 0.0, MVector{3, Float64}(0.0, 0.0, 0.0)),
		Body(50.0, 0.0, 0.0, 1.0, MVector{3, Float64}(0.0, 0.0, 0.0)),
		Body(50.0, 0.0, 1.0, 0.0, MVector{3, Float64}(0.0, 0.0, 0.0)),
		Body(50.0, 0.0, 1.0, 1.0, MVector{3, Float64}(0.0, 0.0, 0.0)),
		Body(50.0, 1.0, 0.0, 0.0, MVector{3, Float64}(0.0, 0.0, 0.0)),
		Body(50.0, 1.0, 0.0, 1.0, MVector{3, Float64}(0.0, 0.0, 0.0)),
		Body(50.0, 1.0, 1.0, 0.0, MVector{3, Float64}(0.0, 0.0, 0.0)),
		Body(50.0, 1.0, 1.0, 1.0, MVector{3, Float64}(0.0, 0.0, 0.0))
		], 1300, 0.5)
end
