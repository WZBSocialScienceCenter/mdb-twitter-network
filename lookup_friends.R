library(dplyr)
library(rtweet)

source('twitterkeys.R')


friends <- readRDS('data/deputies_twitter_friends_tmp.RDS')

token <- create_token(
    app = "WZBAnalysis",
    consumer_key = consumer_key,
    consumer_secret = consumer_secret,
    access_token = access_token,
    access_secret = access_secret)

friends_ids <- unique(friends$user_id)
#friends_ids <- friends_ids[1:1000]   # subset for testing

n_friends_ids <- length(friends_ids)

n_retries <- 5
sleep_sec <- 15 * 60  # 15 minutes is the time window for rate limit reset
chunksize <- 100      # the docs say 300 requests with 100 IDs each per 15 min.
n_max_requests <- 280
chunk_idx <- 0
cur_retry <- 0
friendsdata <- data_frame()

print('fetching data from Twitter API...')

request_i <- 0
while(TRUE) {
    chunk_start <- chunk_idx * chunksize + 1
    chunk_end <- min(c((chunk_idx + 1) * chunksize, n_friends_ids))
    friends_ids_chunk <- friends_ids[chunk_start:chunk_end]
    print(sprintf('fetching data for friends IDs in range [%d, %d] (%d ids)', chunk_start, chunk_end, length(friends_ids_chunk)))
    
    
    success <- tryCatch({
        request_i <- request_i + 1
        friendsdata_chunk <- lookup_users(friends_ids_chunk)
        friendsdata <- bind_rows(friendsdata, friendsdata_chunk)
        TRUE
    }, error = function(cond) {
        FALSE
    })
    
    if (success) {
        cur_retry <- 0
        
        if (chunk_start + chunksize > n_friends_ids) {
            break()
        }
    } else {
        cur_retry <- cur_retry + 1
        
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
    
    if (success) {   # if no success, retry with same chunk
        chunk_idx <- chunk_idx + 1
    }
}

n_fetched <- sum(!is.na(friendsdata$screen_name))
print(sprintf('got data for %d out of %d unique friends accounts', n_fetched, n_friends_ids))

friendsdata$fetch_friendsdata_timestamp <- Sys.time()

print('joining data...')
friendsfull <- left_join(friends, friendsdata, by = 'user_id')
n_matched <- sum(!is.na(friendsfull$screen_name))
print(sprintf('matching successful for %d out of %d rows', n_matched, nrow(friends)))

saveRDS(friendsfull, 'data/deputies_twitter_friends_full.RDS')
friendsfull_csvfriendly <- select_if(friendsfull, function(x) all(!is.list(x)))
write.csv(friendsfull_csvfriendly, 'data/deputies_twitter_friends.csv', row.names = FALSE)
