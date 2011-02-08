# -*- encoding: utf-8 -*-
require './ppockets-core.rb'
require 'haml'
require 'sinatra'
require 'sinatra_more/markup_plugin'
Sinatra::Base.register SinatraMore::MarkupPlugin
#require 'haml/template'
#Haml::Template.options[:escape_html] = true

enable :sessions

before do
  @player = Player.find(:id => 1) # @todo: from login session
end

get '/new_card' do
  if @player.new_cards.count == 0
    redirect '/'
  else
    haml :new_card
  end
end

get '/players/:id' do
  @player = Player.find(:id => params[:id])
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
  @debug_log = session[:debug_log]
  @notice = session[:notice]
  session[:debug_log] = nil
  session[:notice] = nil
  haml :home
end

# -- cmd API -----------
get '/cmd/new_card' do
  @player.run_cmd :draw_new_card
  session[:notice] = 'created a new card.'
  redirect '/new_card'
end

get '/cmd/off_up' do
  @player.run_cmd :off_up
  session[:notice] = '攻撃強化コマンドを実行しました'
  redirect '/'
end

get '/cmd/def_up' do
  @player.run_cmd :def_up
  session[:notice] = 'ディフェンス強化コマンドを実行しました'
  redirect '/'
end

get '/cmd/put_new_card/:id' do
  card = @player.run_cmd :put_new_card, params[:id]
  session[:notice] = "#{card.name}をポケットに入れました"
  redirect '/'
end

get '/cmd/swap/:a/:b' do
  @player.swap_cards params[:a].to_i, params[:b].to_i
  session[:notice] = "swap cards(#{params[:a]}, #{params[:b]})"
  redirect '/'
end

get '/dcmd/run_core' do
  if @player.game_master?
    run_core 
    session[:debug_log] = 'run core'
  end
  redirect '/'
end

def plus_param(card, meth)
  param = card.__send__(meth)
  param == 0 ? '' : "+#{param}"
end

__END__

@@ home
- games = Game.filter('home_player_id = ? OR away_player_id = ?', @player.id, @player.id)
.message
  %ul
    - if @player.new_cards.count > 0
      %li
        = link_to h("#{@player.new_cards.count}枚の new card があります"), '/new_card'
%h2 CARDS
%table.cards
  %tr
    %th idx
    %th name
    %th agi
    %th{:colspan=>2} off
    %th{:colspan=>2} def
    %th life
    %th{:colspan=>2} swap
  - @player.cards_.each do |card|
    - i = card.position
    %tr
      %td.c&= card.position + 1
      %td&= card.name
      %td.c.agi&= card.agi_org
      %td.r&= card.off_org
      %td.plus&= plus_param(card, :off_plus)
      %td.r&= card.def_org
      %td.plus&= plus_param(card, :def_plus)
      %td.c&= card.life
      %td
        - unless card.position == @player.cards_.count - 1
          = link_to 'V', "/cmd/swap/#{i}/#{i + 1}"
      %td
        - unless card.position == 0
          = link_to 'A', "/cmd/swap/#{i - 1}/#{i}"
%h2 COMMANS
- if @player.num_commands > 0
  .memo memo: リーグにエントリしたとき、または試合を行ったあと、次のコマンドを実行できます
  %ul
    %li
      = link_to 'NEW CARD', "/cmd/new_card"
      %span.memo&= '... 新しいカードを1枚引きます'
    %li
      = link_to 'OFF UP', "/cmd/off_up"
      %span.memo&= '... 攻撃強化を図ります。結果はランダムです'
    %li
      = link_to 'DEF UP', "/cmd/def_up"
      %span.memo&= '... 攻撃強化を図ります。結果はランダムです'
- else
  .memo memo: コマンドは実行済みです
%h2 STATUS
%ul
  %li= link_to "#{h(@player.name)}の公開情報", "/players/#{@player.id}"
  %li
    - if league = @player.leagues_dataset.filter('status < 2').order(:id.desc).first
      - str = "league#{league.id}"
      = link_to h(str), "/leagues/#{league.id}"
      に参加しています
      %ul
        - @player.next_games_.each do |game|
          %li
            - str = "vs #{game.opponent(@player).name}"
            = link_to h(str), "/games/#{game.id}"
            &= '... '
            &= "#{game.turn_count}試合目"
    - else
      リーグには参加していません


@@ new_card
%h2 NEW CARD
- new_card = @player.new_cards_dataset.first
.new_card
  &= new_card.name
%img{:src=>"http://d.hatena.ne.jp/images/diary/k/ken106/2008-06-16.jpg"}
<!-- %img{:src=>"http://image.blog.livedoor.jp/aoicafe/imgs/4/a/4a87eb92.jpg"} -->
.commands
  %ul
    - if @player.cards_.count < Max_cards
      %li= link_to h('ポケットに入れる'), "./cmd/put_new_card/#{new_card.id}"
    - else
      %li= h('ポケットに入れる')
    %li= link_to h('売る'), './'


@@ players_show
%h2&= @player.name
%ul
  %li
    grade:
    &= @player.grade
  %li
    wins:
    &= @player.results_dataset.sum(:win_count)
  %li
    loses:
    &= @player.results_dataset.sum(:lose_count)
  %li
    draws:
    &= @player.results_dataset.sum(:draw_count)
  %li
    points:
    &= @player.point
%h2 今後の試合
%ul
  - @player.next_games_.each do |game|
    %li
      - str = "vs #{game.opponent(@player).name}"
      = link_to h(str), "/games/#{game.id}"
%h2 最近の試合
%ul
  - @player.recent_games_.limit(5).all.reverse.each do |game|
    - card_logs = game.card_logs_dataset.filter(:player_id => @player.id)
    %li
      - str = "vs #{game.opponent(@player).name}"
      = link_to h(str), "/games/#{game.id}"
      &= '... 0 - 0'
      &= card_logs.map {|e| "[#{e.name}]" }.join


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
      = 'html{margin: 0 10}'
      = 'h2{margin: 8 0 4 0; color: #999}'
      = 'ul{margin: 10 0}'
      = '.debug_log {color: #F84}'
      = '.notice {color: #0A0}'
      = '.message a {color: red; font-weight: bold; text-decoration: underline;}'
      = '.memo {color: gray}'
      = '.todo {color: gray}'
      = 'span.menu {margin-right: 10}'
      = '.r {text-align: right}'
      = '.c {text-align: center}'
      = 'table.cards th {padding: 0 5}'
      = '.agi {font-weight: bold}'
      = '.plus {color: #666; font-size: 80%; vertical-align: bottom}'
      = 'a {text-decoration: none;}'
  %table.menu{:width=>'100%'}
    %tr
      %td
        %span.menu= link_to 'HOME', "/"
        %span.menu= link_to 'LEAGUES', "/leagues"
        %span.menu= link_to 'PLAYERS', "/players"
      %td
        = link_to 'Login', "/"
  - if @debug_log
    .debug_log&= @debug_log
  - if @notice
    .notice&= @notice
  = yield
  .footer
    %hr
    .debug_commands
      = link_to 'Run core', "/dcmd/run_core"
    ppockets
