#!/usr/bin/env julia

include("library.jl")

"""
    TemplateBody(m, x, y, z, v)

Create a template of a celestial body. By default, all arguments are `nothing`.

See also: [`Body`](@ref)
"""
Base.@kwdef mutable struct TemplateBody
	m::Union{Float64, Nothing} = nothing

	x::Union{Float64, Nothing} = nothing
	y::Union{Float64, Nothing} = nothing
	z::Union{Float64, Nothing} = nothing

	v::MVector{3, Union{Float64, Nothing}} = MVector{3, Union{Float64, Nothing}}(nothing, nothing, nothing)
end

"""
    Body(tb::TemplateBody)

Create a Body object from a TemplateBody object. Will throw errors if any attribute is `nothing`.
"""
function Body(tb::TemplateBody)::Body
	if isnothing(tb.m); error("Mass must not be nothing"); end
	if isnothing(tb.x); error("x must not be nothing"); end
	if isnothing(tb.y); error("y must not be nothing"); end
	if isnothing(tb.z); error("z must not be nothing"); end
	if isnothing(tb.v[1]); error("Velocity x component must not be nothing"); end
	if isnothing(tb.v[2]); error("Velocity y component must not be nothing"); end
	if isnothing(tb.v[3]); error("Velocity z component must not be nothing"); end

	Body{Float64}(tb.m, tb.x, tb.y, tb.z, MVector{3, Float64}(tb.v[1], tb.v[2], tb.v[3]))
end

"""
    parsenums(num::String, len::Int64)

Parse the string `num` and return a list of all indices to target.

`len` is the length of the bodies list. If any number is larger than it,
then we throw an error.

See also: [`parseargs`](@ref)
"""
function parsenums(num::String, len::Int64)::Vector{Int64}
	if num == "a"
		return [1:len;]

	# If it's not a range or group
	elseif !occursin("-", num) && !occursin(".", num)
		n = parse(Int64, num)
		if n > len; error("You cannot select body $n; there are only $len bodies."); end
		return [n]

	# If it's not a range but it is a group
	elseif !occursin("-", num) && occursin(".", num)
		ns = [parse(Int64, i) for i in split(num, ".")]

		if max(ns...) > len; error("You cannot select body $(max(ns...)); there are only $len bodies."); end
		return ns

	# If it's a range but not a group
	elseif occursin("-", num) && !occursin(".", num)
		first = parse(Int64, split(num, "-")[1])
		second = parse(Int64, split(num, "-")[2])
		ns = [first:second;]

		if max(ns...) > len; error("You cannot select body $(max(ns...)); there are only $len bodies."); end
		return ns

	# If it's both a range and a group
	else
		splitnum = split(num, ".")

		# We recur down to get the ranges of each part of splitnum
		# We don't need to check that all nums are <= len, because we do that check in the recurrance
		return collect(Iterators.flatten([parsenums(splitnum[i], len) for i in 1:length(splitnum)]))
	end
end

# When we recur, we're calling parsenums with SubString{String}, so we have to convert it to String
parsenums(a::SubString{String}, b::Int64) = parsenums(string(a), b)

