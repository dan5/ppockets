# -*- encoding: utf-8 -*-
require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra_more/markup_plugin'
require 'haml'
Sinatra::Base.register SinatraMore::MarkupPlugin
enable :sessions

configure :production do
  require 'core.rb'
end

before do
  load 'core.rb' if development?
end

helpers do
  def unescape_html(text) CGI::unescapeHTML(text) end
  def plus_param(character, meth)
    param = character.__send__(meth)
    param == 0 ? '' : "+#{param}"
  end

  def link_to_player(player) link_to h(player.name), "/players/#{player.id}" end
  def link_to_league(league) link_to h("league#{league.id}"), "/leagues/#{league.id}" end
  def path_info() @env['PATH_INFO'] end

  def redirect_logs
    return if path_info[/^\/logs/] or path_info[/\.css\z/]
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
  @debug_logs = session[:debug_logs] || []
  @notices = session[:notices] || []
  session[:debug_logs] = []
  session[:notices] = []
  @custam = (@player and @player.custam) || Custam.first
  if @player
    @notices_h = []
    if @player.new_characters.count > 0
      @notices_h << link_to(h("#{@player.new_characters.count}枚の新しいカードがあります"), '/new_character')
    end
    if @player.num_commands > 0
      @notices_h << "コマンドを#{h @player.num_commands}回実行できます"
    end
  end
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
    session[:notices] << "#{user.name}さん、ようこそ！"
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
  session[:notices] << "logout."
  redirect '/'
end

get '/logs/delete_all' do
  @player.delete_logs
  session[:debug_logs] << 'clear logs.'
  redirect '/'
end

get '/logs' do
  @logs = @player.logs
  haml :logs
end

get '/custam' do
  return 'please login' unless @player
  haml :custam
end

get '/custam/:uid' do
  custam = Custam.find(:uid => params[:uid])
  return 'cannot found' unless custam
  haml :custam_show, :locals => {:custam => custam}
end

get '/custam_delete' do
  return 'please login' unless @player
  @player.user.delete_own_custam
  redirect '/custam'
end

get '/custam_edit' do
  return 'please login' unless @player
  custam = @player.user.own_custam
  body = Character.names.map {|name|
    c = custam.find_card(name)
    asin = c ? c.asin : nil
    nick = c ? c.nick : nil
    "#{name}\t#{asin}\t#{nick}\n" }.join
  haml :custam_edit, :locals => {:title => @player.custam.name, :body => body}
end

post '/custam_edit' do
  return 'please login' unless @player
  title, text = params[:title], params[:body]
  @player.user.own_custam.update(:name =>title)
  @player.user.own_custam.update_custam_card(text)
  redirect '/custam_edit'
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
  session[:notices] << "リーグ#{params[:id]}にエントリしました"
  redirect '/'
end

get '/leagues' do
  haml :leagues
end

get '/games/:id' do
  haml :games_show
end

get '/characters/stock' do
  @characters_notice = session[:characters_notice] || []
  session[:characters_notice] = []
  haml :characters_stock
end

get '/characters/:id' do
  @character = Character.find(:id => params[:id])
  @item = @character.amazon_item
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
  session[:notices] << 'created a new character.'
  redirect '/new_character'
end

get '/cmd/off_up' do
  @player.run_cmd :off_up
  session[:notices] << '攻撃強化コマンドを実行しました'
  redirect '/'
end

get '/cmd/def_up' do
  @player.run_cmd :def_up
  session[:notices] << 'ディフェンス強化コマンドを実行しました'
  redirect '/'
end

get '/cmd/put_new_character/:id' do
  character = @player.run_cmd :put_new_character, params[:id]
  session[:notices] << "#{character.name}をポケットに入れました"
  redirect '/'
end

get '/cmd/sell_new_character/:id' do
  name = @player.run_cmd :sell_new_character, params[:id]
  session[:notices] << "#{name}を手放しました"
  redirect '/'
end

get '/cmd/sell_character/:id' do
  name = @player.run_cmd :sell_character, params[:id]
  session[:notices] << "#{name}を手放しました"
  redirect '/'
end

get '/cmd/swap/:a/:b' do
  @player.run_cmd :swap_characters, params[:a].to_i, params[:b].to_i
  session[:notices] << "swap characters(#{params[:a]}, #{params[:b]})"
  redirect '/'
end

get '/cmd/buy_character/:id/:pre_price' do
  @player.run_cmd :buy_character, params[:id], params[:pre_price].to_i
  stock = CharacterStock.find(:id => params[:id])
  session[:characters_notice] << "#{stock.name}のカードを買いました"
  redirect '/characters/stock'
end

get '/cmd/use_custam/:uid' do
  @player.user.use_custam(params[:uid])
  redirect '/custam'
end

get '/cmd/use_default_custam' do
  @player.user.use_default_custam
  redirect '/custam'
end

get '/cmd/use_own_custam' do
  @player.user.use_own_custam
  redirect '/custam'
end

get '/dcmd/run_core' do
  if @player.game_master?
    run_core 
    session[:debug_logs] << 'run core'
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

