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
    Int :num_games, :default => 5
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
    
class Player < Sequel::Model
  many_to_one :user
  one_to_many :cards
  one_to_many :player
  many_to_one :leagues
  set_schema {
    primary_key :id
    foreign_key :user_id, :users
    foreign_key :league_id, :leagues
    Bool :npc?, :default => false
    Bool :home?
    Bool :entry?
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
    raise if entry? && league_id
  end
end 

class Result < Sequel::Model
  many_to_one :player
  set_schema {
    primary_key :id
    foreign_key :player_id, :players
    Int :stage
    Int :grade
    Int :wins, :default => 0
    Int :draws, :default => 0
    Int :loses, :default => 0
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
  one_to_many :players
  set_schema {
    primary_key :id
    Bool :ready?, :default => false
    Int :game_count, :default => 0
    Int :max_game_count
    #unique [:home_player_id, :away_player_id]
  }
  create_table unless table_exists?

  def next_game
    games = Game.filter(:league_id => self.id).order(:game_count) # todo
    games.filter(:played? => false).limit(1).first
  end

  def dump_string
    "id: #{id}" +
    games.map {|e| " game_count(#{e.game_count}, #{e.played? ? 'x' : '-'})" }.join(',')
  end
end
      
class Game < Sequel::Model
  many_to_one :leagues
  set_schema {
    primary_key :id
    foreign_key :league_id, :leagues
    Int :game_count
    Bool :played?, :default => false
    Text :logs
    Timestamp :created_at
    unique [:league_id, :game_count]
  }
  create_table unless table_exists?
end

# ----------------------------
def create_leagues
  dump_method_name
  env = GameEnv.first
  max_game_count = env[:num_games]
  players = Player.filter(:league_id => nil).all
  while players.count >= 2 do
    league = League.create(:max_game_count => max_game_count)
    puts "League.create: id => #{league.id}"
    players.shift.update(:stage => env[:stage], :league_id => league.id, :home? => true)
    players.shift.update(:stage => env[:stage], :league_id => league.id, :home? => false)
    max_game_count.times {|game_count| Game.create(:league_id => league.id, :game_count => game_count + 1) }
  end
  p players.count
end

def delete_leagues
  dump_method_name
  League.all.each do |league|
    next if league.next_game
    Player.filter(:league_id => league.id).update(:league_id => nil)
    Game.filter(:league_id => league.id).delete # todo: 自動的に消えてほしい
    league.delete
  end
end

def update_leagues
  dump_method_name
  League.all.each do |league|
    league.update(:game_count => league.game_count + 1) # todo
  end
  p League.all
end

def do_games
  dump_method_name
  League.filter('game_count > 0').each do |league|
    game = league.next_game
    game.update(:played? => true)
  end
end

# -- debug ---------------------
def debug_dump_leagues
  puts League.all.map(&:dump_string)
end

def debug_create_players(n)
  n.times do |i|
    user = User.create(:name => "testman%04d" % i)
    player = Player.find_or_create(:user_id => user.id)
  end
end

debug_create_players(7)

15.times do
  create_leagues
  do_games
  debug_dump_leagues
  delete_leagues
  update_leagues
end
