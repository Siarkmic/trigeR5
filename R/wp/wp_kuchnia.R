db <- dbConnect(drv = SQLite(), dbname = "data/wp.db")
#### KUCHNIA ####
adress <- "http://kuchnia.wp.pl/"
adresses <- adress %>%
  read_html() %>%
  html_nodes(css = "._1lXcfrU") %>%
  html_text %>%
  tolower() %>%
  gsub("[[:punct:]]", "", .) %>%
  gsub("[[:space:]]", "-", .) %>%
  chartr("ąćęłńóśźż", "acelnoszz", .) %>%
  paste0(adress, .)

links <- pblapply(adresses, function(one_ad) {
  ad_html <- read_html(one_ad)
  ad_nodes <- html_nodes(ad_html, css = "script")
  
  ad_text <- ad_nodes %>%
    grep("kuchnia.wp.pl", .) %>%
    ad_nodes[.] %>%
    as.character()
  
  biggest_list <- ad_text %>%
    stri_count_regex("kuchnia.wp.pl") %>%
    which.max()
  
  big_links <- biggest_list %>%
    ad_text[.] %>%
    stri_extract_all_regex("[[:alnum:]]+-[[:alnum:]-]+[[:digit:]]+[ag]")
  
  big_links
}) %>%
  unlist() %>%
  unique %>%
  paste0(adress, .)

# art_links <- links %>%
#   grep("a$", ., value = TRUE)
# gal_links <- links %>%
#   grep("g$", ., value = TRUE)

# Filter out galleries
links <- links %>%
  grep("a$", ., value = TRUE)

# db <- dbConnect(drv = SQLite(), dbname = "../data/wp.db")
db_links <- dbGetQuery(db, "SELECT links FROM wp_kuchnia")
links <- setdiff(links, db_links$links)

bodies <- pblapply(links, function(link) {
  tryCatch(link %>%
             read_html() %>%
             html_nodes(css = "p , ._1HGmjUl , ._1xAmRvR") %>%
             html_text() %>%
             paste0(collapse = " "),
           error = function(e) {
             "Hmm... Nie ma takiej strony."
           })
}) %>%
  unlist() %>%
  gsub("'", "''", .)

wp_kuchnia <- data_frame(links = links, bodies = bodies) %>%
  filter(bodies != "Hmm... Nie ma takiej strony.")

db_next <- "', '"

for (i in 1:nrow(wp_kuchnia)) {
  dbGetQuery(db,
             paste0("INSERT INTO wp_kuchnia (links, bodies) VALUES ('",
                    wp_kuchnia$links[i], db_next,
                    wp_kuchnia$bodies[i], "')"))
}

dbDisconnect(db)

update_csv('wp_kuchnia')
