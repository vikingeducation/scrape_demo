## Web Scraping Craigslist with Ruby

This mini-lesson is an introduction to one of the more powerful ways to make the Internet's data bend to your will, using pretty minimal coding skills. All it takes is enough time and patience to figure out what you're going for.  

We'll use an example of a very famous apartment hunting website that rhymes with "Schmaigslist" since it's kind of a pain to go search for apartments manually. Wouldn't it be nice to just run a little script that grabbed all the apartments that you wanted (keywords, neighborhood and price point) and added them to a spreadsheet for you?

We assume a familiarity with HTML markup and the basic building blocks of programming.


### Our Tools

First of all, let's see what we're working with here anyway:

"Scraping" is the act of pulling data from a website programmatically.  If you find yourself going to a page, clicking around in a repetitive way, taking annoyingly mechanical notes into a text file or spreadsheet, and only ending up with the information you actually want an hour or two later, then scraping is probably the right tool for the job.

"Ruby" is a popular scripting language that also underlies the Rails framework, and it has some great scraping tools in its own right. 

"[Mechanize](https://github.com/sparklemotion/mechanize)" is the main Ruby gem (aka code library) we'll feature here.  It makes scraping very easy for you. 



### System Setup

Let's get a few setup things out of the way to make sure we're all on the same page:

