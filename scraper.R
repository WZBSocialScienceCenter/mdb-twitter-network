# Scraper für "Weiterführende Links" von MdB Profilen auf abgeordnetenwatch.de.
#
# Nov. 2018, Markus Konrad <markus.konrad@wzb.eu>
#

library(jsonlite)
library(rvest)
library(dplyr)

# Daten der Abgeordneten für Bundestag 2017 - 2021
# abgerufen von https://www.abgeordnetenwatch.de/api/parliament/bundestag/deputies.json
deputies <- fromJSON('data/deputies.json')

sleep_sec <- 10  # nach robots.txt

# Profil URLs
prof_urls <- deputies$profiles$meta %>% select(uuid, url)

#prof_urls <- prof_urls %>% head(10)

fetch_urls <- function(profile_row) {
    print(paste('fetching profile page at', profile_row$url))
    
    # Warten und HTML abrufen
    Sys.sleep(sleep_sec)
    html <- read_html(profile_row$url)
    
    # Links in "Weiterführende Links von ..." extrahieren
    links <- html_nodes(html, 'div.deputy__custom-links ul.link-list li a')
    urls <- html_attr(links, 'href')
    
    if (length(urls) == 0) {
        urls <- NA
    }
    
    # Partiellen Dataframe zurückgeben
    data.frame(profile_row, custom_links = urls, stringsAsFactors = FALSE)
}

# fetch_urls pro Profil anwenden
# Auf Parallelisierung wird verzichtet um den Server nicht übermäßig zu beanspruchen...
prof_urls_complete <- prof_urls %>% rowwise() %>% do(fetch_urls(.))

# Speichern
write.csv(prof_urls_complete, 'data/deputies_custom_links.csv', row.names = FALSE)

