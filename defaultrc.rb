require 'sequel'
root_path = File.dirname(File.expand_path(__FILE__)).untaint
$LOAD_PATH.unshift root_path

# -- DB connection
DB = Sequel.sqlite(root_path + '/development.db')

# -- game setting
Max_players_in_league = 8
