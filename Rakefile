
desc "Bundle install"
task :bundle_install do
	bundle_install = %{bundle install}
	# sh bundle_install
end

desc "'Compile' literate ruby to app.rb (for Heroku, for example)"
task :compile do

	LITRB_EXTENSIONS = %w{litrb md}
	
	def to_ruby(filename)
		filename.downcase!

		unless (this_ext = filename.split(".").last) && LITRB_EXTENSIONS.include?(this_ext)
			raise SyntaxError, "Must be .litrb or .md, but this file is #{filename}" 
		end
		
		if filename == "readme.md"
			ruby_file = "app.rb"
		else
			ruby_file = filename.sub(/(md|litrb)$/, "rb")
		end


		# kill the old version
		File.delete(ruby_file) if File.exists?(ruby_file)
		# make a new version!
		open(ruby_file, "wb") do |file|
			file.puts %{# compiled from #{filename} by literate-ruby}
			open(filename).each_line do |line|
				if line[0] == "\t"
					file.puts line[1..-1]
				elsif line[0,4] == "    "
					file.puts line[4..-1]
				end
				# else it's not code!
			end
		end

		return ruby_file

	end

	LITRB_EXTENSIONS.each do |extension|

		files_to_compile = File.join("**", "*.#{extension}")
		Dir.glob(files_to_compile).each do |file|
			ruby_file = to_ruby(file)
			p "Compiled #{file} to #{ruby_file}"
		end
	end

	puts "Finished compiling." 

end

desc "Compile and run the app"
task :run => [:compile] do

	run_app = %{ruby app.rb}
	sh run_app
	
end

namespace :github do 
	desc "Compile and push to github (requires git remote origin)"
	task :push, [:msg] => [:compile] do |t, args|
		msg = args.msg || "rake github:push"
		commit_and_push = [
			%{git add . },
			%{git commit -am "#{msg}"},
			%{git push origin master},
		]

		commit_and_push.each{ |cmd| sh cmd}
	end
end

namespace :heroku do
	desc "Compile and Deploy to Heroku (requires git remotes: heroku and origin)"
	task :deploy, [:msg] => [:bundle_install, :compile] do |t, args|
		msg = args.msg || "rake heroku:deploy"
		commit_and_deploy = [
			%{git add . },
			%{git commit -am "#{msg}"},
			%{git push origin master}, # if i knew how pass :msg to rake github:push, I would.
			%{git push heroku master}
		]

		commit_and_deploy.each{ |cmd| sh cmd}

	end
end

desc "Visit self -- for keeping awake"
task :visit_self do
	require 'open-uri'
	app_url = "" # put your Heroku url here
	open(app_url)
end
