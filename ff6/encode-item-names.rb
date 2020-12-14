#!/usr/bin/env ruby
#
# ./encode-item-names.rb items.csv > item-names.inc

require 'csv'

item_rows = CSV.read(ARGV[0])

puts ".segment \"DATA\""
puts ""

puts "ff6vwf_long_item_names:"
item_rows.each_index do |item_index|
    printf "    .word .loword(ff6vwf_long_item_name_%03d)\n", item_index
end
puts ""

item_rows.each_index do |item_index|
    long_name = item_rows[item_index][2]
    printf "ff6vwf_long_item_name_%03d: .asciiz \"%s\"\n", item_index, long_name
end
puts ""

