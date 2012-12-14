#!/usr/bin/env ruby
# ex: set sw=2 et:

require 'rubygems'
require 'google/api_client'
require 'sinatra'
require 'google/api_client'
require 'logger'

enable :sessions

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

get '/summarise' do
  numPages = 0
  numItems = 0
  numEvents = 0
  numUIDs = 0
  numGoogleUIDs = 0
  numToDelete = 0

  parameters = {'calendarId' => 'primary'}

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
        end
      end
    }

    parameters['pageToken'] = nil
    if !result.data['nextPageToken'].nil? && !result.data['nextPageToken'].empty?
      parameters['pageToken'] = result.data['nextPageToken']
    end

    numPages += 1

  end while !parameters['pageToken'].nil?

  [result.status, {'Content-Type' => 'text/html'},
   "<dl>" +
   "<dt>numPages<dd>#{numPages}" +
   "<dt>numItems<dd>#{numItems}" +
   "<dt>numEvents<dd>#{numEvents}" +
   "<dt>numUIDs<dd>#{numUIDs}" +
   "<dt>numGoogleUIDs<dd>#{numGoogleUIDs}" +
   "<dt>numToDelete<dd>#{numToDelete}" +
   "</dl>"
   ]
end

get '/' do
  # Fetch list of events on the user's default calandar
  result = api_client.execute(:api_method => settings.calendar.events.list,
                              :parameters => {'calendarId' => 'primary'},
                              :authorization => user_credentials)
  [result.status, {'Content-Type' => 'text/html'},
   "<style type='text/css'>
      .container {
        padding: 10px;
        border: 1px solid black;
      }
      .inner_container {
        padding: 0;
        margin: 0;
        border: 0;
        display: none;
      }
      .block_header {
        padding: 10px;
        background: red;
      }
      .item_header {
        padding: 2px;
        background: green;
      }
    </style>
    <script type='text/javascript'>
    function createElem(className) {
      var elem = document.createElement('div');
      elem.className = className;
      return elem;
    }
    function textNode(type, text) {
      var elem = createElem(type);
      elem.appendChild(document.createTextNode(text));
      return elem;
    }
    function blockHeader(text) {
      var node = textNode('block_header', text);
      node.onclick = blockHeader_click;
      return node;
    }
    function blockHeader_click(event) {
      if (event.target.nextSibling) {
        if (event.target.nextSibling.style.display == 'block') {
          event.target.nextSibling.style.display = 'none';
        } else {
          event.target.nextSibling.style.display = 'block';
        }
      }
    }
    function itemHeader(text) { return textNode('item_header', text); }
    function jsonTree(json) {
      var elem = createElem('container');
      if (json == null) {
      } else if (json instanceof Array) {
        elem.appendChild(blockHeader('Array'));
        var inner = createElem('inner_container');
        elem.appendChild(inner);
        for (var i=0; i<json.length; i++) {
          inner.appendChild(jsonTree(json[i]));
        }
      } else if (json instanceof Object) {
        elem.appendChild(blockHeader('Hash'));
        var inner = createElem('inner_container');
        elem.appendChild(inner);
        for (var name in json) {
          inner.appendChild(itemHeader(name));
          inner.appendChild(jsonTree(json[name]));
        }
      } else {
        elem.appendChild(document.createTextNode(json));
      }
      return elem;
    }
    var json = #{result.data.to_json};
    var node = jsonTree(json);
    function onload() {
      document.body.appendChild(node);
    }
    </script><body onload='onload()'></body>"]
end
