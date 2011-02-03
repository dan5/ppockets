# -*- encoding: utf-8 -*-
require './ppockets-core.rb'
require 'haml'
require 'sinatra'
require 'sinatra_more/markup_plugin'
Sinatra::Base.register SinatraMore::MarkupPlugin

helpers do
end

get '/leagues/:id' do
  haml :leagues_show
end

get '/' do
  @players = Player.all
  haml :index
end

__END__

@@ layout
%html
  %h1.title
    ppockets
  .menus
    = link_to 'home', "/"
  = yield


@@ leagues_show
= h League.find(params[:id]).values


@@ index
%ul
  - @players.each do |player|
    %li
      = player.name

%h2
  エントリ待ちのリーグ
%ul
  - WaitingLeague.each do |league|
    %li
      = league.id
      = league.players_count
%h2
  開催中のリーグ
%ul
  - OpenedLeague.each do |league|
    %li
      = link_to league.id, "/leagues/#{league.id}"
      = league.players_count
%h2
  過去のリーグ
%ul
  - ClosedLeague.each do |league|
    %li
      = league.id
      = league.players_count
