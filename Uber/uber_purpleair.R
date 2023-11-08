# Load required libraries
library(dplyr) # For data manipulation
library(data.table) # Faster than dataframes (for big files) 
library(ggplot2) # For visualizing data
library(rjson) # For working with JSON data
library(httr) # For making HTTP requests
library(sf) # For working with spatial data
library(osmdata) # Open Street Map
library(mapview) # For interactive maps
library(tidycensus) # Census data

#########################
# Read uber speeds data #
#########################

# set working directory
dir = '/Users/heba/Desktop/Uni/Lim Lab/Uber/Speeds'
setwd(dir)

# Coordinate reference system (CRS) that will be used for all shapefiles
# CRS: 4326 in degrees (sphere)
# CRS: 3857 in meters (flat map) - didnt work with getbb
crs = 4326

# Download files from 
# This selection may be missing data from 9/4/2019 - 9/5/2019
# https://movement.uber.com/cities/san_francisco/downloads/speeds

# list files in working directory
file_list <- list.files()

# # Read all files from directory and combine them
# # empty list to contain data
# data_list <- list() 
# 
# # fread all files from directory
# data_list <- lapply(file_list, fread)
# 
# # combine data to 1 file
# combined_data <- do.call(rbind, data_list)
# 
# Error: vector memory exhausted (limit reached?)
# Use only one file for now

# first file from directory
file <- file_list[1]

# read file 
uber_data <- fread(file)

# Convert the OSM way IDs in the Uber speeds data to character type
uber_data$osm_way_id <- as.character(uber_data$osm_way_id)

# glimpse(uber_data)

######################################
# San Francisco Open Street Map data #
######################################

# to get bounding box coordinates
# got approximate bb from https://boundingbox.klokantech.com/
# choose TSV format to get coordinates

# # can use either city name or bounding box coordinates for OSM
# bb <- 'san francisco'
# bb <- c(left = -122.6, bottom = 37.5, right = -122, top = 38)

# # view available features and tags
# available_features()
# available_tags(feature = "highway")$Value

###################################################
# Download San Francisco OSM highways

# Download specified top priority highways
# https://wiki.openstreetmap.org/wiki/Map_features#Highway

# **check if i can only download specific columns for osm$osm_lines (osm_id, name, bicycle, foot, highway, lanes, maxspeed)
# osm <- opq(bbox = bb) %>%
#   add_osm_feature(key = 'highway',
#                   value = c("motorway", "trunk", "primary", "secondary", "tertiary", 	"unclassified",	"residential")) %>%
#   osmdata_sf()

###################################################

# download osm for san francisco

bb <- getbb("san francisco, california")
osm <- opq(bbox = bb) %>%
  add_osm_feature(key = 'highway') %>%
  osmdata_sf()
# Select only the columns you want to keep
selected_ways_sf <- osm$osm_lines %>% select(osm_id, name, bicycle, foot, highway, lanes, maxspeed)
# Select required columns and rows based on uber_data osm_way_id
all_selected_ways_sf <- selected_ways_sf[selected_ways_sf$osm_id %in% unique(uber_data$osm_way_id), ]

# download osm for surrounding counties and bind them

# List of locations to query
locations = c("san mateo, california", 
              "marin, california", "alameda, california", 
              "solano, california", "napa, california", 
              "sonoma, california", "contra costa, california")

# Loop through each location to get the bounding box and OSM data
for(loc in locations) {
  
  bb <- getbb(loc)
  osm <- opq(bbox = bb) %>%
    add_osm_feature(key = 'highway') %>%
    osmdata_sf()
  
  # Select only the columns you want to keep
  selected_ways_sf <- osm$osm_lines %>% select(osm_id, name, bicycle, foot, highway, lanes, maxspeed)
  
  # Select required columns and rows based on uber_data osm_way_id
  selected_ways_sf <- selected_ways_sf[selected_ways_sf$osm_id %in% unique(uber_data$osm_way_id), ]
  
  # Append to all_selected_ways_sf data frame
  all_selected_ways_sf <- bind_rows(all_selected_ways_sf, selected_ways_sf)
}

