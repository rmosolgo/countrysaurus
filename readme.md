
# Country Name Fixer

## Use

### 1. Upload a CSV

- "Not sure how to get a CSV? Click here for picture instructions"
- User uploads CSV, is verified (by server?)

### 2. Identify your country column

- "I checked your CSV and found these columns, which one has country names in it?"

### 3. Check country matches
- "Ok, I found these countries, and matched them like this:"
  - Two columns: value found, recommended value
  - "Something not right?"
    - select your own
    - recommend a fix in the DB
    
### 4. Add new country names

- "I can look through and find countries. What fields should I add to your spreadsheet?"


### 5. Return original CSV with new names

- "All done -- here ya go"
- Facebook, Twitter, tips?


## Implementation

###  About literate_ruby.rb
keep your code:


  - in "readme.md"
  - tab-indented (not four spaces, sorry)
  - use ```Ruby ... ``` for pretty printing on Github


to run in development: 
```
  $ ruby literate_ruby.rb < readme.md
```
to deploy:
 
```  
  $ # must be a literal tab!
  $ cat readme.md | grep "^	" > app.rb
  # or, on windows, I can't figure out how to get a literal tab
  # so I paste into the file and ctl-h (\n)[^\t\n].*$ -> empty string 
  $ bundle install
  $ heroku create
  $ git push heroku master
```

### Gems 
CODE ```
```Ruby
	# coding: utf-8
	require 'rubygems'
	require 'bundler/setup'
	require 'sinatra'
	require 'sinatra/namespace'

	require 'thin' # HTTP server
	require 'haml' # for quick views
	require 'barista' # for using :coffescript in Haml
```
Caching via memcachier/dalli:

```Ruby
	require 'dalli'
	require 'memcachier'
	CACHES = Dalli::Client.new
	
