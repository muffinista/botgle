require 'oj'
require './game'
require './season'
require './utils'

require 'twitter-text'

class Manager
  GAME_HOURS = [2, 8, 14, 20]
  
  FLAIR = [
    Twitter::Unicode::U1F3C6,
    Twitter::Unicode::U1F4AF,
    Twitter::Unicode::U1F386,
    Twitter::Unicode::U1F387,
    Twitter::Unicode::U1F638,
    Twitter::Unicode::U1F38A,
    Twitter::Unicode::U1F48E,
    Twitter::Unicode::U1F380,
    Twitter::Unicode::U1F525,
    Twitter::Unicode::U2728,
    Twitter::Unicode::U1F4A5,
    Twitter::Unicode::U1F31F,
    Twitter::Unicode::U1F4AB,
    Twitter::Unicode::U1F680,
    Twitter::Unicode::U2668,
    Twitter::Unicode::U1F40C,
    Twitter::Unicode::U1F409,
    Twitter::Unicode::U1F432,
    Twitter::Unicode::U2600,
    Twitter::Unicode::U1F308,
    Twitter::Unicode::U1F38A,
    Twitter::Unicode::U1F47E,
    Twitter::Unicode::U1F3B6
  ]

  
  attr_accessor :game
  attr_reader :state
  attr_reader :season
  attr_reader :users
  attr_reader :next_game_at
  attr_reader :notifications
  attr_reader :one_minute_warnings
  
  attr_accessor :heads_up_issued
  attr_accessor :one_minute_warning_issued

  def initialize
    @state = "lobby"
    @next_game_at = Time.now
    @game_id = nil
    @season_id = nil

    @users = {}
    @notifications = []
    @one_minute_warnings = []
    
    @mutex = Mutex.new

    @heads_up_issued = false
    @one_minute_warning_issued = false

    if File.exist?("manager.json")
      load
    end

    if File.exist?("users.json")
      load_users
    end
  end

  def last_game
    Game.new(@game_id)
  end
  
  def load_users(src="users.json")
    @mutex.synchronize {
      file = File.read(src)
      @users = Oj.load(file)
    }
  end
  
  def record_user(id, screen_name)
    @users[id] = screen_name

    @mutex.synchronize {
      File.open("users.json", "w") do |f|
        f.write(Oj.dump(@users))
      end
    }

    @users
  end

  def set_user_notify(user, notify=true, _when=10)
    if notify == true
      if _when == 10
        @notifications << user.id unless @notifications.include?(user.id)
      else
        @one_minute_warnings << user.id unless @one_minute_warnings.include?(user.id)
      end        
    else
      @notifications.delete(user.id)
      @one_minute_warnings.delete(user.id)
    end

    save
  end
  
  def finish_current_game
    puts "finishing the current game"
    @state = "lobby"
    @game.finish!
    @game = nil
    
    if @new_game_request == true
      @next_game_at = Time.now
    else
      @next_game_at = next_game_should_be_at
      @heads_up_issued = false
      @one_minute_warning_issued = false
    end

    save
  end

  def next_game_should_be_at
    t = Time.now.beginning_of_next_hour
    while !GAME_HOURS.include?(t.hour)
      t = t + (3600)
    end

    t
  end

  def trigger_new_game
    @new_game_request = true
  end
  
  def start_new_game
    @new_game_request = false
    if active?
      finish_current_game
    end

    @state = "active"
    @game_id = @game_id.to_i + 1
    @game = Game.new(@game_id)

    if @season.nil?
      start_new_season
    end
    
    @season.add_game(@game)
    
    save
  end

  def start_new_season
    @season_id = @season_id.to_i + 1
    @season = Season.new(@season_id)

    save
  end
  
  def active?
    @state == "active"
  end

  def need_to_finish?
    @new_game_request || (active? && @game.time_remaining <= 0)
  end

  def need_to_start?
    #STDERR.puts "#{!active?} && #{Time.now.to_i} <= #{@next_game_at.to_i} #{Time.now.to_i <= @next_game_at.to_i}"
    @new_game_request || (!active? && Time.now.to_i >= @next_game_at.to_i)
  end


  # take the scores for this game and turn them into a nicely
  # formatted text, split across a couple tweets
  # note: could run the same code for a season
  def pretty_scores(game)
    prefix = "GAME OVER! SCORES:"
    guts = game.scores.collect { |id, points|
      name = @users[id] || id
      word = points.to_i > 1 ? "points" : "point"
      "@#{name}: #{points} #{FLAIR.sample}"
    }.join("\n")

    "#{prefix}\n#{guts}".pretty_split
  end

  def pretty_leaderboard(data, prefix="GAME OVER! SCORES:", limit=5, type="point")
    guts = data.collect { |id, points|
      name = @users[id] || id
      word = points.to_i > 1 ? "#{type}s" : type
      "@#{name}: #{points} #{FLAIR.sample}"
    }.first(limit).join("\n")

    "#{prefix}\n#{guts}".pretty_split
  end
  
  
  def tick
    do_yield = false
    if active?
      if need_to_finish?
        do_yield = true
        finish_current_game
      end
    end

    if need_to_start?
      do_yield = true
      start_new_game
    end

    if do_yield && block_given?
      yield @game, @state
    end

    @state
  end
  
  
  def load(filename="manager.json")
    file = File.read(filename)
    h = Oj.load(file)

    @state = h["state"]
    @next_game_at = h["next_game_at"]
    @game_id = h["game_id"]
    @season_id = h["season_id"]
    @notifications = h["notifications"] || []
    @one_minute_warnings = h["one_minute_warnings"] || []
    
    
    if @game_id.to_i > 0 && @state == "active"
      @game = Game.new(@game_id)
    end
    if @season_id.to_i > 0
      @season = Season.new(@season_id)
    end
  end

  def save(filename="manager.json")
    hash = {
      "state" => @state,
      "next_game_at" => @next_game_at,
      "game_id" => @game_id,
      "season_id" => @season_id,
      "notifications" => @notifications,
      "one_minute_warnings" => @one_minute_warnings
    }
    
    File.open(filename, "w") do |f|
      f.write(Oj.dump(hash))
    end
  end
end
