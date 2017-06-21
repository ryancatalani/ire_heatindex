require 'dotenv/load'
require 'twitter'
require 'tzinfo'
require 'aws-sdk'
require 'json'
require 'httparty'
# require 'pry'

USE_LOCAL = true

fname = "results.json"
calculated_results = {}
bins = []
last_id = nil

# Read existing data

if USE_LOCAL
	if File.file?(fname)
		existing_file = File.read(fname)
		existing_data = JSON.parse(existing_file)	
	end
else
	s3 = Aws::S3::Resource.new(
	  credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY']),
	  region: 'us-east-1'
	)

	s3_obj = s3.bucket(ENV['S3_BUCKET']).object("ire_heatindex/#{fname}")

	if s3_obj.exists?
		existing_data = JSON.parse(s3_obj.get.body.read)
	end
end

if existing_data
	calculated_results = Hash[existing_data['results'].map do |r|
		time = r.delete('time')
		[time, r]
	end]
	last_id = existing_data['last_id']
end

# Set up bins in format YYYYMMDD-HH

start_day = 20170621
tz = TZInfo::Timezone.get('America/Phoenix')
start_time = tz.local_to_utc(Time.parse(start_day.to_s))
hours = ((Time.now - start_time) / (60 * 60)).ceil

hours.times do |i|
	day = ((i+1) / 24).to_i
	hour = i % 24
	hour_str = "%02d" % hour
	dayhour = "#{start_day + day}-#{hour_str}"
	bins << dayhour
end

# Search

client = Twitter::REST::Client.new do |config|
  config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
  config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
  config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
  config.access_token_secret = ENV['TWITTER_ACCESS_SECRET']
end

search_options = {
	result_type: 'recent'
}
search_options[:since_id] = last_id unless last_id.nil?
search = client.search('#ire17', search_options)

if search.count > 0

	last_id = search.first.id

	# Filter

	regex = /\bhot\b|heat|temp|deg|warm|melt|sun|lava|inside|outside|fire|\bac\b|a\.c\.|forecast|inferno|cook|bake|cool|cold|weather|1[0-9][0-9]|🔥|🌞|☀️|🌡️/
	matching = search.select{|t| t.text =~ regex }
	matching_binned = matching.group_by{|t| tz.utc_to_local(t.created_at).strftime("%Y%m%d-%H") }
	matching_totals = Hash[matching_binned.map{|k,v| [k, v.count]}]

	# Calculate

	all_binned = search.group_by{|t| tz.utc_to_local(t.created_at).strftime("%Y%m%d-%H") }
	all_totals = Hash[all_binned.map{|k,v| [k, v.count]}]

	bins.each do |dayhour|
		result = 0

		matching = matching_totals[dayhour] || 0
		all = all_totals[dayhour] || 0

		if !calculated_results[dayhour].nil?
			previous = calculated_results[dayhour]
			matching += previous['matching'] || 0
			all += previous['all'] || 0
		end

		calculated_results[dayhour] = {
			'matching' => matching,
			'all' => all,
			'result' => (matching == 0 && all == 0) ? 0 : ((matching*1.0) / all).round(4)
		}
	end

else
	puts "no new twitter search results"
end

# Get weather

begin
	weather_res = HTTParty.get("https://api.darksky.net/forecast/#{ENV['DARK_SKY_API_KEY']}/33.45,-112.066667")
	current_temp = JSON.parse(weather_res.body)['currently']['temperature']
rescue
	puts "error getting weather"
end

# Create text

last_tw_value = calculated_results[calculated_results.keys.last]['result']
last_tw_temp = ((Math.sqrt(last_tw_value) * 100) * 1.8 + 32).round
last_tw_temp_greater = last_tw_temp > current_temp

display_text = 'Right now in Phoenix, it’s '
display_text += current_temp.round.to_s
display_text += '°F, '
display_text += last_tw_temp_greater ? 'but ' : 'and '
display_text += 'on IRE Twitter, it feels '
display_text += last_tw_temp_greater ? 'more like ' : 'like only '
display_text += last_tw_temp.to_s
display_text += '°F.'

# Store

json = {
	last_id: last_id,
	current_temp: current_temp,
	display_text: display_text,
	labels: bins,
	results: calculated_results.map{|k,v| { time: k }.merge(v) }
}

if USE_LOCAL
	File.open(fname, 'w') do |f|
		f.puts JSON.pretty_generate(json)
	end
	puts "wrote file locally"
else
	s3_obj.put(body: JSON.pretty_generate(json), acl: 'public-read')
	puts "wrote file to s3"
end