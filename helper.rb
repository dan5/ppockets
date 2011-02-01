class Object
  def dump_method_name()
    current_method = caller.first.scan(/`(.*)'/).flatten.first
    puts "--- #{current_method} ---"
  end
end

def assert(boolean, message = nil)
  raise message if boolean
end

#class Array; def sample() self[rand(size)] end end
