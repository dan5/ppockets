# -*- encoding: utf-8 -*-
require './ppockets-core.rb'
require 'haml'
require 'sinatra'
require 'sinatra_more/markup_plugin'
Sinatra::Base.register SinatraMore::MarkupPlugin

helpers do
end

get '/players/:id' do
  haml :players_show
end

get '/players' do
  haml :players
end

get '/leagues/:id' do
  haml :leagues_show
end

get '/games/:id' do
  haml :games_show
end

get '/' do
  haml :index
end

__END__

@@ layout
%html
  %h1.title
    ppockets
  .menus
    = link_to 'home', "/"
    = link_to 'players', "/players"
  = yield


@@ players_show
- player = Player.find(params[:id])
- games = Game.filter('home_player_id = ? OR away_player_id = ?', player.id, player.id)
- next_games = games.filter(:played? => false)
- recent_games = games.filter(:played? => true).order(:id.desc).limit(5)
%h2= h player.name
%p.todo @todo: 成績表示
= h player.values
%h2 今後の試合
%ul
  - next_games.each do |game|
    %li
      - str = "vs #{game.opponent(player).name}"
      = link_to h(str), "/games/#{game.id}"
%h2 最近の試合
%ul
  - recent_games.all.reverse.each do |game|
    - card_logs = game.card_logs_dataset.filter(:player_id => player.id)
    %li
      - str = "vs #{game.opponent(player).name}"
      = link_to h(str), "/games/#{game.id}"
      = h '... 0 - 0'
      = h card_logs.map {|e| "[#{e.name}]" }.join
%h2 cards
%p.todo @todo: ログインしていないと見えない
%ul
  - player.cards.each do |card|
    %li
      - str = "#{card.name} #{card.agi}/#{card.off}/#{card.def}/#{card.life}"
      = h str


@@ players
%h2 players
%ul
  - Player.each do |player|
    %li
      = link_to player.name, "/players/#{player.id}"


@@ leagues_show
= h League.find(params[:id]).values


@@ games_show
= h Game.find(params[:id]).values


@@ index
%h2 エントリ受付中のリーグ
%ul
  - WaitingLeague.each do |league|
    %li
      = h league.id
      = "(#{league.players_count})"
%h2 開催中のリーグ
%ul
  - OpenedLeague.each do |league|
    %li
      = link_to league.id, "/leagues/#{league.id}"
      = h league.players_count
%h2 過去のリーグ
%ul
  - ClosedLeague.each do |league|
    %li
      = h league.id
      = h league.players_count
