# TODOs:
# - interaktiv?
# - Anteil Follower / Friends jew. anderer Parteien pro Account / pro Partei
# - ggraph?

library(dplyr)
library(igraph)

dep_twitter_full <- read.csv('data/deputies_twitter.csv', stringsAsFactors = FALSE)
head(dep_twitter_full)

dep_twitter <- filter(dep_twitter_full, !is.na(twitter_name)) %>%
    select(twitter_name, personal.first_name, personal.last_name, personal.gender, personal.birthyear,
           personal.location.state, personal.location.city, party)

unique(dep_twitter$party)

party_colors <- c(
    'SPD' = '#FF0000',
    'CDU' = '#000000',
    'DIE GRÜNEN' = '#00FF00',
    'DIE LINKE' = '#800080',
    'FDP' = '#FFFF00',
    'AfD' = '#0000FF',
    'CSU' = '#ADD8E6',
    'fraktionslos' = '#808080'
)

party_colors_semitransp <- paste0(party_colors, '40')
names(party_colors_semitransp) <- names(party_colors)

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
head(dep_friends)

stopifnot(sum(!(dep_friends$user %in% dep_twitter$twitter_name)) == 0)

#dep_friends <- left_join(dep_friends, dep_twitter, by = c('user' = 'twitter_name'))
#sum(is.na(dep_friends$party))

edgelist <- select(dep_friends, from_account = user, to_account = screen_name) %>%
    left_join(select(dep_twitter, twitter_name, party), by = c('from_account' = 'twitter_name'))

head(edgelist)

accounts_connected <- unique(c(edgelist$from_account, edgelist$to_account))
accounts_not_connected <- dep_twitter$twitter_name[!(dep_twitter$twitter_name %in% accounts_connected)]
accounts_not_connected

dep_twitter_connected <- filter(dep_twitter, twitter_name %in% accounts_connected)

g <- graph_from_data_frame(edgelist, vertices = dep_twitter_connected)
g

V(g)$color <- party_colors[V(g)$party]
E(g)$color <- party_colors_semitransp[E(g)$party]

#lay <- layout_with_kk(g)  # okay
#lay <- layout_with_fr(g)  # not optimal
lay <- layout_with_drl(g, options=list(simmer.attraction=0))  # good separation

#lay <- layout_nicely(g)  # uses fr

png('plots/dep_igraph_drl.png', width = 2048, height = 2048)
par(mar = rep(0.1, 4))   # reduce margins
plot(g, layout = lay,
     vertex.size = 2.5, vertex.label.cex = 1.2,   # 0.6
     vertex.label.color = 'black', vertex.label.family = 'arial',
     vertex.label.dist = 0.5, vertex.frame.color = 'white',
     edge.arrow.size = 1, edge.curved = TRUE)    # edge.arrow.size = 0.2 , edge.color = '#AAAAAA20'
legend('topright', legend = names(party_colors), col = party_colors,
       pch = 15, bty = "n",  pt.cex = 2.5, cex = 2,    # pt.cex = 1.25, cex = 0.7,  
       text.col = "black", horiz = FALSE)
dev.off()
