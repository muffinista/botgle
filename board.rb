
#
# https://github.com/scheibo/boggle/blob/master/lib/boggle/board.rb
#
class Board
  attr_reader :size
  attr_reader :letters

  def initialize(opts = {})
    opts = {dictionary:"words.dict", variant:0, size:4}.merge(opts)

    @size = opts[:size]

    if opts[:letters]
      @letters = opts[:letters]
    else   
      @letters = Board.distributions(@size, opts[:variant]).sort_by{ rand }.map { |d| d.sample }
    end
    
    @board = []
    tmp = @letters.dup
    @size.times do
      @board << tmp.pop(@size)
    end
  end

  def [](row, col)
    ( (row < 0) || (col < 0) || (row >= @size) || (col >= @size) ) ? nil : @board[row][col]
  end

  # deepcopy first
  def []=(row, col, val)
    @board[row][col]=val
  end

  def deepcopy
    Marshal.load( Marshal.dump(self) )
  end

  def self.distributions( size, variant ) # 4,0 gives standard distrubtion

    distros = [[
      # http://everything2.com/title/Boggle
      %w{
        ASPFFK NUIHMQ OBJOAB LNHNRZ
        AHSPCO RYVDEL IOTMUC LREIXD
        TERWHV TSTIYD WNGEEH ERTTYL
        OWTOAT AEANEG EIUNES TOESSI
      },

      # http://www.boardgamegeek.com/thread/300565/review-from-a-boggle-veteran-and-beware-differen
      %w{
        AAEEGN ELRTTY AOOTTW ABBJOO
        EHRTVW CIMOTV DISTTY EIOSST
        DELRVY ACHOPS HIMNQU EEINSU
        EEGHNW AFFKPS HLNNRZ DEILRX
      },

      %w{
        AACIOT AHMORS EGKLUY ABILTY
        ACDEMP EGINTV GILRUW ELPSTU
        DENOSW ACELRS ABJMOQ EEFHIY
        EHINPS DKNOTU ADENVZ BIFORX
      }
    ],[

      # http://boardgamegeek.com/thread/300883/letter-distribution
      %w{
        aaafrs aaeeee aafirs adennn aeeeem
        aeegmu aegmnn afirsy bjkqxz ccenst
        ceiilt ceilpt ceipst ddhnot dhhlor
        dhlnor dhlnor eiiitt emottt ensssu
        fiprsy gorrvw iprrry nootuw ooottu
      }.map(&:upcase),

      %w{
        AAAFRS	AAEEEE	AAFIRS	ADENNN	AEEEEM
        AEEGMU	AEGMNN	AFIRSY	BJKQXZ	CCNSTW
        CEIILT	CEILPT	CEIPST	DHHNOT	DHHLOR
        DHLNOR	DDLNOR	EIIITT	EMOTTT	ENSSSU
        FIPRSY	GORRVW	HIPRRY	NOOTUW	OOOTTU
      }
    ]]

    min_size = 4

    distros[size-min_size].map { |dist|
      dist.map { |die|
        die.split(//).map { |letter|
          # our distrubutions return Qu, not Q's
          letter == 'Q' ? 'Qu' : letter
        }
      }
    }[variant]
  end

  def available_styles
    letters.include?("Qu") ? ["wide"] : ["wide", "compact"]
  end
  
  def to_s(style = "wide")
    s = ""
    @size.times do |row|
      @size.times do |col|
        l = @board[row][col]
        if style == "wide"
          (l == "Qu") ? s << " #{l}" : s << " #{l} "
        else
          s << "#{l} "
        end
      end
      s << "\n"
    end
    s
  end
end
