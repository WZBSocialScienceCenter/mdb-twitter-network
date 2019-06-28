library(dplyr)
library(igraph)


friends_full <- readRDS('data/deputies_twitter_friends_full.RDS')


friends <- select(friends_full, user, fetch_friends_timestamp, fetch_friendsdata_timestamp,
                  created_at, screen_name, name, location, description, 
                  protected, followers_count, friends_count, statuses_count, account_created_at, verified,
                  account_lang)
head(friends)

friends[is.na(friends$screen_name),]

friends <- filter(friends, !is.na(screen_name))

dep_accounts <- unique(friends$user)

dep_friends <- filter(friends, screen_name %in% dep_accounts)

edgelist <- select(dep_friends, from_account = user, to_account = screen_name) %>% distinct()


g <- graph_from_data_frame(edgelist)
g

lay <- layout_with_fr(g)
lay <- layout_nicely(g)

plot(g, layout = lay, vertex.size = 5, vertex.label.cex = 0.5, edge.arrow.size = 0.2)
