# This script fetches Twitter profile data (like user name, bio, location, latest tweet, etc.) for each
# Twitter user ID that was obtained via `fetch_friends.R`; again, this takes quite some time; saves
# the result in `data/deputies_twitter_friends_full.RDS`.
#
# December 2018, Markus Konrad <markus.konrad@wzb.eu>
#


library(dplyr)
library(rtweet)

source('twitterkeys.R')

# ---- load the data with the friends user IDs ----

friends <- readRDS('data/deputies_twitter_friends_tmp_20190702.RDS')

friends_ids <- unique(friends$user_id)
#friends_ids <- friends_ids[1:1000]   # subset for testing
n_friends_ids <- length(friends_ids)

# ---- look up information about each friend user ID ----

n_retries <- 5         # maximum number of *subsequent* retries when an API call failed
sleep_sec <- 16 * 60   # 15 minutes is the time window for rate limit reset; add a little time buffer of 1 min.
chunksize <- 100       # number of user IDs per request; the docs say 300 requests with 100 IDs each per 15 min.
n_max_requests <- 280  # max. number of requests within a 15 min. time frame; we stay a bit below the 300 requests threshold
chunk_idx <- 0         # current chunk index
cur_retry <- 0         # current number of retries; is reset to 0 once a successful API call was made
friendsdata <- tibble()   # collected data

print('fetching data from Twitter API...')

# get authentication token for Twitter API
token <- create_token(
    app = twitter_app,
    consumer_key = consumer_key,
    consumer_secret = consumer_secret,
    access_token = access_token,
    access_secret = access_secret)

request_i <- 0   # current number of requests

# repeat API requests until all data was collected or too many retries happened due to request failures
while(TRUE) {
    # get chunk of friends IDs
    chunk_start <- chunk_idx * chunksize + 1
    chunk_end <- min(c((chunk_idx + 1) * chunksize, n_friends_ids))
    friends_ids_chunk <- friends_ids[chunk_start:chunk_end]
    print(sprintf('fetching data for friends IDs in range [%d, %d] (%d ids)',
                  chunk_start, chunk_end, length(friends_ids_chunk)))
    
    # make an API request for user ID lookup
    # if it successes, add the data to the "friendsdata" data frame set "success" to TRUE,
    # else do not add data and set "success" to FALSE
    success <- tryCatch({
        request_i <- request_i + 1
        friendsdata_chunk <- lookup_users(friends_ids_chunk)
        friendsdata <- bind_rows(friendsdata, friendsdata_chunk)
        TRUE
    }, error = function(cond) {
        FALSE
    })
    
    if (success) {  # on success
        cur_retry <- 0   # reset number of retries
        
        # check if we collected data for all IDs
        if (chunk_start + chunksize >= n_friends_ids) {
            break()
        }
    } else {  # on failure
        # increment the number of retries
        cur_retry <- cur_retry + 1
        
        # check if number of retries reached maximum
        if (cur_retry >= n_retries) {
            print(sprintf('failed after %d retries', cur_retry))
            break()
        }
        
        print(sprintf('will advance with retry %d', cur_retry))
    }
    
    if (request_i %% n_max_requests == 0 || !success) {    # wait after max. num. requests or when no success
        print(sprintf('waiting for %d sec.', sleep_sec))
        Sys.sleep(sleep_sec)
    }
    
    if (success) {   # if no success, retry with same chunk, otherwise increment chunk index
        chunk_idx <- chunk_idx + 1
    }
}

# ---- process collected friends data ----

n_fetched <- sum(!is.na(friendsdata$screen_name))
print(sprintf('got data for %d out of %d unique friends accounts', n_fetched, n_friends_ids))

friendsdata$fetch_friendsdata_timestamp <- Sys.time()   # add timestamp

# join friends user data by user ID
print('joining data...')
friendsfull <- left_join(friends, friendsdata, by = 'user_id')
n_matched <- sum(!is.na(friendsfull$screen_name))
print(sprintf('matching successful for %d out of %d rows', n_matched, nrow(friends)))

# save as RDS
saveRDS(friendsfull, 'data/deputies_twitter_friends_full_20190702.RDS')

# friendsfull_csvfriendly <- select_if(friendsfull, function(x) all(!is.list(x)))
# write.csv(friendsfull_csvfriendly, 'data/deputies_twitter_friends.csv', row.names = FALSE)
