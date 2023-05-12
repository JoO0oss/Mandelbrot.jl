#!/bin/julia
if !("-s=ALL" in ARGS || "--silence=ALL" in ARGS || "-h" in ARGS || "--help" in ARGS)
    println("Running mandelbrot.jl.")
end

import Images
import Dates



#### Numerical parameters, tweak as desired. ####

PICTURE_UNIT = 10000  # How many pixels per unit in the complex plane.
MANDELBROT_MAX_ITERATIONS = 180
COLOUR_BAND_WIDTH = 30  # How many iterations to go to the next ("vibrant") colour.
SEGMENT_SIZE = 500  # The width and height of each segment.

UNIT_WIDTH = 3.2  # The range of real units wide the picture is.
UNIT_HEIGHT = 2.5  # The range of complex units high the picture is.

# Images which don't get whole numbers of segments have dimensions rounded up.


# (The image starts 0 + 0i in the centre.)
X_UNIT_OFFSET = 0.5  # Increase this number to move the image right.
Y_UNIT_OFFSET = 0  # Increase this number to move the image up.

# Filename options for the segments.
SUBFOLDER_NAME = "segments"

#### End of numerical parameters. ####



REPORT_PROGRESS = true  # Percentage progress report.
SILENCE_OUTPUT = false  # Hide away start and finish messages.
ACCEPT_EXISTING = true  # True to skip any previously rendered segments.

SEGMENT_NUM_X = Int(ceil(PICTURE_UNIT * UNIT_WIDTH / SEGMENT_SIZE))
SEGMENT_NUM_Y = Int(ceil(PICTURE_UNIT * UNIT_HEIGHT / SEGMENT_SIZE))
SEGMENT_NUM = SEGMENT_NUM_X * SEGMENT_NUM_Y

MAX_STRING_PAD = length(string(SEGMENT_NUM))  # For padding the segment number in the filename.


COLOUR_CYCLE_LENGTH = 5  # Five block colours cycle in increasing detail.

function segment_name(x::Int, y::Int)::String
    #return "$(SUBFOLDER_NAME)/mandelbrot_$(PICTURE_UNIT)_$(MANDELBROT_MAX_ITERATIONS)_$(x)_$(y).png"
    num = x + (y-1) * SEGMENT_NUM_X
    num_str = "0" ^ (MAX_STRING_PAD - length(string(num))) * string(num)
    
    return "$(SUBFOLDER_NAME)/mandelbrot_$(PICTURE_UNIT)_$(MANDELBROT_MAX_ITERATIONS)_$(num_str)_$(x)-$(y).png"
end


function mandelbrot(x::Float64, y::Float64)::Int
    c = x + y*im
    z = 0
    for i = 1:MANDELBROT_MAX_ITERATIONS
        z = z * z + c
        if abs(z) > 2
            return i
        end
    end
    return -1
end

function length_to_colour(length::Int)::Tuple{UInt8, UInt8, UInt8}
    # Black -> blue -> green -> yellow -> red -> magenta -> blue -> green etc.
        
    colour_band_num = length ÷ COLOUR_BAND_WIDTH  # Which set of two colours to go between.
    band_progress = length % COLOUR_BAND_WIDTH  # How far between them it is.
    colour_val = min(Int(floor(band_progress / COLOUR_BAND_WIDTH * 256)), 255)
    # Turn band_progress (as a fraction of COLOUR_BAND_WIDTH) into a colour value from 0 to 256.
    # min() is just there to make sure it can't *be* 256.

    if colour_band_num == 0
        # Black -> blue.
        return (0, 0, colour_val)
    elseif (colour_band_num) % COLOUR_CYCLE_LENGTH == 1
        # Blue -> green.
        return (0, colour_val, 255 - colour_val)        
    elseif (colour_band_num) % COLOUR_CYCLE_LENGTH == 2
        # Green -> yellow.
        return (colour_val, 255, 0)
    elseif (colour_band_num) % COLOUR_CYCLE_LENGTH == 3
        # Yellow -> red.
        return (255, 255 - colour_val, 0)
    elseif (colour_band_num) % COLOUR_CYCLE_LENGTH == 4
        # Red -> magenta.
        return (255, 0, colour_val)
    elseif (colour_band_num) % COLOUR_CYCLE_LENGTH == 0
        # Magenta -> blue.
        return (255 - colour_val, 0, 255)
    else
        if !SILENCE_OUTPUT
            println("Some inner maths went wrong in length_to_colour().")
            println("length = $(length)")
            println("colour_band_num = $(colour_band_num)")
            println("band_progress = $(band_progress)")
            println("colour_val = $(colour_val)")
            println()
        end

        return (100, 100, 100)  # This dull grey should stick out in the final render.
    end

