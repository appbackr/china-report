# This script compares the namespaces for all baidu apps (apk91) to known SDK namespaces
# and reports matches. It also checks for android ID matches with our google play scrape
# and lists a google play store URL if a match is found.

# Final output is a CSV listing:
# SDK, Android ID, App Title, URL on China Store, and Google Play URL

require 'mysql2'
require 'csv'
require 'json'
require 'time'
require 'set'
require 'rubygems'
require 'date'

# Check for numeric value
def is_numeric?(obj) 
   obj.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/) == nil ? false : true
end

# Create new mysql2 client
db = Mysql2::Client.new(:host => "db.appbackr.com", :username => "anil", :password => "ewb@rK0ns", :database => "finapps")

china_table = "xchange2_eval_android_china_pkg_apk91"
base_url = "http://apk.91.com"

# Get datestring
datestring = Date.today.strftime("%Y-%m")

# Build a hash from the local file
gps_hsh = Hash.new
puts ">> Prepare local app data..."
CSV.foreach("#{datestring}-all_apps.csv") do |row|
	id = row[0]
	url = row[1]

	gps_hsh[id] = url
end
puts "<< ...done."

# Define queries
count_q = "select count(distinct(pkg_id)) from #{china_table}" #Get the count of the different titles
row_q = "select count(pkg_id) from #{china_table}"
get_q = "SELECT pkg_id, namespace from #{china_table}"#Get the titles for comparison

get_q = "SELECT pkg_id, namespace, title, app_id, url from xchange2_eval_android_china_pkg_apk91 cn_pkg
INNER JOIN scrape_china_apk91 scrp ON scrp.app_id = cn_pkg.pkg_id
LIMIT 90000000"

# Get namespaces for crosswalk
sdk_q = "SELECT sdk_title, mixrank_slug_id, namespaces FROM xchange2_eval_android_sdk
		WHERE mixrank_slug_id LIKE 'apache-cordova'
		OR mixrank_slug_id LIKE 'phonegap'
		OR mixrank_slug_id LIKE 'appmobi'
		OR mixrank_slug_id LIKE 'crosswalk'
		OR mixrank_slug_id LIKE 'cocos2d'"

puts ">> Query crosswalk namespaces..."
sdks_arr = db.query(sdk_q).to_a
puts "<< ...done."
sdk_hsh = Hash.new([])

sdks_arr.each do |row|
	sdk_hsh[row['mixrank_slug_id']] = JSON.parse(row['namespaces'])['namespaces']
	#sdk_hsh[row['mixrank_slug_id']].push(row['namespace'])
end

# Get the total and the count of unique apps in the table
total = db.query(count_q).to_a[0]["count(distinct(pkg_id))"]
titles = []
puts ">> Query China Table..."
titles = db.query(get_q).to_a
puts "<< ...done."
puts "Inspecting #{titles.length}..."
row_count = db.query(row_q).to_a[0]["count(pkg_id)"]

puts "#{total} China Apps"
puts "#{row_count} rows"
done_hsh = {'apache-cordova'=>[], 'phonegap'=>[], 'appmobi'=>[], 'crosswalk'=>[], 'cocos2d'=>[]}
id_data_hsh = {}

titles.each do |row|
	id = row['pkg_id']
	nspace = row['namespace']
	if is_numeric?(id)
		id = row['app_id']
	end
	#nspace = "org.cocos2d.realblock"
	#puts "checking #{id}, |#{nspace}|"

	sdk_hsh.each do |slug, sdk|
		if sdk.include?(nspace)
			#puts "#{id} is using #{slug}"
			if !done_hsh[slug].include?(id)
				done_hsh[slug].push(id)
				if !id_data_hsh.has_key?(id)
					url = "#{base_url}#{row['url']}"
					app_title = row['title']
					#puts "#{url}, #{app_title}"
					id_data_hsh[id] = {'url' => url, 'app_title' => app_title}
				end
			end
		end
	end
end

puts "==="

# Output file
outfile = File.open(("#{datestring}-baidu_apps.csv"), "w")

outfile.puts ["sdk", "app_id", "title", "china_url", "gplay_url"].to_csv

matched_count = 0
no_url_count = 0
match_hsh = Hash.new(0)
done_hsh.each do |key, val|
	if val.length == 0
		puts "Nothing for #{key}"
	else
		val.each do |v|
			#puts "#{v} is using #{key}"
			url = gps_hsh[v]

			if url.nil?
				url = "NA"
				no_url_count += 1
			end

			final = [key, v, id_data_hsh[v]['app_title'], id_data_hsh[v]['url'], url]
			outfile.puts final.to_csv
			matched_count += 1
			match_hsh[key] += 1
		end
	end

	puts "--"
end

outfile.close

url_count = matched_count - no_url_count
puts "Matched #{matched_count} apps"
puts "Google Play Matches: #{url_count}"
match_hsh.each do |key,val|
	puts "#{key}: #{val}"
end