- First, make sure you have a version of Ruby on your machine (OSX has it by default, you can definitely grab it with `apt-get` in Ubuntu)
- Make sure you know the basics of Ruby as a scripting language. If you're not familiar with it, you can go check out [Ruby in 100 Minutes](http://tutorials.jumpstartlab.com/projects/ruby_in_100_minutes.html) for the basic syntax. If you need more, go check out [Viking Code School's Web Markup and Coding prep course](http://www.vikingcodeschool.com/web-markup-and-coding), which will also give you some extra practice with HTML and CSS if you're weak on those.
- Go into your command line and type:

    ```language-bash
    gem install mechanize
    gem install pry-byebug
    ```

    If your console doesn't recognize those commands, type `brew install rubygems` or use your system's package manager to grab the rubygems package

- You should also use a browser like Chrome or Firefox which has an extensive set of developer tools for debugging.


### Identifying Your Scraping Path

Okay, we're ready to go.  Now what?

Before you write a script to scrape a page, you need to identify the actual path a normal user would take to get the information you're looking for. This section will take you through the whole research process to get you ready to write your script.


#### First Turn off JavaScript

First up, you want to temporarily turn off JavaScript in your browser. Since the tool we're going to use doesn't use JavaScript, you want to make sure that you're only seeing in the browser what your scraper can "see".

Instructions in Chrome: 

1. Click the Chrome menu in the top right hand corner of your browser
2. Select "Settings"
3. Click "Show Advanced Settings"
4. In the "Privacy" section, click "Content settings"
5. In the JavaScript section, click "Do not allow any site to run JavaScript". (Remember to undo this later!)

If you're using another browser, just Google for "how to turn off JavaScript in BROWSERNAME" and you will have instructions in 10 seconds flat.


#### The Information Scavenger Hunt

Before we can programmatically scrape a page, we need to know what we actually want to pull off of it. The only way to do so is by first inspecting the page manually and taking a few notes along the way.

In particular, you'll want to note a few key things:

1. *What page do you need to start on?* Grab the address from your browser window. If you click through a couple of pages to a common starting point for all your searches, grab *that* address, not the initial landing page.
2. *The IDs of any form tags you need to input information to.* Just use your browser's "inspect element" feature to figure this out.
3. The names of any input fields you fill in on those forms. (inspect element is your friend)
4. The IDs or classes of the results you're trying to grab on the results page.

Let's now walk through the Craigslist example, taking exactly those four steps.

1. Visit the main Craigslist site for your town. For us, that's San Francisco, so we'll go to http://sfbay.craigslist.org/sfc/, the San Francisco branch of the San Francisco Bay Area. But clicking around, we see an Apartments heading, and under that heading there's the "apts/housing" link. Clicking through there, we get a very nice direct search page, whose address is **[http://sfbay.craigslist.org/search/sfc/apa](http://sfbay.craigslist.org/search/sfc/apa).** Mission 1 accomplished.
2. Conveniently inspecting elements, it appears that *all* the form fields are contained in a single `<form>` with **id="searchform"**. Later on, that's going to allow us to target the right form on this page using our scraper. That's two down.
3. The actual fields we might want to fill in, we hope they have explicit names set.
    1. The minimum dollar amount turns out to have the name `minAsk`, while the maximum is `maxAsk`.
    2. There are checkboxes for neighborhoods whose input elements look like `<input id='sunset_/_parkside_28'>`, so we'll take down any of those if we want to filter by neighborhood.
    3. There's also the main query field, an input whose name is "query". These fields are often named "query" or just "q"
4. Inspecting the actual results of a test query, the apartment listings all seem to be inside of `<p class="row">`'s who are all inside of a `<div class="content">`. That means that when the time comes, we can just look inside that container div and grab a collection of those row paragraphs. More detailed results parsing will have to wait till we have something to parse.


### Start Scripting

First, we set up a Ruby script. These all end in `.rb`, so let's call it `scrape.rb` and open it up in our favorite development-oriented text editor.


#### Setting Up the Script

For the sake of being extremely accessible to various readers, we're going to write this scraper in an entirely linear, procedural style, but if you're used to object-oriented programming in Ruby, it should be pretty trivial to wrap all this in a portable, modular `ApartmentScraper` object.

We'll start by using `require` statements to call in the various modules we need for the script. That includes: 

1. Rubygems, which manages our various packages of code
2. The [Mechanize](https://github.com/sparklemotion/mechanize) gem
3. The Pry Debugger gem that lets you start up a debugging console at any point in your script
4. A built-in CSV library that will later allow us to save our output in highly-portable spreadsheet format.

```language-ruby
require 'rubygems'
require 'mechanize'
require 'pry-byebug'
require 'csv'
```

Next, we'll instantiate an object that does the scraping and set it up.

```language-ruby
scraper = Mechanize.new
scraper.history_added = Proc.new { sleep 0.5 }
BASE_URL = 'http://sfbay.craigslist.org'
ADDRESS = 'http://sfbay.craigslist.org/search/sfc/apa'
results = []
```

The scraper is a new Mechanize object that has all the powers of the Mechanize gem. We'll get into the special methods it contains soon enough.

That `history_added` line is a callback, a method that runs every time you finish visiting a new page. What it's doing is *rate limiting* your scraping, so that you stop and wait half a second between each time you visit a page. If you go much faster than that, many sites will decide your scraper is a bot that might be [DDOSing](http://en.wikipedia.org/wiki/Denial-of-service_attack) them or otherwise up to no good, so this way you just look like a human clicking through things quickly.

`ADDRESS` is a constant that represents the starting address of your scraper and simplifies your code later on. This way, it's only hard-coded in one place. If you had been scraping a site in more varied ways (for more than just apartments). For later uses, we're also grabbing a `BASE_URL` constant only consists of the domain itself, 'http://sfbay.craigslist.org'.

Results is an empty array that will soon contain all your cool scraped stuff.


#### Start Scrapin'

Next up, we pull up our information grabbed from that initial information scavenger hunt and start the scrape in earnest.

First, everything in your scraping session is going to be wrapped up in a single block of Ruby code that looks like this:

```language-ruby
scraper.get(ADDRESS) do |search_page|
    # everything else will go here
end
```

That means that your scraper object is sending a GET request to your hardcoded `ADDRESS` starting point, and it gives you a `search_page` variable inside that block that can be inspected and played with to see what your results are. That variable gives you all the HTML of visiting the actual page, plus some very convenient methods to find elements and keep navigating through the site.


#### Navigating Your First Form

Next up, we find the form with **id="searchform"**, like we discovered in our first investigation of the site. There is a `form_with` method on any page object created by Mechanize which returns an object representing the form on the page matching those parameters. Pass in an id, and we get that specific form back as a Ruby object. 

However, we'll take one step further and pass it a block of configuration code, which is very common Ruby style. In that configuration code, we can directly fill in form fields by name. (Remember how we grabbed the field names in the setup?) You'll see below how that works:

```language-ruby
search_form = search_page.form_with(:id => 'searchform') do |search|
  search.query = "Garden Apartment"
  search.minAsk = 250
  search.maxAsk = 1500
end
```

The result? We have a `search_form` object with two fields filled out. This is going to be our test run, so we just make up some parameters for the query, minAsk and maxAsk fields.

With the form all set to go, we can submit the form and again return a new object representing the results page, using a convenient `submit` method found on Mechanize form objects:

```language-ruby
results_page = search_form.submit
```


#### Parsing Your Results

Now that you've got this far, it's going to be time to do some dirtier work: parsing your results. In order to do that, you probably want to pull up a console like Pry that lets you input Ruby code on the fly and try various commands out on your variables.

Right after that last `results_page = search_form.submit` line, add the line:
`binding.pry`. That means that when your script runs, it will stop at that point and start a console in which you can inspect current variables. Run your script on the command line by typing `ruby scrape.rb` and let the Pry session open.

First, just type `results_page` and see what happens. Pry has built-in object inspection, so it'll show you a giant object full of instance variables. Check out properties of the object like `forms` or `links` or the raw HTML with `body`.

But really, what you're looking to do is to grab a collection of all the results that you can then parse for data. You know each result is wrapped in a `<p class="row">` from initial investigations.

Luckily, your results_page also has a `search` method, thanks to the [Nokogiri gem](http://www.nokogiri.org/) it is based on, which works much like jQuery and other HTML parsers. In English, you can input the name of a CSS tag or class or ID and it will grab you anything that matches. 

After some fiddling, we discover that `results_page.search('p.row')` will give us an array of all the paragraphs of class "row". Then, we run an `each` iterator through all of those rows, grabbing the actual link inside that contains all the useful information for each result. That happens to be the SECOND link inside of the result. What that looks like in code:

```language-ruby
...
raw_results = result_page.search('p.row')
raw_results.each do |result|
  link = result.search('a')[1]
  # going to do the rest of the useful stuff
  # in here in a minute
end
...
```


#### Finally, Get Your Results

Now, it's time to parse those result fields in specific to get the information you'd like to save into your spreadsheet.

What can you grab from that initial search page? The link itself, the title of the listing, the price of the apartment, and the location. These take a lot more inspecting of the result element to figure out in detail, so we'll poke around for a while.

First, here's the results, and then a quick walkthrough to explain them:

```language-ruby
...
raw_results.each do |result|
  ...
  name = link.text.strip
  url = "http://sfbay.craigslist.org" + link.attributes["href"].value
  price = result.search('span.price').text
  location = result.search('span.pnr').text[3..-13]

  results << [name, url, price, location]
  ...
end
...
```

So the name is the easy part. It's just the text of the link, and you use `.strip` to remove extra whitespace.

The link tag has an `attributes` variable on it, which is basically a hash. Poking around that hash in Pry, we discover it has an 'href', which is exactly pulled from the text of the tag. The result of that is still an object, but its `value` is the actual text of the link. 

*The only easy way to do this is to keep interrogating objects in Pry and use the `inspect` method on anything you're confused about*. It may take a while, but you will eventually find the property you need. Additionally, since it's a relative link, we concatenate it with the BASE_URL we saved at the top of the file to make it a link you can visit from anywhere.

Finding the price involves going back to the browser and noticing that the actual price is inside a span of class "price". So we search our specific result for 'span.price', then get its `text`, which includes a dollar sign. If we want to turn it into a number later, we can, but that's not necessary right now.

Finally, more use of Inspect Element finds that there is only one way to get the neighborhood location: by grabbing `span.pnr`.  Unfortunately, the `<span>` with `class="pnr"` doesn't just contain the neighborhood, but also some unrelated text: `"  (sunset / parkside)    pic  map"`. 

There are cleaner and less clean ways to solve this problem, but we're going to do a quick-and-dirty approach that may not always work. You can play around with other methods. We'll just use a range on the string that removes the first 3 characters and the last 12, all of which appear to be filler in all of the tags we've seen so far. That gets us just what's inside the parentheses, such as: 'sunset / parkside'.

Finally, we push this row of result to the master results object (that's the << operator). But realizing that it would be nice to have headings for each column of results, we hop back up to when we defined the array in the first place and add `results << ['Name', 'URL', 'Price', 'Location']`.

So now we have a bunch of data. Let's move on to saving it to a file you can read in a spreadsheet.

But first, your entire script so far:

```language-ruby

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

  # work with the form
  form = search_page.form_with(:id => 'searchform') do |search|
    search.query = 'Garden'
    search.maxAsk = 1500
  end
  result_page = form.submit

  # get the results
  raw_results = result_page.search('p.row')

  #parse the results
  raw_results.each do |result|
    link = result.css('a')[1]

    name = link.text.strip
    url = "http://sfbay.craigslist.org" + link.attributes["href"].value
    price = result.search('span.price').text
    location = result.search('span.pnr').text[3..-13]

    #save the results
    results << [name, url, price, location]
  end
end
```


#### Saving Your File

One thing you don't realize is how easy we've made it for you to save this stuff into a file. A Comma-Separated-Value spreadsheet is already formatted the way your two-dimensional array looks: the first row is an array of headings, and all the rest of the rows are your entries. There is a convenient CSV library for Ruby, and we've already included it, so all we need to do is use its methods to save a new file.

The text of that file-saving apparatus looks like this:

```language-ruby
CSV.open("filename.csv", "w+") do |csv_file|
    results.each do |row|
        csv_file << row
    end
end
```

What's happening?

You're calling the CSV class to open a file named 'filename.csv' in Write-Plus mode. That means that if the file already exists, you blow it away and rewrite it. If it doesn't, you start a new file. (There's also 'a+' mode, Append-Plus mode, which instead just adds new data to the end of a file if it's already there).

Inside the block, you have a `csv_file` object you can simply append to like an array. Every array you shovel onto it, it treats like a new line that should be written to the file. So, you loop through your 2D `results` array, row by row and shovel them all onto this file object. That's IT.

Now you have a CSV file you can open in any spreadsheet program, upload to Google Docs, read in Excel or OpenOffice, anything you'd like. Any time you want new data, you just rerun your scraper and let it take all the notes in the background. You can extend this by having it actually click the links and visit the pages of the listings as well, but we'll leave that exercise to you.

All you have to do to change your scrape is to go into the form section and change your form inputs and queries. If you're a little more seasoned, you can redesign this to pass in variables instead, wrap object-orientation around this process, whatever you'd like to modularize your code.

In the meantime, you have a custom list of apartments you can refresh and filter in a spreadsheet without ever firing up a browser. That's pretty cool.