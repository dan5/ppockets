require 'rubytter'
require 'yaml'

Data_fname = 'db/twitter_data.yaml'
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

def new_followeres(data, client)
  screen_name = data[:access_token].params[:screen_name]
  followers_ids = client.followers_ids(screen_name)
  d = followers_ids - data[:followers_ids]
  data[:followers_ids] = followers_ids
  save(data)
  d
end

data = read_or_create_data()
client = OAuthRubytter.new(data[:access_token])

p new_followeres(data, client)
