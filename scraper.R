# This script scrapes the abgeordnetenwatch.de profile page of each deputy from `data/deputies.json` in
# order to extract the links to social media platforms; saves the result in
# `data/deputies_custom_links.csv`.
#
# December 2018, Markus Konrad <markus.konrad@wzb.eu>
#

library(jsonlite)
library(rvest)
library(dplyr)

# data from members of the 19th German Bundestag
# obtained from https://www.abgeordnetenwatch.de/api/parliament/bundestag/deputies.json
deputies <- fromJSON('data/deputies_20190702.json')

sleep_sec <- 10  # according to robots.txt

# get profile URLs
n_profiles <- nrow(deputies$profiles)
print(paste('Num. profiles:', n_profiles))

prof_urls <- deputies$profiles$meta %>% select(uuid, url)

#prof_urls <- prof_urls %>% head(10)

# function to fetch HTML from profile page and extract "further links" section
# ("Weiterführende Links von ...") on the page
fetch_urls <- function(profile_row) {
    print(paste('fetching profile page at', profile_row$url))
    
    # wait and fetch HTML
    Sys.sleep(sleep_sec)
    html <- read_html(profile_row$url)
    
    # extract links
    links <- html_nodes(html, 'div.deputy__custom-links ul.link-list li a')
    urls <- html_attr(links, 'href')
    
    if (length(urls) == 0) {
        urls <- NA
    }
    
    # return data frame for this deputy which will be concatenated to a single data frame
    # of all deputies
    data.frame(profile_row, custom_links = urls, stringsAsFactors = FALSE)
}

# apply fetch_urls to each profile
prof_urls_complete <- prof_urls %>% rowwise() %>% do(fetch_urls(.))

# save result
write.csv(prof_urls_complete, 'data/deputies_custom_links_20190702.csv', row.names = FALSE)

