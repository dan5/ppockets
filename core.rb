# -*- encoding: utf-8 -*-
require 'sequel'

if $0 == __FILE__
  require 'optparse'
  rcfile = nil
  run_game_times = 1
  optparse = OptionParser.new {|opts|
    opts.banner = "Usage: ruby #{$0} [options]"

    opts.separator "\nRequire options:"
    opts.on("-r", "--rc [RCFILE]", "Specify rcfile(required)") {|f|
      rcfile = f
    }

    opts.separator "\nOptional:"
    opts.on("-d", "--debug", "Debug PPockets") {
      $PP_Debug = true
      puts 'Enter PPockets Debug mode'
    }
    opts.on("-t", "--times [n]", "Run game core n times") {|t|
      run_game_times = t.to_i
    }
  }
  optparse.parse!(ARGV)

  unless rcfile and run_game_times > 0
    puts optparse
    exit
  end
  $LOAD_PATH.unshift('./')
  load rcfile
end

# -- command ---------------------
module PlayerCommand
  def run_cmd(*args)
    command, *opts = args
    DB.transaction { r = __send__("cmd_#{command}", *opts) }
  rescue
    "run cmd error"
  end

  def cmd_draw_new_card
    return if num_commands <= 0
    self.num_commands -= 1; save
    create_new_card
  end

  def cmd_off_up
    return if num_commands <= 0
    self.num_commands -= 1; save
    # todo
    cards_dataset.update('off_plus = off_plus + 1')
  end

  def cmd_def_up
    return if num_commands <= 0
    self.num_commands -= 1; save
    ptn = {:position => -1}
    Max_cards.times {|i| ptn |= {:position => i} if rand(2) == 0 }
    cards_dataset.filter(ptn).update('def_plus = def_plus + 1')
  end

  def cmd_put_new_card(new_card_id)
    ralse unless new_card_ = new_cards_dataset.first(:id => new_card_id)
    # @todo: カードがmaxのときはそれを通知する必要がある
    if cards_.count < Max_cards
      Card.create(:player_id => self.id, :name => new_card_.name, :position => cards_.count)
      new_card_.delete
    end
  end

  def swap_cards(a, b)
    assert a < 0 || a >= Max_cards
    assert b < 0 || b >= Max_cards
    card_a = cards_dataset.first(:position => a)
    card_b = cards_dataset.first(:position => b)
    return unless card_a && card_b
    DB.transaction {
      card_a.update(:position => b)
      card_b.update(:position => a)
      order_card
    }
  end

  def order_card
    # @todo: updateを最小限に
    cards.each.with_index {|card, i| card.update(:position => i) }
  end

  def create_new_card
    name = Card.sample_name
    NewCard.create(:player_id => id, :name => name)
  end
end

# -- DB ---------------------
require 'helper'
Sequel::Model.plugin(:schema)

class GameEnvironment < Sequel::Model
  set_schema {
    primary_key :id
    Int :num_games, :default => 3
    Int :stage, :default => 1
  }
  unless table_exists?
    create_table
    self.create
  end
end 
GameEnv = GameEnvironment.find(:id => 1)
    
class User < Sequel::Model
  one_to_one :player
  one_to_one :twitter_account
  set_schema {
    primary_key :id
    String :name, :unique => true
    String :login_password, :unique => true
  }
  create_table unless table_exists?

  def self.create_from_twitter(twitter_id, name)
    raise if TwitterAccount.find(:id_of_twitter => twitter_id)
    account = TwitterAccount.create(:id_of_twitter => twitter_id)
    unless account.user_id
      user = User.create(:name => name, :login_password => name)
      account.user = user
      account.save
    end
    account.user
  end
end 
    
class TwitterAccount < Sequel::Model
  many_to_one :user
  set_schema {
    primary_key :id
    foreign_key :user_id, :users
    Int :id_of_twitter
    String :screen_name
    String :profile_image_url
  }
  create_table unless table_exists?
end

