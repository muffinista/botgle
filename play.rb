class Play
  attr_accessor :player
  attr_accessor :word

  def initialize(player, word)
    @player = player
    @word = word
  end

  def score
    case word.size
    when 0,1,2 then 0
    when 3,4 then 1
    when 5 then 2
    when 6 then 3
    when 7 then 5
    else 11
    end
  end  
end
