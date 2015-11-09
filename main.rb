require 'rubygems'
require 'sinatra'
require 'pry'


use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'end_of_world' 
BLACKJACK = 21
PLAYER_AMOUNT = 1000

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
    "<img src='/images/cards/#{card[0]}_#{card[1]}.jpg'>"
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
      total -= 10 if total > BLACKJACK
    end   
    total
  end

  def blackjack?(hand)
    calculate_total(hand) == BLACKJACK
  end

  def bust?(hand)
    calculate_total(hand) > BLACKJACK
  end 

  def player_turn_over?(hand)
    bust?(hand) || blackjack?(hand)
  end

  def dealer_turn_over?(dealer_hand)
    player_turn_over?(dealer_hand) || calculate_total(dealer_hand) >= 17
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
    blackjack?(player_hand) || ((calculate_total(player_hand) > calculate_total(dealer_hand)) && !bust?(player_hand))
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
  session[:player_amount] = PLAYER_AMOUNT
  redirect "/bet"
end

get "/bet" do
  erb :bet
end

post '/bet' do
  if params[:bet_amount].to_i > session[:player_amount] 
    @error = "Max bet is $#{session[:player_amount]} "
    halt erb :bet
  elsif params[:bet_amount].to_i < 1
    @error = "You must bet a positive amount."
    halt erb :bet
  end

  session[:player_hand] = []
  session[:dealer_hand] = []
  session[:turn] = 'player'
  create_deck
  deal
  session[:bet_amount] = params[:bet_amount].to_i
  session[:won_hand] = false
  redirect "/game/player"
end

get '/game/player' do
  if player_turn_over?(session[:player_hand])
      @display_hit_stay_buttons = false
      bust?(session[:player_hand]) ? @error = "You busted at #{calculate_total(session[:player_hand])}" : @success = "You hit blackjack."
  end
  erb :game
end

post "/game/hit" do
  session[:player_hand] << session[:deck].pop
  redirect "/game/player/hit"
end

get "/game/player/hit" do
  if player_turn_over?(session[:player_hand])
      @display_hit_stay_buttons = false
      bust?(session[:player_hand]) ? @error = "You busted at #{calculate_total(session[:player_hand])}" : @success = "You hit blackjack."
  end
  erb :game, layout: false
end

post "/game/stay" do  
  session[:turn] = 'dealer'
  redirect "/game/dealer"
end

get "/game/dealer" do
  @show_dealer_hit_button = true
  @display_hit_stay_buttons = false
  if dealer_turn_over?(session[:dealer_hand])
      @show_dealer_hit_button = false
      display_end_of_round_message(session[:player_hand], session[:dealer_hand])
  end
  erb :game, layout: false
end

post "/game/dealer_hit" do
  session[:dealer_hand] << session[:deck].pop
  session[:turn] = 'dealer'
  redirect "/game/dealer"
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