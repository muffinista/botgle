require './board'
require './trie'
require './solver'
require './play'
require 'oj'

DURATION = 8 * 60
WARNING_TIME = 3 * 60

class Array
  # basically a case-insensitive version of include?
  def has_word?(w)
    any?{ |s| s.casecmp(w) == 0 } 
  end
end

class Game
  attr_reader :board
  attr_reader :plays
  attr_reader :id
  attr_reader :style

  attr_accessor :warning

  
  def initialize(id)
    @id = id
    @board = nil

    if File.exist?(filename)
      load
    end

    if @board.nil?
      @board = Board.new

      trie = Marshal.load(File.read('./words.dict'))
      s = Solver.new(trie)
      s.solve(@board)
      @words = s.words
      @found_words = []
      @time_started_at = Time.now
      @first_play_at = 0
      @plays = []
      @warning = false
      @style = @board.available_styles.sample
    end

    save
  end
  
  def filename
    "games/#{@id}.json"
  end

  def finish!
  end

  def warning_issued!
    @warning = true
    save
  end
  
  def issue_warning?
    @warning == false && time_remaining <= WARNING_TIME
  end
  
  def time_remaining
    # no countdown until someone makes a play
    if @plays.count == 0
      return 1000
    end
    
    elapsed = Time.now.to_i - @first_play_at.to_i
    STDERR.puts "TIME REMAINING #{elapsed} #{DURATION - elapsed}"
    DURATION - elapsed
  end

  def play_words(target, tries)
    words = []
    score = 0

    tries.each { |w|
      STDERR.puts "*** #{w}"
      p = Play.new(target, w)

      if try_play(p)
        @first_play_at = Time.now.to_i if @plays.empty?

        words << w
        score += p.score
      end
    }

    save

    yield(words, score) if block_given?

    [words, score]
  end
  
  def try_play(play)
    STDERR.puts "trying to play #{play.word}"
    test = play.word.upcase
    if @words.has_word?(test) && ! @found_words.has_word?(test)
      @plays << play
      @found_words << play.word

      true
    else
      false
    end
  end

  def scores
    self.plays.
      group_by { |p| p.player }.
      collect { |k, v| [k, v.collect(&:score).inject(:+)]}.
      sort { |x| -x.last }.sort_by { |k, v| -v }.to_h
  end

  def winning_score
    scores[self.scores.keys.first]
  end
  
  def winners
    hi_score = winning_score
    puts "HIGH SCORE #{hi_score}"
    scores.select { |k, v| v >= hi_score }.keys
  end
  
  def load
    STDERR.puts "load #{filename}"
    file = File.read(filename)
    h = Oj.load(file)

    @words = h["words"] || []
    @found_words = h["found_words"] || []
    @board = h["board"] && Board.new(letters:h["board"])
    @plays = h["plays"] || []
    @time_started_at = h["time_started_at"]
    @first_play_at = h["first_play_at"]
    @warning = h["warning"] || false
    @style = h["style"] || @board.available_styles.sample
  end

  def save
    hash = {
      "board" => @board.letters,
      "words" => @words,
      "found_words" => @found_words,
      "time_started_at" => @time_started_at,
      "first_play_at" => @first_play_at,
      "plays" => @plays,
      "warning" => @warning,
      "style" => @style
    }

    File.open(filename, "w") do |f|
      f.write(Oj.dump(hash))
    end
  end

  class << self
    def create_dictionary(src, dest)
      trie = Trie.new
      File.open(src).each_line do |line|
        # idx = line.index " " # get first space
        # if idx.nil? # no definition
        #   word, defn = line, "no definition available"
        # else
        #   word, defn = line[0..idx-1], line[idx+1..line.size]
        # end

        word = line.upcase.chomp
        
#        word.chomp! # case where we had just words on the line
#        puts word
        
        # skip words that are too small for boggle
        if word.size > 2
          trie[word] = word
        end
      end

      dump = Marshal.dump(trie)
      dict_file = File.new(dest, "w")      

#      dict_file = Zlib::GzipWriter.new(dict_file)
      dict_file.write dump
      dict_file.close
    end
  end

end
