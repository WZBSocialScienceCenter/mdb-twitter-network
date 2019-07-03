# This script extracts the Twitter handles (where present) from the social media links for each
# deputy and combines that information with the deputies' profile data from abgeordnetenwatch.de;
# saves the result in `deputies_twitter.csv`
#
# December 2018, Markus Konrad <markus.konrad@wzb.eu>
#

library(dplyr)
library(tibble)
library(jsonlite)

# ---- load and process social media links ----

# load links obtained from scraping
dep_links <- distinct(read.csv('data/deputies_custom_links_20190702.csv', stringsAsFactors = FALSE))

# extract Twitter handle from Twitter URLs
# matches the following strings where optional parts are given in [brackets]:
# http[s]://[www.]twitter.com/<NAME>[/]
pttrn_twitter <- '^https?://(www\\.)?twitter\\.com/([A-Za-z0-9_-]+)/?'
matches <- regexec(pttrn_twitter, dep_links$custom_links)
dep_links$twitter_name <- sapply(regmatches(dep_links$custom_links, matches),
                                function(s) { if (length(s) == 3) s[3] else NA })   # if there's a match, take component 3 (the Twitter handle)

# have a look at a sample
sample_n(dep_links[c('custom_links', 'twitter_name')], 10)

# filter to get only the rows with extracted Twitter handles
dep_twitter <- dep_links[!is.na(dep_links$twitter_name), ]
head(dep_twitter)

# corrections for wrong links to Twitter (affects two accounts)
# e.g. "https://twitter.com/twitter.com/MartinaRenner"
pttrn_twitter_correct <- '/([A-Za-z0-9_-]+)/?$'
matches <- regexec(pttrn_twitter_correct, dep_twitter[dep_twitter$twitter_name == 'twitter', 'custom_links'])
dep_twitter[dep_twitter$twitter_name == 'twitter', ]$twitter_name <- sapply(
    regmatches(dep_twitter[dep_twitter$twitter_name == 'twitter', 'custom_links'], matches),
    function(s) { s[2] })

# drop extremely short Twitter handles (invalid -- affects one account)
dep_twitter <- dep_twitter[nchar(dep_twitter$twitter_name) > 3, ]
print(paste('Anzahl Twitternamen:', nrow(dep_twitter)))

# further clean up
dep_twitter <- dep_twitter %>% select(-custom_links) %>%
    mutate(twitter_name = tolower(twitter_name)) %>%  # all to lowercase
    filter(!is.na(twitter_name) & twitter_name != 'search') %>%
    distinct()   # remove duplicates


# ---- join with deputies data ----

# load deputies data
deputies <- fromJSON('data/deputies_20190702.json', flatten = TRUE)

# select important columns
dep <- as_tibble(deputies$profiles) %>% select(starts_with('meta'), starts_with('personal'), 'party',
                                               starts_with('parliament'))

orig_nrows <- nrow(dep)

# join via abgeordnetenwatch.de profile UUID
dep <- dep %>% left_join(dep_twitter %>% select(uuid, twitter_name), by = c('meta.uuid' = 'uuid'))

stopifnot(orig_nrows == nrow(dep))

# have a glimpse
head(dep %>% select(uuid = meta.uuid, personal.first_name, personal.last_name, party, twitter_name))

# save result
write.csv(dep, 'data/deputies_twitter_20190702.csv', row.names = FALSE)
