library(dplyr)
library(rtweet)

source('twitterkeys.R')

mdb <- read.csv('data/deputies_twitter.csv',
                stringsAsFactors = FALSE,
                colClasses = c(personal.location.postal_code = "character"))

mdb <- mdb %>% filter(!is.na(twitter_name)) %>%
  select(personal.first_name, personal.last_name, personal.gender, personal.birthyear, party, twitter_name, twitter_url) %>%
  mutate(personal.gender = as.factor(personal.gender),
         party = as.factor(party))

token <- create_token(
  app = "WZBAnalysis",
  consumer_key = consumer_key,
  consumer_secret = consumer_secret,
  access_token = access_token,
  access_secret = access_secret)

twitternames <- unique(mdb$twitter_name)
n_twitternames <- length(twitternames)

print(paste('will fetch list of friends for', n_twitternames, 'users'))

friends <- get_friends(twitternames, retryonratelimit = TRUE)
friends$fetch_friends_timestamp <- Sys.time()

saveRDS(friends, 'data/deputies_twitter_friends_tmp.RDS')
