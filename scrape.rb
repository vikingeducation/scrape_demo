require 'rubygems'
require 'mechanize'
require 'csv'
require 'pry-byebug'

scraper = Mechanize.new

# Mechanize setup to rate limit your scraping to once every half-second
scraper.history_added = Proc.new { sleep 0.5 }

# hard-coding an address for your scraper
ADDRESS = 'http://sfbay.craigslist.org/search/sfc/apa'

results = []
results << ['Name', 'URL', 'Price', 'Location']


# SCRAPING TIME

scraper.get(ADDRESS) do |search_page|

  # scrape the page
  form = search_page.form_with(:id => 'searchform') do |search|
    search.query = 'Garden'
    search.minAsk = 250
    search.maxAsk = 1500
  end
  result_page = form.submit


  raw_results = result_page.search('p.row')
  raw_results.each do |result|
    link = result.css('a')[1]

    name = link.text.strip
    url = "http://sfbay.craigslist.org" + link.attributes["href"].value
    price = result.search('span.price').text
    location = result.search('span.pnr').text[3..-13]
    puts location

    results << [name, url, price, location]
  end
end

CSV.open("filename.csv", "w+") do |csv_file|
    results.each do |row|
        csv_file << row
    end
end