```

Back end in Mongo, for fun:
```Ruby	
	# for MongoDB
	require 'mongo'
	require 'mongo_mapper'
	# require 'bson_ext'
	require 'uri'
	include Mongo
	database_name = "country_fixer"
	mongo_url = ENV['MONGOHQ_URL'] || "mongodb://localhost/#{database_name}"
	MongoMapper.connection = Mongo::Connection.from_uri mongo_url
	MongoMapper.database = URI.parse(mongo_url).path.gsub(/^\//, '') #Extracts 'dbname' from the uri
	# YourModel.ensure_index(:field_name)

```
An extra string method -- to remove diacritics:

```Ruby
	class String
		def remove_diacritics
			self.tr(
				"ÀÁÂÃÄÅàáâãäåĀāĂăĄąÇçĆćĈĉĊċČčÐðĎďĐđÈÉÊËèéêëĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħÌÍÎÏìíîïĨĩĪīĬĭĮįİıĴĵĶķĸĹĺĻļĽľĿŀŁłÑñŃńŅņŇňŉŊŋÒÓÔÕÖØòóôõöøŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšſŢţŤťŦŧÙÚÛÜùúûüŨũŪūŬŭŮůŰűŲųŴŵÝýÿŶŷŸŹźŻżŽž", 
				"AAAAAAaaaaaaAaAaAaCcCcCcCcCcDdDdDdEEEEeeeeEeEeEeEeEeGgGgGgGgHhHhIIIIiiiiIiIiIiIiIiJjKkkLlLlLlLlLlNnNnNnNnnNnOOOOOOooooooOoOoOoRrRrRrSsSsSsSssTtTtTtUUUUuuuuUuUuUuUuUuUuWwYyyYyYZzZzZz")
		end
	end

```

Configure __New Relic__:
```Ruby

	configure :production do
	  require 'newrelic_rpm'
	end
```
### Stats 

Keep track of how much work we've done, and show it to users:
- countries standardized 
- spreadsheet cells served
- --> Human hours saved

```Ruby
	require './models/stat'

```


### Country


- aliases: 
  - other names?? Other spellings, "The", "Ivory Coast"
  - ALWAYS DOWNCASE for matches!
- User-editable -- add to aliases, not canonical names
- Sends email to me when edited

- __What about a missing country all together?__

```Ruby
	require './models/country'

```

### Spreadsheets

This is for holding spreadsheets while they're being worked on. I'll dump it when I'm done
(to save space, if not to protect privacy...)

```Ruby
	require './models/spreadsheet'
```


### Helpers
```Ruby
	helpers do 
```

Syntactic sugar for data:

```Ruby
		def returns_json(serializable_object=nil)
```
for example, 
`returns_json(@country)` 
sends @country.to_json

```Ruby
		    content_type :json
		    json_response = ""
		    if serializable_object
		    	if serializable_object.respond_to? :to_json
		    		json_response = serializable_object.to_json
		    	else
		    		json_response = JSON.dump(serializable_object)
		    	end
		    end
		    json_response
		end
```

Oops, this one doesn't work that way:

```Ruby
		def returns_csv(filename='data')
		    content_type 'application/csv'
		    attachment "#{filename}.csv"
		end
```

Authorization
```Ruby
	# Uncomment and set ENV HTTP_USERNAME and HTTP_PASSWORD to enable password protection with "protected!"
		def protected!
			unless authorized?
				p "Unauthorized request."
				response['WWW-Authenticate'] = %(Basic)
				throw(:halt, [401, "Not authorized\n"])
			end
		end
		# AUTH_PAIR = [ENV['HTTP_USERNAME'], ENV['HTTP_PASSWORD']]
		AUTH_PAIR = ["aiddata", (ENV['HTTP_PASSWORD'] ||  "aiddata")]
		def authorized?
			@auth ||=  Rack::Auth::Basic::Request.new(request.env)
			(@auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == AUTH_PAIR)
		end
```

```Ruby
	end
```

### Routes 

#### General Routes

```Ruby
	get "/" do
		haml :home
	end

	get "/api_documentation" do
		haml :api_docs
	end
```

Endpoint for standardization API:

```Ruby
	namespace "/standardize" do
	
		get do 

```
`GET /standardize?query=<some string>` 

```	Ruby
			if query_name = params[:query]
				response = Country.could_be_called(query_name)				
				
```

`GET /standardize/many?queries[][query]=<string>&queries[][query]=<string>`

```Ruby

			elsif queries = params[:queries]
				response = []
				unique_queries = []

				queries.each do |this_query|
```
I'm only going to return unique ones:

```Ruby
					if !this_query.blank? && !unique_queries.include?(this_query)
						unique_queries.push(this_query)
						matches = Country.could_be_called(this_query)
						response_obj = {
							query: this_query,
							countries: matches
						}
						response.push(response_obj)
					end
				end
			end
			returns_json(response || {})
		end

	end
```

#### Spreadsheets

```Ruby

	namespace "/spreadsheets" do 


		get do 
			protected!
			haml :"spreadsheets/index"
		end

		post do
			# p "Posting to spreadsheets... #{params.inspect}"
			if params[:file]
				# p "Receiving file #{params[:file]}"

				unless params[:file] && (tempfile = params[:file][:tempfile]) && (name = params[:file][:filename])
					return "Error: couldn't find your file!"
				end

				if tempfile.size <= MAX_FILE_SIZE
					this_csv_text = tempfile.read
					this_spreadsheet = Spreadsheet.create(filename: name.gsub(/\.csv$/, ''), csv_text: this_csv_text )
					# p "Ok, saved #{this_spreadsheet.filename}!"
					redirect to("/spreadsheets/#{this_spreadsheet.id}/process")
				else
					return "Error: that file is too big! Try splitting into multiple files."
				end
			end
		end
		
		get '/demo' do
			ss = Spreadsheet.demo
			redirect to("/spreadsheets/#{ss.id}/process")
		end

		namespace "/:id" do 
			before do 
				@spreadsheet = Spreadsheet.find(params[:id])
			end

			get do 
				returns_json
				@spreadsheet.to_json
			end

			put do 
				returns_json
				@spreadsheet.update_attributes! params
				@spreadsheet.to_json
			end


			get "/process" do 

				haml :"spreadsheets/show"
			end

			delete do 
				returns_json
				@spreadsheet.delete_in_5_minutes!
				@spreadsheet.to_json
			end

			delete "/now" do
				@spreadsheet.destroy
				redirect to("/spreadsheets")
			end



			get "/unique_values" do
				returns_json 
				# Starts a background process:
				@spreadsheet.find_unique_values_in(params[:field_names])

				@spreadsheet.to_json
			end
			
			get "/possible_names" do
				returns_json 

				@spreadsheet.find_possible_names_in(params[:field_names])

				@spreadsheet.to_json

			end

			post "/standardize" do

				@spreadsheet.standardize!(params[:field_names], params[:codes_to_add], params[:values_to_iso3])


				returns_json
				@spreadsheet.to_json
			end

			get "/new_csv" do
				
				if @spreadsheet.status = "csv_is_ready"
					returns_csv("#{@spreadsheet.filename}_with_countrysaurus")
					@spreadsheet.new_csv_text
				else
					returns_json
					"{ \"status\" : \"#{@spreadsheet.status}\"}"
				end

			end

		end

	end

```

#### Countries

Ruby/REST style routing for Countries:


```Ruby

	namespace "/countries" do

```

Get a country list as HTML or JSON (with `/json`):

``` Ruby
		before do

			if !CACHES.get('countries')
				CACHES.set('countries', Country.sort(:name).all)
			end

			@countries = CACHES.get 'countries'
				
		end

		get do 
			
			haml :countries
		end

		get "/json" do 
			returns_json
			"[#{@countries.map(&:to_json).join(",")}]"
		end

		get "/csv" do
			csv_header =  Country.csv_header 
			csv_body = Country.all.map(&:to_csv).join
			csv_text = csv_header + csv_body
			returns_csv("countries")
			csv_text
		end

```

Access a country at `/countries/:iso3`:

```Ruby
		namespace "/:iso3" do
			before do
				iso3 = params[:iso3].upcase
				@country = Country.find_by_iso3(iso3) # or whatever
			end

			get { haml :country }

			get "/json" do
				returns_json
				@country.to_json
			end

			get "/edit" do 
				protected!
				haml :country_edit
			end

			post do
				protected!
				@country.update_attributes!(params[:country])
				redirect to("/countries/#{@country.iso3}")
			end
```


Piping for easy access to the country's aliases:

```Ruby			
			namespace "/aliases" do
				get do
					returns_json 
					@country.aliases.to_json
				end

				get "/all" do
					returns_json 
					@country.all_aliases.to_json
				end

				post do
					returns_json
					# post { alias: "your_alias"}
					@country.add_alias!(params[:alias])
					redirect to("/countries/#{@country.iso3}")

				end

				delete do
					protected!
					returns_json
					@country.remove_alias!(params[:alias])
					@country.aliases.to_json
				end
			end
		end

	end
```


Covenience for populating the database:

```Ruby
	get "/initialize" do
		protected!
		if Country.all.count == 0
			require 'csv'
			initial_codes_file = "public/data/country_codes.csv"
			CSV.foreach(initial_codes_file, headers: true) do |row|
				# p row.to_s
				aliases = []
				aliases += row["historical_name"].split("; ")
				aliases += row["historical_iso3"].split("; ")
				aliases << row["r_name"]
				aliases << row["aiddata_name"]
				aliases << row["geonames_name"]
				aliases << row["oecd_name"]

				Country.create({
					name: row["name"],
					iso3: row["iso3"],
					iso2: row["iso2"],
					iso_numeric: row["iso_numeric"],
					aiddata_name: row["aiddata_name"],
					aiddata_code: row["aiddata_code"],
					fao_code: row["fao_code"],
					un_code: row["un_code"],
					wb_code: row["wb_code"],
					imf_code: row["imf_code"],
					fips: row["fips"],
					geonames_id: row["geonames_id"],
					oecd_name: row["oecd_name"],
					oecd_code: row["oecd_code"],
					cow_numeric: row["cow_numeric"],
					cow_alpha: row["cow_alpha"],
					aliases: aliases,
					})
			end
		end
		Country.count
	end

	get "/wipe" do
		protected!
		Country.find_each(&:destroy)
	end

	get "/touch_all_countries" do
		Country.find_each(&:save!)
	end

	get "/reset_stats" do
		protected!
		Stat.reset!
		"Stats reset..."
	end



```



