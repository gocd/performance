require './lib/looper'

describe Looper do
  it 'runs every 1 seconds for 2 times' do
   counter = 0
   Looper::run(interval:1, times:2) { counter = counter + 1 }
   expect(counter).to eq(2)
   end
end
