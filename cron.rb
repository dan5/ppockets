# -*- encoding: utf-8 -*-
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
  set_schema {
    primary_key :id
    foreign_key :user_id, :users
    Bool :npc?, :default => false
    Int :jewel, :default => 1000
    Int :num_commands, :default => 1
    Int :grade, :default => 0
    Int :points, :default => 0
    Timestamp :last_login_time
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
  set_schema {
    primary_key :id
    foreign_key :home_player_id, :players
    foreign_key :away_player_id, :players
    Bool :ready?, :default => true
    unique [:home_player_id, :away_player_id]
  }
  create_table unless table_exists?
end
      
class Game < Sequel::Model
  set_schema {
    primary_key :id
    foreign_key :schedule_id, :schedules
    Int :day
    Bool :played?, :default => false
    Text :logs
    unique [:schedule_id, :day]
  }
  create_table unless table_exists?
end

def match_make
  entry_players = Player.all
  while entry_players.count >= 2 do
    Schedule.create({
      :home_player_id => entry_players.shift.id,
      :away_player_id => entry_players.shift.id,
    })
  end
end

# ----------------------------

def debug_create_players(n)
  n.times do |i|
    user = User.create(:name => "testman%04d" % i)
    player = Player.find_or_create(:user_id => user.id)
  end
end

debug_create_players(10)
p Card.count
match_make

p Schedule.all
