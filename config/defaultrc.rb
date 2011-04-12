require 'sequel'
require 'amazon/ecs'

# -- DB connection
root_path = File.dirname(File.expand_path(__FILE__)).untaint + '/..'
DB = Sequel.sqlite(root_path + '/db/development.db')

# -- game setting
Max_players_in_league = 8
Max_characters = 8

# -- www setting
#Server_port = 2333
Base_url = 'http://localhost:2333'

# -- amazon
#Amazon::Ecs.debug = true
#Amazon::Ecs.options = {
#  :aWS_access_key_id => '__TODO__',
#  :aWS_secret_key => '__TODO__',
#  :associate_tag => 'ppockets-22',
#  :country => :jp
#}
load 'config/amazonconfig'
