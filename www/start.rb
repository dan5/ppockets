# -*- encoding: utf-8 -*-
require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra_more/markup_plugin'
require 'haml'
require 'core.rb'
Sinatra::Base.register SinatraMore::MarkupPlugin

enable :sessions

helpers do
  def plus_param(character, meth)
    param = character.__send__(meth)
    param == 0 ? '' : "+#{param}"
  end

  def link_to_player(player) link_to h(player.name), "/players/#{player.id}" end
  def link_to_league(league) link_to h("league#{league.id}"), "/leagues/#{league.id}" end
  def path_info() @env['PATH_INFO'] end

  def redirect_logs
    return if path_info[/^\/logs/]
    return if @player.nil? || @player.logs_dataset.count == 0
    redirect '/logs'
  end
end

before do
  # login auth
  if session[:login_password] && user = User.find(:login_password => session[:login_password])
    @player = Player.find_or_create(:user_id => user.id)
  end
  redirect_logs
  @debug_log = session[:debug_log]
  @notice = session[:notice]
  session[:debug_log] = nil
  session[:notice] = nil
end

error do
  exc = request.env['sinatra.error']
  "ppockets error: `#{exc.message}' -- #{exc.backtrace.first}"
end

require 'sass'
get '/stylesheet.css' do
  sass :stylesheet
end

get '/login/:login_password' do
  session[:login_password] = params[:login_password]
  if user = User.find(:login_password => session[:login_password])
    session[:notice] = "#{user.name}さん、ようこそ！"
    redirect '/'
  else
    'Log in failure'
  end
end

get '/login' do
  haml :login
end

get '/logout' do
  session[:login_password] = nil
  session[:notice] = "logout."
  redirect '/'
end

get '/logs/delete_all' do
  @player.delete_logs
  session[:debug_log] = 'clear logs.'
  redirect '/'
end

get '/logs' do
  @logs = @player.logs
  haml :logs
end

get '/new_character' do
  if @player.new_characters.count == 0
    redirect '/'
  else
    @new_character = @player.new_characters_dataset.first
    @item = @new_character.character.amazon_item
    haml :new_character
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

get '/leagues/:id/entry' do
  @player.run_cmd :entry_league, params[:id]
  session[:notice] = "リーグ#{params[:id]}にエントリしました"
  redirect '/'
end

get '/leagues' do
  haml :leagues
end

get '/games/:id' do
  haml :games_show
end

get '/characters/stock' do
  @characters_notice = session[:characters_notice]
  session[:characters_notice] = nil
  haml :characters_stock
end

get '/characters/:id' do
  haml :characters_show
end

get '/amazon/:asin' do
  asin = params[:asin]
  @item = AmazonItem.find_item(asin)
  haml :amazon_show
end

put '/amazon' do
  @word = request[:word]
  res = Amazon::Ecs.item_search(@word, :search_index => 'All', :response_group => 'Medium')
  @items = res.items
  haml :amazon
end

get '/amazon' do
  @items = []
  haml :amazon
end

get '/' do
  haml @player ? :home : :leagues
end

# -- cmd API -----------
get '/cmd/new_character' do
  @player.run_cmd :draw_new_character
  session[:notice] = 'created a new character.'
  redirect '/new_character'
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

get '/cmd/put_new_character/:id' do
  character = @player.run_cmd :put_new_character, params[:id]
  session[:notice] = "#{character.name}をポケットに入れました"
  redirect '/'
end

get '/cmd/swap/:a/:b' do
  @player.run_cmd :swap_characters, params[:a].to_i, params[:b].to_i
  session[:notice] = "swap characters(#{params[:a]}, #{params[:b]})"
  redirect '/'
end

get '/cmd/buy_character/:id/:pre_price' do
  @player.run_cmd :buy_character, params[:id], params[:pre_price].to_i
  stock = CharacterStock.find(:id => params[:id])
  session[:characters_notice] = "#{stock.name}を買いました"
  redirect '/characters/stock'
end