class Player < Sequel::Model
  include PlayerCommand
  many_to_one :user
  many_to_many :leagues
  one_to_many :new_cards
  one_to_many :cards, :order => :position
  one_to_many :card_logs, :order => :position
  one_to_many :home_games, :class => :Game, :key => :home_player_id
  one_to_many :away_games, :class => :Game, :key => :away_player_id
  one_to_many :results
  set_schema {
    primary_key :id
    foreign_key :user_id, :users
    Bool :game_master?, :default => false
    Bool :npc?, :default => false
    Bool :home?, :default => false
    Bool :entry?, :default => false
    Int :jewel, :default => 1000
    Int :num_commands, :default => 1
    Int :stage
    Int :grade, :default => 0
    Int :point, :default => 0
    Timestamp :loged_at
  }
  create_table unless table_exists?

  def name() user.name end
  def games_() Game.filter('home_player_id = ? OR away_player_id = ?', id, id) end
  def next_games_() games_.filter(:played? => false) end
  def recent_games_() games_.filter(:played? => true).order(:id.desc) end

  def cards_
    cards_dataset
  end

  def after_create
    super
    5.times do |i|
      Card.create(:player_id => self.id, :position => i)
    end
  end

  def validate
    #raise if entry? && league_id
    # @todo: only debug mode
    return unless id
    assert cards_.count > Max_cards
    cards.each.with_index {|card, i| assert card.position != i }
  end
end 

class League < Sequel::Model
  one_to_many :games
  one_to_many :rsults
  many_to_many :players
  set_schema {
    primary_key :id
    Int :status, :default => 0 # 0:waiting 1:opened 2:closed
    Int :turn_count, :default => 0
    Int :max_turn_count
    Int :num_games
    Int :max_players, :default => 2
    Int :players_count, :default => 0 # @todo: it should be removed
    Int :stage
    Int :grade
    Timestamp :created_at, :default => Time.now
  }
  create_table unless table_exists?

  def after_create
    super
    self.max_turn_count = num_games + 1
    self.save
  end

  def dump_string
    "id: #{id} " + games.map(&:dump_string).join(' ')
  end
end

WaitingLeague = League.filter(:status => 0) # @todo
OpenedLeague = League.filter(:status => 1)
ClosedLeague = League.filter(:status => 2)

unless DB.table_exists?(:leagues_players)
  DB.create_table :leagues_players do
    primary_key :id
    foreign_key :league_id, :leagues
    foreign_key :player_id, :players
  end 
end
      
class Game < Sequel::Model
  many_to_one :league
  many_to_one :home_player, :class => :Player
  many_to_one :away_player, :class => :Player
  one_to_many :card_logs
  set_schema {
    primary_key :id
    foreign_key :league_id, :leagues
    foreign_key :home_player_id, :players
    foreign_key :away_player_id, :players
    Int :turn_count
    Bool :played?, :default => false
    Int :home_score
    Int :away_score
    Timestamp :created_at, :default => Time.now
    unique [:league_id, :turn_count]
  }
  create_table unless table_exists?

  def validate
    assert home_player_id == away_player_id
  end

  def opponent(player)
    case player.id
    when home_player_id then Player.find(:id => away_player_id)
    when away_player_id then Player.find(:id => home_player_id)
    else raise
    end
  end

  def dump_string
    "(#{home_player.name} vs #{away_player.name} #{turn_count}#{played? ? 'x' : '-'})"
  end
end

class Result < Sequel::Model
  many_to_one :player
  set_schema {
    primary_key :id
    foreign_key :player_id, :players
    foreign_key :league_id, :leagues
    Int :win_count, :default => 0
    Int :lose_count, :default => 0
    Int :draw_count, :default => 0
    Int :point, :default => 0
    Int :score, :default  => 0
    Int :winning_margin, :default  => 0
  }
  create_table unless table_exists?
end

class TotalResult < Sequel::Model
  many_to_one :player
  set_schema {
    primary_key :id
    foreign_key :player_id, :players
    Int :grade
    Int :win, :default => 0
    Int :lose, :default => 0
    Int :draw, :default => 0
  }
  create_table unless table_exists?
end

class NewCard < Sequel::Model
  many_to_one :player
  set_schema {
    primary_key :id
    foreign_key :player_id, :players
    String :name
  }
  create_table unless table_exists?
end

