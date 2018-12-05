# Twitter Namen zu Profilen von abgeordnetenwatch.de hinzufügen.
#
# Dez. 2018, Markus Konrad <markus.konrad@wzb.eu>
#

library(dplyr)
library(jsonlite)

dep_links <- read.csv('data/deputies_custom_links.csv', stringsAsFactors = FALSE)

# Twitter Name aus URL herausfischen
pttrn_twitter <- '^https?://(www\\.)?twitter\\.com/([A-Za-z0-9_-]+)/?'
matches <- regexec(pttrn_twitter, dep_links$custom_links)
dep_links$twitter_name <- sapply(regmatches(dep_links$custom_links, matches),
                                function(s) { if (length(s) == 3) s[3] else NA })

#as.tibble(sample_n(dep_links[c('custom_links', 'twitter_name')], 10))

dep_twitter <- dep_links[!is.na(dep_links$twitter_name), ]

# Verbinden mit kompletten Daten
deputies <- fromJSON('data/deputies.json', flatten = TRUE)

dep <- as.tibble(deputies$profiles) %>% select(starts_with('meta'), starts_with('personal'), 'party',
                                               starts_with('parliament'))

dep <- dep %>% left_join(dep_twitter %>% select(uuid, twitter_name, twitter_url = custom_links), by = c('meta.uuid' = 'uuid'))

dep %>% select(personal.first_name, personal.last_name, party, twitter_name)

write.csv(dep, 'data/deputies_twitter.csv', row.names = FALSE)
