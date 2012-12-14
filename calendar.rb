#!/usr/bin/env ruby
# ex: set sw=2 et:

require 'rubygems'
require 'google/api_client'
require 'sinatra'
require 'google/api_client'
require 'logger'

enable :sessions

# N.B. uids.list can be created from an iCal file using
# grep ^UID: filename.ics | cut -d: -f2- > uids.list
$uids = {}
File.open("../uids.list") {|fh| fh.readlines }
  .map(&:chomp)
  .each{|uid|
    $uids[uid] = uid
  }

def logger; settings.logger end

def api_client; settings.api_client; end

def calendar_api; settings.calendar; end

def user_credentials
  # Build a per-request oauth credential based on token stored in session
  # which allows us to use a shared API client.
  @authorization ||= (
    auth = api_client.authorization.dup
    auth.redirect_uri = to('/oauth2callback')
    auth.update_token!(session)
    auth
  )
end

configure do
  log_file = File.open('calendar.log', 'a+')
  log_file.sync = true
  logger = Logger.new(log_file)
  logger.level = Logger::DEBUG
  
  client = Google::APIClient.new
  File.open(Pathname.new(File.dirname(__FILE__)) + "local.cfg") {|fh|
    lines = fh.readlines
    client.authorization.client_id = lines[0].chomp
    client.authorization.client_secret = lines[1].chomp
  }
  client.authorization.scope = 'https://www.googleapis.com/auth/calendar'

  calendar = client.discovered_api('calendar', 'v3')

  set :logger, logger
  set :api_client, client
  set :calendar, calendar
end

before do
  # Ensure user has authorized the app
  unless ( user_credentials.access_token && !user_credentials.expired? ) ||
         request.path_info =~ /^\/oauth2/
    redirect to('/oauth2authorize')
  end
end

after do
  # Serialize the access/refresh token to the session
  session[:access_token] = user_credentials.access_token
  session[:refresh_token] = user_credentials.refresh_token
  session[:expires_in] = user_credentials.expires_in
  session[:issued_at] = user_credentials.issued_at
end

get '/oauth2authorize' do
  # Request authorization
  redirect user_credentials.authorization_uri.to_s, 303
end

get '/oauth2callback' do
  # Exchange token
  user_credentials.code = params[:code] if params[:code]
  user_credentials.fetch_access_token!
  redirect to('/')
end

def summary_or_action(action=false)
  numPages = 0
  numItems = 0
  numEvents = 0
  numUIDs = 0
  numGoogleUIDs = 0
  numToDelete = 0

  parameters = {'calendarId' => 'primary'}

  deleteIds = []
  toDelete = []
  deleteDates = []
  toKeep = []
  keepDates = []

  begin
    result = api_client.execute(:api_method => settings.calendar.events.list,
                                :parameters => parameters,
                                :authorization => user_credentials)

    numItems += result.data.items.size
    result.data.items.each {|item|
      if item.kind == 'calendar#event'
        numEvents += 1
      end
      if !item.iCalUID.nil?
        numUIDs += 1
        if item.iCalUID =~ /@google\.com$/
          numGoogleUIDs += 1
        end
        if $uids.has_key?(item.iCalUID)
          numToDelete += 1
          deleteIds << item.id
          toDelete << item.summary
          deleteDates << item.created.strftime('%F')
          #puts "item.created.class = #{item.created.class}"
        else
          toKeep << item.summary
          keepDates << item.created.strftime('%F')
        end
      end
    }

    parameters['pageToken'] = nil
    if !result.data['nextPageToken'].nil? && !result.data['nextPageToken'].empty?
      parameters['pageToken'] = result.data['nextPageToken']
    end

    numPages += 1

  end while !parameters['pageToken'].nil?

  toDelete = toDelete.sort.uniq
  toKeep = toKeep.sort.uniq
  deleteDates = deleteDates.sort.uniq
  keepDates = keepDates.sort.uniq

  if action
    result = api_client.execute(:api_method => settings.calendar.calendars.insert,
                                :parameters => {'summary' => 'calendar-unimport'},
                                :authorization => user_credentials)
    [result.status, {'Content-Type' => 'text/html'},
     json_viewer(result.data.to_json)]
#    [result.status, {'Content-Type' => 'text/html'},
#     "<dl>" +
#     "<dt>kind<dd>#{result.data.kind}" +
#     "<dt>id<dd>#{result.data.id}" +
#     "</dl>"
#    ]
  else
    [result.status, {'Content-Type' => 'text/html'},
     "<h2>Summary</h2>" +
     "<dl>" +
     "<dt>numPages<dd>#{numPages}" +
     "<dt>numItems<dd>#{numItems}" +
     "<dt>numEvents<dd>#{numEvents}" +
     "<dt>numUIDs<dd>#{numUIDs}" +
     "<dt>numGoogleUIDs<dd>#{numGoogleUIDs}" +
     "<dt>numToDelete<dd>#{numToDelete}" +
     "</dl>" +
     "<h2>To Delete</h2>" +
     "<select size='20'>" + toDelete.map{|s| "<option>#{s}</option>" }.join("") + "</select>" +
     "<h2>Delete Dates</h2>" +
     "<select size='20'>" + deleteDates.map{|s| "<option>#{s}</option>" }.join("") + "</select>" +
     "<h2>To Keep</h2>" +
     "<select size='20'>" + toKeep.map{|s| "<option>#{s}</option>" }.join("") + "</select>" +
     "<h2>Keep Dates</h2>" +
     "<select size='20'>" + keepDates.map{|s| "<option>#{s}</option>" }.join("") + "</select>" +
     ""
     ]
  end
end

get '/summarise' do
  summary_or_action(false)
end

get '/delete' do
  summary_or_action(true)
end

get '/' do
  # Fetch list of events on the user's default calandar
  result = api_client.execute(:api_method => settings.calendar.events.list,
                              :parameters => {'calendarId' => 'primary'},
                              :authorization => user_credentials)
  [result.status, {'Content-Type' => 'text/html'},
   json_viewer(result.data.to_json)]
end

def json_viewer(json)
 "<link rel='stylesheet' type='text/css' href='json_viewer.css'>
  <script type='text/javascript' src='json_viewer.js'></script>
  <script type='text/javascript'>
  var json = #{json};
  </script><body onload='onload(json)'></body>"
end
