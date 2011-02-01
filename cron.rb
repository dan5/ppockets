# -*- encoding: utf-8 -*-
class Object
  def dump_method_name()
    current_method = caller.first.scan(/`(.*)'/).flatten.first
    puts "--- #{current_method} ---"
  end
end

#class Array; def sample() self[rand(size)] end end

require 'rubygems'
require 'sequel'
Sequel::Model.plugin(:schema)
Encoding.default_external = 'utf-8'

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
GameEnv = DB[:game_environments].find(:id => 1)
    
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
  one_to_many :player
  many_to_many :leagues
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
    Int :life_plus, :default => 0
  }
  create_table unless table_exists?

  def after_create
    super
    self.name = Values.keys.sample
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

class League < Sequel::Model
  one_to_many :games
  one_to_many :rsults
  many_to_many :players
  set_schema {
    primary_key :id
    Bool :active?, :default => true
    Int :game_count, :default => 0
    Int :max_game_count
    Int :stage
    Int :grade
    #unique [:home_player_id, :away_player_id]
  }
  create_table unless table_exists?

  def dump_string
    "id: #{id} " +
    games.map {|e| "(#{e.game_count} #{e.played? ? 'x' : '-'})" }.join(' ')
  end
end
ActiveLeague = League.filter(:active? => true) # todo
      
class Game < Sequel::Model
  many_to_one :leagues
  set_schema {
    primary_key :id
    foreign_key :league_id, :leagues
    foreign_key :home_player_id, :players
    foreign_key :away_player_id, :players
    Int :home_score
    Int :away_score
    Int :game_count
    Bool :played?, :default => false
    Timestamp :created_at
    unique [:league_id, :game_count]
    unique [:league_id, :game_count, :home_player_id]
    unique [:league_id, :game_count, :away_player_id]
  }
  create_table unless table_exists?
end

# ----------------------------
def create_leagues
  dump_method_name
  env = GameEnv.first
  max_game_count = env[:num_games]
  league = League.create(:max_game_count => max_game_count)
=begin
  players = Player.filter(:entry? => true).all # todo: entry
  while players.count >= 2 do
    puts "League.create: id => #{league.id}"
    [true, false].each do |is_home|
      player = players.shift
      player.update(:stage => env[:stage], :home? => is_home, :entry? => false)
      league.add_player(player)
      league.save
    end
    max_game_count.times {|game_count| Game.create(:league_id => league.id, :game_count => game_count + 1) }
  end
=end
  #players.count == 0 or raise
end

def close_leagues
  dump_method_name
  League.filter(:active? => true).all.each do |l|
    games = Game.filter(:league_id => l.id, :played? => false)
    next if games.count > 0
    l.update(:active? => false)
    puts "close: #{l.id}"
  end
end

def update_leagues
  dump_method_name
  League.filter(:active? => true).all.each do |league|
    league.update(:game_count => league.game_count + 1) # todo
  end
end

def do_game(game)
  #do_game(home_player, away_player)
  #home_player.result.win += 1
  game.update(:played? => true)
end

def do_games
  dump_method_name
  League.filter('game_count > 0').each do |l|
    games = Game.filter(:league_id => l.id, :game_count => l.game_count)
    games.each {|e| do_game(e) }

    #games = Game.filter(:league_id => self.id).order(:game_count) # todo
    #games.filter(:played? => false).limit(1).first

    #game = league.next_game
  end
end

# -- debug ---------------------
def debug_dump_leagues
  puts ActiveLeague.map(&:dump_string)
end

def debug_create_players(n)
  n.times do |i|
    user = User.create(:name => "testman%04d" % i)
    player = Player.find_or_create(:user_id => user.id)
  end
end

def debug_entry_players
  Player.all.each do |player|
    unless player.leagues.find(&:active?)
      player.update(:entry? => true)
      p player.user.name
    end
  end
end

debug_create_players(3)

7.times do
  debug_entry_players
  create_leagues
  do_games
  debug_dump_leagues
  update_leagues
  close_leagues
end
