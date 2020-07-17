---
title: "WILDSI Use Cases"
author: "Blaise Alako"
date: "`r Sys.Date()`"
output:
  html_document: default
  pdf_document: default
---

- #### Load  libraries and Connect to the PostGreSQL SEQREF_DB


```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE)

library('RPostgreSQL')
library('tidyverse')
library('parallel')
library('maps')
library('viridis')
library('ggrepel')
require("ggrepel")
set.seed(42)
```

```{r, eval=T, echo=FALSE}
pg <- dbDriver('PostgreSQL')
conn<- dbConnect(pg, user='postgres',
                 password='l',
                 host="193.62.52.XXX",
                 port=5432, 
                 dbname='SEQREF_DB')
# Get data from DB
continent <- tibble::as.tibble(dbGetQuery(conn, "select * from continent"))
countries <- tibble::as.tibble(dbGetQuery(conn, "select * from country"))
geolocation <- tibble::as.tibble(dbGetQuery(conn, "select * from geolocation;"))
#join PMC_REFERENCES and ENA_SEQUENCES into on composite table for subsequent use
pmc_ena <- "select * from PMC_REFERENCES A
            LEFT  JOIN ena_sequences B  ON A.accession=B.accession 
            -- Exclude PMIDs
            WHERE A.accession !~'^[0-9]+$' and A.country <> 'NA' and B.country <> 'NA' 
			     and A.country in (select name from country) and B.country in (SELECT name from country);"
```


```{r, eval=T, echo=T}
system.time(pmc_ena <- dbGetQuery(conn, pmc_ena))
```

```{r}
column_name <- c('_id','accession','idpmc','source' ,'pubtype','issn','isopenaccess','secondary_pmid', 'secondary_pmcid','secondary_doi','author','affiliation','author_country',
                    'first_pub_date','first_epub_date', 'author_orcid', 'language','grantid','grant_agency','grant_acronym','receipt_data','revision_date',
                 'ena_accession','primary_pmid','primary_doi', 'primary_pmcid', 
                 'seq_origin','seq_country','submission_date', 'first_created', 'seq_lat_lon','organism', 'taxid','code','project_acc')
# Rename pmc_ena column header
colnames(pmc_ena) <- column_name
pmc_ena <- tbl_df(pmc_ena)
```

- #### Or Load data from Rdata object
```{r}
#load('seqref.Rdata')
```

## Use Case #1:

#### For each country in the world, please collect the following data:
- #### SELF: How many X COUNTRY scientists use X COUNTRY data?

```{r}
# A function that take a country name generates the above
self <- function (countryName='Cameroon'){
  pmc_ena %>% filter( author_country == countryName & seq_country == countryName) %>% 
    select(author_country, seq_country, ena_accession, author, secondary_pmid) %>% 
    unique() %>% group_by(author_country, seq_country) %>%
    mutate(nseq=length(unique(ena_accession)), nscientist=length(unique(author)),  npublication=length(unique(secondary_pmid))) %>%
    ungroup() %>% select (author_country, seq_country, nseq, nscientist, npublication) %>% unique()
}
# Loop through all country name 
system.time(selfUse <- mclapply(countries$name, function(x) self(countryName=x)))
# Merge the results
selfUseOnly<- do.call(rbind, selfUse)

selfUseOnly <- selfUseOnly %>% mutate(seqByScientist=nseq/nscientist, pubByScientist=npublication/nscientist)
selfUseOnly
```
- ####  TARGET: How many non-X COUNTRY scientists (all other countries) use X COUNTRY data?

```{r}
#A function that take a country name generates the above
target <- function (countryName='Cameroon'){
  pmc_ena %>% filter(seq_country==countryName & !author_country == countryName ) %>% 
    select(author_country, seq_country, ena_accession, author, secondary_pmid) %>%
    unique()  %>% group_by(author_country,seq_country) %>% 
    mutate(nscientist=length(unique(author)), nseq=length(unique(ena_accession)), npublication=length(unique(secondary_pmid))) %>%
    ungroup() %>% select(seq_country, author_country, nscientist, nseq, npublication) %>% unique()
}

# Loop through all country name 
system.time(targetByCountry <- mclapply(countries$name, function(x) target(countryName=x)))
# Merge the results
targetByCountry <- do.call(rbind, targetByCountry)
```

