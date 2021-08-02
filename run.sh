#!/usr/bin/env sh

rm /tmp/jl_*.gif
julia gravity.jl "$@"
mv /tmp/jl_*.gif ./out.gif
