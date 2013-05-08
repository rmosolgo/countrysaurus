CODE ```
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
- Available names:
  - ISO2
  - ISO3
  - COW
  - UN
  - AidData Names

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
  $ bundle install
  $ heroku create
  $ git push heroku master
```

### Gems 
```Ruby
	require 'rubygems'
	require 'bundler/setup'
	require 'sinatra'
	require 'sinatra/namespace'

	require 'thin' # HTTP server
	require 'haml' # for quick views
	require 'barista' # for using :coffescript in Haml
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

### Country

  - OECD, AidData, IMF, COW, UN, ISO2, ISO3
  - Names in other languages
- aliases: 
  - other names?? Other spellings, "The", "Ivory Coast"
  - ALWAYS DOWNCASE for matches!
- User-editable -- add to aliases, not canonical names
- Sends email to me when edited

- __What about a missing country all together?__


```Ruby
	class Country
		include MongoMapper::Document

```
#### Canonical names
These specified keys hold values which the user can map into his spreadsheet. 
Only admin can change them. They are systematically combined
with the `:aliases` to implement standardization.

If you add a canonical key, make sure you add it to `@@canonical_keys`, which is used for 
generating `:all_aliases`.

```Ruby
		# If you add a key, add it to the 
		# canonical keys, too!
		key :name, String, required: true, unique: true
		key :iso2, String
		key :iso3, String, required: true, unique: true
		key :iso_numeric, Integer
		key :aiddata_name, String
		key :aiddata_code, Integer
		key :fao_code, Integer
		key :un_code, Integer
		key :wb_code, String
		key :imf_code, Integer
		key :fips, String
		key :geonames_id, Integer
		key :oecd_name, String
		key :oecd_code, Integer
		key :cow_numeric, String # since it starts with zeros
		key :cow_alpha, String
		key :aliases, Array 
		key :all_aliases, Array
		timestamps!
		before_save :remove_duplicate_aliases
		before_save :combine_fields_to_all_aliases
		

		@@canonical_keys = [
			:iso2, :iso3, :name, :iso_numeric, 
			:aiddata_name, :aiddata_code, 
			:fao_code, :un_code, :wb_code, :imf_code, :fips,
			:geonames_id, :oecd_code, :oecd_name, 
			:cow_numeric, :cow_alpha
		]

		def self.canonical_keys
			@@canonical_keys
		end

		def remove_duplicate_aliases
			self.aliases = self.aliases.uniq
		end

		def combine_fields_to_all_aliases
			new_aliases = []
			new_aliases += aliases

			@@canonical_keys.each do |key|
				new_aliases << self.send(key)
			end

			# a few programatic aliases
			new_aliases += self.programatic_aliases

			# save unique, downcased names for matching
			self.all_aliases = new_aliases.map{|a| a.respond_to?(:downcase) ? a.downcase : a}.uniq
		end

		def programatic_aliases
			downcased_name = name.downcase 
			new_aliases = []
			
			# St. Nevis 
			if downcased_name =~ /saint/ || downcased_name =~ /st\./
				new_aliases << downcased_name.gsub(/saint|st\./, 'st')
				new_aliases << downcased_name.gsub(/saint/, 'st.')
				new_aliases << downcased_name.gsub(/st\./, 'saint')	
			end

			# & // and
			if downcased_name =~ /and/ || downcased_name =~ /&/
				new_aliases << downcased_name.gsub(/and|&/, 'and')
				new_aliases << downcased_name.gsub(/and|&/, '&')
			end			

			# Dem. Rep.
			if downcased_name =~ /republic/ || downcased_name =~ /rep\./
				new_aliases << downcased_name.gsub(/republic|rep\./, 'rep')
				new_aliases << downcased_name.gsub(/republic/, 'rep.')
				new_aliases << downcased_name.gsub(/rep\./, 'republic')
			end

			if downcased_name =~ /democratic/ || downcased_name =~ /dem\./
				new_aliases << downcased_name.gsub(/democratic|dem\./, 'dem')
				new_aliases << downcased_name.gsub(/democratic/, 'dem.')
				new_aliases << downcased_name.gsub(/dem\./, 'democratic')				
			end

			if (downcased_name =~ /democratic/ || downcased_name =~ /dem\./) &&
					(downcased_name =~ /republic/ || downcased_name =~ /rep\./)
				new_aliases << downcased_name.gsub(/democratic|dem\./, 'dem').gsub(/republic|rep\./, 'rep')
				new_aliases << downcased_name.gsub(/democratic/, 'dem.').gsub(/republic/, 'rep.')
				new_aliases << downcased_name.gsub(/dem\./, 'democratic').gsub(/rep\./, 'republic')
			end

			new_aliases
		end	

		def add_alias!(new_alias)
			unless aliases.include?(new_alias)
				aliases << new_alias
				save 
			end
		end

		def remove_alias!(bad_alias)
			aliases.delete(bad_alias)
			save
		end
```

Standardize with Country.could_be_called(possible_name)
```Ruby
		def self.could_be_called(possible_name)
			query_name = possible_name.downcase 

			matches = []
			Country.find_each do |country|
				is_match = false
				
				country.all_aliases.each do |a|
					if a =~ /#{query_name}/
						is_match = true
						break
					end
				end

				if is_match	
					matches << country
				end
			end
			matches

		end
```

Define the MongoMapper `serializable_hash` method for JSON repsponses:

```Ruby
		def serializable_hash(options={})
			if options == nil
				options = {}
			end
			fields_to_show = @@canonical_keys + [:aliases]
			super({only: fields_to_show}.merge(options))
		end

	end

```

#### Helpers
```Ruby
	helpers do 
```

syntactic sugar for JSON:
```Ruby
		def returns_json
			content_type :json
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
		AUTH_PAIR = ["aiddata", "a1dd4t4"]
		def authorized?
			@auth ||=  Rack::Auth::Basic::Request.new(request.env)
			(@auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == AUTH_PAIR)
		end
```

```Ruby
	end
```

#### Routes 

##### General Routes

```Ruby
	get "/" do
		haml :home
	end
```

Endpoint for standardization API:

```Ruby
	get "/standardize" do
		returns_json
		query_name = params[:name]
		matches = Country.could_be_called(query_name)
		matches.to_json
	end
```

##### Countries

Ruby/REST style routing for Countries:


```Ruby

	namespace "/countries" do

```

Get a country list as HTML or JSON (with `/json`):

``` Ruby

		get do 
			@countries = Country.all
			haml :countries
		end

		get "/json" do 
			@countries = Country.all
			returns_json
			"[#{@countries.map(&:to_json).join(",")}]"
		end

```

Access a country at `/countries/:iso3`:

```Ruby
		namespace "/:iso3" do
			before do
				@country = Country.find_by_iso3(params[:iso3]) # or whatever
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

				post do
					returns_json
					# post { alias: "your_alias"}
					@country.add_alias!(params[:alias])
					@country.aliases.to_json

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
		if Country.all.count == 0
			require 'csv'
			initial_codes_file = "public/data/country_codes.csv"
			CSV.foreach(initial_codes_file, headers: true) do |row|
				p row.to_s
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



```