"""
    parseargs(progname, args)

Parse the arguments and call creategif(). Should be called with PROGRAM_FILE and ARGS.

See also: [`parsenum`](@ref)
"""
function parseargs(progname::String, args::Vector{String})
	# We need to put a space in front to split by " -" and avoid breaking negatives
	connectedargs = " " * join(args, " ")

	if occursin("--help", connectedargs) || occursin("-h", connectedargs) || length(args) < 4 # We need at least 4 args
		println("""
				Usage: $progname [--help] [--cube] -n <number> -f <frames> [-t <seconds>] [options]

				Options:
				  --help, -h         Display this help text.

				  --cube             Give the plot cubic bounds.
				  --initial-bounds   Give the plot bounds to only include the initial positions.

				  -n <number>        The number of bodies.
				  -f <frames>        The number of frames to use in the GIF.
				  -t <seconds>       The time step in seconds (default 60).

				  -m n,m             Set the mass of body number n to be m kg.
				  -p n,x,y,z         Set the initial position of body number n to be (x, y, z).
				  -v n,x,y,z         Set the initial velocity of body number n to be [x, y, z].

				See README.md (read it at https://github.com/DoctorDalek1963/Julia-Gravity) for a full guide on using the options.
				""")
		return
	end

	# We split the args by " -", get rid of the "" in the list, and strip
	# the whitespace from the end of each element
	arglist = strip.(split(connectedargs, " -", keepempty=false))

	n = 0
	frames = 0
	Δt::Float64 = 60.0
	cube = false
	initialbounds = false

	# We loop through and get all the meta values before getting the body attributes
	# This allows us to make a fixed length StaticArray of TemplateBody objects
	for i in 1:length(arglist)
		arg = arglist[i]

		if startswith(arg, "n")
			if n != 0 # If we're trying to redefine n
				throw(ErrorException("-n may only be defined once"))
			else
				n = parse(Int64, split(arg, " ")[2])
			end

		elseif startswith(arg, "f")
			if frames != 0 # If we're trying to redefine n
				throw(ErrorException("-f may only be defined once"))
			else
				frames = parse(Int64, split(arg, " ")[2])
			end

		elseif startswith(arg, "t")
			Δt = parse(Float64, split(arg, " ")[2])

		# We need 1 "-" here because we split by " -" and these args are long form
		elseif arg == "-cube"
			cube = true

		elseif arg == "-initial-bounds"
			initialbounds = true
		end
	end

	templatebodies = MVector{n, TemplateBody}([TemplateBody() for _ in 1:n]...)

	for i in 1:length(arglist)
		arg = arglist[i]

		if startswith(arg, "m")
			datalist = split(split(arg, " ")[2], ",")
			nums = parsenums(datalist[1], length(templatebodies))
			value = datalist[2]

			for i in 1:n
				# If this is a body that we want to edit
				if in(i, nums)
					templatebodies[i].m = parse(Float64, value)
				end
			end

		elseif startswith(arg, "p")
			# Position doesn't allow multiple selection, so we don't need to parsenums()
			datalist = split(split(arg, " ")[2], ",")
			num = parse(Int64, datalist[1])
			if num > length(templatebodies); error("You cannot select body $n; there are only $(length(templatebodies)) bodies."); end

			# If we've only got 1 number, use that for all
			if length(datalist[2:end]) == 1
				templatebodies[num].x = parse(Float64, datalist[2])
				templatebodies[num].y = parse(Float64, datalist[2])
				templatebodies[num].z = parse(Float64, datalist[2])
			else
				templatebodies[num].x = parse(Float64, datalist[2])
				templatebodies[num].y = parse(Float64, datalist[3])
				templatebodies[num].z = parse(Float64, datalist[4])
			end

		elseif startswith(arg, "v")
			datalist = split(split(arg, " ")[2], ",")
			nums = parsenums(datalist[1], length(templatebodies))

			# If we've only got 1 number, use that for all
			if length(datalist[2:end]) == 1
				values = MVector{3, Float64}([parse(Float64, datalist[2]) for _ in 1:3]...)
			else
				values = MVector{3, Float64}([parse(Float64, datalist[i]) for i in 2:4]...)
			end

			for i in 1:n
				if in(i, nums)
					templatebodies[i].v = values
				end
			end
		end
	end

	bodies = Body[]

	for i in 1:length(templatebodies)
		tb = templatebodies[i]

		# Values in a similar order of magnitude to 1e22
		if isnothing(tb.m); tb.m = 1e22 * rand() * rand(1:100); end

		# Values from 0 to 50e6 with variation, positive and negative
		if isnothing(tb.x); tb.x = randn() * rand(0:50000000); end
		if isnothing(tb.y); tb.y = randn() * rand(0:50000000); end
		if isnothing(tb.z); tb.z = randn() * rand(0:50000000); end

		# Values from 0 to 500 with variation, positive and negative
		# We only need to check tb.v[1] for nothing because v can only be set as a whole
		if isnothing(tb.v[1]); tb.v = MVector{3, Float64}([randn() * rand(0:500) for _ in 1:3]...); end

		# We created a custom Body constuctor earlier to construct a
		# Body from a TemplateBody
		push!(bodies, Body(tb))
	end

	# If desired, we get the initial bounds and use those
	if initialbounds
		xs = [bodies[i].x for i in 1:length(bodies)]
		ys = [bodies[i].y for i in 1:length(bodies)]
		zs = [bodies[i].z for i in 1:length(bodies)]

		bounds = [
				(min(xs...), max(xs...)),
				(min(ys...), max(ys...)),
				(min(zs...), max(zs...))
				]
	else
		bounds = nothing
	end

	println("These are the arguments needed to recreate this simulation:")

	print("$progname -n $n -f $frames -t $Δt")
	if cube; print(" --cube"); end
	if initialbounds; print(" --initial-bounds"); end

	for i in 1:length(bodies)
		b = bodies[i]
		print(" -m $i,$(b.m) -p $i,$(b.x),$(b.y),$(b.z) -v $i,$(b.v[1]),$(b.v[2]),$(b.v[3])")
	end

	println()
	println()
	println("Simulating...")
	creategif(bodies, frames, Δt, cube, bounds)
end

if abspath(PROGRAM_FILE) == @__FILE__
	parseargs(PROGRAM_FILE, ARGS)
end