all_selected_ways_sf <- all_selected_ways_sf %>% distinct(osm_id, .keep_all = TRUE)

##
mapview(all_selected_ways_sf)

###################################################

# number of osm ways: 13493 SF
# number of osm ways: 49342 bay area
length(unique(all_selected_ways_sf$osm_id))
# number of uber ways: 71603 (could be larger than SF area?)
length(unique(uber_data$osm_way_id))

# convert selected_ways to sf object
all_selected_ways_sf <- st_as_sf(selected_ways, crs = crs)

# save shapefile
st_write(all_selected_ways_sf, "/Users/heba/Desktop/Uni/Lim Lab/uber_purpleair/selected_ways_sf.shp", append=FALSE)

# Uber data is too big to merge with geometry (for now)
# # merge uber data and geometry
# uber_sf <- merge(uber_data, selected_ways_sf, by.x = "osm_way_id", by.y = "osm_id", all.x = TRUE)
# 
# # convert selected_ways to sf object
# uber_sf <- st_as_sf(uber_sf)
mapview(osm$osm_lines)

####################################################
# Get sensor ids in San Francisco with Lat and Lon #
####################################################

# Store the URL of the API endpoint to request data from for PurpleAir air quality sensors
all <- "https://api.purpleair.com/v1/sensors?fields=latitude%2C%20longitude%2C%20date_created%2C%20last_seen"

# Define the API key used to authenticate the user's request to the PurpleAir API
auth_key  <- ""

# Define the header for the HTTP request to the API, including the API key and Accept content type
header = c(
  'X-API-Key' = auth_key,
  'Accept' = "application/json"
)

# Get Purple Air data using the following steps
# Make the HTTP request to the PurpleAir API using the GET function from the httr library
# Convert the raw content returned by the API into a character string
# Convert the character string into a JSON object
# Extract the "data" element from the JSON object and convert it to a data frame
result <- GET(all, add_headers(header))
raw <- rawToChar(result$content)
json <- jsonlite::fromJSON(raw)
pa <- as.data.frame(json$data)

# Rename the columns of the PurpleAir data frame
colnames(pa) <- c("sensor_id","date_created", "last_seen", "lat", "lon")

# convert epoch timestamp to date
pa$date_created <- as.Date(as.POSIXct(pa$date_created, origin = "1970-01-01"))
pa$last_seen <- as.Date(as.POSIXct(pa$last_seen, origin = "1970-01-01"))

# only keep purple airs created before June 2019 and active after June 2023
pa <- pa %>% filter(date_created <= "2019-06-01")
pa <- pa %>% filter(last_seen >= "2023-06-01")

# Remove any rows from the PurpleAir data frame that contain missing values
pa <- pa %>% na.omit() 

# view pa
head(pa)

# count number of sensors
length(unique(pa$sensor_id)) # 3326

# Convert the PurpleAir data frame to an sf object with "Lon" and "Lat" as the coordinate columns
dt <- st_as_sf(pa, coords=c("lon", "lat"), crs = crs)

#################################
# Filter Data for San Francisco #
#################################

full_poly <- getbb("san francisco, california", format_out = "sf_polygon")$multipolygon
full_poly <- st_transform(full_poly, crs=crs)

locations = c("san mateo, california", 
              "marin, california", "alameda, california", 
              "solano, california", "napa, california", 
              "sonoma, california", "contra costa, california")
for(loc in locations) {
  sf_poly <- getbb(loc, format_out = "sf_polygon")
  if (!is.null(sf_poly$multipolygon)) {
    sf_poly <- st_transform(sf_poly$multipolygon, crs = crs)
  } else {
    sf_poly <- st_transform(sf_poly, crs = crs)
  }
  # Append to sf_poly
  full_poly <- bind_rows(full_poly, sf_poly)
}

mapview(full_poly)
# set CRS
full_poly <- st_transform(full_poly, crs=crs)
all_selected_ways_sf <- st_transform(all_selected_ways_sf, crs=crs)