```{r}
targetByCountry <- targetByCountry %>% mutate(seqByScientist=nseq/nscientist, pubByScientist=npublication/nscientist)
targetByCountry
```

- ####  WORLD: How many X COUNTRY scientists use NON-X COUNTRY (all other country) data?
```{r}
worldUse <- function (countryName='Cameroon'){
  pmc_ena %>% filter(!seq_country==countryName & author_country == countryName ) %>% 
    select(author_country, seq_country, ena_accession, author, secondary_pmid) %>%
    unique()  %>% group_by(author_country,seq_country) %>% 
    mutate(nscientist=length(unique(author)), nseq=length(unique(ena_accession)), npublication=length(unique(secondary_pmid))) %>%
    ungroup() %>% select(seq_country, author_country, nscientist, nseq, npublication) %>% unique()
}

# Loop through all country name 
system.time(worldUseByCountry <- mclapply(countries$name, function(x) worldUse(countryName=x)))
# Merge the results
worldUseByCountry <- do.call(rbind, worldUseByCountry)
worldUseByCountry 
```

- #### WORLD USE ONLY

```{r}
worldUseOnly <- worldUseByCountry %>% group_by(author_country) %>%
  mutate(nscientist=sum(nscientist), nseq=sum(nseq), npublication=sum(npublication)) %>%
  ungroup() %>% select(author_country, nscientist, nseq, npublication) %>% unique() %>% mutate(seqByScientist=nseq/nscientist, pubByScientist=npublication/nscientist)
worldUseOnly 
```

```{r}
# Retrieve world map and rename UK and USA accordingly

world_map <- map_data("world")
world_map <- world_map %>% 
  mutate(region=ifelse (region=="UK", "United Kingdom", region)) %>% 
  mutate(region=ifelse (region=="USA", "United States", region))

```

#### Please create a table for each country in the world with these 3 data types. Next, please display 5 world maps as follows:
- ##### SELF-USE ONLY
```{r}
# Join geolocation info with Self only use
selfUseOnly_map <- left_join(world_map, selfUseOnly,  by = c("region"="author_country"))
```

- #####  Self Use map normalized by the cited sequences number
```{r}
ggplot(selfUseOnly_map, aes(long, lat, group = group))+ 
  geom_polygon(aes(fill = seqByScientist), color = "white", size=0.05)+
  scale_fill_viridis_c(option = "C", trans='sqrt') + ggtitle('Self Use only normalized by the number of sequences') + theme_void()
```

- ##### Self Use map normalized by the number of publication
```{r}
ggplot(selfUseOnly_map, aes(long, lat, group = group))+
  geom_polygon(aes(fill = pubByScientist), color = "white", size=0.05)+
  scale_fill_viridis_c(option = "C", trans='sqrt') + ggtitle('Self Use only normalized by the number of publication') + theme_void()
```

- ##### Self Use map Absolute scientist counts

```{r}
ggplot(selfUseOnly_map, aes(long, lat, group = group))+ 
  geom_polygon(aes(fill = nscientist), color = "white", size=0.05)+
  scale_fill_viridis_c(option = "C", trans='sqrt') + ggtitle('Self Use only Absolute scientists count') + theme_void()

```

- ##### Join geolocation info with world only use 
```{r}
worldUseOnly_map <- tbl_df(left_join(world_map, worldUseOnly , by = c("region"="author_country")))
worldUseOnly_map
```

- ##### World use only normalized by number of sequences cited.
```{r}
ggplot(worldUseOnly_map, aes(long, lat, group = group))+
  geom_polygon(aes(fill = seqByScientist), color = "white", size=0.05)+
  scale_fill_viridis_c(option = "C", trans='sqrt') + ggtitle('World Use only normalized by number of sequences') + theme_void()
```

- ##### World use only normalized by number of publication.
```{r}
ggplot(worldUseOnly_map, aes(long, lat, group = group))+
  geom_polygon(aes(fill = pubByScientist), color = "white", size=0.05)+
  scale_fill_viridis_c(option = "C", trans='sqrt') + ggtitle('World Use only normalized by publication') + theme_void()
```

- ##### World use only absolute scientist counts.
```{r}
ggplot(worldUseOnly_map, aes(long, lat, group = group))+
  geom_polygon(aes(fill = nscientist), color = "white", size=0.05)+
  scale_fill_viridis_c(option = "C", trans='sqrt') + ggtitle('World Use only absolute scientists count') + theme_void()
```


