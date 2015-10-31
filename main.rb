require 'rubygems'
require 'sinatra'
require 'pry'


use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'end_of_world' 


get '/shitballs' do
  erb :"/my_templates/nested"
end

post '/myaction' do
  puts params['username']
end






