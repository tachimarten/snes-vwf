#!/usr/bin/env ruby
#
# ./encode-enemy-names.rb enemies.csv ff6.tbl > enemy-names.inc

require 'csv'

enemy_rows = CSV.read(ARGV[0])

table = Array.new(256, ' ')
File.open(ARGV[1], "r:ascii-8bit").each do |line|
    matches = /^([0-9A-F]{2})=(.)/.match line
    next if matches.nil?
    ff6_code = matches[1].to_i(16)
    ascii_code = matches[2].ord
    table[ascii_code] = ff6_code
end

puts ".segment \"PDATAENEMYNAMES\""
puts ""

puts "ff6_enemy_names:"
enemy_rows.each do |row|
    short_name = row[1]
    next if short_name.nil?
    print ".byte "
    (0...10).each do |char_index|
        print ", " if char_index > 0
        ch = char_index >= short_name.length ? ' ' : short_name[char_index]
        print "$#{table[ch.ord].to_s(16)}"
    end
    puts ""
end
puts ""

puts ".segment \"DATA\""
puts ""

puts "ff6vwf_long_enemy_names:"
enemy_rows.each_index do |enemy_index|
    printf "    .word .loword(ff6vwf_long_enemy_name_%03d)\n", enemy_index
end
puts ""

enemy_rows.each_index do |enemy_index|
    long_name = enemy_rows[enemy_index][2]
    printf "ff6vwf_long_enemy_name_%03d: .asciiz \"%s\"\n", enemy_index, long_name
end
puts ""
