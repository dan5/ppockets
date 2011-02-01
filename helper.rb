class Object
  def dump_method_name()
    current_method = caller.first.scan(/`(.*)'/).flatten.first
    puts "--- #{current_method} ---"
  end
end

#class Array; def sample() self[rand(size)] end end
