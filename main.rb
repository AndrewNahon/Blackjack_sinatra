require 'rubygems'
require 'sinatra'
require 'pry'


use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'end_of_world' 
BLACKJACK = 21

helpers do 

  def create_deck
    suits = ['hearts', 'diamonds', 'clubs', 'spades']
    faces = %w(2 3 4 5 6 7 8 9 10 jack queen king ace)
    session[:deck] = suits.product(faces).shuffle
  end

  def deal
     2.times do
    session[:dealer_hand] << session[:deck].pop 
    session[:player_hand] << session[:deck].pop  
    end
  end
  
  def display_card_image(card)
    return "<img src='/images/cards/#{card[0]}_#{card[1]}.jpg' >"
  end

  def calculate_total(hand)
    card_values = hand.map {|card| card[1]}
    total = 0
    card_values.each do |v|
      if v == 'ace'
        total += 11
      else
        total += v.to_i == 0 ? 10 : v.to_i
      end
    end  
    card_values.select {|v| v == 'ace'}.size.times do
      total -= 10 if total > 21
    end   
    total
  end

  def blackjack?(hand)
    calculate_total(hand) == 21
  end

  def bust?(hand)
    calculate_total(hand) > BLACKJACK
  end 

  def player_turn_over?(hand)
    if bust?(hand) || blackjack?(hand)
      true
    else
      false
    end
  end

  def dealer_turn_over?(dealer_hand)
    if player_turn_over?(dealer_hand) || calculate_total(dealer_hand) >= 17
      true
    else
      false
    end
  end

  def display_end_of_round_message(player_hand, dealer_hand)
    if blackjack?(dealer_hand)
      @error = "Dealer got blackjack. You lose."
    elsif bust?(dealer_hand)
      @success = "Dealer busted at #{calculate_total[dealer_hand]}. You win."
    elsif calculate_total(player_hand) < calculate_total(dealer_hand)
      @error = "Dealer won. You had #{calculate_total(player_hand)} and dealer had #{calculate_total(dealer_hand)}"
    elsif calculate_total(player_hand) == calculate_total(dealer_hand)
      @success = "It's a tie."
    else
      @success = "You won. You had #{calculate_total(player_hand)} and dealer had #{calculate_total(dealer_hand)}"
    end      
  end

  def did_player_win?(player_hand, dealer_hand)
    if blackjack?(player_hand)  
      true
    elsif calculate_total(player_hand) > calculate_total(dealer_hand) && !bust?(player_hand)
      true
    else
      false
    end
  end
end

before do
  @display_hit_stay_buttons = true
end

get '/' do
  if !params[:username]
    redirect "/new_game"
  end
  redirect "/bet"
end

get '/new_game' do
  erb :new_game
end

post '/new_game' do
  if params[:username].empty?
    @error = "You must enter a name."
    halt erb :new_game
  end
  session[:username] = params[:username]
  session[:player_amount] = 1000
  session[:player_hand] = []
  session[:dealer_hand] = []
  create_deck
  deal
  redirect "/bet"
end

get "/bet" do
  erb :bet
end

post '/bet' do
  if params[:bet_amount].to_i > session[:player_amount]
    @error = "Max bet is $#{session[:player_amount]} "
    halt erb :bet
  end
  session[:player_hand] = []
  session[:dealer_hand] = []
  create_deck
  deal
  session[:bet_amount] = params[:bet_amount].to_i
  session[:turn] = 'player'
  session[:won_hand] = false
  redirect "/game"
end

get '/game' do
  if session[:turn] == 'player'
    if player_turn_over?(session[:player_hand])
      @display_hit_stay_buttons = false
      bust?(session[:player_hand]) ? @error = "You busted at #{calculate_total(session[:player_hand])}" : @success = "You hit blackjack."
    end
  elsif session[:turn] = 'dealer'
    @show_dealer_hit_button = true
    @display_hit_stay_buttons = false
    if dealer_turn_over?(session[:dealer_hand])
      @show_dealer_hit_button = false
      display_end_of_round_message(session[:player_hand], session[:dealer_hand])
    end
  end  
  erb :game
end

post "/game/hit" do
  session[:player_hand] << session[:deck].pop
  redirect "/game"
end

post "/game/stay" do  
  session[:turn] = 'dealer'
  redirect "/game"
end

post "/game/dealer_hit" do
  session[:dealer_hand] << session[:deck].pop
  redirect "/game"
end

post '/game/play_again' do
  if did_player_win?(session[:player_hand], session[:dealer_hand])
    session[:player_amount] += session[:bet_amount].to_i
  elsif !did_player_win?(session[:player_hand], session[:dealer_hand])
    session[:player_amount] -= session[:bet_amount].to_i
  end

  if session[:player_amount] == 0
    redirect 'game/over'
  end
  redirect "/bet"
end

post '/game/quit' do
  if did_player_win?(session[:player_hand], session[:dealer_hand])
    session[:player_amount] += session[:bet_amount].to_i
  elsif !did_player_win?(session[:player_hand], session[:dealer_hand])
    session[:player_amount] -= session[:bet_amount].to_i
  end

  if session[:player_amount] == 0
    redirect 'game/over'
  end
  redirect '/game/quit'
end

get '/game/quit' do
  erb :quit
end

get '/game/over' do
  erb :game_over
end