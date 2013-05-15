

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
