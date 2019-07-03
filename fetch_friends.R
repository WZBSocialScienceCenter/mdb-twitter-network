# This script fetches the "following" list (called "friends" in Twitter API terminology) of each deputy
# Twitter profile using the `rtweet` package; because of Twitter API's rate limiting, this takes quite
# some time; saves the result – consisting of Twitter user IDs – in `data/deputies_twitter_friends_tmp.RDS`.
#
# December 2018, Markus Konrad <markus.konrad@wzb.eu>
#

library(dplyr)
library(rtweet)

source('twitterkeys.R')  # contains access tokens for Twitter API

# ---- load deputies data with their Twitter handle ----

dep <- read.csv('data/deputies_twitter_20190702.csv',
                stringsAsFactors = FALSE,
                colClasses = c(personal.location.postal_code = "character"))

twitternames <- filter(dep, !is.na(twitter_name)) %>% pull(twitter_name) %>% unique()
n_twitternames <- length(twitternames)

# ---- fetch list of Twitter friends ----

# get authentication token for Twitter API
token <- create_token(
  app = twitter_app,
  consumer_key = consumer_key,
  consumer_secret = consumer_secret,
  access_token = access_token,
  access_secret = access_secret)

print(paste('will fetch list of friends for', n_twitternames, 'users'))

# this will return a data frame consisting of column "user" (the deputy Twitter handle) and
# "user_id", which is a Twitter user ID of a friend of the respective "user"
# we will need to use "lookup_users()" in order to get information such as the Twitter name
# about the friends user IDs
friends <- get_friends(twitternames, retryonratelimit = TRUE)
friends$fetch_friends_timestamp <- Sys.time()   # add a timestamp for the collection time

head(friends)

# save to file
saveRDS(friends, 'data/deputies_twitter_friends_tmp_20190702.RDS')
