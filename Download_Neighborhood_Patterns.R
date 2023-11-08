# Download Neighborhood Patterns files from Dewey Data Marketplace
# Filter data by county (LA or SF) and save to CSV
# Popularity by hour is grouped by zip code
# Map of popularity by hour and zip code

# Load R libraries
library(httr);
library(rjson);
library(jsonlite);
library(rstudioapi);
library(readxl)
library(dplyr)
library(data.table)
library(SafeGraphR) # expand_integer_json

dir = '/Users/heba/Desktop/Uni/Lim Lab/Neighborhood Patterns'
setwd(dir)

#############################
# Download files from Dewey #
#############################

# Define global variables
DEWEY_TOKEN_URL = "https://marketplace.deweydata.io/api/auth/tks/get_token";
DEWEY_MP_ROOT   = "https://marketplace.deweydata.io";
DEWEY_DATA_ROOT = "https://marketplace.deweydata.io/api/data/v2/list";

# Get access token
get_access_token = function(username, passw) {
  response = POST(DEWEY_TOKEN_URL, authenticate(username, passw));
  response_content = content(response);
  
  return(response_content$access_token);
}

# Return file paths in the sub_path folder
get_file_paths = function(token, sub_path = NULL) {
  response = GET(paste0(DEWEY_DATA_ROOT, sub_path),
                 headers=add_headers(Authorization = paste0("Bearer ", token)));
  
  json_text = content(response, as = "text", encoding = "UTF-8");
  
  response_df = as.data.frame(fromJSON(json_text));
  response_df;
  
  return(response_df);
}

# Download a single file from Dewey (src_url) to a local destination file (dest_file).
download_file = function(token, src_url, dest_file) {
  options(timeout=200); # increase the timeout if you have a large file to download
  download.file(src_url, dest_file, mode = "wb",
                headers = c(Authorization = paste0("Bearer ", token)));
}

# Dewey credentials
user_name = "";
pass_word = "";

# Get access token
tkn = get_access_token(user_name, pass_word);
tkn;

# Download the first file in each month's directory
for(m in 1:12){
  file_paths = get_file_paths(token = tkn,
                              sub_path = paste0("/2019/",sprintf("%02d", m),"/01/SAFEGRAPH/NP"));
  src_url = paste0(DEWEY_MP_ROOT, file_paths$url[1]);
  dest_file = paste0(dir,"/neighborhood_patterns_2019",sprintf("%02d", m),".csv.gz");
  download_file(tkn, src_url, dest_file);
  }

####################
# filter by county #
####################

# LA COUNTY NUMBER:  06037
# San Francisco:     06075
# https://transition.fcc.gov/oet/info/maps/census/fips/fips.txt

# quarters for file names
qs = c('03','06','09','12')

# lists to contain dataframes
tract_zip = list()
zip_tract = list()
county_zip = list()
county_zip_la = list()
zip_tract_la = list()
tract_zip_la = list()

for (i in 1:4){
  # files containing county to zip and zip to tract
  tract_zip[[i]] <- read_excel(paste0("TRACT_ZIP_",qs[i],"2019.xlsx"))
  zip_tract[[i]] <- read_excel(paste0("ZIP_TRACT_",qs[i],"2019.xlsx"))
  county_zip[[i]] <- read_excel(paste0("ZIP_COUNTY_",qs[i],"2019.xlsx"))
  
  # only keep relevant columns
  tract_zip[[i]] = subset(tract_zip[[i]], select = c(zip, tract,tot_ratio))
  zip_tract[[i]] = subset(zip_tract[[i]], select = c(zip, tract))
  county_zip[[i]] = subset(county_zip[[i]], select = c(zip, county))
  
  # filter county to la
  # county_code <- '06037' # LA County
  county_code <- '06075' # San Fran County
  county_name <- 'sf'
  
  county_zip_la[[i]] = county_zip[[i]] %>% filter(county==county_code)
  tract_zip_la[[i]] <- subset(tract_zip[[i]], zip %in% county_zip_la[[i]]$zip)
  zip_tract_la[[i]] <- subset(zip_tract[[i]], zip %in% county_zip_la[[i]]$zip)
  
  # transform tract to numeric
  tract_zip_la[[i]] <- transform(tract_zip_la[[i]], tract = as.numeric(tract))
  zip_tract_la[[i]] <- transform(zip_tract_la[[i]], tract = as.numeric(tract))
  
  # Print number of zip codes and tracts in LA each quarter of 2019
  print(paste('Q',i,' ',county_name,' zip codes: ',n_distinct(zip_tract_la[[i]]$zip)))
  print(paste('Q',i,' ',county_name,' tracts: ',n_distinct(zip_tract_la[[i]]$tract)))
}