- ####  TARGET USE ONLY

```{r}
targetUseOnly <- targetByCountry %>% group_by(seq_country) %>% 
  mutate(nscientist=sum(nscientist), nseq=sum(nseq), npublication=sum(npublication)) %>% 
  ungroup() %>% select(seq_country, nscientist, nseq, npublication) %>% unique() %>%
  mutate(seqByScientist=nseq/nscientist, pubByScientist=npublication/nscientist)
targetUseOnly
```

- #### Join geolocation info with target only use 
```{r}
targetUseOnly_map <- tbl_df(left_join(world_map, targetUseOnly, by = c("region"="seq_country")))
```
- #### Create the map normalize by the number of sequences
```{r}
ggplot(targetUseOnly_map, aes(long, lat, group = group))+
  geom_polygon(aes(fill = seqByScientist), color = "white", size=0.05)+
  scale_fill_viridis_c(option = "C", trans = "sqrt") + ggtitle('Target Use normalized by number of sequences') + theme_void()
```

- #### Create the map normalized by the number of publication
```{r}
ggplot(targetUseOnly_map, aes(long, lat, group = group))+
  geom_polygon(aes(fill = pubByScientist), color = "white", size=0.05)+
  scale_fill_viridis_c(option = "C", trans = "sqrt") + ggtitle('Target Use normalized by number of publication') + theme_void()
```

- #### Create the map absolute number of sequence counts
```{r}
ggplot(targetUseOnly_map, aes(long, lat, group = group))+
  geom_polygon(aes(fill = nscientist), color = "white", size=0.05)+
  scale_fill_viridis_c(option = "C", trans = "sqrt") + ggtitle('Target Use , Absolute scientists count') + theme_void()
```

- #### World/Self: This ratio should answer the question: How much more often does a country’s scientists use sequence data generated by another country compared to using their own data relative to all other countries in the world?

```{r}
norm_world_self <- left_join(selfUseOnly,  worldUseOnly, by=c("author_country"="author_country")) %>% 
  rename(selfScientist=nscientist.x, worldScientist=nscientist.y, selfNseq=nseq.x, worldNseq=nseq.y, selfNpub=npublication.x, worldNpub = npublication.y) %>%
  mutate(seqByWorldSelf=(worldNseq/worldScientist)/(selfNseq/selfScientist), pubByWorldSelf=(worldNpub/worldScientist)/(selfNpub/selfScientist), worldBySelf=worldScientist/selfScientist) %>% 
  select (author_country,worldNseq,worldNpub, worldScientist, selfNseq, selfNpub, selfScientist, seqByWorldSelf,pubByWorldSelf, worldBySelf)
# Join geolocation info with world/Self 
worldSelf_map <- tbl_df(left_join(world_map, norm_world_self, by = c("region"="author_country")))
```


- #### Create the map Normalized by Sequences cited
```{r}
ggplot(worldSelf_map, aes(long, lat, group = group))+
  geom_polygon(aes(fill = seqByWorldSelf), color = "white", size=0.05)+
  scale_fill_viridis_c(option = "C", trans='sqrt') +
  ggtitle(paste('World/Self normalized by Sequences cited \n Ratio range=', paste(round(range(na.omit(worldSelf_map$seqByWorldSelf)),2), sep=" ", collapse="-"))) +
  theme_void()
```
- #### Create the map Normalized by number of publications
```{r}
ggplot(worldSelf_map, aes(long, lat, group = group))+
  geom_polygon(aes(fill = pubByWorldSelf), color = "white", size=0.05)+
  scale_fill_viridis_c(option = "C", trans='sqrt') +
  ggtitle(paste('World/Self normalized by Number of publications \n Ratio range=', paste(round(range(na.omit(worldSelf_map$pubByWorldSelf)),2), sep=" ", collapse="-"))) +
  theme_void()
```
- #### Create the map absolute ratio
```{r}
ggplot(worldSelf_map, aes(long, lat, group = group))+
  geom_polygon(aes(fill = worldBySelf), color = "white", size=0.05)+
  scale_fill_viridis_c(option = "C", trans='sqrt') +
  ggtitle(paste('World/Self absolute ratio \n Ratio range=', paste(round(range(na.omit(worldSelf_map$worldBySelf)),2), sep=" ", collapse="-"))) +
  theme_void()
```


