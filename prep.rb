require 'net/http'
require 'json'
require 'octokit'
require 'twitter'
require 'date'

def verify_git(id)
  user = Octokit.user id
rescue
  return false
else
  return true
end

def verify_twitter(id)
  url = "https://twitter.com/users/username_available?username=#{id}"
  begin
    uri = URI(url)
    response = Net::HTTP.get(uri)
  rescue
    puts 'Connection to Twitter failed.'
  end
  x = JSON.parse(response)['reason']
  x == 'taken'
end

def add_ID(service, id)
  idfound = @services[service]['verificationMethod'].call(id)
  idfound
end

def verify_git_repository(user, project)
  uri = URI("https://api.github.com/repos/#{user}/#{project}")
  begin
    response = Net::HTTP.get(uri)
  rescue
    puts 'Connection to GitHub failed.'
    return false
  end
  begin
    x = JSON.parse(response)['name']
  rescue
    return false
  else
    return true
  end
end

def get_user_activity(user)
  eventList = []
  url = "https://api.github.com/users/#{user}/events"
  begin
    uri = URI(url)
    response = Net::HTTP.get(uri)
    data = JSON.parse(response)
  rescue
    puts 'Connection to GitHub failed.'
  end
  begin
    data.each do |entry|
      eventTime = Time.parse(entry['created_at'])
      eventLogin = entry['actor']['login']
      info = entry['payload']
      eventText = ''
      case entry['type']
      when 'IssuesEvent'
        eventText = "Issue ##{info['issue']['number']} #{info['action']}: #{info['issue']['title']}"
      when 'IssueCommentEvent'
        eventText = puts "Comment on issue ##{info['issue']['number']} #{info['action']}: #{info['issue']['body']}"
      when 'PushEvent'
        info['commits'].each do |commit|
          eventText += "Commit pushed: #{commit['message']}\n"
          # SOMETHING'S WRONG HERE
        end
      when 'ForkEvent'
        eventText = "Forked by #{info['forkee']['owner']['login']} at #{info['forkee']['full_name']}"
      when 'CreateEvent'
        eventText = "#{info['ref_type'].capitalize} created"
        case info['ref_type']
        when 'repository'
          eventText += '.'
        when 'branch'
          eventText += ": #{info['ref']}."
        end
      when 'DeleteEvent'
        eventText = "#{info['ref_type'].capitalize} deleted"
        case info['ref_type']
        when 'repository'
          eventText += '.'
        when 'branch'
          eventText += ": #{info['ref']}."
        end
      when 'PullRequestEvent'
        eventText = "Pull request ##{info['number']} #{info['action']}: #{info['pull_request']['title']}"
      end
      event = { time: eventTime, login: eventLogin, text: eventText }
      eventList.push(event)
    end
  end
  eventList
end

def parse_all_tweets(user)
  eventList = []
  def collect_with_max_id(collection = [], max_id = nil, &block)
    response = yield(max_id)
    collection += response
    response.empty? ? collection.flatten : collect_with_max_id(collection, response.last.id - 1, &block)
  end

  client = Twitter::REST::Client.new do |config|
    config.consumer_key        = 'UcwZpiYDRCOksbZd9zSwMjp67'
    config.consumer_secret     = '2HM7XKXO8UuvfX3ySwjYN92DbzjXqufJKhuGrYaa4PB6XpD5SH'
    config.access_token        = '864230949894205444-tv4xG08aElBlNlwb1KOprAEKFFWCzFE'
    config.access_token_secret = 'wwEJIUWqaZFlgU2ZUJ70LF7RGGSDOsgnlcdVoCvJdADKO'
  end

  def client.get_all_tweets(user)
    collect_with_max_id do |max_id|
      options = { count: 50, include_rts: true }
      options[:max_id] = max_id unless max_id.nil?
      user_timeline(user, options)
    end
  end

  recent_tweets = client.get_all_tweets(user)

  recent_tweets.each do |tweet|
    eventLogin = user
    eventTime = tweet.created_at
    eventText = tweet.full_text
    event = { time: eventTime, login: eventLogin, text: eventText }
    eventList.push(event)
  end
  eventList
end

# Globals
@services = {
  'GitHub' => {
    'verificationMethod' => method(:verify_git),
    'getMethod' => method(:get_user_activity)
  },
  'Twitter' => {
    'verificationMethod' => method(:verify_twitter),
    'getMethod' => method(:parse_all_tweets)
  }
}

def team_config
  team = {}
  username = ''
  while username != ':q'
    username = gets.chomp
    id = add_ID('GitHub', username)
    next if id == false
    team[username] = { 'GitHub' => username }
    # if :q, next. Otherwise, verify and add
    twitterVerified = false
    until twitterVerified
      print "User's Twitter username: "
      twitterHandle = gets.chomp
      if twitterHandle == ':q'
        team[username]['Twitter'] == false
        twitterVerified = true
        next
      else
        team[username]['Twitter'] == twitterHandle if add_ID('Twitter', twitterHandle)
      end
    end
  end
  team
end

# Verifies github project exists
def project_config
  verified = false
  until verified
    puts 'Project name:'
    project = gets.chomp
    puts 'Repo owner:'
    user = gets.chomp # Currently username, should select from user list?
    verified = verify_git_repository(user, project)
  end
  [user, project]
end

# Sets time constraints
def time_constraint_config
  puts 'Date and time of start:'
  starttime = Time.parse(gets.chomp)
  puts starttime
  puts 'Date and time of end:'
  endtime = Time.parse(gets.chomp)
  [starttime, endtime]
end

# Console flags
verbose = ARGV.include? '-v'
latex = ARGV.include? '-l'

team = team_config
master, name = project_config
eventList = []
puts
print team
@services.each do |service, methods|
  team.each do |user, _usernames|
    next if team[user][service].nil? || team[user][service].empty?
    eventList += methods['getMethod'].call(team[user][service])
    puts
    print eventList
  end
end
starttime, endtime = time_constraint_config

eventlistSorted = eventList#.sort_by { |k| k["time"] } # Sort events by time
eventlistSorted.each do |event|
  eventWithinTimeframe = false
  event.each do |key, value|
    if key == :time && value > starttime && value < endtime
      eventWithinTimeframe = true
    end
    next unless eventWithinTimeframe
    puts "#{key}: #{value}" #if verbose
    # write to latex file if latex
    # write to HTML template if HTML
  end
end
