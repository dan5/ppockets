require 'sequel'

# -- DB connection
root_path = File.dirname(File.expand_path(__FILE__)).untaint + '/..'
DB = Sequel.sqlite(root_path + '/db/development.db')

# -- game setting
Max_players_in_league = 8
