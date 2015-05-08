require 'rubygems'
require 'mechanize'
require 'csv'
require 'pry-byebug'

# Instantiate a new web scraper with Mechanize
scraper = Mechanize.new

# Mechanize setup to rate limit your scraping 
# to once every half-second.  
# THIS IS IMPORTANT OR YOU WILL BE IP BANNED!
scraper.history_added = Proc.new { sleep 0.5 }

# hard-coding an address for your scraper
ADDRESS = 'http://sfbay.craigslist.org/search/sfc/apa'

# Set up an array to store all of our results
results = []

# Make the first row of the array the column names
results << ['Name', 'URL', 'Price', 'Location']


# SCRAPING TIME!!!!
# Use our scraper to fetch the address 
# and pass the page that is returned to 
# the following lines so we can play with it
scraper.get(ADDRESS) do |search_page|


    # Use Mechanize to enter search terms into the form fields
    form = search_page.form_with(:id => 'searchform') do |search|

        search.query = 'Garden'   # Find places with a nice garden
        search.minAsk = 250       # Minimum price
        search.maxAsk = 1500      # Maximum price

    end


    # Actually submit the form and store the resulting HTML
    # page in our `result_page` variable
    result_page = form.submit   


    # Parse the result page for all the paragraph tags with
    # the class `row`.
    # Each of these is a giant Nokogiri object, as we'll see below
    raw_results = result_page.search('p.row')


    # Go through each of these rows, pulling data out
    # The `result` variable will contain the giant nested
    # Nokogiri object which represents all the HTML tags
    # on the page and their attributes
    raw_results.each do |result|

        # NOTE:
        # This is a good place to uncomment the line below
        # (`binding.pry`) and inspect the result in Pry.
        #
        # You can run Ruby code inside of the loop directly!
        #
        # Type `quit` (without backtics) to quit.
        #
        # Be careful of using it inside loops, though, because
        # it will halt code execution with *each* iteration.
        #
        # Use `CTRL+C` to break out entirely if you're stuck.
        
        # Uncomment this to inspect in your terminal mid-script:
        # binding.pry       


        # Now let's grab just the individual posting by finding
        # the anchor tag in the result and then indexing into it.
        # When we pull out just the anchor tags using this
        # `css` function, we get a slightly more manageable
        # object containing just the specific result we want.
        # We will still have to parse it for more info though...
        #
        # The `link` we're pulling out is just an object with
        # attributes we can inspect.  It looks like this:
        # 
        # => #(Element:0x3fd643835230 {
        # name = "a",
        # attributes = [
        #   #(Attr:0x3fd6438343d0 { name = "href", value = "/sfc/apa/5015026228.html" }),
        #   #(Attr:0x3fd6438343bc { name = "data-id", value = "5015026228" }),
        #   #(Attr:0x3fd6438343a8 { name = "data-repost-of", value = "4991097035" }),
        #   #(Attr:0x3fd643834394 { name = "class", value = "hdrlnk" })],
        # children = [ #(Text "3bd/1.5 Bath with Yard & Garden")]
        # })
        #
        # Notice all the juicy data contained inside that object...

        link = result.css('a')[1]


        # Because `link` is a Nokogiri object, we know we can
        # call methods on it to access its attributes directly or
        # just index into them "hash-style".  Both are used below
        # to help us pull out the actual data we want,
        # e.g. `name` and `url`
        name = link.text.strip
        url = "http://sfbay.craigslist.org" + link.attributes["href"].value


        # We're done playing with the link, so now let's do some 
        # searching back on the results page to find the `price`
        # and `location` data.
        # This follows the similar pattern that we used above
        price = result.search('span.price').text
        location = result.search('span.pnr').text[3..-13]


        # Let's output the location so we know when the scraper
        # is actually finding things
        puts location


        # Now let's take the variables we located from the
        # code above and put them into our results array.
        results << [name, url, price, location]
    end

    # Keep iterating over each new result until we're
    # out of results...
end


# The final step is to open up a new CSV file 
# in "write" mode and pass it to the code within
# so we can write our results to CSV.
CSV.open("filename.csv", "w+") do |csv_file|

    # It's this easy... just push each row
    # of our results into the `csv_file` in turn.
    results.each do |row|
        csv_file << row
    end
end

# Presto! Check out `filename.csv` in the current folder 
# to view your results!
