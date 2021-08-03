#!/usr/bin/env julia

include("library.jl")

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
end

if abspath(PROGRAM_FILE) == @__FILE__
	parseargs(PROGRAM_FILE, ARGS)
end
