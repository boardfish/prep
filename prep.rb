require 'net/http'
require 'json'
require 'octokit'

userlist=Array.new
github=Hash.new
twitter=Hash.new
servicelist={"GitHub" => github, "Twitter" => twitter}
projectdetails={}
def add_name(userlist)
  print "User's Full Name: "
  name = gets.chomp
  return name
end

def add_ID(name, servicename, servicelist)
  print "User's #{servicename} ID: "
  id = gets.chomp
  return if id == "exit"
  #check if user exists on service
  case servicename
  when "GitHub"
    puts "Checking if account exists on GitHub."
    begin
      user = Octokit.user id
    rescue
      puts "Not found!"
      id = ""
    else
      puts "Account exists."
    end
  when "Twitter"
    puts "Checking if account exists on Twitter."
    puts id
    url = "https://twitter.com/users/username_available?username=#{id}"
    begin
      uri = URI(url)
      response = Net::HTTP.get(uri)
    rescue
      puts "Connection to Twitter failed."
    end
    x=JSON.parse(response)["reason"]
    if x=="taken"
      puts "Account exists."
    else
      puts "Not found!"
      id = ""
    end
  end
  servicelist[name] = id
end

def print_users(userlist, servicelist)
  userlist.each do |user|
    puts "#{user}"
    servicelist.each do |servicename, profiles|
      puts "#{servicename}: #{profiles[user]}"
    end
  end
end

#new team member
loop do
  name = add_name(userlist)
  break if name=="" || name=="exit"
  userlist << name
  servicelist.each do |servicename, servicelist|
    add_ID(name, servicename, servicelist)
  end
end
#print list of users and their accounts
print_users(userlist, servicelist)

#PROJECT DETAILS
puts "Project name:"
name = gets.chomp
puts "Repo owner:"
master = gets.chomp #Currently username, should select from user list?
#add github repo
url = "https://api.github.com/repos/#{master}/#{name}"
begin
  uri = URI(url)
  response = Net::HTTP.get(uri)
rescue
  puts "Connection to GitHub failed."
end
begin
  x=JSON.parse(response)["name"]
rescue
  puts "Not found!"
end
#GETTING GITHUB EVENTS FOR THE PROJECT
url = "https://api.github.com/repos/#{master}/#{name}/events"
begin
  uri = URI(url)
  response = Net::HTTP.get(uri)
  data = JSON.parse(response)
rescue
  puts "Connection to GitHub failed."
end
begin
  data.each do |entry|
    print "#{entry["created_at"]}: #{entry["actor"]["login"]} - "
    info = entry["payload"]
    case entry["type"]
    when "IssuesEvent"
      puts "Issue ##{info["issue"]["number"]} #{info["action"]}: #{info["issue"]["title"]}"
    when "IssueCommentEvent"
      puts "Comment on issue ##{info["issue"]["number"]} #{info["action"]}: #{info["issue"]["body"]}"
    when "PushEvent"
      info["commits"].each do |commit|
        puts "Commit pushed: #{commit["message"]}"
      end
    when "ForkEvent"
      puts "Forked by #{info["forkee"]["owner"]["login"]} at #{info["forkee"]["full_name"]}"
    when "CreateEvent"
      print "#{info["ref_type"].capitalize} created"
      case info["ref_type"]
      when "repository"
        puts "."
      when "branch"
        puts ": #{info["ref"]}."
      end
    when "DeleteEvent"
      print "#{info["ref_type"].capitalize} deleted"
      case info["ref_type"]
      when "repository"
        puts "."
      when "branch"
        puts ": #{info["ref"]}."
      end
    when "PullRequestEvent"
      puts "Pull request ##{info["number"]} #{info["action"]}: #{info["pull_request"]["title"]}"
    end
  end
#rescue
#  puts "Not found!"
end