- #### Target/Self: This ratio should answer the question: How much more often does a foreign scientist use a country’s sequence data compared to their own scientists using the country’s sequence data?

```{r}
target_self <- left_join(selfUseOnly,  targetUseOnly, by=c("author_country"="seq_country")) %>% rename(selfScientist=nscientist.x, targetScientist=nscientist.y) %>%
  mutate(target_over_self=targetScientist/selfScientist) %>% select (author_country,targetScientist, selfScientist, target_over_self)  

norm_target_self <- left_join(selfUseOnly,  targetUseOnly, by=c("author_country"="seq_country")) %>% 
  rename(selfScientist=nscientist.x, targetScientist=nscientist.y, selfNseq=nseq.x, targetNseq=nseq.y, selfNpub=npublication.x, targetNpub = npublication.y) %>%
  mutate(seqBytargetSelf=(targetNseq/targetScientist)/(selfNseq/selfScientist), pubBytargetSelf=(targetNpub/targetScientist)/(selfNpub/selfScientist), targetBySelf=targetScientist/selfScientist) %>% 
  select (author_country,targetNseq,targetNpub, targetScientist, selfNseq, selfNpub, selfScientist, seqBytargetSelf,pubBytargetSelf, targetBySelf  )  

targetSelf_map <- left_join(world_map, norm_target_self, by = c("region"="author_country"))
```
- ####  Create the map / By Seq

```{r}
ggplot(targetSelf_map, aes(long, lat, group = group))+
  geom_polygon(aes(fill = seqBytargetSelf), color = "white", size=0.05)+
  scale_fill_viridis_c(option = "C", trans='sqrt') + 
  ggtitle(paste('Target/Self Normalized by Sequences cited \n Ratio range=', paste(round(range(na.omit(targetSelf_map$seqBytargetSelf)),2), sep=" ", collapse="-"))) + theme_void()
```
- #### Create the map / By Pub
```{r}
ggplot(targetSelf_map, aes(long, lat, group = group))+
  geom_polygon(aes(fill = pubBytargetSelf), color = "white", size=0.05)+
  scale_fill_viridis_c(option = "C", trans='sqrt') + 
  ggtitle(paste('Target/Self Normalized by Number of publication \n Ratio range=', paste(round(range(na.omit(targetSelf_map$pubBytargetSelf)),2), sep=" ", collapse="-"))) + theme_void()
```

- #### Create the map / Absolute ratio
```{r}
ggplot(targetSelf_map, aes(long, lat, group = group))+
  geom_polygon(aes(fill = targetBySelf), color = "white", size=0.05)+
  scale_fill_viridis_c(option = "C", trans='sqrt') + 
  ggtitle(paste('Target/Self no normalization \n Ratio range=', paste(round(range(na.omit(targetSelf_map$targetBySelf)),2), sep=" ", collapse="-"))) + theme_void()
```

##  Use case #2: General statistics across ALL countries

```{r}
countries
```
```{r}
pmc_ena
```
```{r}
countries
```

```{r}
# Append North South to pmc_ena
pmc_ena <- tbl_df(left_join(pmc_ena, countries, by=c("author_country"="name")))
pmc_ena_north_south <- pmc_ena %>% select(accession, secondary_pmid, author, affiliation, author_country,seq_country,continent) %>% 
  group_by(secondary_pmid) %>% 
  mutate(north=ifelse(continent %in% c('EU','NA'), TRUE, FALSE), south=ifelse(continent %in% c('AS','AF','SA'), TRUE, FALSE)) 
```

- ####	How many publications that report on sequence data are north-north collaboration? (North = continents Europe and North America), South = (Asia, Africa, South America) North continent code: EU (Europe) NA (North America)

```{r}
# All authors are NORTH
north_north <- pmc_ena_north_south %>%
  filter(all(north)) %>% ungroup() %>% select(secondary_pmid, north)  %>% unique()
# Number of North-North Publication 
dim(north_north )[1]
```

- #### How many publications are north-south collaboration?


```{r}
# Number of North-South Publication : The publication has a least one other from both North and south.
# Table with the corresponding pmid follows
north_south<- pmc_ena_north_south %>%  filter(any(north) & any(south)) %>% 
  ungroup() %>% select (secondary_pmid) %>% unique()
# Number of North-South Publication 
dim(north_south)[1]
```

