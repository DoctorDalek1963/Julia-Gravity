# Julia-Gravity

This is a small Julia project to do an n-body gravity simulation with command line argument processing. This is my first proper Julia project and I want to use it to learn how to use the language properly.

# Command Line Arguments

## Usage
`./gravity.jl [--help] -n <number> -f <frames> [-t <seconds>] [--cube] [--initial-bounds] [options]`

## Description
gravity.jl is a program designed to simulate gravity with any number of bodies and produce a GIF.

The user must specify a number of bodies with `-n`, and a number of frames with `-f`. (A value of 2000 to 4000 frames typically produces a GIF long enough to see interesting movement while being quite quick to process, although this will vary based on other parameters.) A time step in seconds can also be specified with `-t`. This defaults to 60 seconds.

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

# Installation

To use this software on your own machine, you'll have to install [Julia](https://julialang.org/downloads/). If you're on Windows, download the installer and tick the `Add Julia to PATH` box in the installer. This is necessary. If you're on MacOS or Linux, just download the binary package and put it wherever you want, just make sure you add the executable to your PATH.

To download Julia-Gravity, click the green `Code` button at the top of this GitHub page, and select `Download ZIP`. Then extract the zip file to a suitable directory.

Before first usage, open a terminal or command prompt in the directory, and run `julia install_deps.jl`. This will install the dependencies and will probably take some time.

Now you're ready to run `gravity.jl` with the arguments explained above. On MacOS and Linux, you can call it as `./gravity.jl`, but on Windows, you need to call it as `julia gravity.jl` and then specify the arguments.

# Example GIFs

<img alt="8 body random sim gif" src="https://raw.githubusercontent.com/DoctorDalek1963/Julia-Gravity/main/cool_gifs/8_body_random2.gif" />

This gif was unfortunately generated before I implemented argument output, so I don't know what initial conditions it had, but this is a good example of the interesting behaviour that can emerge from random conditions.

<img alt="5 body random sim gif" src="https://raw.githubusercontent.com/DoctorDalek1963/Julia-Gravity/main/cool_gifs/example_1.gif" />

This gif was generated randomly and can be recreated with the rather verbose command `./gravity.jl -n 5 -f 2000 -t 60.0 --initial-bounds -m 1,6.3865954366971175e22 -p 1,-1.046485995157114e7,-1.1831052719693702e7,-2.6124825559583876e7 -v 1,602.2471821174969,88.0355239859146,-495.0546023282165 -m 2,3.804158913293605e22 -p 2,-4.086806858434652e6,1.9348056090842357e6,-2.8617446571503744e7 -v 2,126.54203553393488,-63.085411086555666,-1527.467404647707 -m 3,6.395369975409342e22 -p 3,6.869456059422254e6,-3.157228773415399e6,-3.161737269857981e7 -v 3,-32.53353053414486,-25.268658357766032,22.209676234563126 -m 4,4.915573852388649e23 -p 4,-2.1807002632697403e7,2.3497704125483662e7,7.232159300847966e6 -v 4,-270.2588160830812,117.2775111366177,-299.9622743423679 -m 5,1.6248795696763953e23 -p 5,-1.3716253056501677e7,8.498209911887344e6,-1.475952193047466e7 -v 5,56.02793615046529,665.5571009664108,-85.70102444687495`. When a simulation is generated randomly, the corresponding command is often very long.
