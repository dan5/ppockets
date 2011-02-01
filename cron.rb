# -*- encoding: utf-8 -*-
require 'sequel'
require './helper'
Sequel::Model.plugin(:schema)

DB = Sequel.sqlite

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
  set_schema {
    primary_key :id
    String :name, :unique => true
  }
  create_table unless table_exists?
end 
    
DB.create_table :leagues_players do
  primary_key :id
  foreign_key :league_id, :leagues
  foreign_key :player_id, :players
end 

class Player < Sequel::Model
  many_to_one :user
  one_to_many :cards
  many_to_many :leagues
  one_to_many :home_games, :class => :Game, :key => :home_player_id
  one_to_many :away_games, :class => :Game, :key => :away_player_id
  set_schema {
    primary_key :id
    foreign_key :user_id, :users
    Bool :npc?, :default => false
    Bool :home?, :default => false
    Bool :entry?, :default => false
    Int :jewel, :default => 1000
    Int :num_commands, :default => 1
    Int :stage
    Int :grade, :default => 0
    Int :points, :default => 0
    Timestamp :loged_at
  }
  create_table unless table_exists?

  def name() user.name end

  def after_create
    super
    5.times do |i|
      Card.create(:player_id => self.id, :position => i)
    end
  end

  def validate
    #raise if entry? && league_id
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
    Int :stage
    Int :grade
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
WaitingLeague = League.filter(:status => 0) # todo
OpenedLeague = League.filter(:status => 1)
ClosedLeague = League.filter(:status => 2)
      
class Game < Sequel::Model
  many_to_one :leagues
  many_to_one :home_player, :class => :Player
  many_to_one :away_player, :class => :Player
  set_schema {
    primary_key :id
    foreign_key :league_id, :leagues
    foreign_key :home_player_id, :players
    foreign_key :away_player_id, :players
    Int :turn_count
    Bool :played?, :default => false
    Int :home_score
    Int :away_score
    Timestamp :created_at
    unique [:league_id, :turn_count]
  }
  create_table unless table_exists?


  def validate
    assert home_player_id == away_player_id
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
    Int :win, :default => 0
    Int :lose, :default => 0
    Int :draw, :default => 0
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

class Card < Sequel::Model
  many_to_one :player
  set_schema {
    primary_key :id
    foreign_key :player_id, :players
    String :name
    Int :position
    Int :off_plus, :default => 0
    Int :def_plus, :default => 0
    Int :agi_plus, :default => 0
    Int :life
  }
  create_table unless table_exists?

  def after_create
    super
    self.name = Values.keys.sample
    self.life = 5
    self.save
  end

  Values = {
    'keroro' => [],
    'tamama' => [],
    'giroro' => [],
    'dororo' => [],
    'kururu' => [],
  }
end 

# ----------------------------
def create_leagues
  dump_method_name
  league = League.create(:num_games => GameEnv.num_games)
  puts "    create_league id => #{league.id}"
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
  OpenedLeague.update('turn_count = turn_count + 1')
end

def do_game(game)
  game.update(:played? => true)
  #game.home_player.result.win += 1
end

def do_games
  dump_method_name
  League.filter('turn_count > 0').each do |l|
    games = l.games_dataset.filter(:turn_count => l.turn_count)
    games.each {|e| do_game(e) }
  end
end

def decrease_life
  dump_method_name
  OpenedLeague.each do |l|
    if game = l.games_dataset.filter(:turn_count => l.turn_count - 1).first
      puts "========================"
      assert !game.played?
      cards = game.home_player.cards_dataset.filter('position < 5')
      cards.update('life = life - 1')
      dead_cards = cards.filter('life <= 0')
      dead_cards.delete
    end
  end
end

# -- debug ---------------------
def debug_dump_leagues
  puts OpenedLeague.map(&:dump_string)
end

def debug_create_players(n)
  n.times do |i|
    user = User.create(:name => "testman%04d" % i)
    player = Player.find_or_create(:user_id => user.id)
  end
end

def debug_entry_players
  Player.all.each do |player|
    next if player.entry?
    if league = WaitingLeague.find {|l| l.players.count < l.max_players }
      p player.user.name
      player.update(:entry? => true)
      league.add_player(player)
      league.save
    end
  end
end

debug_create_players(2)

9.times do
  create_leagues
      debug_entry_players # debug
  open_leagues
  do_games
      debug_dump_leagues # debug
  update_leagues
  decrease_life
  close_leagues
end
