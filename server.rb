# Cookie Server
# Braden Neufeld
# 4 March 2013

# LOAD FILE
# load the IDs and their human-readable description from file
# we will store them in a hash called values
values = Hash.new("invalid reference") # returns invalid reference for IDs called that are not included in the file.
file = File.open('data.csv', 'r')
file.each_line("\n") do |row|
  columns = row.split(",")
  values[columns[0]]=columns[1].chomp! # assign the ID as the key and the description as the value.
                                       # chomp is used to get rid of return character.
end

# SERVER
require 'socket'
server = TCPServer.new('localhost',3000)
while (session = server.accept)
  request = session.gets

  # we find out if we are in a directory. the unless is there because gsub will throw an exception for an empty string.
  directory = request.gsub!(/GET\ \//, '').gsub!(/\ HTTP.*/, '').chomp unless request == ''
  # is the browser making a request for a favicon instead? if so, send a response, close the session and skip the rest of the loop.
  if directory.include?('favicon')
    session.print "HTTP/1.1 200/OK\r\nContent-type:text/html\r\n\r\n"
    session.close
    next
  # are we pointed to the reset directory? if so, expire the cookies and 302 redirect.
  elsif directory == 'reset'
    session.print "HTTP/1.1 302 Found\r\nLocation: http://localhost:3000\r\nContent-type:text/html\r\nSet-Cookie: segments=nil; expires=Thu, 01 Jan 1970 00:00:00 GMT\r\n\r\n"
    session.close
    next
  end

  # we initialize the variable to store the incoming cookie information (if any).
  # I wanted this to freshly obtained each time, not stored locally, to avoid potential glitches (what if a user clears cookies?)
  incoming_cookies = ''
  # go through the rest of the request and find if there is any cookie information.
  while true
    request = session.gets
    incoming_cookies = request.gsub!(/Cookie: /, '').chomp! if request.include?('Cookie: ') #gsub tends to leave a character behind. chomp gets rid of this.
    break if ((incoming_cookies != '') or (request.length == 2)) #stop the loop if we reach the end (which is a two character escape string) or we have our cookies.
  end

  # if there are no cookies, cookie_list is an empty array. otherwise, we grab the IDs and split them into an array of values.
  incoming_cookies == '' ? cookie_list = Array.new : cookie_list = incoming_cookies.gsub!(/segments=/, '').split(",")
  # add the directory (representing our ID) to the cookie list unless it's already there or we're on the top-level page.
  cookie_list << directory unless cookie_list.include?(directory) or directory == ''

  output = '' # initialize out output string
  # if the top-level directory was requested, output a list of the cookie IDs and their descriptors.
  if directory == ''
    session.print "HTTP/1.1 200/OK\r\nContent-type:text/html\r\n\r\n"
    # compile a readable output string
    for cookie in cookie_list
      output = output + "#{cookie} #{values[cookie]}, "
    end
    session.print output[0..-3] unless output == '' #cut off the last ', ' character and send string to client
  # if another directory was requested, we send (or resend) the cookies to the browser
  else
    cookie_list.length > 1 ? output = cookie_list.dup.join(',') : output = cookie_list.to_s
    session.print "HTTP/1.1 200/OK\r\nContent-type:text/html\r\nSet-Cookie: segments=#{output}\r\n\r\n"
  end
  session.close
end