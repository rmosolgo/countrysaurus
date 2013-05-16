

desc "'Compile' literate ruby to app.rb (for Heroku, for example)"
task :compile do
	bundle_install = %{bundle install}
	sh bundle_install

	compile_readme_to_app = %{rm app.rb; cat readme.md | grep "^	" > app.rb}
	sh compile_readme_to_app
	puts "Compiled to app.rb" 
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
	task :deploy, [:msg] => [:compile] do |t, args|
		msg = args.msg || "rake heroku:deploy"
		commit_and_deploy = [
			%{git add . },
			%{git commit -am "#{msg}"},
			%{git push origin master},
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