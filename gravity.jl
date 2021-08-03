#!/usr/bin/env julia

include("library.jl")

Base.@kwdef mutable struct TemplateBody{T <: Union{Float64, Nothing}}
	m::T=nothing

	x::T=nothing
	y::T=nothing
	z::T=nothing

	v::MVector{3, T}=MVector{3, T}(nothing, nothing, nothing)
end

function parsenum(num::String, len::Int64)::Vector{Int64}
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
		# This is probably a really inefficent way to change the type from Vector{SubStringg{String}}
		# to Vector{String} but it works
		splitnum_substrings = split(num, ".")
		splitnum = [string(splitnum_substrings[i]) for i in 1:length(splitnum_substrings)]

		# We recur down to get the ranges of each part of splitnum
		# This is better than rewriting code
		return collect(Iterators.flatten([parsenum(splitnum[i], len) for i in 1:length(splitnum)]))
	end
end

function parseargs(progname::String, args::Vector{String})
	connectedargs = join(args, " ")

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
				  --help, -h     Display this help text.
				  --guide        Display the full guide for all options.

				  --cube         Give the plot cubic bounds.

				  -n <number>    The number of bodies.
				  -f <frames>    The number of frames to use in the GIF.
				  -t <seconds>   The time step in seconds (default 60).

				  -m n,m         Set the mass of body number n to be m kg.
				  -p n,x,y,z     Set the initial position of body number n to be (x, y, z).
				  -v n,x,y,z     Set the initial velocity of body number n to be [x, y, z].

				See --guide for a full guide on using the options.
				""")
		return
	end

	# We split the args by "-", strip the whitspace from the end of each one,
	# and get rid of the "" at the start of the list
	arglist = strip.(split(connectedargs, "-"))[2:end]

	n = 0
	frames = 0
	Δt::Float64 = 60.0

	# We loop through and get all the meta values before getting the body attributes
	# This allows us to make a fixed length StaticArray of TemplateBody objects
	for i in 1:length(arglist)
		arg = arglist[i]

		if startswith(arg, "n")
			if n != 0 # If we're trying to redefine n
				throw(ErrorException("-n may only be defined once"))
			else
				n = parse(split(arg, " ")[2], Int64)
			end

		elseif startswith(arg, "f")
			if frames != 0 # If we're trying to redefine n
				throw(ErrorException("-f may only be defined once"))
			else
				frames = parse(split(arg, " ")[2], Int64)
			end

		elseif startswith(arg, "t")
			Δt = parse(split(arg, " ")[2], Int64)
		end
	end

	templatebodies = MVector{n, TemplateBody{Union{Float64, Nothing}}}

	for i in 1:length(arglist)
		arg = arglist[i]

		if startswith(arg, "m")
			datalist = split(split(arg, " ")[2], ",")
			nums = parsenum(datalist[1], length(templatebodies))
			value = datalist[2]

			for i in 1:nums
				templatebodies[i].m = value
			end
		end
	end
end

if abspath(PROGRAM_FILE) == @__FILE__
	parseargs(PROGRAM_FILE, ARGS)
end
