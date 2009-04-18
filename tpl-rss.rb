#!/usr/bin/env ruby
#
# == TPL-RSS ==
#  <http://github.com/gabrielmansour/tpl-rss>
#  Provides an RSS (Atom) Feed of books checked out from the Toronto Public Library
#  created by Gabriel Mansour
#  based on the Perl script by Sacha Chua <http://sachachua.com/wp/2009/03/29/new-library-reminder-script/>
#
require 'rubygems'
require 'mechanize'

@LIBRARY_CARD, @PIN = '0000000000000', '0000'  # your personal account credentials go here

@LIBRARY_CARD, @PIN = *ARGV unless ARGV.empty? # ..or optionally, you can pass in your credentials when executing this script from the command line

LOGIN_URL = 'https://ezproxy.torontopubliclibrary.ca/login'
ACCOUNT_URL = 'http://ezproxy.torontopubliclibrary.ca/sso/myacct'
CATALOGUE_URL = 'http://catalogue.torontopubliclibrary.ca'

ua = WWW::Mechanize.new
ua.read_timeout = 10

response = ua.post(LOGIN_URL, :user => @LIBRARY_CARD, :pass => @PIN, :url => ACCOUNT_URL)
raise "Login Error: Incorrect library card number or PIN." if response.body.match(/Incorrect library card number or PIN. Please try again./)


feed = Nokogiri::XML::Builder.new do
  feed( :xmlns => "http://www.w3.org/2005/Atom", :"xml:lang" => "en" ) do |f|
    f.title     "Library books"
    f.subtitle  "From the Toronto Public Library"
    f.updated   Time.now.iso8601
    f.link      :rel => 'self', :href => ''
    f.link      :rel => 'alternate', :type => 'text/html', :href => CATALOGUE_URL
    f.generator(:uri => 'http://github.com/gabrielmansour/tpl-rss'){ text "TPL-RSS" }
    f.id_       "tag:torontopubliclibrary.ca,2008:tpl-rss"
    f.icon      ""

    ua.get(CATALOGUE_URL) do |page|

      # Find the Your Account page
      # We need to click the link twice because apparently its @href isn't set properly the first time
      2.times {  page = page.links_with(:text => 'Your Account').first.click }

      (page/"tbody#renewcharge tr").each do |book|
        book_link = book.at("a")
        checkbox = book.at("input") # TODO - on next nokogiri release, change at to %
        unless book_link.nil?
          info = {}
          # RENEW^39100049582508^658.84 SWE^1^Sweeney, Susan, 1956-^101 Internet businesses you can start from home : how to choose and build your own successful e-business^
          command, catno, callno, status, info[:author], info[:title] = *checkbox['name'].to_s.split(/\^/) if checkbox
          due_date = (book/"td:nth-child(4)").text.strip
          clean_href = book_link['href'].sub(/\/uhtbin\/cgisirsi\/.*\?/, "/uhtbin/cgisirsi/x/0/0/5/3?") # strip out session information from URL
          
          f.entry do
            title    info[:title]
            author   info[:author]
            id_      "tag:torontopubliclibrary.ca,2008;#{catno}"
            updated  Time.now.iso8601
            link     :rel => 'alternate', :href => "#{CATALOGUE_URL}#{clean_href}#catno#{catno}"
            summary(:type => 'html') do
              text "Due on <strong>#{due_date}</strong>"
              text "<br /> <small>&#x2116; #{catno}</small>"
            end
          end # ENTRY

        end
      end
    end

  end # FEED
end

puts feed.to_xml