end

function pixel_to_complex(x::Int, y::Int)::Tuple{Float64, Float64}
    cx = x / PICTURE_UNIT - UNIT_WIDTH/2 - X_UNIT_OFFSET
    cy = -(y / PICTURE_UNIT) + UNIT_HEIGHT/2 - Y_UNIT_OFFSET

    return cx, cy
end

function draw_point!(img::Array{UInt8, 3}, x::Int, y::Int, colour::Tuple{UInt8, UInt8, UInt8})
    img[y, x, 1] = colour[1]
    img[y, x, 2] = colour[2]
    img[y, x, 3] = colour[3]
end


function generate()
    img::Array{UInt8, 3} = fill(0, (SEGMENT_SIZE, SEGMENT_SIZE, 3))

    if !isdir(SUBFOLDER_NAME)
        try
            mkdir(SUBFOLDER_NAME)
            if !SILENCE_OUTPUT
                println("Folder '$SUBFOLDER_NAME' did not exist and has been created.")
            end
        catch
            if !SILENCE_OUTPUT
                println("Error trying to write images into '$SUBFOLDER_NAME'.")
            end
        end
    end

    if !SILENCE_OUTPUT
        println("Image processing started.")
    end

    segment_num = 0

    start = Dates.now()
    
    for segment_x = 1:SEGMENT_NUM_X
        for segment_y = 1:SEGMENT_NUM_Y
            segment_num += 1

            filename = segment_name(segment_x, segment_y)
            if isfile(filename) && ACCEPT_EXISTING
                if REPORT_PROGRESS
                    print("Skipping '$filename'.  ($segment_num of $SEGMENT_NUM)")
                end
                continue
            end
            
            img = fill(0, (SEGMENT_SIZE, SEGMENT_SIZE, 3))

            for x = 1:SEGMENT_SIZE
                for y = 1:SEGMENT_SIZE
                    cx, cy = pixel_to_complex((segment_x - 1) * SEGMENT_SIZE + x, (segment_y - 1) * SEGMENT_SIZE + y)
                    mandel = mandelbrot(cx, cy)  # mandel stores the "depth"/number of iterations.

                    # Draw the colour accordingly, unless the point is in the mandelbrot set, then just leave that pixel.
                    if mandel != -1
                        mandel_colour = length_to_colour(mandel)
                        draw_point!(img, x, y, mandel_colour)
                    end
                end
            end

            Images.save(filename, img)
            if REPORT_PROGRESS
                println("Saved '$filename' ($segment_num of $SEGMENT_NUM).")
            end
        end
    end
    finish = Dates.now()
    
    if !SILENCE_OUTPUT
        println("Image processing finished.")

        delta_seconds = round(Dates.value(finish - start) / 100) / 10
        println("Mandelbrot set calculations took $delta_seconds seconds. (This does not include time to import libraries etc.)")
    end


    # montage *.png -geometry +0+0 -tile 7x5 all.png
end

function main()
    global REPORT_PROGRESS
    global SILENCE_OUTPUT
    global ACCEPT_EXISTING

    if "-h" in ARGS || "--help" in ARGS
        println("Usage: mandelbrot.jl [OPTIONS]")
        println("Mandelbrot rendering parameters are defined in mandelbrot.jl.")
        println()
        println("Options:")
        println("  -h, --help       Print this help message.")
        println("  -s, --silence    Hide percentage progress report. If --silence=ALL, then silence all output.")
        println("  -o, --overwrite  Overwrite existing images (default is to leave segments as they are).")
        return
    end

    for arg = ARGS
        if contains(arg, "=")
            arg_name, arg_val = split(arg, "=", limit=2)
            
            if (arg_name == "--silence" || arg_name == "-s")
                if arg_val == "ALL"
                    REPORT_PROGRESS = false
                    SILENCE_OUTPUT = true
                else
                    println("Unrecognised value: '$arg_val' for argument '$arg_name', use --help or -h for more information.")
                    return
                end
            else
                println("Unrecognised argument: '$arg_name=...' to be used with a value, use --help or -h for more information.")
                return
            end
        else
            arg_name = arg
        
            if arg_name == "--silence" || arg_name == "-s"
                # If just the silence option is provided, then give start and end outputs.s
                REPORT_PROGRESS = false
            elseif (arg_name == "--overwrite" || arg_name == "-o")
                # -y or "--overwrite" option means ignore existing image in that place.
                ACCEPT_EXISTING = false
            else
                println("Unrecognised argument: '$arg_name', use --help or -h for more information.")
                return
            end
        end
    end

    generate()
end


main()
