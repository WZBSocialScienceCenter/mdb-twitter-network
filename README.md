# Twitter network of members of the 19th German Bundestag

December 2018 and July 2019, Markus Konrad <markus.konrad@wzb.eu>

Wissenschaftszentrum Berlin für Sozialforschung / WZB Social Science Center

This repository contains R scripts for

1. scraping links to social media accounts of members of the 19th German Bundestag (called deputies here);
2. fetching the "following" list for those deputies with a Twitter account (i.e. which Twitter accounts does a deputy follow);
3. processing and visualizing this data as network.

The respective downloaded and processed data also resides in the `data` directory.

TODO: link to blog post

## Data sources

Data on German representatives in different parliaments can be found on [abgeordnetenwatch.de](https://www.abgeordnetenwatch.de), which also provides an [API](https://www.abgeordnetenwatch.de/api). The list of deputies of the current (19th) German Bundestag is obtained from:

https://www.abgeordnetenwatch.de/api/parliament/bundestag/deputies.json

Unfortunately, links to social media profiles cannot be obtained via this API, although the data is available on the profile pages for individual deputies, see for example [this profile](https://www.abgeordnetenwatch.de/profile/anke-domscheit-berg). These links are extracted via scraping.

## Scripts

At first, the file `deputies.json` from the above link must be downloaded. The process of obtaining the social media data is divided into the following scripts:

1. `scraper.R` – scrapes the abgeordnetenwatch.de profile page of each deputy from `data/deputies.json` in order to extract the links to social media platforms; saves the result in `data/deputies_custom_links.csv`
2. `twitter_profiles.R` – extracts the Twitter handles (where present) from the social media links for each deputy and combines that information with the deputies' profile data from abgeordnetenwatch.de; saves the result in `deputies_twitter.csv`
3. `fetch_friends.R` – fetches the "following" list (called "friends" in Twitter API terminology) of each deputy Twitter profile using the `rtweet` package; because of Twitter API's rate limiting, this takes quite some time; saves the result –  consisting of Twitter user IDs – in `data/deputies_twitter_friends_tmp.RDS`
4. `lookup_friends.R` – fetches Twitter profile data (like user name, bio, location, latest tweet, etc.) for each Twitter user ID that was obtained via `fetch_friends.R`; again, this takes quite some time; saves the result in `data/deputies_twitter_friends_full.RDS`

There is a `Makefile` which allows calling the scripts directly and running them in the background from command line. They write their output in the respective file in the `logs` folder.

The datasets `deputies_twitter.csv` and `deputies_twitter_friends_full.RDS` can be joined resulting in a dataset with deputies and a list of Twitter profiles that they follow.

The script `friends_network.R` uses this dataset to create and visualize the Twitter network between deputies (i.e. who follows whom / who is followed by whom).
