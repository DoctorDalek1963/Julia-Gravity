# Julia-Gravity

This is a small Julia project to do an n-body gravity simulation with command line argument processing. This is my first proper Julia project and I want to use it to learn how to use the language properly.

# Usage
`./gravity.jl [--help] -n <number> -f <frames> [-t <seconds>] [--cube] [--initial-bounds] [options]`

## Description
gravity.jl is a program designed to simulate gravity with any number of bodies and produce a GIF.

The user must specify a number of bodies with `-n`, and a number of frames with `-f`. (A value of 2000 to 4000 frames typically produces a GIF long enough to see interesting movement while being quite quick to process, although this will vary based on other parameters.) A time step can also be specified in seconds with `-t`. This defaults to 60 seconds.

`-n` and `-f` must be integers, but `-t` can be any real number.

The `--cube` flag will give the plot cubic bounds, making the aspect ratio less distorting, but this will likely make the action of the bodies harder to see. Leaving out the `--cube` flag will give the plot tight bounds, so that the camera is better focussed on the action of the bodies.

The `--initial-bounds` flag sets the bounds of the plot to only contain the initial positions. Normally, if one or more bodies flies far away from the initial area, then the plot will have bounds to include its final position. This means that all of the interesting motion is concentrated in the centre and is hard to see. With the `--initial-bounds` flag, the camera will only focus on the initial area and any bodies that fly away will be ignored.

There are three options to specify attributes of bodies. They are as follows:

`-m n,m`       Set the mass of body number `n` to be `m` kg.<br>
`-p n,x,y,z`   Set the initial position of body number `n` to be `(x, y, z)`.<br>
`-v n,x,y,z`   Set the initial velocity of body number `n` to be `[x, y, z]`.

These are all optional and if any attribute is not specified for any particular body, then it will be randomly generated with a suitable range of values for that attribute.

The program will output the full commands necessary to recreate a simulation, so if you generate one with random attributes, you can use this output to generate the same simulation, but with more frames, for example.

With the `-p` and `-v` flags, you can either specify all `x,y,z` coordinates or you can specify a single number in place of `x,y,z` to set them all to the same thing.  
You can also use precise selectors, so you can specify just part of the attribute. For example, `-v a,x15,z0` will give all bodies a velocity of 15 m/s in the x direction, 0 m/s in the z direction, and a random velocity in the y direction.

Every attribute is parsed as a `Float64` type, meaning that exponential notation (like `1e6` for 1 million) is allowed.

For the `n` in the `-m` and `-v` flags, you can use a number to specify that body like normal (the list starts at index 1), or you can use a range or group, or you can target all of the bodies with `a`.

A range is specified with `-` and is inclusive, so a range of `1-3` would target bodies 1, 2, and 3. A group is specified with `.` so a group of `1.4` would target bodies 1 and 4, but not 2, 3, or any other. Ranges and groups can also be combined, so, for example `1.3-5` would target bodies 1, 3, 4, and 5.

This targeting of multiple bodies in the same argument cannot be done for `-p`, because having multiple bodies starting in the same position doesn't make sense. The calculation of force involves dividing by distance squared, so if two bodies have the same initial position, then we'd have to divide by 0, and the program would crash.

Options are evaluated in the order that they are passed.

## Option Examples
`-v a,0 -v 1.3,10,0,0` would give all bodies a velocity of 0, except bodies 1 and 3, which would get velocities of 10 m/s in the positive x direction. Order is important in this example. If we did `-v 1.3,10,0,0 -v a,0` then the second flag would overwrite the first, and all bodies would get a velocity of 0.

`-m a,1e20 -v a,0` would give all bodies a mass of 100 quintillion kg and a velocity of 0.

## Useful Examples
`./gravity.jl -n 2 -f 3000 -t 300 -m 1,6e24 -m 2,2e23 -p 1,0 -p 2,375e6,0,0 -v 1,0,0,50 -v 2,0,-250,0` would create a simulation of 2 bodies with 3000 frames and a time step of 5 minutes. Body 1 would have a mass of 6e24 kg, be located at (0, 0, 0), and have a velocity of 50 m/s in the positive z direction. Body 2 would have a mass of 2e23 kg, be located 375 million metres from the origin in the positive x direction, and have a velocity of 250 m/s in the negative y direction.

`./gravity.jl -n 5 -f 5000` would create a simulation of 5 bodies with 5000 frames and a time step of 60 seconds. Every attribute of every body would be randomly generated every time this command is run, but the program will output what flags would need to be needed to generate the exact same simulation again.
