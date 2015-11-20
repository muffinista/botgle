#!/usr/bin/env ruby

require 'json'

total_games = Dir.glob("games/*.json").count

words = Dir.glob("games/*.json").collect { |f| JSON.parse(File.read(f))["found_words"] }.flatten
total_words = words.count

plays = Dir.glob("games/*.json").collect { |f| JSON.parse(File.read(f))["plays"] }.flatten; nil
total_players = plays.collect { |p| p["player"] }.uniq.count


puts "TOTAL GAMES:\t#{total_games}"
puts "TOTAL WORDS:\t#{total_words}"
puts "TOTAL PLAYERS:\t#{total_players}"
