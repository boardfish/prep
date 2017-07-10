require 'net/http'
require 'json'
require 'octokit'
require 'twitter'
require 'date'

# Globals
@services = {
    'GitHub' => {
      "verificationMethod" => method(:verify_git),
    },
    'Twitter' => {
      "verificationMethod" => method(:verify_twitter),
    }
}


def verify_git(id)
  user = Octokit.user id
rescue
  puts 'Not found!'
  return false
else
  puts 'Account exists.'
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

def add_ID(servicename)
  print "User's #{servicename} ID: "
  id = gets.chomp
  idfound = verificationmethods[service].call(id)
  if idfound
    return id
  else
    return false
  end
end

def verify_git_repository(user, project)
  url = "https://api.github.com/repos/#{user}/#{project}"
  begin
    uri = URI(url)
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

def get_project_activity(user, project)
  eventList = []
  url = "https://api.github.com/repos/#{user}/#{project}/events"
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

def parse_all_tweets(user, eventList)
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
end

def team_config
  team = {}
  while username != 'exit'
    puts
    id = add_ID("GitHub")
    next if id == false
    team[id] = {}
    team[id]["GitHub"] == id
    team[id]["Twitter"] == add_ID("Twitter")
  end
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
  puts 'Date and time of end:'
  endtime = Time.parse(gets.chomp)
  [starttime, endtime]
end

# Console flags
verbose = ARGV.include? '-v'
latex = ARGV.include? '-l'

team_config(userlist, servicelist)
master, name = project_config
servicelist.each do |service, name|
  name.each do |_name, username|
    case service
    when 'Twitter'
      parse_all_tweets(username, eventList)
      # when "GitHub"
      # method_for_individual_user_activity?
      # This section is a case so that as new APIs are added it can be expanded!
    end
  end
end
get_project_activity(master, name, eventList)
starttime, endtime = time_constraint_config

eventlistSorted = eventList.sort_by { |k| k[:time] } # Sort events by time
eventlistSorted.each do |event|
  eventWithinTimeframe = false
  event.each do |key, value|
    if key == :time && value > starttime && value < endtime
      eventWithinTimeframe = true
    end
    next unless eventWithinTimeFrame
    puts "#{key}: #{value}" if verbose
    # write to latex file if latex
    # write to HTML template if HTML
  end
end
