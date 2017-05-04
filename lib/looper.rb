# Wait and execute methods
module Looper
  def run(interval: 5, times: 2)
    counter = 0
    loop do
      counter += 1
      yield
      sleep interval
      break if counter >= times
    end
  end

  def time_out(interval: 5, times: 10)
    begin
      Timeout.timeout(interval * times) do
        while(true) do
          sleep interval
          yield
        end
      end
    rescue Timeout::Error
      p "Stopping the loop since reached timeout period."
    end
  end

  module_function :run
  module_function :time_out
end