# find intersections of uber and purple airs in SF
uber_ways_sf <- st_intersection(all_selected_ways_sf, full_poly)

purpleairs_sf <- st_intersection(dt, full_poly)

# remove columns which are all NA
uber_ways_sf <- uber_ways_sf[,colSums(is.na(uber_ways_sf))<nrow(uber_ways_sf)]

# Change highway column to factor (to have ordered levels)
# https://wiki.openstreetmap.org/wiki/Map_features#Highway

uber_ways_sf$highway <- factor(uber_ways_sf$highway, 
                               levels=c("motorway", "trunk", "primary", "secondary", "tertiary",
                                        "construction", "unclassified", "residential", 
                                        "motorway_link", "trunk_link", "primary_link", "secondary_link", "tertiary_link",
                                        "service", "pedestrian", "cycleway"))
mapview(uber_ways_sf)
mapview(purpleairs_sf)
#################################
# Map Uber ways with PA sensors #
#################################

# Plot purple airs map
map_sf <- mapview(purpleairs_sf, col.regions="purple", col="purple")

# Add uber layer
map_sf <- map_sf + mapview(uber_ways_sf, col.regions="lightblue", col="lightblue")

# View map
map_sf

# Save map as html
path = '/Users/heba/Desktop/Uni/Lim Lab/uber_purpleair/'

url1 = paste0(path,'map_sf.html')

mapshot(
  map_sf,
  url = url1)

# Save shapefile
st_write(purpleairs_sf, paste0(path,'purpleairs_sf.shp'))
st_write(uber_ways_sf, paste0(path,'uber_ways_sf.shp'))

# purpleairs_sf2 <- st_read(paste0(path,'purpleairs_sf.shp'))
# uber_ways_sf2 <- st_read(paste0(path,'uber_ways_sf.shp'))

############################################
# Create Buffers around Purple Air Sensors #
############################################

# buffer radius in meters
buffer = 500
purpleairs_buffers <- st_buffer(purpleairs_sf, dist=buffer)

# Save shapefile
st_write(purpleairs_buffers, paste0(path,'purpleairs_buffers.shp'))

# purpleairs_buffers2 <- st_read(paste0(path,'purpleairs_buffers.shp'))


# Plot purple airs map
# alpha: line opacity
# alpha.regions: fill opacity
map_uber_pa <- mapview(purpleairs_buffers, col.regions="purple", col="purple", alpha=1, alpha.regions=0.2)

# Add uber layer (showing highway type)
map_uber_pa <- map_uber_pa + mapview(uber_ways_sf,zcol="highway", legend=TRUE)

# View map
map_uber_pa

# Save map as html
url2 = paste0(path,'map_uber_pa.html')

mapshot(
  map_uber_pa,
  url = url2)

########################################################
# Show intersection of purple air buffers and highways #
########################################################
intersections <- st_intersection(uber_ways_sf, purpleairs_buffers)

map_intersections <- mapview(intersections)

# View map
map_intersections

# Save map as html

url3 = paste0(path,'map_intersections.html')

mapshot(
  map_intersections,
  file = url)

# Save shapefile
st_write(intersections, paste0(path,'intersections.shp'))
# intersections2 <- st_read(paste0(path,'intersections.shp'))


#########################################################
# Analyze SF purple air data from June 2019 - June 2023 #
#########################################################

# List all files in the path
path = '/Users/heba/Desktop/Uni/Lim Lab/Purple Air'
files <- list.files(path = path)

# Get the files that start with "purple_air_sf_" and end with ".csv"
files <- files[grepl("^purple_air_sf_.*\\.csv$", files)]

# # Read all these CSV files into data frames
# data_list <- lapply(files, read.csv)
# 
# # Bind all data frames into a single data frame
# df <- do.call(rbind, data_list)

df <- read.csv(paste0(path,'/',files[1]))

# select relevant columns
df <- df[, c("sensor_id", "time_stamp", "pm1.0_atm", "pm2.5_atm")]

