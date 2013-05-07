
# Boilerplate Sinatra app in Literate Ruby

## About literate_ruby.rb
keep your code:
  - in "readme.md"
  - tab-indented (not four spaces, sorry)
  - use ```Ruby ... ``` for pretty printing on Github

to run in development: 
  $ ruby literate_ruby.rb < readme.md

to deploy:
  $ # must be a literal tab!
  $ cat readme.md | grep "^	" > app.rb 
  $ bundle install
  $ heroku create
  $ git push heroku master

```Ruby
	require 'rubygems'
	require 'bundler/setup'
	require 'sinatra'

	require 'thin' # HTTP server
	require 'haml' # for quick views
	require 'barista' # for using :coffescript in Haml
	
	# # for postgres:
	# require 'pg'
	# require 'data_mapper'
	# require 'dm-postgres-adapter'
	# DataMapper.setup(:default, ENV['DATABASE_URL'] || 'postgres://postgres:postgres@localhost/postgres')

	# for MongoDB
	require 'mongo'
	require 'mongo_mapper'
	# require 'bson_ext'
	require 'uri'
	include Mongo
	database_name = "your_db_name"
	mongo_url = ENV['MONGOHQ_URL'] || "mongodb://localhost/#{database_name}"
	MongoMapper.connection = Mongo::Connection.from_uri mongo_url
	MongoMapper.database = URI.parse(mongo_url).path.gsub(/^\//, '') #Extracts 'dbname' from the uri
	# YourModel.ensure_index(:field_name)

```

# Helpers

```Ruby
	# # Uncomment and set ENV HTTP_USERNAME and HTTP_PASSWORD to enable password protection with "protected!"
	# def protected!
	# 	unless authorized?
	# 		p "Unauthorized request."
	# 		response['WWW-Authenticate'] = %(Basic)
	# 		throw(:halt, [401, "Not authorized\n"])
	# 	end
	# end
	# AUTH_PAIR = [ENV['HTTP_USERNAME'], ENV['HTTP_PASSWORD']]
	# def authorized?
	# 	@auth ||=  Rack::Auth::Basic::Request.new(request.env)
	# 	@auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == AUTH_PAIR
	# end
```

# Routes 
```Ruby
	get "/" do
		"Home"
	end
```



