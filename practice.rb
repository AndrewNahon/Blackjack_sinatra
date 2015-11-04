require 'pry'
def square_amount(square)
  2 ** (square - 1)
end

def total(square)
  square_amount(square) - 1
end

puts square_amount(3)