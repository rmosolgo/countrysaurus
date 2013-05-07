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
	class Country
		include MongoMapper::Document
		# If you add a key, add it to the 
		# canonical keys, too!
		key :name, String, required: true, unique: true
		key :iso2, String
		key :iso3, String
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
		before_save :combine_fields_to_all_aliases
		@@canonical_keys = [
			:iso2, :iso3, :name, :iso_numeric, 
			:aiddata_name, :aiddata_code, 
			:fao_code, :un_code, :wb_code, :imf_code, :fips,
			:geonames_id, :oecd_code, :oecd_name, 
			:cow_numeric, :cow_alpha
		]
		def combine_fields_to_all_aliases
			new_aliases = []
			new_aliases += aliases
			@@canonical_keys.each do |key|
				new_aliases << self.send(key)
			end
			# a few programatic aliases
			new_aliases += self.programatic_aliases
			# save unique, downcased names for matching
			all_aliases = new_aliases.uniq{|a| a.respond_to?(:downcase) ? a.downcase : a}
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
		def serializable_hash(options = {})
			super({:only => @@canonical_keys}.merge(options))
		end
	end
	def returns_json
		content_type :json
	end
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
	get "/" do
		"Home"
	end
	get "/standardize" do
		"Give an alias, I give you the JSON for the country"
	end
	get "/downloads" do
		"Download country files"
	end
	namespace "/countries" do
		get do 
			Country.all.count
		end
		
		namespace "/:iso3" do
			before do
				@country = Country.find_by_iso3(params[:iso3]) # or whatever
			end
			get { "Country page!"}
			post "/alias/:new_alias" do
				@country.add_alias(params[:new_alias])
				redirect to("/countries/#{@country.iso3}")
			end
			get "/json" do
				returns_json
				@country.as_json
			end
		end
	end
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
