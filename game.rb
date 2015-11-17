require './board'
require './trie'
require './solver'
require './play'
require 'oj'

require 'aws-sdk'

DURATION = 8 * 60
WARNING_TIME = 3 * 60
MIN_WORDS_ON_BOARD = 65

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
      @board, @words = generate_decent_board

      @found_words = []
      @time_started_at = Time.now
      @plays = []
      @warning = false
      @style = @board.available_styles.sample
    end

    save
  end

  def generate_decent_board
    b = nil
    w = nil
    count = 0

    target = if rand > 0.7
               MIN_WORDS_ON_BOARD * 1.35
             else
               MIN_WORDS_ON_BOARD      
             end

    #size = rand > 0.8 ? 5 : 4
    size = 4

    while count < target
      STDERR.puts "Generating new board"
      b = Board.new(size: size)
    
      trie = Marshal.load(File.read('./words.dict'))
      s = Solver.new(trie)
      s.solve(b)
      w = s.words

      count = w.count
      STDERR.puts "board has #{count} words"
    end

    return b, w
  end
  
  def filename
    "games/#{@id}.json"
  end

  def finish!
    begin
      to_s3
    rescue
      nil
    end
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
    
    elapsed = Time.now.to_i - @plays.first.played_at.to_i
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
        @plays << p
        @found_words << p.word

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
    @warning = h["warning"] || false
    @style = h["style"] || @board.available_styles.sample
  end

  def to_h
    {
      "board" => @board.letters,
      "words" => @words,
      "found_words" => @found_words,
      "time_started_at" => @time_started_at,
      "plays" => @plays,
      "warning" => @warning,
      "style" => @style
    }
  end
  
  def save
    File.open(filename, "w") do |f|
      f.write(Oj.dump(to_h))
    end
  end

  def to_s3
    s3 = Aws::S3::Resource.new(region:'us-east-1')
    bucket = s3.bucket('botgle')
    
    object = bucket.object(filename)
    object.put(body: Oj.dump(to_h), acl:'public-read')
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
