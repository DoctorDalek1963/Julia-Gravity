#!/usr/bin/env julia

include("library.jl")

Base.@kwdef mutable struct TemplateBody
	m::Union{Float64, Nothing} = nothing

	x::Union{Float64, Nothing} = nothing
	y::Union{Float64, Nothing} = nothing
	z::Union{Float64, Nothing} = nothing

	v::MVector{3, Union{Float64, Nothing}} = MVector{3, Union{Float64, Nothing}}(nothing, nothing, nothing)
end

# This is an alternate constructor method to convert a TemplateBody
function Body(tb::TemplateBody)::Body{Float64}
	if isnothing(tb.m); error("Mass must not be nothing"); end
	if isnothing(tb.x); error("x must not be nothing"); end
	if isnothing(tb.y); error("y must not be nothing"); end
	if isnothing(tb.z); error("z must not be nothing"); end
	if isnothing(tb.v[1]); error("Velocity must not be nothing"); end

	Body{Float64}(tb.m, tb.x, tb.y, tb.z, MVector{3, Float64}(tb.v[1], tb.v[2], tb.v[3]))
end

function parsenums(num::String, len::Int64)::Vector{Int64}
	if num == "a"
		return [1:len;]

	# If it's not a range or group
	elseif !occursin("-", num) && !occursin(".", num)
		return [parse(Int64, num)]

	# If it's not a range but it is a group
	elseif !occursin("-", num) && occursin(".", num)
		return [parse(Int64, i) for i in split(num, ".")]

	# If it's a range but not a group
	elseif occursin("-", num) && !occursin(".", num)
		first = parse(Int64, split(num, "-")[1])
		second = parse(Int64, split(num, "-")[2])
		return [first:second;]

	# If it's both a range and a group
	else
		splitnum = split(num, ".")

		# We recur down to get the ranges of each part of splitnum
		# This is better than rewriting code
		return collect(Iterators.flatten([parsenums(splitnum[i], len) for i in 1:length(splitnum)]))
	end
end

# When we recur, we're calling parsenums with SubString{String}, so we have to convert it to String
parsenums(a::SubString{String}, b::Int64) = parsenums(string(a), b)

function parseargs(progname::String, args::Vector{String})
	# We need to put a space in front to split by " -" and avoid breaking negatives
	connectedargs = " " * join(args, " ")

	if occursin("--guide", connectedargs)
		open("guide.md", "r") do f
			println(read(f, String))
		end
		return
	end

	if occursin("--help", connectedargs) || occursin("-h", connectedargs) || length(args) < 4 # We need at least 4 args
		println("""
				Usage: $progname [--help | --guide] [--cube] -n <number> -f <frames> [-t <time_step>] [options]

				Options:
				  --help, -h         Display this help text.
				  --guide            Display the full guide for all options.

				  --cube             Give the plot cubic bounds.
				  --initial-bounds   Give the plot bounds to only include the initial positions.

				  -n <number>        The number of bodies.
				  -f <frames>        The number of frames to use in the GIF.
				  -t <seconds>       The time step in seconds (default 60).

				  -m n,m             Set the mass of body number n to be m kg.
				  -p n,x,y,z         Set the initial position of body number n to be (x, y, z).
				  -v n,x,y,z         Set the initial velocity of body number n to be [x, y, z].

				See --guide for a full guide on using the options.
				""")
		return
	end

	# We split the args by "-", get rid of the "" in the list, and strip
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
