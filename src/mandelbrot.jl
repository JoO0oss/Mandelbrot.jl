import Images

PICTURE_UNIT = 500  # How many pixels per unit in the complex plane.
MANDELBROT_MAX_ITERATIONS = 100

PICTURE_WIDTH = Int(round(PICTURE_UNIT * 3.2))
PICTURE_HEIGHT = Int(round(PICTURE_UNIT * 2.5))

REPORT_PROGRESS = true  # Percentage progress report.
SILENCE_OUTPUT = false  # Hide away start and finish messages.
OVERWRITE_EXISTING = false  # Automatically overwrite a picture without asking the user.

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
    # Black -> blue -> green -> yellow -> red -> white.
    colour_val = Int(round((length % COLOUR_BAND_WIDTH) / COLOUR_BAND_WIDTH * 255))

    if length < COLOUR_BAND_WIDTH
        return (0, 0, colour_val)
    elseif length < 2COLOUR_BAND_WIDTH
        return (0, colour_val, 255 - colour_val)
    elseif length < 3COLOUR_BAND_WIDTH
        return (colour_val, 255, 0)
    elseif length < 4COLOUR_BAND_WIDTH
        return (255, 255 - colour_val, 0)
    elseif length < 5COLOUR_BAND_WIDTH
        return (255, colour_val, colour_val)
    elseif length < 6COLOUR_BAND_WIDTH
        return (colour_val, colour_val, colour_val)
    else
        return (255, 255, 255)
    end

function pixel_to_complex(x::Int, y::Int)::Tuple{Float64, Float64}
    cx = x / PICTURE_UNIT - 2.3  # Increase this number to shift right.
    cy = - (y / PICTURE_UNIT) + 1.25  # Increase this number to shift down.

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
            print("Picture already exists. Overwrite? [Y/n] ")
            user_in = lowercase(readline())
            overwrite = commit_write = (user_in == "y" || user_in == "yes" || user_in == "")
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

    total_pixels = PICTURE_WIDTH * PICTURE_HEIGHT
    pc_through = 0
    pixels_through = 0

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
    
    Images.save(filename, img)
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
        println("  -s, --silence    Silence output. If --silence=ALL, then the percentage progress report is turned off, too.")
        println("  -y, --overwrite  Overwrite existing image without asking.")
        return
    end

    for arg = ARGS
        if contains(arg, "=")
            arg_name, arg_val = split(arg, "=", limit=2)
            
            if (arg_name == "--silence" || arg_name == "-s") && arg_val == "ALL"
                REPORT_PROGRESS = false
                SILENCE_OUTPUT = true
            end
        else
            arg_name = arg
        
            if arg_name == "--silence" || arg_name == "-s"
                # If just the silence option is provided, then give start and end outputs.
                REPORT_PROGRESS = false
            end

            if (arg_name == "--overwrite" || arg_name == "-y")
                # -y or "--overwrite" option means ignore existing image in that place.
                OVERWRITE_EXISTING = true
            end
        end
    end

    if !SILENCE_OUTPUT
        println("Image processing started.")
    end
    
    generate()

    if !SILENCE_OUTPUT
        println("Image processing finished.")
    end
end


main()
exit(0)
