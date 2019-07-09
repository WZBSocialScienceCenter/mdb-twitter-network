# This script does some exploratory Twitter network analysis for followings between members of the
# German Bundestag.
#
# July 2019, Markus Konrad <markus.konrad@wzb.eu>
#

library(dplyr)
library(tidyr)
library(ggplot2)
library(igraph)
library(visNetwork)

# choose the dataset

#source_date <- '20181205'
#source_date_title <- 'December 05, 2018'
source_date <- '20190702'
source_date_title <- 'July 02, 2019'

# ---- load and prepare data about deputies and their twitter handles ----

dep_twitter_full <- read.csv(sprintf('data/deputies_twitter_%s.csv', source_date), stringsAsFactors = FALSE)
head(dep_twitter_full)

dep_twitter <- filter(dep_twitter_full, !is.na(twitter_name)) %>%    # dismiss rows without Twitter handle
    select(twitter_name, personal.first_name, personal.last_name, personal.gender, personal.birthyear,
           personal.location.state, personal.location.city, party)   # these may be variables of interest

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

party_colors_semitransp <- paste0(party_colors, '40')   # add transparency as hex code (25% transparency)
names(party_colors_semitransp) <- names(party_colors)

# ---- load and prepare deputies' Twitter connections data ----

friends_full <- readRDS(sprintf('data/deputies_twitter_friends_full_%s.RDS', source_date))

# in this dataset, "user" is the Twitter handle of the deputy and "screen_name" and further variables
# refer to the data of the deputy's Twitter "friend" (i.e. the account she/he follows)
friends <- select(friends_full, user, fetch_friends_timestamp, fetch_friendsdata_timestamp,
                  created_at, screen_name, name, location, description, 
                  protected, followers_count, friends_count, statuses_count, account_created_at, verified,
                  account_lang)  # these may be variables of interest
head(friends)

# a few NAs for "screen_name"; remove those observations

friends[is.na(friends$screen_name),]

friends <- filter(friends, !is.na(screen_name))

# retain only the connections between deputies, not to other Twitter accounts

dep_accounts <- unique(friends$user)   # Twitter handles of deputies

dep_friends <- filter(friends, screen_name %in% dep_accounts)   # only retain "friends" that are deputies
head(dep_friends)

stopifnot(sum(!(dep_friends$user %in% dep_twitter$twitter_name)) == 0)

# ---- followings / followers share between parties ----

# deputy Twitter handles and their party
dep_accounts_parties <- select(dep_twitter, twitter_name, party)

# make two joins to create a data frame with edges defined by "from_account", "from_party"
# and "to_account", "to_party"
no_party_label <- c('fraktionslos', 'parteilos')
edges_parties <- select(dep_friends, from_account = user, to_account = screen_name) %>%
    left_join(dep_accounts_parties, by = c('from_account' = 'twitter_name')) %>%
    rename(from_party = party) %>%
    left_join(dep_accounts_parties, by = c('to_account' = 'twitter_name')) %>%
    rename(to_party = party) %>%
    filter(!(tolower(from_party) %in% no_party_label | tolower(to_party) %in% no_party_label))

head(edges_parties)

# count how often each "from_party" -> "to_party" edge occurs
counts_p2p <- group_by(edges_parties, from_party, to_party) %>% count() %>% ungroup()
head(counts_p2p, 10)
# count the absolute number of edges per "from_party"; this is required to calculate the proportions
counts_party_edges <- group_by(counts_p2p, from_party) %>% summarise(n_edges = sum(n))
counts_party_edges
# add a column "prop" for the "from_party" -> "to_party" edges proportions
counts_p2p <- left_join(counts_p2p, counts_party_edges, by = 'from_party') %>%
    mutate(prop = n/n_edges) %>% select(-n_edges)
head(counts_p2p, 10)

stopifnot(min(counts_p2p$prop) > 0)
stopifnot(max(counts_p2p$prop) <= 1)

#interaction(counts_p2p$from_party, counts_p2p$to_party)

# create a matrix of "friends" proportions with "from_party" in rows and "to_party" in columns
p2p_mat <- select(counts_p2p, -n) %>% spread(to_party, prop) %>%
    mutate_all(function(x) { ifelse(is.na(x), 0, x) })   # some edge combinations do not occur -> replace NAs with 0
p2p_mat

# rows must sum up to 1
stopifnot(all(rowSums(as.matrix(p2p_mat[, 2:ncol(p2p_mat)])) == 1))

# to make a heatmap with ggplot, we can't use the matrix but need the "long format" with
# "from_party", "to_party", "prop" columns
# convert the matrix back to this format, because we already filled in 0 for edge combinations
# that did not occur
counts_p2p <- gather(p2p_mat, 'to_party', 'prop', 2:ncol(p2p_mat)) %>% arrange(from_party, to_party) %>%
    mutate(perc = prop * 100,                     # we use percent in the plot
           perc_label = sprintf('%.1f', perc))    # a label to display the rounded number in the cells
head(counts_p2p, 10)

