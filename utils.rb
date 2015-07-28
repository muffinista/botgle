# coding: utf-8
class String
  def to_full_width
    offset = 65248
    self.each_byte.collect { |x|
      if x == 10
        "\n"
      else
        [x == 32 ? 12288 : (x + offset)].pack("U").freeze
      end
    }.join("")
  end

  def pretty_split(len=140)
    output = []
    line = ""
    self.split(/\n/).each { |x|
      if ( (line + "\n" + x).size > 140 )
        output << line.dup
        line = ""
      end
      line << x << "\n"
    }
    output << line.dup
    output
  end
end

class Time
  def beginning_of_next_hour
    now = self
    now = now - (now.min) * 60
    now = now - (now.sec)
    now + 3600
  end
end