# read neighborhood pattern files
# only keep LA county then save

for(m in 1:12){
  print(m)
  start = Sys.time()
  print(start)
  read_file = paste0(dir,"/NP files/neighborhood_patterns_2019",sprintf("%02d", m),".csv.gz");
  np = fread(read_file)
  read_time = Sys.time()
  print("time it took to read:")
  print(read_time-start)
  # tract = first 10 digits of CBG
  np = np %>% mutate(tract = substr(x = area, start = 0, stop = 10))
  if (between(m,1,3)) {
    la_tracts = zip_tract_la[[1]]
  } else if (between(m,4,6)) {
    la_tracts = zip_tract_la[[2]]
  } else if (between(m,7,9)) {
    la_tracts = zip_tract_la[[3]]
  } else if (between(m,10,12)) {
    la_tracts = zip_tract_la[[4]]
  }
  # filter by tract in LA
  np_la <- np[tract %in% la_tracts$tract, ]
  # TRY THIS TO SAVE JSON PROPERLY
  # jsonlite::write_csv(df, "json_data.csv", json_as_string = TRUE)
  #save to csv
  fwrite(np_la, paste0("neighborhood_patterns_",county_name,"_2019",sprintf("%02d", m),".csv"))
  write_time = Sys.time()
  print(write_time-read_time)
  # remove variables
  rm(np_la)
  rm(np)
}

################
# Add zip code #
################

for(m in 1:12){
  print(m)
  read_file = paste0(dir,"/neighborhood_patterns_",county_name,"_2019",sprintf("%02d", m),".csv");
  np_la = fread(read_file)
  if (between(m,1,3)) {
    la_tracts = tract_zip_la[[1]]
  } else if (between(m,4,6)) {
    la_tracts = tract_zip_la[[2]]
  } else if (between(m,7,9)) {
    la_tracts = tract_zip_la[[3]]
  } else if (between(m,10,12)) {
    la_tracts = tract_zip_la[[4]]
  }
  # np_la tract to int
  np_la <- transform(np_la, tract = as.numeric(tract))
  
  # expand popularity by hour #
  
  # select only relevant columns
  np_la <- np_la %>% select(tract,date_range_start,date_range_end,popularity_by_each_hour)
  
  # columns to group by
  groupcols = c('tract','date_range_start','date_range_end')
  
  # expand pop by hr column
  x = expand_integer_json(np_la, 'popularity_by_each_hour', by=groupcols)
  x = as.data.frame(x)
  
  # date column = start date + 1 hr for each row
  x['date'] = x['date_range_start']+(x['index']-1)*3600
  
  # drop date range start and end columns
  x <- x %>% select(tract,date,popularity_by_each_hour)
  
  # sum by tract and date (in case there were repeated tracts)
  x <- x %>% group_by(tract,date) %>% summarise(popularity_each_hour = sum(popularity_by_each_hour))
  
  # extract hour and weekday from date
  x['hour'] <- hour(x$date)
  x['wday'] <- lubridate::wday(x$date,label=TRUE)
  # x: (tract,date,popularity_each_hour,hour,wday)
  
  # hourly_sum: tract, hour, popularity
  hourly_sum <- x %>% group_by(tract,hour) %>% summarise(popularity = sum(popularity_each_hour))
  
  # hourly_sum_zip: tract, hour, popularity, zip, tot_ratio
  hourly_sum_zip <- hourly_sum %>% left_join(y = la_tracts, by = c("tract"))
  
  # multiple popularity by ratio of tract to zip
  hourly_pop_zip <- hourly_sum_zip %>% mutate(popularity = popularity*tot_ratio) %>% as.data.frame() %>% select(zip,hour,popularity)
  
  # add up popularity by zip code and hour
  popularity_zip <- hourly_pop_zip %>% group_by(zip,hour) %>% summarise(popularity = sum(popularity)) %>% as.data.frame()
  
  #save to csv
  fwrite(popularity_zip, paste0("popularity_zip_",county_name,"_2019",sprintf("%02d", m),".csv"))
}

######################
#         MAP        #
######################
library(ggplot2)
library(gganimate)
library(gifski)
# install.packages("gifski")
library(rgdal) 
library(transformr) 

which_state <- "california"
county_info <- map_data("county", region=which_state)
head(county_info)

# download shapefile here: https://www.census.gov/cgi-bin/geo/shapefiles/index.php

shapefile <- readOGR(dsn = "tl_2019_us_zcta510", layer = "tl_2019_us_zcta510")

par(mar=c(0,0,0,0))
plot(shapefile, col="#f2f2f2", bg="skyblue", lwd=0.25, border=0 )

head(shapefile)

