require 'scraperwiki'
require 'mechanize'

INITIAL_PAGE_URL = "https://www.yarracity.vic.gov.au/planning-and-building/planning-permits".freeze

url_base = "https://www.yarracity.vic.gov.au/planning-application-search"
url = url_base + "?suburb=(All)&street=(All)&status=Current&ward=(All)"

def clean_whitespace(a)
  a.gsub("\r", ' ').gsub("\n", ' ').squeeze(" ").strip
end

def get_page_data(page, url_base)
  comment_url = "mailto:info@yarracity.vic.gov.au"

  trs = page.search('table.search tbody tr')
  trs.each do |tr|
    texts = tr.search('td').map{|n| n.inner_text}
    council_reference = clean_whitespace(texts[0])

    info_url = url_base + "?applicationNumber=#{council_reference}"
    record = {
      'info_url' => info_url,
      'comment_url' => comment_url,
      'council_reference' => council_reference,
      'date_received' => Date.parse(texts[1]).to_s,
      'address' => clean_whitespace(texts[2]),
      'description' => clean_whitespace(texts[3]),
      'date_scraped' => Date.today.to_s
    }
    begin
      record["on_notice_from"] = Date.parse(texts[4]).to_s
    rescue
      # In case the date is invalid
    end

    puts "Saving record " + council_reference + " - " + record['address']
#       puts record
    ScraperWiki.save_sqlite(['council_reference'], record)
  end
end

agent = Mechanize.new
agent.verify_mode = OpenSSL::SSL::VERIFY_NONE

start_time = Time.now.to_f
initial_page = agent.get INITIAL_PAGE_URL

# Find and click the "View advertised applications" link
view_apps_link = initial_page.links.find { |link| link.text.include?("View advertised applications") }
duration = (Time.now.to_f - start_time).round(3) + 0.5
puts "Pausing #{duration}s"
sleep(duration)

start_time = Time.now.to_f
if view_apps_link
  page = view_apps_link.click
  # Now 'page' should be the page with the advertised applications
else
  raise "Could not find 'View advertised applications' link"
end
duration = (Time.now.to_f - start_time).round(3) + 0.5

page_no = 0
while page_no < 100
  get_page_data(page, url_base)

  links = page.search('div.pagination-container').search('a')
  next_page_link = links.find{|a| a.inner_text == 'Next'}

  unless next_page_link
    puts "Finished - no Next page"
    puts page.body
    break
  end

  puts "Pausing #{duration}s"
  sleep(duration)

  page_no += 1
  puts
  puts "Getting page: #{page_no}: #{url}"
  start_time = Time.now.to_f
  url = url_base + next_page_link["href"]
  page = agent.get url
  duration = (Time.now.to_f - start_time).round(3) + 0.5
end

