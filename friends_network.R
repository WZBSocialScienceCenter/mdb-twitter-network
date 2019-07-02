# TODOs:
# - Daten aktualisieren
# - Vergl. mit neuen Daten
# - Dokumentation

library(dplyr)
library(tidyr)
library(ggplot2)
library(igraph)
library(visNetwork)

# ---- load and prepare data about deputies and their twitter handles ----

dep_twitter_full <- read.csv('data/deputies_twitter.csv', stringsAsFactors = FALSE)
head(dep_twitter_full)

dep_twitter <- filter(dep_twitter_full, !is.na(twitter_name)) %>%
    select(twitter_name, personal.first_name, personal.last_name, personal.gender, personal.birthyear,
           personal.location.state, personal.location.city, party)

# ---- prepare colors for parties ----

unique(dep_twitter$party)

party_colors <- c(   # HTML codes for colors to later add a transparency value
    'SPD' = '#CC0000',
    'CDU' = '#000000',
    'DIE GRÜNEN' = '#33D633',
    'DIE LINKE' = '#800080',
    'FDP' = '#EEEE00',
    'AfD' = '#0000ED',
    'CSU' = '#ADD8E6',
    'fraktionslos' = '#808080'
)

party_colors_semitransp <- paste0(party_colors, '40')   # add transparency
names(party_colors_semitransp) <- names(party_colors)

# ---- load and prepare deputies' twitter connections data ----

friends_full <- readRDS('data/deputies_twitter_friends_full.RDS')

friends <- select(friends_full, user, fetch_friends_timestamp, fetch_friendsdata_timestamp,
                  created_at, screen_name, name, location, description, 
                  protected, followers_count, friends_count, statuses_count, account_created_at, verified,
                  account_lang)
head(friends)

# a few NAs for "screen_name"; remove those observations

friends[is.na(friends$screen_name),]

friends <- filter(friends, !is.na(screen_name))

# retain only the connections between deputies, not to other twitter accounts

dep_accounts <- unique(friends$user)

dep_friends <- filter(friends, screen_name %in% dep_accounts)
head(dep_friends)

stopifnot(sum(!(dep_friends$user %in% dep_twitter$twitter_name)) == 0)

#dep_friends <- left_join(dep_friends, dep_twitter, by = c('user' = 'twitter_name'))
#sum(is.na(dep_friends$party))

# ---- followings / followers share between parties ----

dep_accounts_parties <- select(dep_twitter, twitter_name, party)

edges_parties <- select(dep_friends, from_account = user, to_account = screen_name) %>%
    left_join(dep_accounts_parties, by = c('from_account' = 'twitter_name')) %>%
    rename(from_party = party) %>%
    left_join(dep_accounts_parties, by = c('to_account' = 'twitter_name')) %>%
    rename(to_party = party) %>%
    filter(from_party != 'fraktionslos' & to_party != 'fraktionslos')

head(edges_parties)

counts_p2p <- group_by(edges_parties, from_party, to_party) %>% count() %>% ungroup()
counts_party_edges <- group_by(counts_p2p, from_party) %>% summarise(n_edges = sum(n))
counts_p2p <- left_join(counts_p2p, counts_party_edges, by = 'from_party') %>%
    mutate(prop = n/n_edges) %>% select(-n_edges)
head(counts_p2p)

#interaction(counts_p2p$from_party, counts_p2p$to_party)

p2p_mat <- select(counts_p2p, -n) %>% spread(to_party, prop) %>%
    mutate_all(function(x) { ifelse(is.na(x), 0, x) })
p2p_mat

rowSums(as.matrix(p2p_mat[, 2:8]))   # rows sum up to 1

counts_p2p <- gather(p2p_mat, 'to_party', 'prop', 2:ncol(p2p_mat)) %>% arrange(from_party, to_party) %>%
    mutate(perc_label = sprintf('%.2f', prop * 100))
counts_p2p

p <- ggplot(counts_p2p, aes(x = to_party, y = from_party, fill = prop * 100)) +
    geom_raster() +
    geom_text(aes(label = perc_label), color = 'white') +
    scale_fill_viridis_c(guide = guide_legend(title = 'Followers / following\nshare in percent')) +
    labs(x = 'party in column is followed by party in row', y = 'party in row follows party in column',
         title = 'Proportion of followings / followers between parties') +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
p

ggsave('plots/p2p_follower_shares.png', p, width = 8, height = 6)

# TODO: do this on deputy level


# ---- create and edge list ----

edgelist <- select(dep_friends, from_account = user, to_account = screen_name) %>%
    left_join(select(dep_twitter, twitter_name, party), by = c('from_account' = 'twitter_name'))

head(edgelist)

# remove accounts that are not connected to any other deputy account

accounts_connected <- unique(c(edgelist$from_account, edgelist$to_account))
accounts_not_connected <- dep_twitter$twitter_name[!(dep_twitter$twitter_name %in% accounts_connected)]
accounts_not_connected

dep_twitter_connected <- filter(dep_twitter, twitter_name %in% accounts_connected)

# ---- create an igraph object ----

g <- graph_from_data_frame(edgelist, vertices = dep_twitter_connected)
g

# set the vertice and edge colors according to party membership

V(g)$color <- party_colors[V(g)$party]
E(g)$color <- party_colors_semitransp[E(g)$party]

# ---- create a layout and plot a static image ----

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

# ---- visNetwork interactive plot ----

vis_nw_data <- toVisNetworkData(g)

vis_nw_data$nodes$title <- sprintf('@%s (%s %s)', vis_nw_data$nodes$id, vis_nw_data$nodes$personal.first_name, vis_nw_data$nodes$personal.last_name)
head(vis_nw_data$nodes)

vis_nw_data$edges$color <- substr(vis_nw_data$edges$color, 0, 7)
head(vis_nw_data$edges)

vis_legend_data <- data.frame(label = names(party_colors), color = unname(party_colors), shape = 'square')

vis_nw <- visNetwork(nodes = vis_nw_data$nodes, edges = vis_nw_data$edges, height = '700px', width = '90%') %>%
    visIgraphLayout(layout = 'layout_with_drl', options=list(simmer.attraction=0)) %>%
    visEdges(color = list(opacity = 0.25), arrows = 'to') %>%
    visNodes(labelHighlightBold = TRUE, borderWidth = 1, borderWidthSelected = 12) %>%
    visLegend(addNodes = vis_legend_data, useGroups = FALSE, zoom = FALSE, width = 0.2) %>%
    visOptions(nodesIdSelection = TRUE, highlightNearest = TRUE, selectedBy = 'party') %>%
    visInteraction(dragNodes = FALSE)

visSave(vis_nw, file = 'dep_visnetwork.html')
