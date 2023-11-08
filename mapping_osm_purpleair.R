library(httr)
library(jsonlite)
library(osmdata)

library(dplyr)
library(data.table)
library(ggplot2)


# get uber speeds data #

dir = '/Users/heba/Desktop/Uni/Lim Lab/Uber/Speeds'
setwd(dir)

# Download files from 
# This selection may be missing data from 9/4/2019 - 9/5/2019
# https://movement.uber.com/cities/san_francisco/downloads/speeds

# list files in working directory
file_list <- list.files()

# first file name
file <- file_list[1]

# read file 
data <- fread(file)
glimpse(data)

# list of osm way ids
osm_way_ids <- unique(data$osm_way_id)

# subset to test on
osm_way_ids = osm_way_ids[1:5]





available_features()

available_tags(feature = "highway")
available_tags(feature = "boundary")

sf_bb <- getbb("San Francisco")
# Print the matrix to the console
sf_bb


sf_major <- getbb(place_name = "San Francisco") %>%
  opq() %>%
  add_osm_feature(key = "highway", 
                  value = c("motorway", "primary", "secondary")) %>%
  osmdata_sf()

sf_minor <- getbb(place_name = "San Francisco") %>%
  opq() %>%
  add_osm_feature(key = "highway", value = c("tertiary")) %>%
  osmdata_sf()

# Drop Date column and rows with NA values
sf_sensors <- sf_sensors %>%
  select(-`Date Created`) %>% na.omit(sf_sensors)


# Convert sf_sensors to an sf object
sf_sensors_sf <- st_as_sf(sf_sensors, coords = c("Lon", "Lat"), crs = 4326)

street_plot <- ggplot() +
  geom_sf(data = sf_major$osm_lines,
          inherit.aes = FALSE,
          color = "black",
          size = 0.2) +
  geom_sf(data = sf_minor$osm_lines,
          inherit.aes = FALSE,
          color = "#666666",  # medium gray
          size = 0.05) + # half the width of the major roads 
  geom_sf(data = sf_sensors_sf,
          inherit.aes = FALSE,
          color = "purple",
          size = 1) +
  geom_sf(data = osmObj$osm_lines,
          inherit.aes = FALSE,
          color = "blue",
          size = 5) 

# Print the plot
street_plot


osmObj <- opq_osm_id(type = "way", id = 40722998) %>% opq_string() %>% osmdata_sf()
------
# Example for one osm way id
osm_way_id <- osm_way_ids[1]  # replace with your list of osm way ids

# Retrieve data for the osm way id
osm_obj <- opq_osm_id(type = "way", id = osm_way_id) %>% 
  opq_string() %>% 
  osmdata_sf()

# Convert the osmdata object to an sf object
sf_obj <- osm_obj$osm_lines

# Filter the sf object by the bounding box
sf_obj_filtered <- sf_obj[st_intersects(sf_obj, st_as_sfc(sf_bb)), ]

-----
# Initialize an empty list to store data frames
df_list <- list()

# Loop over each osm_way_id
for (osm_way_id in osm_way_ids) {
  osm_way_id <- as.numeric(osm_way_id)

  # Get the OSM data for this ID
  osmObj <- opq_osm_id(type = "way", id = osm_way_id) %>% opq_string() %>% osmdata_sf()
  # Convert the osmdata object to an sf object
  sf_obj <- osmObj$osm_lines
  
  # Filter the sf object by the bounding box
  # sf_obj_filtered <- sf_obj[st_intersects(sf_obj, st_as_sfc(sf_bb)), ]
  
  # 
  # # osmObj <- tryCatch({
  # #   opq_osm_id(type = "way", id = osm_way_id) %>%
  # #     opq_string() %>%
  # #     osmdata_sf()
  # # }, error = function(e) NULL)  # If an error occurs, return NULL
  # 
  # # If the request was successful, process the data
  # # if (!is.null(osmObj)) {
  #   # Get the coordinates of the line
  #   coords <- osmObj$osm_lines %>% 
  #     st_coordinates() %>% 
  #     as.data.frame()
  #   
  #   # Create a data frame
  #   df <- data.frame(
  #     osm_way_id = osm_way_id,
  #     lon = coords$X,
  #     lat = coords$Y
    # )
    
    # Append the data frame to the list
    df_list[[length(df_list) + 1]] <- df
  # }
}

# Combine all data frames in the list into one data frame
result <- do.call(rbind, df_list)



#############

# Open street map for San Francsico
api_url <- "https://overpass-api.de/api/map?bbox=-122.6143,37.6645,-122.2153,37.8602"

# get 
response <- GET(api_url)

response$status_code

data <- content(response, "text", encoding = "UTF-8")
json <- fromJSON(data)

# Retrieve the coordinates of the nodes of the way
lat <- json$elements$geometry$lat
lon <- json$elements$geometry$lon

# Print the coordinates
print(lat)
print(lon)



# Load the necessary libraries
# install.packages(c("httr", "jsonlite", "dplyr", "purrr"))
library(httr)
library(jsonlite)
library(dplyr)
library(purrr)
library(sf)

osm_way_id = "40722998"

osmObj <- opq_osm_id(type = "way", id = osm_way_id) %>% opq_string() %>% osmdata_sf()

points <- osmObj$osm_points
points <- st_coordinates(points)

# Extracting lines
lines <- osmObj$osm_lines
lines <- st_coordinates(lines)







# Define a function to get the latitude and longitude of a way
get_way_coordinates <- function(osm_way_id) {
  # Define the URL of the Overpass API endpoint
  # api_url <- paste0("http://overpass-api.de/api/interpreter?data=[out:json];way(", osm_way_id, ");out geom;")
  api_url <- paste0("http://overpass-api.de/api/interpreter?data=[out:json];(way(", osm_way_id, "););out geom;")
  
  # Make the HTTP request to the Overpass API
  response <- GET(api_url)
  
  # Check if the request was successful
  if (response$status_code == 200) {
    # Parse the JSON response
    data <- content(response, "text", encoding = "UTF-8")
    json <- fromJSON(data)
    
    # Retrieve the coordinates of the nodes of the way
    lat <- json$elements$geometry$lat
    lon <- json$elements$geometry$lon
    
    # Return a data frame with the osm_way_id and the coordinates
    return(data.frame(osm_way_id = osm_way_id, lat = lat, lon = lon))
  } else {
    print(paste("The request for osm_way_id", osm_way_id, "failed with status code:", response$status_code))
    return(NULL)
  }
}

# Get the unique osm_way_ids in your data frame
osm_way_ids <- unique(data$osm_way_id)

# Use map_dfr to apply the function to each osm_way_id and row-bind the results into a data frame
coordinates_df <- map_dfr(osm_way_ids, get_way_coordinates)
