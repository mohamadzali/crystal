lib LibReadline("readline")
  fun readline(prompt : Char*) : Char*
  fun add_history(line : Char*)
end

module Readline
  def self.readline(prompt, add_history = false)
    line = LibReadline.readline(prompt)
    if line
      LibReadline.add_history(line) if add_history
      String.new(line)
    else
      nil
    end
  end
end