- ####	How many publications are south-south collaboration?
```{r}
# Strictly South author
south_south <- pmc_ena_north_south %>%  filter(all(south)) %>% 
  ungroup() %>% select (secondary_pmid) %>% unique()
# Number of North-South Publication 
dim(south_south)[1]
```

- ####	How many publications are 1 country only? 

```{r}
# Table with the corresponding pmid follows
one_country_pub <- pmc_ena_north_south %>% select(secondary_pmid, author_country) %>% 
  group_by(secondary_pmid) %>% 
  mutate(country_count = length(unique(author_country))) %>% 
  select(secondary_pmid, country_count) %>%
  filter(country_count==1) %>%
  ungroup() %>% unique() 

# How many publications are 1 country only?
dim(one_country_pub)[1]
```


- ####	What is the average (geometric mean) number of countries on a publication that uses sequence data?
```{r}
gmean <- function(x) exp(mean(log(x)))
pmc_ena %>% select(secondary_pmid, author_country) %>% 
  unique() %>% group_by(secondary_pmid) %>%
  mutate(ncountry=length(unique(author_country))) %>% 
  select(secondary_pmid, ncountry) %>% 
  unique() %>% ungroup() %>% unique() %>%
  summarise(geometric_mean=gmean(ncountry))
```

## Use case #3: For each country in the world please make a map showing:
- ####	How many total collaborations do they have?

```{r}
# Extract list of pmid with cameroonian author
# pmc_ena %>% select(secondary_pmid, author_country) %>% filter(author_country =='Cameroon') %>% select(secondary_pmid) %>%unique()

collaboration_count <- function(countryName='Cameroon'){
  pmid <-  pmc_ena  %>% filter(author_country ==countryName) %>% 
    select(secondary_pmid) %>%unique()
  if(length(pmid$secondary_pmid)>0){
    collab <- pmc_ena %>% filter(secondary_pmid %in% pmid$secondary_pmid) %>% 
    select(secondary_pmid, author_country) %>% unique() %>% 
    filter(!author_country==countryName) %>% select(author_country) %>% unique()
    if(dim(collab)[1] > 0){
      result <- data.frame(country=countryName, ncollab=dim(collab)[1], partner=collab$author_country)
      result
  }
  }
}

collabList <- mclapply(countries$name, function(x) collaboration_count (countryName=x))

collaborator<- tbl_df(do.call(rbind, collabList))
collaborator
collaborator %>% select(country, ncollab) %>% unique()
```
- #### World map with collaborator numbers.
```{r}
collab_map <-tbl_df(left_join(collaborator %>% select(country, ncollab) %>% unique(), world_map, by=c("country"="region")))
island <- c('Tonga','Solomon Islands','Samoa','Tonga','Marshall Islands','Guadeloupe','Martinique','Bermuda', 'Comoros','Haiti ','Jamaica','French Polynesia')
label_data <- collab_map %>% group_by(country, ncollab) %>% summarise(long=mean(long), lat=mean(lat))  %>% mutate(group="NA")
ggplot(collab_map, aes(long, lat, group = group))+
  geom_polygon(aes(fill = ncollab), color = "white", size=0.05)+
  scale_fill_viridis_c(option = "C", trans='sqrt') +
  geom_text_repel(data=label_data, aes(x=long, y=lat, label=ncollab),size=3) +
  geom_text_repel(data=label_data %>% filter(country %in% island), aes(x=long, y=lat, label=country),size=3) +
  ggtitle('Collaborators') +
  theme_void()
```
- #### Create a traffic map:

```{r}
label_data2 <- tbl_df(left_join(label_data, collaborator, by=c('country'='country')))
country_centroid<- tbl_df(world_map) %>% group_by(region) %>% summarise(long=mean(long), lat=mean(lat))

collabs <- tbl_df(left_join(label_data2, country_centroid, by=c('partner'='region')))

map_collaboration <- function(countryName='Cameroon'){
  map_result <- ggplot(collab_map, aes(long, lat, group = group))+
    geom_polygon(aes(fill = ncollab), color = "white", size=0.05)+
    scale_fill_viridis_c(option = "C", trans='sqrt') +
    geom_text_repel(data=label_data, aes(x=long, y=lat, label=ncollab),size=3) +
    geom_text_repel(data=label_data %>% filter(country %in% island), aes(x=long, y=lat, label=country),size=3) +
    geom_point(data = label_data, aes(x = long, y = lat), col = "#970027") +
    geom_curve(data=collabs %>% filter(country %in% countryName), aes(x = long.x, y = lat.x, xend = long.y, yend = lat.y ), col = "#b29e7d", size = .3) +
    ggtitle(paste(countryName,' Collaborators')) +
    theme_void()
  map_result
}

top_country <- lapply(c('United States', 'United Kingdom', 'Germany'), function(x) map_collaboration(countryName = x))
```
```{r}
top_country
```

