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
  many_to_one :schedules
  set_schema {
    primary_key :id
    foreign_key :user_id, :users
    foreign_key :schedule_id, :schedules
    Bool :npc?, :default => false
    Bool :home?
    Int :jewel, :default => 1000
    Int :num_commands, :default => 1
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

class Schedule < Sequel::Model
  one_to_many :games
  one_to_many :players
  set_schema {
    primary_key :id
    Bool :ready?, :default => true
    #unique [:home_player_id, :away_player_id]
  }
  create_table unless table_exists?

  def next_game
    games = Game.filter(:schedule_id => self.id).order(:day) # todo
    games.filter(:played? => false).limit(1).first
  end

  def dump_string
    "id: #{id}" +
    games.map {|e| " day(#{e.day}, #{e.played? ? 'x' : '-'})" }.join(',')
  end
end
      
class Game < Sequel::Model
  many_to_one :schedules
  set_schema {
    primary_key :id
    foreign_key :schedule_id, :schedules
    Int :day
    Bool :played?, :default => false
    Text :logs
    Timestamp :created_at
    unique [:schedule_id, :day]
  }
  create_table unless table_exists?
end

# ----------------------------
def create_schedules
  dump_method_name
  players = Player.filter(:schedule_id => nil).all
  while players.count >= 2 do
    schedule = Schedule.create
    players.shift.update(:schedule_id => schedule.id, :home? => true)
    players.shift.update(:schedule_id => schedule.id, :home? => false)
    3.times {|day| Game.create(:schedule_id => schedule.id, :day => day + 1) }
  end
end

def delete_schedules
  dump_method_name
  Schedule.all.each do |schedule|
    next if schedule.next_game
    Player.filter(:schedule_id => schedule.id).update(:schedule_id => nil)
    Game.filter(:schedule_id => schedule.id).delete # todo: 自動的に消えてほしい
    schedule.delete
  end
end

def do_games
  dump_method_name
  Schedule.filter(:ready? => true).each do |schedule|
    game = schedule.next_game
    game.update(:played? => true)
  end
end

# -- debug ---------------------
def debug_dump_schedules
  puts Schedule.all.map(&:dump_string)
end

def debug_create_players(n)
  n.times do |i|
    user = User.create(:name => "testman%04d" % i)
    player = Player.find_or_create(:user_id => user.id)
  end
end

debug_create_players(5)

15.times do
  create_schedules
  do_games
  debug_dump_schedules
  delete_schedules
end
