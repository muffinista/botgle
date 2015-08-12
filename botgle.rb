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

GAME_REMINDER_TIME = 60 * 60 * 2
ADMIN_USERS = ["muffinista"]


use_streaming true

followed do |user|
  follow user
end

home_timeline do |tweet|
  $mutex.synchronize {
    STDERR.puts tweet.text
    next if tweet.text !~ /^@botgle/i || ! @manager.active?

    STDERR.puts "PLAY #{Time.now}\t#{tweet.user.screen_name}\t#{tweet.text}"
    
    target = tweet.user.screen_name

    @manager.record_user(tweet.user.id, tweet.user.screen_name)

    words = []

    tries = tweet.text.gsub(/@botgle/, "").gsub(/[\s,]+/m, ' ').strip.split(" ")
    g = @manager.game
    prior_count = g.plays.count

    g.play_words(tweet.user.id, tries) do |words, score|
      if ! words.empty?
        favorite tweet
    
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
  STDERR.puts "well, here i am #{tweet.sender.screen_name}: #{tweet.text}"
  STDERR.puts tweet.inspect
  $mutex.synchronize {
    #
    # command interface for admin users only
    #
    if ADMIN_USERS.include? tweet.sender.screen_name
      if tweet.text =~ /NEW GAME/
        @manager.trigger_new_game
        direct_message "got it #{Time.now.to_i}", tweet.sender
      end

      if tweet.text =~ /LEADERBOARD/
        s = @manager.season
        data = s.leaderboard
        @manager.pretty_leaderboard(data, "Season Point Totals:").each { |t|
          tweet t
        }
      
        data = s.game_winners
        @manager.pretty_leaderboard(data, "Season Victories").each { |t|
          tweet t
        }
      end

      if tweet.text =~ /NEW SEASON/
        @manager.start_new_season
        tweet "A new season begins.... now! #{flair}#{flair}#{flair}"
      end
    end
    
    if tweet.text =~ /^NOTIFY/i
      @manager.set_user_notify(tweet.sender, true)
      direct_message "OK, I'll let you know when a game is coming up! #{flair}"
    elsif tweet.text =~ /^WARN/i
      @manager.set_user_notify(tweet.sender, true, 1)
      direct_message "OK, I'll let you know one minute before games start! #{flair}"
    elsif tweet.text =~ /^STOP/i
      @manager.set_user_notify(tweet.sender, false)
      direct_message "OK, I'll stop annoying you about Botgle games #{flair}"
    end
  }
end


def tweet_state(type)
  if type == "active"
    g = @manager.game

    base = ["THE BOARD:",
            "Boggle Summons You:",
            "TIME FOR BOGGLE:",
            "The mist clears. Time for Boggle:",
            "You see a Boggle board in the distance:",
            "You awaken from a dream of eldritch horrors to find a game before you:",
            "The only thing blocking you from total victory is this Boggle board:",
            "B-O-G-G-L-E",
            "Above you a skywriter dances the path of a Boggle board",
            "Your dreams are haunted by visions of Boggle"
           ].sample

    output = [
      "#{base}\n\n",     
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


    diff = @manager.next_game_at.to_i - Time.now.to_i
    tweet "Next game in #{(diff.to_f / 60 / 60).round.to_i} hours! #{flair}"
  end
end

def flair
  Manager::FLAIR.sample
end



def run_bot
  @game_state_tweet_at = Time.now.to_i

  STDERR.puts "run bot!"
  timer_thread = Thread.new {
    while(true) do
      begin
        $mutex.synchronize {
          
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

          if @manager.state == "lobby"
            ten_minutes_before = @manager.next_game_at.to_i - (60*10)
            one_minute_before = @manager.next_game_at.to_i - 60
            
            if @manager.heads_up_issued == false && Time.now.to_i >= ten_minutes_before 
              @manager.heads_up_issued = true
              tweet "Hey there! Boggle in 10 minutes! #{flair}"
              @manager.notifications.each { |n|
                begin
                  msg = [
                    "Hey! There's a new game of botgle in 10 minutes!",
                    "Botgle in 10 minutes!",
                    "BEWARE: Botgle starts in 10 minutes!",
                    "**WARNING** a game of botgle is just 10 minutes away!"
                  ].sample
                  direct_message "#{msg} #{flair}", n
                rescue StandardException => e
                  STDERR.puts e
                end
              }
            end
            
            if @manager.one_minute_warning_issued == false && Time.now.to_i >= one_minute_before 
              @manager.one_minute_warning_issued = true
              @manager.one_minute_warnings.each { |n|
                begin
                  msg = [
                    "EMERGENCY!!! Boggle in ONE MINUTE",
                    "Hey! Boggle starts in a minute!",
                    "BEWARE: Botgle starts in one minute!",
                    "**WARNING** a game of botgle is just ONE minute away!"
                  ].sample
                  direct_message "#{msg} #{flair} #{flair}", n
                rescue StandardException => e
                  STDERR.puts e
                end
              }
            end

          elsif @manager.state == "active"
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
        }
        
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

