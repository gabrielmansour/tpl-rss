#!/usr/local/bin/ruby
#
# == TPL-RSS ==
#  <http://github.com/gabrielmansour/tpl-rss>
#  Provides an RSS (Atom) Feed of books checked out from the Toronto Public Library
#  created by Gabriel Mansour
#  based on the Perl script by Sacha Chua <http://sachachua.com/wp/2009/03/29/new-library-reminder-script/>
#
require 'rubygems'
require 'mechanize' # using nokogiri

LIBRARY_CARD, PIN = '0000000000000', '0000' # your personal account credentials

LOGIN_URL = 'https://ezproxy.torontopubliclibrary.ca/login'
ACCOUNT_URL = 'http://ezproxy.torontopubliclibrary.ca/sso/myacct'
CATALOGUE_URL = 'http://catalogue.torontopubliclibrary.ca'

ua = WWW::Mechanize.new
ua.read_timeout = 10

response = ua.post(LOGIN_URL, :user => LIBRARY_CARD, :pass => PIN, :url => ACCOUNT_URL)

feed = Nokogiri::XML::Builder.new do
  feed( :xmlns => "http://www.w3.org/2005/Atom", :"xml:lang" => "en" ) do |f|
    f.title     "Library books"
    f.subtitle  "From the Toronto Public Library"
    f.updated   Time.now.iso8601
    f.link      CATALOGUE_URL
    f.link      :rel => 'self', :href => ''
    f.generator(:href => 'http://github.com/gabrielmansour/tpl-rss'){ text "TPL-RSS" }
    f.id_       ""
    f.author    ""

    ua.get(CATALOGUE_URL) do |page|

      # Find the Your Account page
      # We need to click the link twice because apparently its @href isn't set properly the first time
      2.times {  page = page.links_with(:text => 'Your Account').first.click }

      (page/"tbody#renewcharge tr").each do |book|
        book_link = book/"a"
        checkbox = book.at("input") # TODO - on next nokogiri release, change at to %
        unless book_link.nil? or book_link.empty?
          info = {}
          # RENEW^39100049582508^658.84 SWE^1^Sweeney, Susan, 1956-^101 Internet businesses you can start from home : how to choose and build your own successful e-business^
          command, info[:id_], callno, status, info[:author], info[:title] = *checkbox['name'].to_s.split(/\^/) if checkbox

          due_date = (book/"td:nth-child(4)").text.strip
          
          info[:summary] = "Due on #{due_date}"
          info[:guid]    = "#{CATALOGUE_URL}#catno#{info[:id_]}" # guid must be unique for each entry
          
          f.entry do |entry|
            info.each{ |tag, value| entry.send(tag, value) }
          end # ENTRY

        end
      end
    end

  end # FEED
end

puts feed.to_xml