library(sf)
zip_shape <- st_read("tl_2019_us_zcta510/tl_2019_us_zcta510.shp")

popularity_zip = read.csv(paste0("popularity_zip_",county_name,"_201901.csv"))

pz <- merge(popularity_zip, zip_shape, by.x = "zip", by.y = "ZCTA5CE10", all.x=TRUE)

map_with_data <- ggplot(data = pz, aes(geometry = geometry, fill=popularity, group=hour)) + geom_sf(lwd = 0)

map_with_animation <- map_with_data +
  transition_time(hour) +
  ggtitle('Hour: {frame_time}',
          subtitle = 'Frame {frame} of {nframes}')

animate(map_with_animation, nframes = 24)

anim_save("example1.gif")

anim_save("example1.gif", map_with_animation, nframes = 24, fps = 2)


##### try to fix it: 

map_with_data <- ggplot(data = pz, aes(geometry = geometry, fill=popularity, group=hour)) + geom_sf(lwd = 0)

map_with_animation <- map_with_data +
  transition_time(hour) +
  ggtitle('Hour: {frame_time}',
          subtitle = 'Frame {frame} of {nframes}')


animate(map_with_animation, duration = 12, fps = 2, width = 1000, height = 1000, renderer = gifski_renderer())
anim_save(paste0("output_",county_name,".gif"))



######################
# Popularity by Hour #
######################

read_file = paste0(dir,"/neighborhood_patterns_la_201901.csv")

np = fread(read_file)

groupcols = c('tract','date_range_start','date_range_end')

df = np[,.(tract,date_range_start,date_range_end,popularity_by_each_hour)]

x = expand_integer_json(df, 'popularity_by_each_hour', by=groupcols)

x = as.data.frame(x)

x['date'] = x['date_range_start']+(x['index']-1)*3600

x2 <- x %>% select(tract,date,popularity_by_each_hour)

# sum by tract and date (in case there were repeated tracts)
x2 <- x2 %>% group_by(tract,date) %>% summarise(popularity_each_hour = sum(popularity_by_each_hour))

x2['hour'] <- hour(x2$date)

x2['day'] <- lubridate::wday(x2$date,label=TRUE)

hourly_sum <- x2 %>% group_by(tract,hour) %>% summarise(popularity = sum(popularity_each_hour))

# save to csv
fwrite(hourly_sum, "popularity_201901.csv")

head(hourly_sum)
# x3 <- x2 %>% group_by(area,hour,day) %>% summarise(pop_hour = mean(popularity_by_each_hour))
x3 <- x2 %>% group_by(hour,day) %>% summarise(pop_hour = mean(popularity_by_each_hour))

head(x3)

# x3 <- x3 %>% ungroup()

glimpse(x3)

# heat map (not using area or region)

ggplot(x3, aes(x = hour, y = day, fill = pop_hour)) +
  geom_tile() +
  scale_fill_gradient(low = "white", high = "blue")


###########################
# Visualize Census Tracts #
###########################
install.packages('zipcode')
library(zipcode)
library(ggplot2)

# Load ZIP code boundaries data
data(zipcode)

# Create a data frame with some example data by ZIP code
example_data <- data.frame(
  zip = c("90001", "90002", "90003", "90004", "90005", "90006"),
  value = c(5, 7, 8, 10, 9, 6)
)

# Merge example data with ZIP code boundaries data
map_data <- merge(zipcode, example_data, by.x = "zip", by.y = "zip")

# Plot the map using ggplot2
ggplot(map_data) +
  geom_sf(aes(fill = value)) +
  scale_fill_gradient(low = "white", high = "blue") +
  labs(title = "Example Data by ZIP Code",
       subtitle = "Los Angeles County",
       fill = "Value")


#########








# Load required packages
library(tidycensus)
library(tidyverse)

# Set the API key for accessing Census Bureau data
census_api_key("")

# Download census data for the desired area and variables
census_data <- get_acs(
  geography = "tract",
  variables = c("B01003_001", "B19013_001"),
  state = "06", # CA
  county = "037" # LA
)

# Rename columns for clarity
census_data <- rename(census_data, population = estimate, median_income = moe)

# Get the geographic boundaries for the tracts
tract_boundaries <- get_acs(
  geography = "zcta",
  variables = c("B01003_001", "B19013_001"),
  # state = "06",
  county = "037",
  geometry = TRUE
)



head(tract_boundaries)

# Plot the map using ggplot2
ggplot(tract_boundaries) +
  geom_sf(aes(fill = moe)) +
  scale_fill_gradient(low = "white", high = "blue") +
  labs(title = "Median Income by Zip",
       subtitle = "CA, LA",
       fill = "Median Income")

