# -*- encoding: utf-8 -*-

require 'rubytter'
require 'yaml'
root = File.dirname(File.expand_path(__FILE__)).untaint
$LOAD_PATH.unshift root
require 'core.rb'

Data_fname = "#{root}/db/twitter_data.yaml"
def read
  raise unless File.exist?(Data_fname)
  YAML.load(File.read(Data_fname))
end

def save(data)
  File.open(Data_fname, 'w') {|f| f.puts data.to_yaml }
  data
end

def get_string(msg)
  print msg
  gets.strip
end

def read_or_create_data
  read()
rescue
  key = get_string('Enter KEY: ')
  secret = get_string('Enter SECRET: ')
  oauth = Rubytter::OAuth.new(key, secret)

  request_token = oauth.get_request_token
  system('open', request_token.authorize_url) || puts("Access here: #{request_token.authorize_url}\nand...")

  pin = get_string('Enter PIN: ')
  access_token = request_token.get_access_token(
    :oauth_token => request_token.token,
    :oauth_verifier => pin
  )

  save(:access_token => access_token, :followers_ids => [])
end

def new_followeres_ids(data, client)
  screen_name = data[:access_token].params[:screen_name]
  followers_ids = client.followers_ids(screen_name)
  news = followers_ids - data[:followers_ids]
  data[:followers_ids] = followers_ids
  save(data)
  news
end

def msg(client, message)
  puts message
  #client.update message
end

data = read_or_create_data()
 data[:followers_ids] = []
client = OAuthRubytter.new(data[:access_token])

new_followeres_ids(data, client).each do |id|
  begin
    login_password = rand(100000000000000000000).to_s(36)
    name = client.user(id).name
    User.create_from_twitter(id, name, login_password)
    msg(client, "#{name}を作成しました")
  rescue
    User.update_login_password(id, name, login_password)
    p $!
  end
  client.direct_message(id, "#{Base_url}/login/#{login_password}")
  msg(client, "#{name}にログインパスワードを送信しました")
end
