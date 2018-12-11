lookup_friends:
	R --vanilla < lookup_friends.R > logs/lookup_friends.log 2>&1

fetch_friends:
	R --vanilla < fetch_friends.R > logs/fetch_friends.log 2>&1

scrape:
	R --vanilla < scraper.R > logs/scraper.log 2>&1

json_mdb2017:
	wget https://www.abgeordnetenwatch.de/api/parliament/bundestag/deputies.json