- #### Countries collaborator

```{r}
ggplot(data=label_data %>% arrange(desc(ncollab)), aes(x=reorder(country, ncollab), y=ncollab)) +
  geom_bar(stat="identity", fill="steelblue")+
  geom_text(aes(label=ncollab), vjust=-1, size=2, col='white') + theme_bw() + ylab('# collaborator')+ xlab('Countries') +theme(axis.text.x = element_text(angle = 60, hjust = 1)) + coord_flip()
```

- #### How many single collaborations do they have?
```{r}
onecollab <- label_data %>% filter(ncollab==1) %>% select(country) %>% unique() 
partner <- collaborator %>% filter(country %in% onecollab$country) %>% select(partner)
ggplot(collab_map , aes(long, lat, group = group))+
  geom_polygon(aes(fill = ncollab), color = "white", size=0.05)+
  scale_fill_viridis_c(option = "C", trans='sqrt') +
  geom_text_repel(data=label_data %>% filter(ncollab==1), aes(x=long, y=lat, label=ncollab),size=3) +
  geom_text_repel(data=label_data %>% filter(ncollab==1) %>% filter(country %in% onecollab$country) , aes(x=long, y=lat, label=country),size=3) +
  geom_point(data = label_data %>% filter(country %in% partner$partner) , aes(x = long, y = lat), col = "#970027") +
  geom_curve(data=collabs %>% filter(ncollab.x==1) , aes(x = long.x, y = lat.x, xend = long.y, yend = lat.y ), col = "#b29e7d", size = .5) +
  ggtitle(paste('How many single collaborations do they have?')) +
  theme_void()
```

- ####	How many countries does country X use data from? 

```{r}
dataUsage <- function(x='China'){
  result <- pmc_ena %>% filter(author_country==x) %>% select(author_country, seq_country) %>% unique() %>%summarise(country_count=n())
  result <- data.frame(country=x, country_count=result$country_count)
  result
}

odusage <- do.call(rbind, mclapply(countries$name, function(x) dataUsage(x)))
```
- #### World map with collaborator numbers.

```{r}
otherdata_map <-tbl_df(left_join(odusage, world_map, by=c("country"="region")))
island <- c('Tonga','Solomon Islands','Samoa','Tonga','Marshall Islands','Guadeloupe','Martinique','Bermuda', 'Comoros','Haiti ','Jamaica','French Polynesia')
label_data <- otherdata_map %>% group_by(country, country_count) %>% summarise(long=mean(long), lat=mean(lat))  %>% mutate(group="NA")
ggplot(otherdata_map, aes(long, lat, group = group))+
  geom_polygon(aes(fill = country_count), color = "white", size=0.05)+
  scale_fill_viridis_c(option = "C", trans='sqrt') +
  geom_text_repel(data=label_data %>% filter(country_count>0), aes(x=long, y=lat, label=country_count),size=3) +
  geom_text_repel(data=label_data  %>% filter(country_count>0) %>% filter(country %in% island), aes(x=long, y=lat, label=country),size=3) +
  ggtitle('How many countries does country X use data from?') +
  theme_void()
```

- #### Countries collaborator
```{r}
ggplot(data=label_data %>% filter(country_count>0), aes(x=reorder(country, country_count), y=country_count)) +
  geom_bar(stat="identity", fill="steelblue")+
  geom_text(aes(label=country_count), vjust=-1, size=2, col='white') + theme_bw() + 
  ylab('# countries country X used data from')+ xlab('Countries') +
  theme(axis.text.x = element_text(angle = 60, hjust = 1)) + coord_flip() + ggtitle('How many countries does country X use data from? ')
```

```{r}
#save(pmc_ena, countries, continent, file="seqref.Rdata")
sessionInfo()
```

```{r}
#rm(list=ls())
#ls()
```



