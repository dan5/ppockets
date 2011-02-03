require './ppockets-core.rb'
require 'sinatra'
require 'haml'

get '/' do
  'Hello world!'
  Player.all.inspect
end
