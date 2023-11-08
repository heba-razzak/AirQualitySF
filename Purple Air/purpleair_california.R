# fips_codes: state, county
# Purple airs id, lat, lon
# median household income data from the American Community Survey for each state
# Find number of purple air in each county (by looking at intersections of geometry)
# Interactive map showing number of purpleAir in each census tract
# Interactive map showing number of purpleAir in each country in the world (min 3 purpleAirs)
# Bar plot Number of PurpleAirs by State
# Map of number of PurpleAirs by State

# Load required packages
library(rjson) # For working with JSON data
library(httr) # For making HTTP requests
library(sf) # For working with spatial data
library(dplyr)
library(tidycensus) # For accessing US Census data
library(tidyverse) # For data manipulation and visualization

# set working directory
dir = '/Users/heba/Desktop/Uni/Lim Lab/Purple Air'
setwd(dir)

# Enable caching for faster data retrieval
options(tigris_use_cache = TRUE) 

#sets the API key for accessing the US Census Bureau API
census_api_key("")

# Store the URL of the API endpoint to request data from for PurpleAir air quality sensors
# location_type=0 outside
# location_type=1 inside
# outside <- "https://api.purpleair.com/v1/sensors?fields=latitude%2C%20longitude%2C%20date_created&location_type=0"
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

# get all purpleair data
result <- GET(all, add_headers(header))
raw <- rawToChar(result$content)
json <- jsonlite::fromJSON(raw)
pa <- as.data.frame(json$data)

# Overwrite the column names of the PurpleAir data frame with "ID", "Lat", "Lon"
colnames(pa) <- c("sensor_id","date_created", "last_seen", "lat", "lon")

# convert epoch timestamp to date
pa$date_created <- as.Date(as.POSIXct(pa$date_created, origin = "1970-01-01"))
pa$last_seen <- as.Date(as.POSIXct(pa$last_seen, origin = "1970-01-01"))

# only keep purple airs created before June 2019
pa <- pa %>% filter(date_created <= "2019-06-01")
pa <- pa %>% filter(last_seen >= "2023-06-01")

# Remove any rows from the PurpleAir data frame that contain missing values
pa <- pa %>% na.omit() 

# view pa
head(pa)

# count number of sensors
length(unique(pa$sensor_id)) # 3328

# Convert the PurpleAir data frame to an sf object with "Lon" and "Lat" as the coordinate columns
dt <- st_as_sf(pa, coords=c("lon", "lat"))

# Retrieve median household income data from the American Community Survey for each state
# California
census.sf <- get_acs(geography = "tract", variables = "B19013_001",
            state = 'CA', geometry = TRUE)

# Assign the coordinate reference system (CRS) of the 'dt' spatial object to be the same as the 'census.sf' object
st_crs(dt) <- st_crs(census.sf)

# Purple Airs in California
ca_pa <- st_join(dt,census.sf, join = st_intersects, left = FALSE) 

# library(mapview) # For interactive maps
# mapview(ca_pa, zcol = "sensor_id", layer.name = "California PurpleAirs")

# list of purple air ids in california
ca_purpleairs <- unique(ca_pa$sensor_id)

# number of sensorss in california
length(ca_purpleairs)

dir = '/Users/heba/Desktop/Uni/Lim Lab'
setwd(dir)

api_key = ""

start_time <- Sys.time()
all_purple_air = getPurpleairApiHistory(
  sensorIndex=ca_purpleairs,
  apiReadKey=api_key,
  startTimeStamp="2019-06-01 00:00:00",
  endTimeStamp="2019-06-01 24:00:00",
  average="1440", # 1 day: 1440
  fields=c("pm2.5_atm, pm1.0_atm")
)
end_time <- Sys.time()
time_difference <- end_time - start_time
print(time_difference)



subset_pa = ca_purpleairs[1:10]
subset_pa = ""
start_time <- Sys.time()
purple_air = getPurpleairApiHistory(
  sensorIndex=subset_pa,
  apiReadKey=api_key,
  startTimeStamp="2019-01-01 00:00:00",
  endTimeStamp="2019-02-01 00:00:00",
  average="1440", # 1 day: 1440
  fields=c("pm2.5_atm, pm1.0_atm")
)
end_time <- Sys.time()
time_difference <- end_time - start_time
print(time_difference)

x <- purple_air %>% na.omit()
length(unique(x$sensor_id))
