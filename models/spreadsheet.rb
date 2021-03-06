# compiled from models/spreadsheet.litrb by literate-ruby
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
	timestamps!
	def self.demo
		
		unless new_demo = Spreadsheet.find_by_filename("Countrysaurus_Demo")
			new_demo = Spreadsheet.create(
				filename: "Countrysaurus_Demo", 
				field_names: ["country", "year"],
				csv_text: "country,year\nAlgeria,2001\n\"Macedonia, FYR\",2002\n" +
					"DR Congo,2004\nThe Bahamas,2006\nBahamas,2006\nBahama Is.,2007"
			)
		end
		new_demo
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
		if self.status != "deleting" && self.status != "invalid_file"
			
			if self.status != "invalid_file"
				self.update_attributes! status:  "deleting"
			end
			Thread.new do
				sleep(5.mins)
				if self && (self.status == 'deleting' || self.status == "invalid_file")
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
					this_value = row[field]
					next if [nil,""].include? this_value
					next_lesser_item = values.bsearch{|v| v <= this_value}
					next if next_lesser_item == this_value
					if next_lesser_item_position = values.index(next_lesser_item)
						values.insert(next_lesser_item_position, this_value)
					else
						values << this_value
					end
				end
			end	
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
				if self.filename == "Countrysaurus_Demo"
					increment_stats = false
				else
					increment_stats = true
				end
				values.each do |possible_name|
					i += 1.0
					self.update_attributes! percent: (i/values_length) * 100
					match = {}
					match["value"] = possible_name
					if country = Country.could_be_called(possible_name, increment_stats: increment_stats)[0]
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
		# p field_names, codes_to_add, values_to_iso3
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
				unless self.filename == "Countrysaurus_Demo"
					Stat.increment_spreadsheet_cells_served!(cells_to_add)
				end
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
