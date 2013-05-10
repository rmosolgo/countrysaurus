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
	# coding: utf-8
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

### Country


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
		

		@@canonical_keys = [:name] + [
			:iso2, :iso3, :iso_numeric, 
			:aiddata_name, :aiddata_code, 
			:fao_code, :un_code, :wb_code, :imf_code, :fips,
			:geonames_id, :oecd_code, :oecd_name, 
			:cow_numeric, :cow_alpha
		].sort

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
				value = self.send(key)
```
Store the aliases WITHOUT special characters:

```Ruby
				value = value.to_s.remove_diacritics
				new_aliases << value
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
```

- Remove diacritics
- Standardize case

```Ruby
			start = Time.new
			query_name = possible_name.remove_diacritics.downcase 

			matches = []
			Country.find_each do |country|
				is_match = false
				
				country.all_aliases.each do |a|
					if a == query_name # regex match was doing bad
						is_match = true
						break
					end
				end

				if is_match	
					matches << country
				end
			end
			p "Tried #{possible_name}, found #{matches.length} matches in #{(Time.new - start).round(3)} seconds"
			matches

		end
```

Define the MongoMapper `serializable_hash` method for JSON responses:

```Ruby
		def serializable_hash(options={})
			if options == nil
				options = {}
			end
			fields_to_show = @@canonical_keys + [:aliases]
			super({only: fields_to_show}.merge(options))
		end

		def self.csv_header
			@@canonical_keys.map{|k| k.to_s}.join(",") + ",aliases" + "\n"
		end

		def to_csv
			
			csv_text = ""
			@@canonical_keys.map {|key|
				csv_text += "\"#{self.send(key)}\""
			}.join(",")

			csv_text += "\"#{self.aliases.join(";")}\""

			csv_text += "\n"

			csv_text
		end

	end

```

### Spreadsheets

This is for holding spreadsheets while they're being worked on. I'll dump it when I'm done
(to save space, if not to protect privacy...)

```Ruby
	MAX_FILE_SIZE = 10485760 # 10 MB in bytes
	class Spreadsheet
		include MongoMapper::Document
		require 'csv'
		safe # Kept getting busted on async changes
		key :filename, String
		key :csv_text, String, required: true 
		key :new_csv_text, String 
		key :file_length, Integer
		key :status, String
		key :field_names, Array
		key :unique_values, Array


		before_create :set_field_names
		def set_field_names
			self.field_names = CSV.parse(self.csv_text).first
			self.file_length = CSV.parse(self.csv_text).length
		end

```

Take some field names (array of strings) and find their unique values:

```Ruby

		def find_unique_values_in(fn)
			
			if !fn.is_a? Array 
				fn = [fn]
			end

			self.field_names = fn

			values = []
			CSV.parse(csv_text, headers: true) do |row|
				fn.each do |field|
					unless (values.include?(row[field])) || ([nil, ""].include?(row[field]))
						values << row[field]
					end
				end
			end	
			values.sort!
			self.unique_values = values 
			self.save 
			p self.unique_values
			self.unique_values
		end

		def find_possible_names_in(fn)
			if (fn != nil && fn!=self.field_names) || self.unique_values==[]
				if self.unique_values == []
					p "Requested possible names, but unique values weren't set yet..."
				else
					p "Reuqested possible names, but for different fields than unique fields"
				end

				values = self.find_unique_values_in(fn)
			else
				p "Requested possible names, field_names and values already found."
				values = self.unique_values
			end

			possible_matches = []
			values.each do |possible_name|
				match = {}
				match["value"] = possible_name
				if country = Country.could_be_called(possible_name)[0]
					country_name = country.name
					country_iso3 = country.iso3
				else
					country_name = nil
					country_iso3 = nil
				end

				match["match"] = {
					"name" => country_name,
					"iso3" => country_iso3
				}
				possible_matches << match
			end	

			possible_matches
		end
```

Implement standardization:
- names of fields to check
- values_to_iso3 is a hash whose keys are original values and whose values are desired ISO3s

```Ruby
		def standardize!(field_names, codes_to_add, values_to_iso3)
			p field_names, codes_to_add, values_to_iso3

			ready = (field_names.length > 0) && (codes_to_add.length > 0) && (values_to_iso3.keys.length > 0)
			if !ready
				self.update_attributes! status: "Failed to start."
			else
				self.update_attributes! status: "Starting."
				new_csv = CSV.generate do |csv|
```

Shovel in the header:

```Ruby
					header =CSV.parse(self.csv_text).first
					field_names.each do |field|
						codes_to_add.each do |code|
							header << "#{field}_#{code}"
						end
					end
					p header
					csv << header
```

Then do it for all rows:
```Ruby
					i = 0
					CSV.parse(csv_text, headers: true) do |row|
						i +=1
						if i % 10 == 0
							self.update_attributes! status: "Working: processed #{i}/#{self.file_length}"
						end

						field_names.each do |field|
							if (desired_iso3 = values_to_iso3[row[field]]) && (desired_country = Country.find_by_iso3(desired_iso3))
								codes_to_add.each do |code|
									row << (desired_country[code] || "")
								end
							else
								codes_to_add.length.times do 
									row << ""
								end
							end
						end
						csv << row
					end	
				end


				self.new_csv_text = new_csv
				self.status = "csv_is_ready"
			end
			self.save
		end

	end
```


### Helpers
```Ruby
	helpers do 
```

syntactic sugar for data:
```Ruby
		def returns_json
			content_type :json
		end

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
		AUTH_PAIR = ["aiddata", "a1dd4t4"]
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
					p "Ok, saved #{this_spreadsheet.filename}!"
					redirect to("/spreadsheets/#{this_spreadsheet.id}")
				else
					return "Error: that file is too big! Try splitting into multiple files."
				end
			end
		end

		namespace "/:id" do 
			before do 
				@spreadsheet = Spreadsheet.find(params[:id])
			end

			get do 
				haml :"spreadsheets/show"
			end

			delete do 
				@spreadsheet.destroy
				redirect to("/spreadsheets")
			end


			get "/unique_values" do
				returns_json 

				possible_names = @spreadsheet.find_unique_values_in(params[:field_names])

				json = JSON.dump(possible_names)
			end
			
			get "/possible_names" do
				returns_json 

				possible_names = @spreadsheet.find_possible_names_in(params[:field_names])

				json = JSON.dump(possible_names) || "{\"status\" : \"error\"}"
			end

			post "/standardize" do

				Thread.new do
					@spreadsheet.standardize!(params[:field_names], params[:codes_to_add], params[:values_to_iso3])
				end


				returns_json
				"{ \"status\" : \"started\"}"
			end

			get "/status" do
				returns_json
				"{ \"status\" : \"#{@spreadsheet.status}\"}"
			end

			get "/new_csv" do
				
				if (text = @spreadsheet.new_csv_text) && text != ""
					returns_csv("#{@spreadsheet.filename}_standardized")
					text
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
			@countries = Country.sort(:name).all
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

	get "/wipe" do
		protected!
		Country.find_each(&:destroy)
	end



```



