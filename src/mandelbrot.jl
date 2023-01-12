if !("-s=ALL" in ARGS || "--silence=ALL" in ARGS || "-h" in ARGS || "--help" in ARGS)
    println("Running mandelbrot.jl.")
end

import Images
import Dates

#### Numerical parameters, tweak as desired. ####

PICTURE_UNIT = 4800  # How many pixels per unit in the complex plane.
MANDELBROT_MAX_ITERATIONS = 180
COLOUR_BAND_WIDTH = 30  # How many iterations to go to the next ("vibrant") colour.

UNIT_WIDTH = 3.2  # The range of real units wide the picture is.
UNIT_HEIGHT = 2.5  # The range of complex units high the picture is.

X_UNIT_OFFSET = 0.5  # Increase this number to move the image right.
Y_UNIT_OFFSET = 0  # Increase this number to move the image up.

#### End of numerical parameters. ####


REPORT_PROGRESS = true  # Percentage progress report.
SILENCE_OUTPUT = false  # Hide away start and finish messages.
OVERWRITE_EXISTING = false  # Automatically overwrite a picture without asking the user.

PICTURE_WIDTH = Int(round(PICTURE_UNIT * UNIT_WIDTH))
PICTURE_HEIGHT = Int(round(PICTURE_UNIT * UNIT_HEIGHT))

COLOUR_CYCLE_LENGTH = 5  # Five block colours cycle in increasing detail.

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
        println("Some inner maths went wrong in length_to_colour().")
        println("length = $(length)")
        println("colour_band_num = $(colour_band_num)")
        println("band_progress = $(band_progress)")
        println("colour_val = $(colour_val)")
        println()

        return (100, 100, 100)
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
    filename = "mandelbrot_$(PICTURE_UNIT)_$(MANDELBROT_MAX_ITERATIONS).png"

    commit_write::Bool = true
    overwrite::Bool = false

    if OVERWRITE_EXISTING
        commit_write = true
        overwrite = isfile(filename)
    else
        if isfile(filename)
            if !SILENCE_OUTPUT
                print("Picture already exists. Overwrite? [Y/n] ")
                user_in = lowercase(readline())
                overwrite = commit_write = (user_in == "y" || user_in == "yes" || user_in == "")
            else
                # If the user does not want output, then, if a file already exists, just stop.
                commit_write = false
            end
        else
            commit_write = true
            overwrite = false
        end
    end

    if !SILENCE_OUTPUT
        if commit_write
            if overwrite
                println("Render target already exists: '$(filename)', overwriting.")
            end
        else
            println("Render target already exists: '$(filename)', skipping.")
        end
    end

    if !commit_write
        return
    end

    img::Array{UInt8, 3} = fill(0, (PICTURE_HEIGHT, PICTURE_WIDTH, 3))


    if !SILENCE_OUTPUT
        println("Image processing started.")
    end

    total_pixels = PICTURE_WIDTH * PICTURE_HEIGHT
    pc_through = 0
    pixels_through = 0

    start = Dates.now()
    for x = 1:PICTURE_WIDTH
        for y = 1:PICTURE_HEIGHT
            cx, cy = pixel_to_complex(x, y)
            mandel = mandelbrot(cx, cy)
            
            # Draw the colour accordingly, unless the point is in the mandelbrot set, then just leave that pixel.
            if mandel != -1
                mandel_colour = length_to_colour(mandel)
                draw_point!(img, x, y, mandel_colour)
            end
        end
        pixels_through += PICTURE_HEIGHT
        if REPORT_PROGRESS && (pc_through != Int(round(pixels_through / total_pixels * 100)))
            print(pc_through, "%  ")
        end
        pc_through = Int(round(pixels_through / total_pixels * 100))
    end
    if REPORT_PROGRESS
        println("100%")
    end
    finish = Dates.now()
    
    if !SILENCE_OUTPUT
        println("Image processing finished.")

        delta_seconds = round(Dates.value(finish - start) / 100) / 10
        println("Mandelbrot set calculations took $delta_seconds seconds. (This does not include time to import libraries, open files etc.)")
    end

    Images.save(filename, img)

    if !SILENCE_OUTPUT
        println("Image saved to '$filename'.")
    end
end

function main()
    global REPORT_PROGRESS
    global SILENCE_OUTPUT
    global OVERWRITE_EXISTING

    if "-h" in ARGS || "--help" in ARGS
        println("Usage: mandelbrot.jl [OPTIONS]")
        println("Mandelbrot rendering parameters are defined in mandelbrot.jl.")
        println()
        println("Options:")
        println("  -h, --help       Print this help message.")
        println("  -s, --silence    Hide percentage progress report. If --silence=ALL, then silence all output.")
        println("  -y, --overwrite  Overwrite existing image without asking.")
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
            elseif (arg_name == "--overwrite" || arg_name == "-y")
                # -y or "--overwrite" option means ignore existing image in that place.
                OVERWRITE_EXISTING = true
            else
                println("Unrecognised argument: '$arg_name', use --help or -h for more information.")
                return
            end
        end
    end

    generate()
end


main()
exit(0)