get '/dcmd/run_core' do
  if @player.game_master?
    run_core 
    session[:debug_log] = 'run core'
  end
  redirect '/'
end

__END__
@@ login
%p.todo todo: login form


@@ _player_ranking
%table
  %tr
    %th name
    %th grade
    %th win
    %th draw
    %th lose
    %th score
    %th margin
    %th point
  - (@players_ || Player.order(:point.desc)).each do |player|
    %tr
      - results_ = player.results_dataset.filter(@result_ptn || {})
      %td= link_to_player player
      %td.r&= player.grade
      %td.r&= results_.sum(:win_count)
      %td.r&= results_.sum(:draw_count)
      %td.r&= results_.sum(:lose_count)
      %td.r&= results_.sum(:score)
      %td.r&= results_.sum(:winning_margin)
      %td.r.b&= ((results_.sum(:point) or 0) / 1000.0).round / 10.0


@@ logs
%h2 Logs
.logs
  - @logs.each do |log|
    %p&= log.message
= link_to 'ok', '/logs/delete_all'


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
    - character_logs = game.character_logs_dataset.filter(:player_id => @player.id)
    %li
      - str = "vs #{game.opponent(@player).name}"
      = link_to h(str), "/games/#{game.id}"
      &= '... 0 - 0'
      &= character_logs.map {|e| "[#{e.name}]" }.join


@@ players
%h2 players
= haml :_player_ranking


@@ leagues_show
- league = League.find(:id => params[:id])
%h1== #{h league.schedule_type.capitalize} League
%p== 更新: #{h league.schedule.join('時 ')}時
- if league.status == 0 and (@player and !@player.entry?)
  .entry_button
    = link_to 'このリーグに参加する', "/leagues/#{league.id}/entry"
    %hr
%h2 Ranking
- @players_ = league.players_dataset.order(:active_point.desc)
- @result_ptn = {:league_id => league.id}
= haml :_player_ranking
%h2 League
%table.league
  - players = league.players
  %tr
    %th
    - players.each do |player|
      %th= player.short_name
  - players.each do |home_player|
    %tr
      %td= link_to_player home_player
      - players.each do |away_player|
        - ptn1 = { :home_player_id => home_player.id, :away_player_id => away_player.id }
        - ptn2 = { :home_player_id => away_player.id, :away_player_id => home_player.id }
        - game = Game.filter(:league_id => league.id).filter(ptn1 | ptn2).first
        %td.c
          - if game
            - if game.played?
              - if game.home_player.id == home_player.id
                - str = "#{h game.home_score} - #{h game.away_score}"
              - else
                - str = "#{h game.away_score} - #{h game.home_score}"
              = link_to h(str), "/games/#{game.id}"
          - else
            &= '-'


@@ leagues
%h2 エントリ受付中のリーグ
.waiting
  - WaitingLeague.each do |league|
    - str = "league#{league.id}(#{league.players_count})"
    = link_to h(str), "/leagues/#{league.id}"
%h2 開催中のリーグ
.opened
  - OpenedLeague.each do |league|
    = link_to_league league
%h2 過去のリーグ
.closed
  - ClosedLeague.limit(50).each do |league|
    = link_to_league league


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
    %link(rel='stylesheet' type='text/css' href='/stylesheet.css')
    %style
  %table.menu{:width=>'100%'}
    %tr
      %td
        %span.menu= link_to 'HOME', "/"
        %span.menu= link_to 'LEAGUES', "/leagues"
        %span.menu= link_to 'PLAYERS', "/players"
        %span.menu= link_to 'CHARACTERS SHOP', "/characters/stock"
        %span.menu= link_to 'AMAZON', "/amazon"
      %td
        - if @player
          = link_to 'Logout', "/logout"
        - else
          = link_to 'Login', "/login"
  - if @debug_log
    .debug_log&= @debug_log
  - if @notice
    .notice&= @notice
  = yield
  .footer
    %hr
    .debug
      == time: #{h game_env.game_time}
    .debug_commands
      = link_to 'Run core', "/dcmd/run_core"
    ppockets
