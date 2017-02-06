require 'net/http'
require 'json'
require 'octokit'
require 'twitter'
require 'date'

def add_name(_userlist)
    print "User's Full Name: "
    name = gets.chomp
    name
end

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
    if x == 'taken'
        puts 'Account exists.'
        return true
    else
        puts 'Not found!'
        return false
    end
end

def add_ID(name, servicename, servicelist)
    print "User's #{servicename} ID: "
    id = gets.chomp
    return if id == 'exit'
    case servicename
    when 'GitHub'
        idfound = verify_git(id)
    when 'Twitter'
        idfound = verify_twitter(id)
    end
    servicelist[name] = id if idfound
end

def print_users(userlist, servicelist)
    userlist.each do |user|
        puts user.to_s
        servicelist.each do |servicename, profiles|
            puts "#{servicename}: #{profiles[user]}"
        end
    end
end

def verify_git_repository(master, name)
    url = "https://api.github.com/repos/#{master}/#{name}"
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
        puts 'Not found!'
        return false
    else
        return true
    end
end

# GETTING GITHUB EVENTS FOR THE PROJECT
def get_project_activity(master, name, eventList)
    url = "https://api.github.com/repos/#{master}/#{name}/events"
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
        # rescue
        #  puts "Not found!"
    end
end

def parse_all_tweets(user, eventList)
    def collect_with_max_id(collection = [], max_id = nil, &block)
        response = yield(max_id)
        collection += response
        response.empty? ? collection.flatten : collect_with_max_id(collection, response.last.id - 1, &block)
    end

    client = Twitter::REST::Client.new do |config|
        config.consumer_key        = 'rdf1smTEPZo0vSsbe6CpwBJtf'
        config.consumer_secret     = 'pHyyqp2LVdhIRdCtpxpburB5sD9oCyzAkUpEXNuTFSiAtx0KlC'
        config.access_token        = '4245171201-L2Re7mSil8Tzg2JhS7SbKxdMCjDHwrii8YaNATA'
        config.access_token_secret = 'pjdqx3pvSGIel9ZS9xJPVTPN2Cr8xw4VSvH2CdBtSKTcr'
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

def team_config(userlist, servicelist)
    name = add_name(userlist)
    return if name == '' || name == 'exit'
    userlist << name
    servicelist.each do |servicename, servicelist|
        add_ID(name, servicename, servicelist)
    end
end

def project_config
    verified = false
    until verified
        puts 'Project name:'
        name = gets.chomp
        puts 'Repo owner:'
        master = gets.chomp # Currently username, should select from user list?
        verified = verify_git_repository(master, name)
    end
    [master, name]
end

def hackathon_config
    puts 'Hackathon title:'
    name = gets.chomp
    puts 'Date and time of start:'
    starttime = Time.parse(gets.chomp)
    puts 'Date and time of end:'
    endtime = Time.parse(gets.chomp)
    [name, starttime, endtime]
end

userlist = []
github = {}
twitter = {}
servicelist = { 'GitHub' => github, 'Twitter' => twitter }
projectdetails = {}
eventList = []

team_config(userlist, servicelist)
master, name = project_config
servicelist.each do |service, name|
    name.each do |name, username|
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
hackathonName, starttime, endtime = hackathon_config

eventlistSorted = eventList.sort_by { |k| k[:time] } # Sort events by time
eventlistSorted.each do |event|
    eventWithinTimeframe = false
    event.each do |key, value|
        if key == :time && value > starttime && value < endtime
            eventWithinTimeframe = true
        end
        puts "#{key}: #{value}" if eventWithinTimeframe
    end
end
