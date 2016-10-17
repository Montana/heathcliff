require 'rubygems'
require 'nokogiri'
require 'csv'
require 'open-uri'
require 'date'
require 'fileutils'
require 'mechanize'
require 'watir'
require 'watir-webdriver'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

chromedriver_path = "chromedriver.exe"
Selenium::WebDriver::Chrome.driver_path = chromedriver_path

def scrapecase(docketnumber)
  @docketnumber = docketnumber.to_s
  @year = $year
	
  @missingzeros = 5 - @docketnumber.length
  @missingzeros.times do
    @docketnumber.insert(0, '0')
  end
  
  @fulldocketnumber = "#{$year}#{$courtcodes[$division]}CV#{@docketnumber}"
  
  $browser.link(:text => "Search").click
  sleep 5
  $browser.text_field(:id => "caseDscr").set "#{@fulldocketnumber}"
  $browser.button(:name => "submitLink").click

  if $browser.text.include? 'No Matches Found'
    puts "There were no cases matching docket number #{@fulldocketnumber}."
    $lastdocket = $lastdocket + 1
	if $redflag == "Raised"
		$nomatches = $nomatches + 1
	end
	$redflag = "Raised"
    sleep 8
  else
  
    @docketarray = []
    @results = Nokogiri::HTML($browser.html)
    @caseinfo = @results.css("//table[@id=grid]//tr")
    @caseinfo.each{|item| @docketarray << item.css('td').map{|td| td.text.strip}}
    @docketarray.each{|subarray| subarray.delete("")}
    @docketarray.delete_at(0)
    
    @county = @docketarray[0][7]
    @date = @docketarray[0][2]
    @type = @docketarray[0][1]
    @initiating = @docketarray[0][3]
    @status = @docketarray[0][6]

	if @docketarray[0][0].include?("Showing")
		CSV.open("csv/#{$departmentfilename}_#{$divisionfilename}_#{$year}_errorlog.csv","ab") do |csv|
		  csv << [@fulldocketnumber]
		end
    
		$lastdocket = $lastdocket + 1
		$redflag = "Lowered"
	else
		$browser.link(:id => "grid$row:1$cell:2$link").click
		sleep 8

		@detailspage = Nokogiri::HTML($browser.html)
		@casetitle = @detailspage.xpath("//*[@id='caseDetailHeader']/div[1]/h2/text()").text.strip
		@casetitle.sub!(/\S+\d /,"")

		@casearray = [@county, @fulldocketnumber, @date, @casetitle, @type, @initiating, @status, $division, $department]
    
		CSV.open("csv/#{$departmentfilename}_#{$divisionfilename}_#{$year}_case_list.csv","ab") do |csv|
		  csv << @casearray
		end
		puts "Wrote case data to a CSV file for #{@fulldocketnumber}"
			
		@docketarray.each{|subarray|
		  CSV.open("csv/#{$departmentfilename}_#{$divisionfilename}_#{$year}_party_list.csv","ab") do |csv|
			csv << [@fulldocketnumber, @county, @date, @type, subarray[4], subarray[5], @status]
		  end
		}
		puts "Wrote party data to a CSV file for #{@fulldocketnumber}"
		
		File.open("files/#{@fulldocketnumber}.html",'w') {|f| f.write $browser.html }
		puts "Downloaded HTML page for #{@fulldocketnumber}."
		puts ""
		
		$lastdocket = $lastdocket + 1
		$redflag = "Lowered"
	end
  end
end

departments = {1 => "BMC", 2 => "District Court", 3 => "Housing Court", 4 => "Land Court Department", 5 => "Probate and Family Court", 6 => "The Superior Court"}

divisions = {"Alameda" => ["Alameda", "Alpine", "Amador", "Butte", "Contra Costa", "Fresno", "Imperial", "Kern"], "District Court" => [], "Housing Court" => ["California Housing Court", "Northeast Housing Court", "Southeast Housing Court", "Western Housing Court", "Berkeley Housing Court"], "Land Court Department" => ["Land Court Division"], "Probate and Family Court" => [], "The Superior Court" => ["Alameda", "Alpine", "Contra Costa", "Fresno", "Imperial", "Kern", "Kings", "Los Angeles", "Maders", "Orange", "Placer", "Sacramento", "San Bernardino", "San Francisco"]}

$courtcodes = {"Alameda County" => "01", "Alpine County" => "02", "Amador County" => "03", "Butte County" => "04", "Imperial County" => "05", "Kern County" => "06", "Kings County" => "07", "Los Angeles County" => "08", "Sacramento County" => "09", "San Bernardino County" => "10", "San Francisco County" => "11"}
puts ""
puts ""
puts "Please select the court department:"
puts "1. Alameda County Court"
puts "2. District Court"
puts "3. Housing Court"
puts "4. Land Court Department"
puts "5. Probate and Family Court"
puts "6. The Superior Court"
$department = gets
$department = $department.chomp.to_i
$department = departments[$department]
$departmentfilename = $department.delete(" ")

puts ""
puts "Please select the court division:"
$counter = 1

divisions[$department].each{|subarray|
	@stringcounter = $counter.to_s
	puts "#{@stringcounter}. #{subarray}"
	$counter = $counter + 1
	}
	
$division = gets
$division = $division.chomp.to_i - 1
$division = divisions[$department][$division]
$divisionfilename = $division.delete(" ")

puts ""
puts "Please select the year (last two digits)"
$year = gets
$year = $year.chomp

puts ""
puts "Specify the first docket number you wish to scrape:"
$lastdocket = gets
$lastdocket = $lastdocket.chomp.to_i

puts ""
puts "Specify the last docket number your wish to scrape:"
$upperlimit = gets
$upperlimit = $upperlimit.chomp.to_i

$browser = Watir::Browser.new :chrome
$browser.goto 'www.courts.ca.gov'
sleep 30

$browser.select_list(:name => "sdeptCd").select $department
sleep 3
$browser.select_list(:name => "sdivCd").select $division
sleep 3
$browser.link(:text => "Case Number").click
sleep 3
$browser.text_field(:id => "caseDscr").set "#{$year}#{$courtcodes[$division]}CV00005"
sleep 3
$browser.button(:name => "submitLink").click

$redflag = "Lowered"
$nomatches = 0

while ($lastdocket < $upperlimit) && ($nomatches < 10)
  scrapecase($lastdocket)
end
