require 'twitter_ebooks'
require 'json'
require 'timezone'
require 'httparty'
require 'dotenv'
require_relative 'us_states'

class MyBot < Ebooks::Bot

  def configure
    Dotenv.load   

    self.consumer_key = ENV['CONSUMER_KEY']
    self.consumer_secret = ENV['CONSUMER_SECRET']

    # Users to block instead of interacting with
    # self.blacklist = ['tnietzschequote']

    # Range in seconds to randomize delay when bot.delay is called
    # self.delay_range = 1..6

    @@cities = JSON.parse(File.read("cities.json"))
    @@all_cities = JSON.parse(File.read("world-cities.json"))

    Timezone::Lookup.config(:google) do |c|
      c.api_key = ENV['GOOGLE_MAPS_API_KEY']
    end

  end

  def on_startup
    # See https://github.com/jmettraux/rufus-scheduler
    scheduler.every '10s' do |job|
      if rand(10) < 8
        tweet_major_city
      else
        tweet_minor_city
      end
      # tweet every ~1-3.5 hours
      job.next_time = Time.now + rand(60..200) * 61
    end
  end

  def on_message(dm)
    reply_with_timestamp(dm)
  end

  def on_follow(user)
    # follow(user.screen_name)
  end

  def on_mention(tweet)
    reply_with_timestamp(tweet)
  end

  def on_timeline(tweet)
    # reply(tweet, "nice tweet")
  end

  def on_favorite(user, tweet)
    # follow(user.screen_name)
  end

  def on_retweet(tweet)
    # follow(tweet.user.screen_name)
  end



  private

  def tweet_major_city
    city = @@cities[@@cities.keys.sample]
    city_name = city['city']
    latitude = city['lat']
    longitude = city['lon']
    local_time = get_pretty_local_time(latitude, longitude)
    tweet(tweet_text(city_name, local_time))
  end

  def tweet_minor_city
    city = @@all_cities.sample
    city_name = "#{city['name']}, #{city['subcountry']}"
    geoname_id = city['geonameid']   
    coords = get_coordinates(geoname_id)
    local_time = get_pretty_local_time(coords[0], coords[1])
    tweet(tweet_text(city_name, local_time))
  end

  def reply_text(city_name, local_time)
    "The time in #{city_name} is #{local_time}."
  end

  def tweet_text(city_name, local_time)
    "The current time in #{city_name} is #{local_time}"
  end

  def reply_with_timestamp(message)
    if message.text.match(",")
      reply_using_region(message)
    else
      city_name = get_city_name(message)
      coords = get_coords_from_primary_file(city_name)
      if coords
        local_time = get_pretty_local_time(coords[0], coords[1])
        reply(message, reply_text(city_name, local_time))
      else
        reply_using_secondary_file(city_name, message)
      end
    end
  end

  def reply_using_region(message)
    data = message.text.split(",").map{|m|m.chomp.strip}
    city = data[0]
    area = parse_country_codes(data[1])
    @@all_cities.each do |value|
      if value['country'].casecmp(area) == 0 || value['subcountry'].casecmp(area) == 0
        if value['name'].casecmp(city) == 0
          coords = get_coordinates(value['geonameid'])
          local_time = get_pretty_local_time(coords[0], coords[1])
          city_name = "#{value['name']}, #{value['subcountry']}"
          reply(message, reply_text(city_name, local_time))
          return 
        end 
      end
    end
  end

  def reply_using_secondary_file(city_name, message)
    geoname_id = get_geoname_id(city_name)    
    if geoname_id
      coords = get_coordinates(geoname_id)
      local_time = get_pretty_local_time(coords[0], coords[1])
      reply(message, reply_text(city_name, local_time))
    end
  end

  def get_pretty_local_time(latitude, longitude)
    local_timezone = Timezone.lookup(latitude, longitude)
    local_time = local_timezone.utc_to_local(Time.now.utc)
    local_time.strftime("%-l:%M%P, %a. %B %d, %Y")
  end

  def get_coords_from_primary_file(city_name)
    @@cities.each do |key, value|
      if value['city'].casecmp(city_name) == 0
        lat = value['lat']
        lon = value['lon']
        return [lat, lon]
      end
    end
    false
  end

  def get_coordinates(geoname_id)
    base_uri = "http://api.geonames.org/get?geonameId="
    username = "matthewhinea"
    request = base_uri + geoname_id + "&username=" + username
    response = HTTParty.get(request)

    lat = response['geoname']['lat']
    long = response['geoname']['lng']
    [lat, long]
  end

  def get_city_name(message)
    message.text.gsub("@city_timestamps", "").chomp.strip
  end

  def get_geoname_id(city_name)
    @@all_cities.each do |city|
      if city['name'].casecmp(city_name) == 0
        puts city
        return city['geonameid']
      end
    end
    false
  end

  def parse_country_codes(area)
    case area
    when "US", "USA", "United States of America"
      return "United States"
    when "UAE"
      return "United Arab Emirates"
    when "UK"
      return "United Kingdom"
    else
      return US_STATES[area.to_sym] if US_STATES[area.to_sym]
      return area
    end
  end

end


MyBot.new("city_timestamps") do |bot|
  bot.access_token = ENV['ACCESS_TOKEN']
  bot.access_token_secret = ENV['ACCESS_TOKEN_SECRET']
end
