#!/usr/bin/env ruby
#
# ./gen-font-2.rb font.tga > font.inc

def getpixel(pixels, width, height, x, y)
    return pixels[width * (height - y - 1) + x]
end

tga_file = File.open ARGV[0], "rb"
tga_data = tga_file.read
pixels = tga_data.unpack("@2C@12SSC@18C*")
tga_type = pixels.shift
tga_width = pixels.shift
tga_height = pixels.shift
tga_bpp = pixels.shift
raise "Expected grayscale TGA" unless tga_type == 3

glyph_images = Array.new(256-32)
glyph_widths = Array.new(256-32)

chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.?!@#$%^&*()-.,\"+/:;<=>_[\\]{|}~'` ".split('')
chars.push(nil)

next_x = 0

chars.each do |ch|
    ch_code = ch.nil? ? nil : (ch.ord() - 32)

    current_x = next_x
    loop do
        next_x += 1
        break if next_x == tga_width
        pixel = getpixel(pixels, tga_width, tga_height, next_x, tga_height - 1)
        break if pixel != 255
    end

    glyph_width = next_x - current_x
    #puts "'" + ch + "'" if next_x == tga_width

    glyph_image = []
    (0...(tga_height - 1)).each do |y|
        row = 0
        (0...glyph_width).each do |x|
            pixel = (getpixel(pixels, tga_width, tga_height, (current_x + x), y) == 255 ?
                     0x00 : 0x80)
            row |= (pixel >> x)
        end
        glyph_image.push row
    end

    unless ch_code.nil?
        glyph_images[ch_code] = glyph_image
        glyph_widths[ch_code] = glyph_width
    else
        glyph_images.map! { |existing_image| existing_image.nil? ? glyph_image : existing_image }
        glyph_widths.map! { |existing_width| existing_width.nil? ? glyph_width : existing_width }
    end
end

puts "glyph_widths:"
glyph_widths.each_index do |i|
    width = glyph_widths[i]
    print "    .byte " + width.to_s
    if (i + 32) < 127
        puts " ; " + (i + 32).chr + " " + i.to_s
    else
        puts ""
    end
end

puts "glyph_images:"
glyph_images.each_index do |i|
    image = glyph_images[i]
    print "    .byte " + image.join(", ")
    if (i + 32) < 127
        puts " ; " + (i + 32).chr + " " + i.to_s
    else
        puts ""
    end
end
