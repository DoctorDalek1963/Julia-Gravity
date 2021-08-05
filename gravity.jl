#!/usr/bin/env julia

using Dates

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

	v::Vector{Union{Float64, Nothing}} = [nothing, nothing, nothing]
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

	Body(tb.m, tb.x, tb.y, tb.z, MVector{3, Float64}(tb.v[1], tb.v[2], tb.v[3]))
end

"""
    parsenums(num::String, len::Int)

Parse the string `num` and return a list of all indices to target.

`len` is the length of the bodies list. If any number is larger than it,
then we throw an error.

See also: [`parseargs`](@ref)
"""
function parsenums(num::String, len::Int)::Vector{Int}
	if num == "a"
		return [1:len;]

	# If it's not a range or group
	elseif !occursin("-", num) && !occursin(".", num)
		n = parse(Int, num)
		if n > len; error("You cannot select body $n; there are only $len bodies."); end
		return [n]

	# If it's not a range but it is a group
	elseif !occursin("-", num) && occursin(".", num)
		ns = [parse(Int, i) for i in split(num, ".")]

		if max(ns...) > len; error("You cannot select body $(max(ns...)); there are only $len bodies."); end
		return ns

	# If it's a range but not a group
	elseif occursin("-", num) && !occursin(".", num)
		first = parse(Int, split(num, "-")[1])
		second = parse(Int, split(num, "-")[2])
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
parsenums(a::SubString{String}, b::Int) = parsenums(string(a), b)

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
				Usage: $progname [--help] -n <number> -f <frames> [-t <seconds>] [--cube] [--initial-bounds] [--quiet] [attribute options]

				Options:
				  --help, -h         Display this help text.

				  -n <number>        The number of bodies.
				  -f <frames>        The number of frames to use in the GIF.
				  -t <seconds>       The time step in seconds (default 60).

				  --cube             Give the plot cubic bounds.
				  --initial-bounds   Give the plot bounds to only include the initial positions.
				  --quiet            Suppress terminal output; only write command to log file.

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

	n::Union{Int, Nothing} = nothing
	frames::Union{Int, Nothing} = nothing
	Δt::Float64 = 60.0
	cube = false
	initialbounds = false
	quiet = false

	# We loop through and get all the meta values before getting the body attributes
	# This allows us to make a fixed length StaticArray of TemplateBody objects
	for i in 1:length(arglist)
		arg = arglist[i]

		if startswith(arg, "n")
			if !isnothing(n) # If we're trying to redefine n
				error("-n may only be defined once")
			else
				n = parse(Int, split(arg, " ")[2])
			end

		elseif startswith(arg, "f")
			if !isnothing(frames) # If we're trying to redefine n
				error("-f may only be defined once")
			else
				frames = parse(Int, split(arg, " ")[2])
			end

		elseif startswith(arg, "t")
			Δt = parse(Float64, split(arg, " ")[2])

		# We need 1 "-" here because we split by " -" and these args are long form
		elseif arg == "-cube"
			cube = true

		elseif arg == "-initial-bounds"
			initialbounds = true

		elseif arg == "-quiet"
			quiet = true
		end
	end

	if isnothing(n); error("-n must be specified"); end
	if isnothing(frames); error("-f must be specified"); end

	templatebodies = MVector{n, TemplateBody}([TemplateBody() for _ in 1:n]...)

	for i in 1:length(arglist)
		arg = arglist[i]

		if startswith(arg, "m")
			datalist = split(split(arg, " ")[2], ",")
			nums = parsenums(datalist[1], n)

			value = parse(Float64, datalist[2])
			if value < 0; error("Mass must not be negative"); end

			for i in 1:n
				# If this is a body that we want to edit
				if in(i, nums)
					templatebodies[i].m = value
				end
			end

		elseif startswith(arg, "p")
			data = split(arg, " ")[2]
			datalist = split(data, ",")

			# We use parsenums() just to check that the user only gave 1 number,
			# so that we can give them a better error message
			nums = parsenums(datalist[1], n)
			if length(nums) > 1
				error("-p only accepts single number selectors; \"$(datalist[1])\" is invalid")
			else
				num = nums[1]
			end

			if num > n; error("You cannot select body $num; there are only $n bodies."); end

			# If we don't have any special selectors and they're just positional
			if !occursin("x", data) && !occursin("y", data) && !occursin("z", data)
				# If we don't have the right number of values
				if length(datalist) != 2 && length(datalist) != 4
					error("-p only accepts 1 or 3 positional values, not $(length(datalist[2:end]))")
				end

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

			# If we've got explicit values
			else
				for i in 2:length(datalist)
					value = datalist[i]

					# If we get a value that doesn't start with x, y, or z, then we just ignore its
					# because we can't mix explicit coords with positional coords
					if startswith(value, "x"); templatebodies[num].x = parse(Float64, value[2:end]); end
					if startswith(value, "y"); templatebodies[num].y = parse(Float64, value[2:end]); end
					if startswith(value, "z"); templatebodies[num].z = parse(Float64, value[2:end]); end
				end
			end

		elseif startswith(arg, "v")
			data = split(arg, " ")[2]
			datalist = split(data, ",")

			nums = parsenums(datalist[1], n)

			# If we don't have any special selectors and they're just positional
			if !occursin("x", data) && !occursin("y", data) && !occursin("z", data)
				# If we don't have the right number of values
				if length(datalist) != 2 && length(datalist) != 4
					error("-v only accepts 1 or 3 positional values, not $(length(datalist[2:end]))")
				end

				# If we've only got 1 number, use that for all
				if length(datalist[2:end]) == 1
					values = [parse(Float64, datalist[2]) for _ in 1:3]
				else
					values = [parse(Float64, datalist[i]) for i in 2:4]
				end

				for i in 1:n
					if in(i, nums)
						templatebodies[i].v = values
					end
				end

			# If we've got explicit values
			else
				for i in 2:length(datalist)
					value = datalist[i]

					for i in 1:n
						if in(i, nums)
							# If we get a value that doesn't start with x, y, or z, then we just ignore its
							# because we can't mix explicit values with positional values
							if startswith(value, "x"); templatebodies[i].v[1] = parse(Float64, value[2:end]); end
							if startswith(value, "y"); templatebodies[i].v[2] = parse(Float64, value[2:end]); end
							if startswith(value, "z"); templatebodies[i].v[3] = parse(Float64, value[2:end]); end
						end
					end
				end
			end
		end
	end

	bodies = Body[]

	for i in 1:n
		tb = templatebodies[i]

		# Values in a similar order of magnitude to 1e22
		if isnothing(tb.m); tb.m = 1e22 * rand() * rand(1:100); end

		# Values from 0 to 50e6 with variation, positive and negative
		if isnothing(tb.x); tb.x = randn() * rand(0:50000000); end
		if isnothing(tb.y); tb.y = randn() * rand(0:50000000); end
		if isnothing(tb.z); tb.z = randn() * rand(0:50000000); end

		# Values from 0 to 500 with variation, positive and negative
		if isnothing(tb.v[1]); tb.v[1] = randn() * rand(0:500); end
		if isnothing(tb.v[2]); tb.v[2] = randn() * rand(0:500); end
		if isnothing(tb.v[3]); tb.v[3] = randn() * rand(0:500); end

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

	# Generate the command and log it
	command = ""
	command *= "$progname -n $n -f $frames -t $Δt"
	if cube; command *= " --cube"; end
	if initialbounds; command *= " --initial-bounds"; end

	for i in 1:n
		b = bodies[i]
		command *= " -m $i,$(b.m) -p $i,$(b.x),$(b.y),$(b.z) -v $i,$(b.v[1]),$(b.v[2]),$(b.v[3])"
	end

	# Write the command to the log file
	open("command_log.txt", "a") do file
		write(file, "[$(Dates.now())] $command\n\n")
	end

	if !quiet
		println("\nThese are the arguments needed to recreate this simulation:\n")
		println(command)
		println()
	end

	println("Simulating...")
	creategif(bodies, frames, Δt, cube, bounds)
end

if abspath(PROGRAM_FILE) == @__FILE__
	parseargs(PROGRAM_FILE, ARGS)
end
