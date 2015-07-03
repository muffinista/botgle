require 'algorithms'

class Trie < Containers::Trie

  # returns either nil if there is nothing along that path, true
  # if that path exists in the tree and the word itself if it is an endpoint

  def match(string)
    string = string.to_s
    return nil if string.empty?
    match_recursive(@root, string, 0)
  end

  def match_recursive(node, string, index)
    return nil if node.nil?

    char = string[index]

    if (char < node.char)
      match_recursive(node.left, string, index)
    elsif (char > node.char)
      match_recursive(node.right, string, index)
    else
      return nil if node.nil?
      if index == (string.length - 1)
        if node.last?
          return node.value
        else
          return true
        end
      end
      match_recursive(node.mid, string, index+1)
    end
  end

end
