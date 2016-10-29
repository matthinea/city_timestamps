require 'twitter_ebooks'
require 'json'
require 'timezone'
require 'active_support/all'
require 'httparty'


class MyBot < Ebooks::Bot

  def configure
    self.consumer_key = ENV['consumer_key']
    self.consumer_secret = ENV['consumer_secret']

    # Users to block instead of interacting with
    # self.blacklist = ['tnietzschequote']

    # Range in seconds to randomize delay when bot.delay is called
    # self.delay_range = 1..6

    @@cities = JSON.parse(File.read("cities.json"))
    @@all_cities = JSON.parse(File.read("world-cities.json"))

    Timezone::Lookup.config(:google) do |c|
      c.api_key = ENV['google_maps_api_key']
    end

  end

  def on_startup
    # See https://github.com/jmettraux/rufus-scheduler
    scheduler.every '151m' do
      if rand(10) < 8
        tweet_major_city
      else
        tweet_minor_city
      end
    end
  end

  def on_message(dm)
    reply_with_timestamp(dm)
    # reply_using_cities(dm) || reply_using_world_cities(dm)
  end

  def on_follow(user)
    # follow(user.screen_name)
  end

  def on_mention(tweet)
    reply_with_timestamp(tweet)
    # reply_using_cities(tweet) || reply_using_world_cities(tweet)
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
    city_name = city['name']
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
    city_name = get_city_name(message)
    coords = get_coords_from_primary_file(city_name)
    if coords
      local_time = get_pretty_local_time(coords[0], coords[1])
      reply(message, reply_text(city_name, local_time))
    else
      reply_using_secondary_file(city_name, message)
    end
  end

  def get_pretty_local_time(latitude, longitude)
    local_timezone = Timezone.lookup(latitude, longitude)
    local_time = local_timezone.utc_to_local(Time.now.utc)
    local_time.strftime("%-l:%M%P, %a. %B %d, %Y")
  end

  def get_coords_from_primary_file(city_name)
    @@cities.each do |key, value|
      if value['city'] == city_name
        lat = value['lat']
        lon = value['lon']
        return [lat, lon]
      end
    end
    false
  end

  def reply_using_secondary_file(city_name, message)
    geoname_id = get_geoname_id(city_name)    
    if geoname_id
      coords = get_coordinates(geoname_id)
      local_time = get_pretty_local_time(coords[0], coords[1])
      reply(message, reply_text(city_name, local_time))
    end
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

  def get_city_name(dm_or_mention)
    dm_or_mention.text.gsub("@city_timestamps", "").chomp.strip.titleize
  end

  def get_geoname_id(city_name)
    @@all_cities.each do |city|
      if city['name'] == city_name 
        puts city
        return city['geonameid']
      end
    end
    false
  end

end


MyBot.new("city_timestamps") do |bot|
  bot.access_token = ENV['access_token']
  bot.access_token_secret = ENV['access_token_secret']
end
