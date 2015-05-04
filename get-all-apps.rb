# This script creates a CSV with android_ids and google play store URLs in your working directory.

require 'mysql2'
require 'csv'
require 'json'
require 'time'
require 'set'
require 'rubygems'
require 'date'

# Query all of the amazon app titles
# Add these titles to a set

# Create new mysql2 client
db = Mysql2::Client.new(:host => "db.appbackr.com", :username => "anil", :password => "ewb@rK0ns", :database => "finapps")

# Query to get all the android ids with google play urls from xchange_project
all_q = "select android_id, url FROM xchange_project WHERE url is not null"

puts "Querying for all the app info..."

apps_hsh = db.query(all_q)
total = apps_hsh.count

puts "...done!"

# Define the date as year and month
datestring = Date.today.strftime("%Y-%m")
# Open the output file
outfile = File.open(("#{datestring}-all_apps.csv"), "w")

# Write the header on the output file
outfile.puts ["app_id", "url"].to_csv

puts "Writing to output file..."

# Create a visible spinner in the terminal
counter = [0]
spinner = Thread.new {
	str = ""

	while 1
		('/-\\|' * 1000).each_char { |c| str = "(#{counter[0]} / #{total}) #{c}"; print str; sleep(0.1); print "\b" * str.length }	
	end
}

# Write to the output file
apps_hsh.each do |row|
	counter[0] += 1
	outfile.puts [row['android_id'], row['url']].to_csv
end

# Kill spinner thread
spinner.exit
puts ""
puts "==="
puts "...done!"


# Close the output file
outfile.close
