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

def initialize_player(user)
  player = Player.find_or_create(:user_id => user.id)
end

user = User.create
player = initialize_player(user)
p player
p player.cards
