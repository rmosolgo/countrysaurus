	# coding: utf-8
	require 'rubygems'
	require 'bundler/setup'
	require 'sinatra'
	require 'sinatra/namespace'
	require 'thin' # HTTP server
	require 'haml' # for quick views
	require 'barista' # for using :coffescript in Haml
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
	class String
		def remove_diacritics
			self.tr(
				"ÀÁÂÃÄÅàáâãäåĀāĂăĄąÇçĆćĈĉĊċČčÐðĎďĐđÈÉÊËèéêëĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħÌÍÎÏìíîïĨĩĪīĬĭĮįİıĴĵĶķĸĹĺĻļĽľĿŀŁłÑñŃńŅņŇňŉŊŋÒÓÔÕÖØòóôõöøŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšſŢţŤťŦŧÙÚÛÜùúûüŨũŪūŬŭŮůŰűŲųŴŵÝýÿŶŷŸŹźŻżŽž", 
				"AAAAAAaaaaaaAaAaAaCcCcCcCcCcDdDdDdEEEEeeeeEeEeEeEeEeGgGgGgGgHhHhIIIIiiiiIiIiIiIiIiJjKkkLlLlLlLlLlNnNnNnNnnNnOOOOOOooooooOoOoOoRrRrRrSsSsSsSssTtTtTtUUUUuuuuUuUuUuUuUuUuWwYyyYyYZzZzZz")
		end
	end
	class Stat
		include MongoMapper::Document
		key :name, String
		key :value, Float
		def self.calculate_human_hours_saved!
			countries_standardized = Stat.find_or_create_by_name("countries_standardized").value || 0
			spreadsheet_cells_served = Stat.find_or_create_by_name("spreadsheet_cells_served").value || 0
			human_hours_saved = Stat.find_or_create_by_name("human_hours_saved")
			new_time_in_seconds = 0
			# 30 seconds per country?
			new_time_in_seconds += (countries_standardized * 30)
			# 1 second per cell
			new_time_in_seconds += (spreadsheet_cells_served * 1)
			new_time_in_hours = ((new_time_in_seconds/60)/60).round(2)
			human_hours_saved.update_attributes! value: new_time_in_hours
		end
		
		def self.increment_countries_standardized!
			cs = Stat.find_or_create_by_name("countries_standardized")
			count = cs.value || 0
			count += 1
			cs.update_attributes! value: count 
			Stat.calculate_human_hours_saved!
		end
		def self.increment_spreadsheet_cells_served!(cells=1)
			cs = Stat.find_or_create_by_name("spreadsheet_cells_served")
			count = cs.value || 0
			count += cells
			cs.update_attributes! value: count 
			Stat.calculate_human_hours_saved!
		end
		
		def self.increment_aliases_added!
			cs = Stat.find_or_create_by_name("aliases_added")
			count = cs.value || 0
			count += 1
			cs.update_attributes! value: count 
			Stat.calculate_human_hours_saved!
		end
		def self.decrement_aliases_added!
			cs = Stat.find_or_create_by_name("aliases_added")
			count = cs.value || 0
			count -= 1
			if count < 0
				count = 0
			end
			cs.update_attributes! value: count 
			Stat.calculate_human_hours_saved!
		end
	end
	class Country
		include MongoMapper::Document
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
			
			# "The"
			countries_with_the = [
				"Bahamas", "United States", "Sudan", "Ukraine",
				"United Kingdom", "United Arab Emirates", "Gambia"
			].map(&:downcase)
			if countries_with_the.include?(downcased_name)
				new_aliases << "the #{downcased_name}"
			end
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
				Stat.increment_aliases_added!
				aliases << new_alias
				save 
			end
		end
		def remove_alias!(bad_alias)
			if aliases.include?(bad_alias)
				Stat.decrement_aliases_added!
				aliases.delete(bad_alias)
				save
			end
		end
		def self.could_be_called(possible_name)
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
			if matches.length > 0
				Stat.increment_countries_standardized!
			end
			matches
		end
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
	MAX_FILE_SIZE = 10485760 # 10 MB in bytes
	class Spreadsheet
		include MongoMapper::Document
		require 'csv'
		safe # Kept getting busted on async changes
		key :filename, String
		key :csv_text, String, required: true 
		key :new_csv_text, String 
		key :file_length, Integer
		key :status, String, default: "Initialized."
		key :percent, Float, default: 0
		key :field_names, Array
		key :unique_values, Array
		key :possible_names, Array
		@@statuses = {
			deleting: "deleting",
			invalid_file: "invalid_file",
			found_unique_values: "found_unique_values",
			found_possible_matches: "found_possible_matches",
			csv_is_ready: "csv_is_ready"
		}
		def self.statuses
			@@statuses
		end
		after_create :set_field_names
		def set_field_names
			thread = Thread.new do
				begin
					self.update_attributes! status: "Parsing CSV and finding field names."
					self.field_names = CSV.parse(self.csv_text).first
					self.file_length = CSV.parse(self.csv_text).length
					self.status = "valid_file"
				rescue
					self.status =  "invalid_file"
					self.delete_in_5_minutes!
				end
				self.save
			end
			thread
		end
		def delete_in_5_minutes!
			if self.status != "deleting"
				self.update_attributes! status:  "deleting"
				Thread.new do
					sleep(5.mins)
					if self && self.status == 'deleting'	
						self.destroy
					end
				end
			end
		end
		def find_unique_values_in(fn, then_find_names=false)
			self.update_attributes! status: "Finding unique values in #{self.file_length} rows.", percent: 0
			thread = Thread.new do
				if !fn.is_a? Array 
					fn = [fn]
				end
				self.field_names = fn
				values = []
				i = 0.0
				CSV.parse(csv_text, headers: true) do |row|
					i += 1
					if i % 10 == 0
						self.update_attributes! percent: (i/self.file_length) * 100
					end
					fn.each do |field|
						unless (values.include?(row[field])) || ([nil, ""].include?(row[field]))
							values << row[field]
						end
					end
				end	
				values.sort!
				self.update_attributes! unique_values: values, status: "found_unique_values", percent: 100
				
				if then_find_names
					self.find_possible_names_in(fn)
				end
			end
			thread
		end
		def find_possible_names_in(fn)
			fn = fn || self.field_names
			ready = (self.unique_values != nil)
			if ready
				self.update_attributes! status: "Finding names for #{self.unique_values.length} values."
				thread = Thread.new do
					values = self.unique_values
					possible_matches = []
					i = 0.0
					values_length = values.length
					values.each do |possible_name|
						i += 1.0
						self.update_attributes! percent: (i/values_length) * 100
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
					self.update_attributes! possible_names: possible_matches, status: "found_possible_matches", percent: 100
				end
			else
				thread = self.find_unique_values_in(fn, true)
			end
			thread
		end
		def standardize!(field_names, codes_to_add, values_to_iso3)
			p field_names, codes_to_add, values_to_iso3
			ready = (field_names.length > 0) && (codes_to_add.length > 0) && (values_to_iso3.keys.length > 0)
			if !ready
				self.update_attributes! status: "Failed to start."
			else
				thread = Thread.new do 
					cells_to_add = field_names.length * codes_to_add.length * self.file_length
					self.update_attributes! status: "Adding #{cells_to_add} values to your spreadsheet."
					new_csv = CSV.generate do |csv|
						header =CSV.parse(self.csv_text).first
						field_names.each do |field|
							codes_to_add.each do |code|
								header << "#{field}_#{code}"
							end
						end
						p header
						csv << header
						i = 0.0
						CSV.parse(csv_text, headers: true) do |row|
							i +=1
							if i % 10 == 0
								self.update_attributes! percent: (i/self.file_length)*100
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
					self.update_attributes! new_csv_text: new_csv, status: "csv_is_ready", percent: 100
					Stat.increment_spreadsheet_cells_served!(cells_to_add)
				end
			end
		end
		def serializable_hash(options={})
			if options == nil
				options = {}
			end
			fields_to_show = [
				:filename, :file_length, :_id, :status, :percent,
				:field_names, :unique_values, :possible_names
			]
			exclude = [:csv_text, :new_csv_text]
			super({except: exclude}.merge(options))
		end
	end
	helpers do 
		def returns_json
			content_type :json
		end
		def returns_csv(filename='data')
			content_type 'application/csv'
			attachment "#{filename}.csv"
		end
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
	end
	get "/" do
		haml :home
	end
	get "/standardize" do
		returns_json
		query_name = params[:name]
		matches = Country.could_be_called(query_name)
		matches.to_json
	end
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
					redirect to("/spreadsheets/#{this_spreadsheet.id}/process")
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
				# 1) User: 			Choose field names
				# 2) Background: 	Find Unique Values
				# 3) Background: 	Match those values
				# 4) User: 			Confirm those matches
				# 5) User: 			Pick codes to add
				# 6) Background: 	Create new CSV
				# 7) User: 			Download CSV
				# 8) Background: 	Delete CSV in 5 mins
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
	namespace "/countries" do
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
