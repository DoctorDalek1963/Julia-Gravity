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
	if r2 == 0; error("Cannot divide by 0. The positions of two bodies cannot be the same."); end

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
function step!(bodies::Vector{Body}, Δt::Float64)
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
function drawframes(bodies::Vector{Body}, framecount::Int, Δt::Float64)::Vector{Vector{SVector{3, Float64}}}
	frames::Vector{Vector{SVector{3, Float64}}} = [[SVector{3, Float64}(bodies[i].x, bodies[i].y, bodies[i].z) for i in 1:length(bodies)]]

	for _ in 1:framecount
		step!(bodies, Δt)

		# We build the position data for this frame
		thisframe::Vector{SVector{3, Float64}} = [SVector{3, Float64}(bodies[i].x, bodies[i].y, bodies[i].z) for i in 1:length(bodies)]

		push!(frames, thisframe)
	end

	return frames
end

"""
    drawgif(positions, cube=false, bounds=nothing)

Draw a GIF using the position data.

`positions` is a Vector{Vector{Vector{Float64}}}. It can be thought of as a list of frames,
where each frame has a list of bodies, and each body has a list of x y z coordinates.

`cube` is a bool for whether to draw the plot bounds as a cube.

`bounds` is a Vector{Tuple{Float64, Float64}} - a list of xlimits, ylimits, and zlimits.
If it's nothing (by default), then the bounds will be auto-generated.

See also: [`drawframes`](@ref), [`creategif`](@ref)
"""
function drawgif(positions::Vector{Vector{SVector{3, Float64}}}, cube::Bool, bounds::Union{Nothing, Vector{Tuple{Float64, Float64}}}=nothing)
	# This is a multiplier to make the bounding box just a bit bigger than strictly necessary,
	# just to make it look a bit nicer
	multiplier = 1.05

	if cube && !isnothing(bounds)
		# We get the maximum absolute value in the bounds and use that to build the cube
		maxbound = multiplier * max(abs.(Iterators.flatten(bounds))...)

		xlimits = (-1 * maxbound, maxbound)
		ylimits = (-1 * maxbound, maxbound)
		zlimits = (-1 * maxbound, maxbound)

	elseif !cube && !isnothing(bounds)
		# We just use the bounds given, multiplied by the multiplier
		xlimits = multiplier .* bounds[1]
		ylimits = multiplier .* bounds[2]
		zlimits = multiplier .* bounds[3]

	elseif cube && isnothing(bounds)
		# This line gets absolute value of every float in positions and then gets the max
		# Because we're dealing with a nested vector, we have to flatten it, and then
		# flatten the result, and then splat it for max
		maxbound = multiplier * max(abs.(Iterators.flatten(Iterators.flatten(positions)))...)

		xlimits = (-1 * maxbound, maxbound)
		ylimits = (-1 * maxbound, maxbound)
		zlimits = (-1 * maxbound, maxbound)

	# Not cube or explicit bounds
	else
		# These list comprehensions loop through the list to get the coords
		# i is every frame in the positions list, and j is every body in each frame
		# We only need to check length(positions[1]) to get j because the length of
		# every sub-list is the same because every frame has the same number of bodies
		xs = [positions[i][j][1] for i in 1:length(positions) for j in 1:length(positions[1])]
		ys = [positions[i][j][2] for i in 1:length(positions) for j in 1:length(positions[1])]
		zs = [positions[i][j][3] for i in 1:length(positions) for j in 1:length(positions[1])]

		xlimits = multiplier .* extrema(xs)
		ylimits = multiplier .* extrema(ys)
		zlimits = multiplier .* extrema(zs)
	end

	# This is just the number of bodies
	n = length(positions[1])

	# We have 4 different subplots. xyz is the 3D perspective camera angle. The others are the orthogonal views.
	# We then put these subplots into a full plot to show everything comprehensively
	xyz = plot3d(n; legend=false, lw=1, title="$n Body Gravity Simulation", xlim=xlimits, ylim=ylimits, zlim=zlimits)
	# We're using standard 2D line plots here to avoid issues with cameras in 3D space
	xy = plot(n; legend=false, lw=0.5, title="Plan", titlefontsize=8, xlim=xlimits, ylim=ylimits, tickfontsize=4)
	xz = plot(n; legend=false, lw=0.5, title="Front", titlefontsize=8, xlim=xlimits, ylim=zlimits, tickfontsize=4)
	yz = plot(n; legend=false, lw=0.5, title="Side", titlefontsize=8, xlim=ylimits, ylim=zlimits, tickfontsize=4)

	# This is the expanded form of the @gif macro over a for loop
	# We're using the expanded form rather than the macro itself because
	# that lets us control the filename
	anim = Plots.Animation()
	counter = 1
	# For each frame
	for i = 1:length(positions)
		# For each body in this frame
		for j in 1:length(positions[i])
			# We add the position data of every body to its respective series in the plots
			bodydata = positions[i][j]
			push!(xyz, j, bodydata[1], bodydata[2], bodydata[3])
			push!(xy, j, bodydata[1], bodydata[2])
			push!(xz, j, bodydata[1], bodydata[3])
			push!(yz, j, bodydata[2], bodydata[3])
		end

		# Only if this counter is a multiple of 10, do we add this frame to the animation
		if counter % 10 == 0
			layout = @layout [a{0.7h}; b c d]
			Plots.frame(anim, plot(xyz, xy, xz, yz; layout, size=(1000, 1000)))
		end

		counter += 1
	end
	Plots.gif(anim, "./out.gif")
end

"""
    creategif(bodies, framecount, Δt, cube=false, bounds=nothing)

Generate a GIF from the list of Body objects `bodies`, with `framecount` frames and a time step of `Δt` seconds.

`cube` is a bool for whether to draw the plot bounds as a cube.

`bounds` is a Vector{Tuple{Float64, Float64}} - a list of xlimits, ylimits, and zlimits.
If it's nothing (by default), then the plot bounds will be auto-generated.

See also: [`drawgif`](@ref), [`drawframes`](@ref)
"""
creategif(bodies::Vector{Body}, framecount::Int, Δt::Float64, cube::Bool=false, bounds::Union{Nothing, Vector{Tuple{Float64, Float64}}}=nothing) = drawgif(drawframes(bodies, framecount, Δt), cube, bounds)
