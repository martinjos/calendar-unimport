# Calendar Unimport
This project, including this ReadMe file, are based on the Google Calendar API
starter project provided by Google. Appropriate parts of this ReadMe have been
modified for the Calendar Unimport project. 

This project allows you to reverse an ICAL Import operation that has polluted
one of your calendars with lots of events that just clutter it up. The items
are moved to a new calendar for backup (unless one already happens to exist
with exactly the right name, in which case they are moved to that).

I'm afraid the procedure is a bit hands-on at the moment, as I haven't yet
bothered to make it user-friendly (because it was initially only for my own
personal use).

## Known issues

It seems that the Google API server sometimes returns error code 500 (internal
server error) when trying to move certain entries to the backup calendar.
Fortunately, this seems to be rare. I've not yet checked what causes it.

## Prerequisites
Please make sure that all of these are installed before you try to run the
sample.

- Ruby 1.8.7+
- Ruby Gems 1.3.7+
- Are you on a Mac? If so, be sure you have XCode 3.2+
- A few gems (run 'sudo gem install <gem name>' to install)
    - sinatra
    - google-api-client

## Setup Authentication

This API uses OAuth 2.0. To prepare to use it:

 - Visit https://code.google.com/apis/console/ to register your application.
 - From the "Project Home" screen, activate access to "Calendar API".
 - Click on "API Access" in the left column
 - Click the button labeled "Create an OAuth2 client ID"
 - Give your application a name and click "Next"
 - Select "Web Application" as the "Application type"
 - Under "Your Site or Hostname" select "http://" as the protocol and enter
   "localhost" for the domain name
 - click "Create client ID"

Create a file called local.cfg in the same directory as calendar.rb, and
insert the following values, on the first and second lines of the file
respectively:

 - Your client ID
 - Your client secret

## Running the Program

1. In the parent directory, perform the following step:

        $ grep ^UID: MY_ICS_FILENAME.ics | cut -d: -f2- > uids.list

   replacing MY_ICS_FILENAME.ics with the name of your ICS file.

   (Yes, I'm sorry about this, but it's something I just haven't got round to
   changing yet.)

2. Back in the project directory, open up the embedded Sinatra web server with

        $ ./calendar.rb 'MY ICAL CALNAME'

   (including the quotes) replacing MY ICAL CALNAME with the title of your
   iCal (taken from within the ics file - probably after 'X-WR-CALNAME:' (this
   time without the quotes - yes, I know, it's confusing)).

   If you already have a calendar named 'MY ICAL CALNAME (Calendar Unimport)'
   (without the quotes), the "deleted" items will in fact be merged into this
   calendar for backup.  Otherwise, a new calendar will be created with this
   name.

3. Open your browser and visit the following local address to perform the
   "delete" (or in actual fact, move) operations:

        http://localhost:4567/delete
   
   (clicking through the Google authentication prompts - which will only give
   privileges to your very own API key that you created earlier.)

   This might take some time. At the end it will display a summary report.

   There are various other local addresses you can visit to display stuff
   about your calendar (for debug purposes). See the source for details.
