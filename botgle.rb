#!/usr/bin/env ruby

require 'rubygems'
require 'chatterbot/dsl'

require './manager'

require './utils'

# remove this to update the db
no_update

# remove this to get less output when running
verbose

Thread.abort_on_exception = true

#tweets = client.user_timeline(count:200).collect(&:id)
#client.destroy_status(tweets)
#exit

$mutex = Mutex.new
@sleep_rate = 3
@manager = Manager.new

STDERR.puts "Loaded Game:"
STDERR.puts @manager.inspect


streaming true

followed do |user|
  follow user
end

home_timeline do |tweet|
  $mutex.synchronize {
    STDERR.puts tweet.text
    next if tweet.text !~ /^@botgle/i

    # maybe we'll want to do stuff here


    # don't play words if game isn't active
    next if ! @manager.active?

    favorite tweet
    
    target = tweet.user.screen_name

    @manager.record_user(tweet.user.id, tweet.user.screen_name)

    words = []

    tries = tweet.text.gsub(/@botgle/, "").gsub(/[\s,]+/m, ' ').strip.split(" ")
    g = @manager.game
    prior_count = g.plays.count

    g.play_words(tweet.user.id, tries) do |words, score|
      if ! words.empty?
        result = words.join(" ").upcase
        reply "#USER# plays #{result} #{flair}", tweet

        if prior_count <= 0 && @manager.game.plays.count > 0
          output = [
                    "The timer is started! #{DURATION / 60} minutes to play!",
                    g.board.to_s(g.style).to_full_width,
                    flair
                   ].join("\n")
          
          tweet output
        end
      end
    end
  }
end

direct_messages do |tweet|
  puts "well, here i am #{tweet.text}"
  puts tweet.inspect
  if tweet.text =~ /NEW GAME/
    @manager.trigger_new_game
    direct_message "got it #{Time.now.to_i}", tweet.sender
  end
end


def tweet_state(type)
  if type == "active"
    g = @manager.game

    base = ["THE BOARD:\n\n",
            "Boggle Summons You:\n\n",
            "TIME FOR BOGGLE:\n\n",
            "The mist clears. Time for Boggle\n\n",
            "You see a Boggle board in the distance:\n\n",
            "You awaken from a dream of eldritch horrors to find a game before you:\n\n"
           ].sample

    output = [
      base,
      g.board.to_s(g.style).to_full_width,
      "#{flair} #{flair} #{flair}"
    ].join("\n")

    tweet output

    @game_state_tweet_at = Time.now.to_i
  elsif type == "lobby"
    g = @manager.last_game

    @manager.pretty_scores(g).each { |t|
      tweet t
    }

    # get and tweet winner   

    tweet "Next game in #{Manager::GAME_WAIT_TIME / 60 / 60} hours! #{flair}"
  end
end

def flair
  Manager::FLAIR.sample
end

GAME_REMINDER_TIME = 60 * 60 * 2

def run_bot
  @game_state_tweet_at = Time.now.to_i

  STDERR.puts "run bot!"
  timer_thread = Thread.new {
    while(true) do
      begin

        #
        # output some debugging/tracking info
        #
        if @manager.state == "active"
          STDERR.puts @manager.game.inspect
        else
          STDERR.puts "#{@manager.state} #{Time.now} #{@manager.next_game_at}"
        end       
        
        # NOTE this block is only called if the state of the game has changed
        @manager.tick { |game, state|
          STDERR.puts "Game state changed to #{@manager.state}"

          if state == "active" || state == "lobby"
            tweet_state @manager.state
          end
        }

        if @manager.state == "active"
          if @manager.game.issue_warning?
            @manager.game.warning_issued!
            output = [
              "Warning! Just #{Game::WARNING_TIME / 60} minutes left",
              @manager.game.board.to_s.to_full_width,
              flair,
              ""
            ].join("\n")

            tweet output
          elsif @manager.game.plays.count == 0 &&
                Time.now.to_i - @game_state_tweet_at > GAME_REMINDER_TIME
            tweet_state @manager.state
          end
        end

        sleep @sleep_rate
      rescue StandardError => e
        STDERR.puts "timer thread exception #{e.inspect}"
        raise e
      end
    end
    STDERR.puts "EXITING TIMER"
  }

  streaming_thread = Thread.new {
    bot.stream!
    STDERR.puts "EXITING STREAMING"   
  }

  check_thread = Thread.new {
    while true do
      sleep @sleep_rate + 5
      
      [timer_thread, streaming_thread].each { |t|
        if t.nil? || t.status == nil || t.status == false
          STDERR.puts "Thread #{t} died, let's jet"
          timer_thread && timer_thread.terminate
          streaming_thread && streaming_thread.terminate
          
          Thread.exit
        end
      }    
    end  
    STDERR.puts "EXITING CHECK"   
  }
  
  timer_thread.run
  streaming_thread.run  
  check_thread.join
end


while true do
  begin
    run_bot
  rescue Exception => e
    STDERR.puts e.inspect
  end
  STDERR.puts "oops, something went wrong, restarting in 20"
  sleep 20
end