class Card < Sequel::Model
  many_to_one :player
  set_schema {
    primary_key :id
    foreign_key :player_id, :players
    String :name
    Int :position
    Int :agi_plus, :default => 0
    Int :off_plus, :default => 0
    Int :def_plus, :default => 0
    Int :life
  }
  create_table unless table_exists?

  def agi() default_value(name)[0] + agi_plus end
  def off() default_value(name)[1] + off_plus end
  def def() default_value(name)[2] + def_plus end
  def job() :fig end

  def after_create
    super
    self.name ||= self.class.sample_name
    self.life = default_value(name)[3]
    self.save
  end

  def default_value(name)
     self.class.default_value(name)
  end

  def self.default_value(name)
    Values[name]
  end

  def self.sample_name
    Values.keys.sample
  end

  Values = {
    # name       ag of df li
    'keroro' => [ 4, 4, 4, 5],
    'tamama' => [ 2, 5, 2, 3],
    'giroro' => [ 5, 6, 3, 4],
    'dororo' => [ 6, 3, 5, 2],
    'kururu' => [ 3, 2, 6, 4],
  }
end 

class CardLog < Sequel::Model
  many_to_one :player
  many_to_one :game
  set_schema {
    primary_key :id
    foreign_key :player_id, :players
    foreign_key :game_id, :games
    String :name
    Bool :home?
    Int :position
    Int :score # 0:draw nil:miss else:success
    Int :off
    Int :def
    Int :agi
    Int :life
    String :job
  }
  create_table unless table_exists?
end

class DefaultCard < Hash
  def initialize(opts = {})
    self.merge!(:name => 'ghost', :off => 0, :def => 0, :agi => 0, :life => 0, :job => :fig).merge!(opts)
  end
end

# -- core ---------------------
def create_leagues(n)
  dump_method_name
  return if WaitingLeague.count > 5
  n.times do
    league = League.create(:num_games => GameEnv.num_games)
    puts "    create_league id => #{league.id}"
  end
end

def open_leagues
  WaitingLeague.all.select{|l| l.players.count == l.max_players }.each do |league|
    league.num_games.times do |turn_count|
      Game.create(:league_id => league.id,
                  :turn_count => turn_count + 1,
                  :home_player_id => league.players[0].id,
                  :away_player_id => league.players[1].id)
    end
    league.update(:status => 1)
    puts "    open_league id => #{league.id}"
  end
end

def close_leagues
  dump_method_name
  OpenedLeague.filter(:max_turn_count => :turn_count).each do |l|
    l.players.each {|e| e.update(:entry? => false) }
    l.update(:status => 2)
    puts "close: #{l.id}"
  end
end

def update_leagues
  dump_method_name
  active_leagues_ = OpenedLeague # @todo: 更新するリーグを選択する
  active_leagues_.update('turn_count = turn_count + 1')
  update_active_players active_leagues_.all.map(&:players).flatten
end

def create_card_logs(game, player, is_home)
  logs = []
  cards = player.cards_dataset.limit(5).all
  # @todo: rewrite...
  cards.fill(cards.size...5) {|i| DefaultCard.new(:position => i) }.each do |card|
    params = [:name, :position, :off, :def, :agi ,:life, :job
             ].inject({}) {|hash, e| hash[e] = card[e] || card.__send__(e); hash }
    params[:home?] = is_home
    params[:player_id] = player.id
    params[:game_id] = game.id
    logs << CardLog.create(params)
  end
  logs
end

def _play_game(mode, home_card, away_card)
  if :comp_agi == mode
    next_mode, log = mode, [:draw] if home_card.agi == away_card.agi
    next_mode, log = :atack_home, [:win_home] if home_card.agi > away_card.agi
    next_mode, log = :atack_away, [:win_away] if home_card.agi < away_card.agi
  else
    off_card, def_card, next_mode = [home_card, away_card, :atack_away] if :atack_home == mode
    off_card, def_card, next_mode = [away_card, home_card, :atack_home] if :atack_away == mode
    if off_card.off == def_card.def
      next_mode, log = :comp_agi, [0] # :draw
    else
      score = off_card.off > def_card.def ? 2 : nil
      log = [score]
    end
  end
  [next_mode, log]
end

def play_game(home_cards, away_cards)
  game_logs = []
  mode = :comp_agi
  home_cards.zip(away_cards).each do |home_card, away_card|
    last_mode = mode
    mode, log = _play_game(mode, home_card, away_card)
    game_logs << [last_mode] + log
  end
  game_logs
end

