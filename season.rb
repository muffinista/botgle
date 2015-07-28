require 'oj'

class Season
  def initialize(id)
    @id = id
    if File.exist?(filename)
      load
    end

    @scores = {} if @scores.nil?
    @games = [] if @games.nil?
    @time_started_at ||= Time.now
    
    save
  end
  
  def filename
    "seasons/#{@id}.json"
  end

  def finish!
  end

  def leaderboard
    result = {}
    @games.each { |id|
      g = Game.new(id)
      g.scores.each { |p, v|
        result[p] ||= 0
        result[p] += v
      }
    }
    result.sort_by { |k, v| -v }.to_h
  end

  def game_winners
    result = {}
    @games.each { |id|
      g = Game.new(id)
      value = 1.0 / g.winners.count
      g.winners.each { |p|
        result[p] ||= 0
        result[p] += value
        result[p] = result[p].round(2)
      }
    }
    result.sort_by { |k, v| -v }.to_h
  end
  
  def add_game(g)
    @games << g.id
    save
  end
  
  def load
    STDERR.puts "load #{filename}"
    file = File.read(filename)
    h = Oj.load(file)

    @scores = h["scores"] || {}
    @games = h["games"] || []
    @time_started_at = h["time_started_at"]
  end

  def save
    hash = {
      "scores" => @scores,
      "games" => @games,
      "time_started_at" => @time_started_at
    }

    File.open(filename, "w") do |f|
      f.write(Oj.dump(hash))
    end
  end
end
