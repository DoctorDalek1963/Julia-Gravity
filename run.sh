#!/usr/bin/env sh

rm /tmp/jl_*.gif > /dev/null 2>&1
julia gravity.jl "$@"
mv /tmp/jl_*.gif ./out.gif > /dev/null 2>&1
