# -*- encoding: utf-8 -*-
require './ppockets-core.rb'
require 'haml'
require 'sinatra'
require 'sinatra_more/markup_plugin'
Sinatra::Base.register SinatraMore::MarkupPlugin
#require 'haml/template'
#Haml::Template.options[:escape_html] = true

enable :sessions

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

get '/leagues' do
  haml :leagues
end

get '/games/:id' do
  haml :games_show
end

get '/' do
  @player = player()
  session[:sid] = 'hello'
  haml :home
end

get '/cmd/off_up' do
  player().off_up
  redirect '/'
end

get '/cmd/swap/:a/:b' do
  player().swap_cards params[:a].to_i, params[:b].to_i
  #player.cards_dataset.map(:position).inspect
  redirect '/'
end

def player
  Player.find(:id => 1) # @todo
end

def plus_param(card, meth)
  param = card.__send__(meth)
  param == 0 ? '' : "+#{param}"
end

__END__

@@ home
- games = Game.filter('home_player_id = ? OR away_player_id = ?', @player.id, @player.id)
- next_games = games.filter(:played? => false)
%h2 CARDS
%table
  %tr
    %th name
    %th{:colspan=>2} off
    %th{:colspan=>2} def
    %th agi
    %th life
    %th{:colspan=>4} swap
  - @player.cards_.each do |card|
    - i = card.position
    %tr
      %td&= card.name
      %td.r&= card.off
      %td.plus&= plus_param(card, :off_plus)
      %td.r&= card.def
      %td.plus&= plus_param(card, :def_plus)
      %td.r&= card.agi
      %td.r&= card.life
      %td
        - unless card.position == @player.cards_.count - 1
          = link_to 'V', "/cmd/swap/#{i}/#{i + 1}"
      %td
        - unless card.position == 0
          = link_to 'A', "/cmd/swap/#{i - 1}/#{i}"
      %td.r&= card.position
%h2 COMMANS
%ul
  %li= link_to 'NEW CARD', "/cmd/new_card"
  %li= link_to 'OFF UP', "/cmd/off_up"
  %li= link_to 'DEF UP', "/cmd/def_up"
%h2 NEXT GAMES
%ul
  - next_games.each do |game|
    %li
      - str = "vs #{game.opponent(@player).name}"
      = link_to h(str), "/games/#{game.id}"


@@ players_show
- player = Player.find(:id => params[:id])
- games = Game.filter('home_player_id = ? OR away_player_id = ?', player.id, player.id)
- next_games = games.filter(:played? => false)
- recent_games = games.filter(:played? => true).order(:id.desc).limit(5)
%h2&= player.name
%p.todo @todo: 成績表示
&= player.values
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
      &= '... 0 - 0'
      &= card_logs.map {|e| "[#{e.name}]" }.join
%h2 cards
%p.todo @todo: ログインしていないと見えない
%ul
  - player.cards.each do |card|
    %li
      - str = "#{card.name} #{card.agi}/#{card.off}/#{card.def}/#{card.life}"
      &= str


@@ players
%h2 players
%table
  %tr
    %td name
    %td grade
    %td win
    %td draw
    %td lose
    %td margin
    %td score
    %td point
  - Player.order(:point.desc).each do |player|
    %tr
      %td= link_to h(player.name), "/players/#{player.id}"
      %td.r&= player.grade
      %td.r&= player.results_dataset.sum(:win_count)
      %td.r&= player.results_dataset.sum(:draw_count)
      %td.r&= player.results_dataset.sum(:lose_count)
      %td.r&= player.results_dataset.sum(:winning_margin)
      %td.r&= player.results_dataset.sum(:score)
      %td.r&= player.point / 10000.0


@@ leagues_show
- league = League.find(:id => params[:id])
- if league.status == 0
  %p.todo @todo: [参加するボタン]
&= league.values


@@ leagues
%h2 エントリ受付中のリーグ
.waiting
  - WaitingLeague.each do |league|
    - str = "league#{league.id}(#{league.players_count})"
    = link_to h(str), "/leagues/#{league.id}"
%h2 開催中のリーグ
.opened
  - OpenedLeague.each do |league|
    - str = "league#{league.id}(#{league.players_count})"
    = link_to h(str), "/leagues/#{league.id}"
%h2 過去のリーグ
.closed
  - ClosedLeague.each do |league|
    - str = "league#{league.id}"
    = link_to h(str), "/leagues/#{league.id}"


@@ games_show
- game = Game.find(:id => params[:id])
- if game.played?
  %p.todo @todo: 試合結果の表示
- else
  %p.todo @todo: まだ試合は行われていません
&= game.values


@@ layout
%html
  %head
    %style
      = '.todo {color: gray}'
      = '.r {text-align: right}'
      = '.plus {color: #666; font-size: 80%; vertical-align: bottom}'
  .menus
    = link_to 'HOME', "/"
    = link_to 'LEAGUES', "/leagues"
    = link_to 'PLAYERS', "/players"
  = yield
  .footer
    %hr
    ppockets