def set_score(game, game_logs)
  home_card_logs = game.card_logs_dataset.filter(:player_id => game.home_player.id)
  away_card_logs = game.card_logs_dataset.filter(:player_id => game.away_player.id)
  game_logs.each.with_index do |log, i|
    mode, score = log
    if score # @trap: (score == 0) => :draw
      home_card_logs.filter(:position => i).update(:score => score) if mode == :atack_home
      away_card_logs.filter(:position => i).update(:score => score) if mode == :atack_away
    end
  end
  assert home_card_logs.count != 5
  game.home_score = home_card_logs.sum(:score) || 0
  assert away_card_logs.count != 5
  game.away_score = away_card_logs.sum(:score) || 0
end

def do_game(game)
  home_cards = create_card_logs(game, game.home_player, true)
  away_cards = create_card_logs(game, game.away_player, false)
  puts "#{game.home_player.name} vs #{game.away_player.name}"
  game_logs = play_game(home_cards, away_cards)
  set_score(game, game_logs)
  puts "log: #{game.home_score}-#{game.away_score} #{game_logs.inspect}"
  game.update(:played? => true)
end

def do_games
  dump_method_name
  League.filter('turn_count > 0').each do |l| # @todo: join tables
    games = l.games_dataset.filter(:turn_count => l.turn_count)
    games.each {|e| do_game(e) }
  end
end

def _update_results(game)
  [
    [game.home_player, game.home_score - game.away_score],
    [game.away_player, game.away_score - game.home_score]
  ].each do |player, d|
    result = Result.find_or_create(:league_id => game.league.id, :player_id => player.id)
    pt = 0
    case
    when d == 0 
      pt = 1
      result.draw_count += 1
    when d > 0 
      pt = 3
      result.win_count += 1
    when d < 0 
      result.lose_count += 1
    end
    result.score += 1
    result.winning_margin += d
    result.save
    player.point += pt * 10000  + d * 100
    player.save
  end
end

def update_results
  League.filter('turn_count > 0').each do |l| # @todo: join tables
    games = l.games_dataset.filter(:turn_count => l.turn_count)
    games.each {|e| _update_results(e) }
  end
end

def decrease_life
  dump_method_name
  OpenedLeague.each do |l|
    if game = l.games_dataset.filter(:turn_count => l.turn_count - 1).first
      puts "========================"
      assert !game.played?
      [game.home_player, game.away_player].each do |player|
        cards_ = player.cards_dataset.filter('position < 5')
        cards_.filter('life <= 1').delete
        cards_.update('life = life - 1')
        player.order_card
      end
    end
  end
end

def deliver_card(players)
  dump_method_name
  players.each do |player|
    player.new_cards_dataset.delete
    player.create_new_card
  end
  #@rss_items << ["新しいカードが配られました（#{@game_env.day}日目）", "#{players.size}人のプレイヤーにカードが配られました。"]
end

def update_active_players(players)
  dump_method_name
  players.each do |player|
    player.update(:num_commands => 1)
  end
  deliver_card players
end

# -- debug ---------------------
def debug_dump_leagues
  puts OpenedLeague.map(&:dump_string)
end

def debug_create_players(n)
  max_user_id = User.count + 1
  n.times do |i|
    name = "testman%04d" % (i + max_user_id)
    user = User.create_from_twitter(i, name)
    #user = User.create(:name => "testman%04d" % (i + max_user_id))
    p player = Player.find_or_create(:user_id => user.id, :game_master? => true)
  end
end

def debug_entry_players
  Player.all.each do |player|
    next if player.entry?
    if league = WaitingLeague.filter('players_count < max_players').first
      p player.user.name
      player.update(:entry? => true)
      league.add_player(player)
      league.players_count += 1
      league.save
    end
  end
end

def debug_puts_new_card
  Player.all.each do |player|
    if new_card = player.new_cards_dataset.first
      player.cmd_put_new_card new_card.id
    end
  end
end

def run_core
  DB.transaction {
    create_leagues(Player.count / 4)
    debug_entry_players if $PP_Debug
    open_leagues
    do_games
    update_results
    debug_dump_leagues if $PP_Debug
    update_leagues
    decrease_life
    close_leagues
    debug_puts_new_card if $PP_Debug
  }
end

if $0 == __FILE__ # cron part

  if $PP_Debug 
    srand(0)
    debug_create_players(7) if Player.count == 0
  end

  run_game_times.times { run_core }

end # --- cron part
