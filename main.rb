require 'dotenv/load'
require 'twitter'
require 'pry'
require 'tzinfo'
require 'aws-sdk'
require 'json'

fname = "ire_heatindex/results.json"
calculated_results = {}
bins = []
last_id = nil

# Read existing data

s3 = Aws::S3::Resource.new(
  credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY']),
  region: 'us-east-1'
)

s3_obj = s3.bucket(ENV['S3_BUCKET']).object(fname)

# if File.file?(fname)
if s3_obj.exists?
	# existing_file = File.read(fname)
	# existing_data = JSON.parse(existing_file)
	existing_data = JSON.parse(s3_obj.get.body.read)
	calculated_results = existing_data['results']
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

	new_last_id = search.first.id

	# Filter

	regex = /hot\b|heat|temp|deg|warm|melt|sun|inferno|cook|bake|cool|cold|weather|1[0-9][0-9]|🔥|🌞|☀️|🌡️/
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
			matching: matching,
			all: all,
			result: (matching == 0 && all == 0) ? 0 : ((matching*1.0) / all).round(4)
		}
	end

	# Store

	json = {
		last_id: new_last_id,
		results: calculated_results
	}

	# File.open(fname, 'w') do |f|
	# 	f.puts JSON.pretty_generate(json)
	# end

	s3_obj.put(body: JSON.pretty_generate(json), acl: 'public-read')

else

	puts "no new results"

end