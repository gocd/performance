module Looper
  def run(interval:5, times:2)
    counter = 0
    loop do
      counter = counter + 1
      yield
      sleep interval
      break if counter >= times
    end
  end

  module_function :run
end
