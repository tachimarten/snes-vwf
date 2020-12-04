#!/usr/bin/env ruby
#
# ./extract-enemy-names.rb ff6.smc ff6.tbl > enemy-names.inc

ENEMY_COUNT = 422

rom_file = File.open ARGV[0]
rom_data = rom_file.read
original_enemy_names = rom_data.unpack "@#{0xfc050}C#{ENEMY_COUNT * 10}"

table = Array.new(256, ' ')
File.open(ARGV[1], "r:ascii-8bit").each do |line|
    matches = /^([0-9A-F]{2})=(.)/.match line
    next if matches.nil?
    table[matches[1].to_i(16)] = matches[2]
end

puts "ff6vwf_long_enemy_names:"

(0...ENEMY_COUNT).each do |enemy_id|
    printf "    .word .loword(ff6vwf_long_enemy_name_%03d)\n", enemy_id
end

puts ""

(0...(original_enemy_names.length / 10)).each do |enemy_id|
    string = ""
    (0...10).each do |char_index|
        string += table[original_enemy_names[char_index + 10 * enemy_id]]
    end
    string.rstrip!
    printf "ff6vwf_long_enemy_name_%03d: .asciiz \"%s\" ; %s\n", enemy_id, string, string
end