# convert time_stamp to Date or POSIXct
df$time_stamp <- as.POSIXct(df$time_stamp, origin="1970-01-01", tz="UTC")

glimpse(df)


sf_bb <- getbb("san francisco, usa")

##################################################
# OSM San Francisco - Buildings, Trees, Water... #
##################################################


# view available features and tags
available_features()
available_tags(feature = "highway")$Value


bb <- getbb("san francisco, california")
osm <- opq(bbox = bb) %>%
  add_osm_feature(key = 'highway') %>%
  osmdata_sf()
# Select only the columns you want to keep
selected_ways_sf <- osm$osm_lines %>% select(osm_id, name, bicycle, foot, highway, lanes, maxspeed)
# Select required columns and rows based on uber_data osm_way_id
all_selected_ways_sf <- selected_ways_sf[selected_ways_sf$osm_id %in% unique(uber_data$osm_way_id), ]

# download osm for surrounding counties and bind them

# List of locations to query
locations = c("san mateo, california", 
              "marin, california", "alameda, california", 
              "solano, california", "napa, california", 
              "sonoma, california", "contra costa, california")

# Loop through each location to get the bounding box and OSM data
for(loc in locations) {
  
  bb <- getbb(loc)
  osm <- opq(bbox = bb) %>%
    add_osm_feature(key = 'highway') %>%
    osmdata_sf()
  
  # Select only the columns you want to keep
  selected_ways_sf <- osm$osm_lines %>% select(osm_id, name, bicycle, foot, highway, lanes, maxspeed)
  
  # Select required columns and rows based on uber_data osm_way_id
  selected_ways_sf <- selected_ways_sf[selected_ways_sf$osm_id %in% unique(uber_data$osm_way_id), ]
  
  # Append to all_selected_ways_sf data frame
  all_selected_ways_sf <- bind_rows(all_selected_ways_sf, selected_ways_sf)
}

all_selected_ways_sf <- all_selected_ways_sf %>% distinct(osm_id, .keep_all = TRUE)







# Smaller bounding box for testing
bb <- c(left = -122.44, bottom = 37.76, right = -122.43, top = 37.77)

# # San Francisco Bounding Box
# sf_bb <- getbb("san francisco, usa")

# Download OSM data
osm <- opq(bbox = bb) %>%
  add_osm_feature(key = 'building') %>%
  osmdata_sf()

# mapview(osm$osm_points, zcol = "building", col.regions = "blue", alpha.regions = 0.5)
# mapview(osm$osm_multipolygons, zcol = "building", col.regions = "blue", alpha.regions = 0.5)
# polygons look best & we can use area of each building type
mapview(osm$osm_polygons, zcol = "building", col.regions = "blue", alpha.regions = 0.5)


# Download OSM data
osm <- opq(bbox = bb) %>%
  add_osm_feature(key = 'water') %>%
  osmdata_sf()
mapview(osm$osm_points, zcol = "water", col.regions = "blue", alpha.regions = 0.5)
mapview(osm$osm_multipolygons, zcol = "water", col.regions = "blue", alpha.regions = 0.5)
mapview(osm$osm_polygons, zcol = "water", col.regions = "blue", alpha.regions = 0.5)
mapview(osm$osm_lines, zcol = "water", col.regions = "blue", alpha.regions = 0.5)

# Download OSM data
osm <- opq(bbox = bb) %>%
  add_osm_feature(key = 'natural') %>%
  osmdata_sf()
# can get trees from points
mapview(osm$osm_points, zcol = "natural", col.regions = "blue", alpha.regions = 0.5)
# mapview(osm$osm_multipolygons, zcol = "natural", col.regions = "blue", alpha.regions = 0.5)
# mapview(osm$osm_polygons, zcol = "natural", col.regions = "blue", alpha.regions = 0.5)
# mapview(osm$osm_lines, zcol = "natural", col.regions = "blue", alpha.regions = 0.5)



# convert selected_ways to sf object
selected_ways_sf <- st_as_sf(selected_ways, crs = crs)