# make a heatmap using geom_raster
p <- ggplot(counts_p2p, aes(x = to_party, y = from_party, fill = perc)) +
    geom_raster() +
    geom_text(aes(label = perc_label), color = 'white') +
    scale_fill_viridis_c(guide = guide_legend(title = 'Followers / following\nshare in percent')) +
    labs(x = 'party in column is followed by party in row', y = 'party in row follows party in column',
         title = 'Proportion of followings / followers between parties',
         subtitle = paste('In percent as of', source_date_title)) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
p

ggsave(sprintf('plots/p2p_follower_shares_%s.png', source_date), p, width = 8, height = 6)

# TODO: do this on deputy level?

# ---- create an edge list and vertices for igraph ----

# we can re-use the edges_parties data frame as edge list for igraph
head(edges_parties)

# remove accounts that are not connected to any other deputy account

accounts_connected <- unique(c(edges_parties$from_account, edges_parties$to_account))
accounts_not_connected <- dep_twitter$twitter_name[!(dep_twitter$twitter_name %in% accounts_connected)]
accounts_not_connected

# these accounts are used as vertices (aka nodes)
dep_twitter_connected <- filter(dep_twitter, twitter_name %in% accounts_connected)

# ---- create an visualize igraph network ----

g <- graph_from_data_frame(edges_parties, vertices = dep_twitter_connected)
g

# graph centrality scores

degree_score <- degree(g, mode = 'total')
betw_score <- betweenness(g)
stopifnot(all(names(betw_score) == names(degree_score)))
graph_scores <- data.frame(twitter_name = names(degree_score),
                           degr_score = degree_score,
                           betw_score = betw_score,
                           row.names = NULL, stringsAsFactors = FALSE)
graph_scores <- left_join(dep_twitter_connected, graph_scores, by = 'twitter_name') %>%
    mutate(full_name = paste(personal.first_name, personal.last_name)) %>%
    select(twitter_name, full_name, degr_score, betw_score, party)

graph_scores %>% arrange(desc(degree_score)) %>% head(10)
graph_scores %>% arrange(desc(betw_score)) %>% head(10)

# set the vertice and edge colors according to party membership

V(g)$color <- party_colors[V(g)$party]
E(g)$color <- party_colors_semitransp[E(g)$from_party]

# ---- create a layout and plot a static image ----

# can try out different layout algorithms
#lay <- layout_with_kk(g)  # okay
#lay <- layout_with_fr(g)  # not optimal
lay <- layout_with_drl(g, options=list(simmer.attraction=0))  # good separation

#lay <- layout_nicely(g)  # uses fr

png(sprintf('plots/dep_igraph_%s.png', source_date), width = 2048, height = 2048)
#par(mar = rep(0.1, 4))   # reduce margins
plot(g, layout = lay,
     vertex.size = 2.5, vertex.label.cex = 1.2,   # 0.6
     vertex.label.color = 'black', vertex.label.family = 'arial',
     vertex.label.dist = 0.5, vertex.frame.color = 'white',
     edge.arrow.size = 1, edge.curved = TRUE)    # edge.arrow.size = 0.2 , edge.color = '#AAAAAA20'
title(main = list('Twitter network of members of the German Bundestag', cex = 3.5),
      sub = list(paste('State as of', source_date_title), cex = 3))
legend('topright', legend = names(party_colors), col = party_colors,
       pch = 15, bty = "n",  pt.cex = 2.5, cex = 2,    # pt.cex = 1.25, cex = 0.7,  
       text.col = "black", horiz = FALSE)
dev.off()

# ---- visNetwork interactive plot ----

# convert igraph object to visNetwork data
vis_nw_data <- toVisNetworkData(g)

# add a title to be displayed when mouse is over a node
vis_nw_data$nodes$title <- sprintf('@%s (%s %s)', vis_nw_data$nodes$id,
                                   vis_nw_data$nodes$personal.first_name, vis_nw_data$nodes$personal.last_name)
head(vis_nw_data$nodes)

# strip transparency from edge color because visNetwork can't handle it
vis_nw_data$edges$color <- substr(vis_nw_data$edges$color, 0, 7)
head(vis_nw_data$edges)

# create a data frame for the legend
vis_legend_data <- data.frame(label = names(party_colors), color = unname(party_colors), shape = 'square')

# create the network
vis_nw <- visNetwork(nodes = vis_nw_data$nodes, edges = vis_nw_data$edges, height = '700px', width = '90%') %>%
    visIgraphLayout(layout = 'layout_with_drl', options=list(simmer.attraction=0)) %>%   # use same layout as above
    visEdges(color = list(opacity = 0.25), arrows = 'to') %>%                            # and same transparency
    visNodes(labelHighlightBold = TRUE, borderWidth = 1, borderWidthSelected = 12) %>%   # set node highlighting
    visLegend(addNodes = vis_legend_data, useGroups = FALSE, zoom = FALSE, width = 0.2) %>%   # add legend
    visOptions(nodesIdSelection = TRUE, highlightNearest = TRUE, selectedBy = 'party') %>%    # further options
    visInteraction(dragNodes = FALSE)   # disable dragging of nodes

visSave(vis_nw, file = sprintf('dep_visnetwork_%s.html', source_date))
