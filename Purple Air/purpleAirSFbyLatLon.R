# Install necessary packages
# install.packages(c("httr", "jsonlite"))

# Load the packages
library(httr)
library(jsonlite)

# Store the URL of the API endpoint to request data from for PurpleAir air quality sensors
api_url <- "https://api.purpleair.com/v1/sensors?fields=latitude,longitude,date_created"

# Define the API key used to authenticate the user's request to the PurpleAir API
api_key = ""

# Define the header for the HTTP request to the API, including the API key and Accept content type
header <- c(
  'X-API-Key' = api_key,
  'Accept' = "application/json"
)

# Make the HTTP request to the PurpleAir API using the GET function from the httr library
result <- GET(api_url, add_headers(header))

# Convert the raw content returned by the API into a character string
content <- rawToChar(result$content)

# Convert the character string into a JSON object
json <- fromJSON(content)

# Convert the data into a data frame
sensors_df <- as.data.frame(json$data)

# rename columns
colnames(sensors_df) <- c("ID","Date Created", "Lat", "Lon")

# convert epoch timestamp to date
sensors_df$`Date Created` <- as.Date(as.POSIXct(sensors_df$`Date Created`, origin = "1970-01-01"))

# only keep purple airs created before 2020 (we want 2018 to 2019 data)
sensors_df <- sensors_df %>% filter(`Date Created` < "2020-01-01")

# Define the coordinates for San Francisco
sf_lat <- c(37.7749)
sf_lon <- c(-122.4194)

# Define a small margin for the coordinates to include nearby sensors
margin <- 0.1

# Filter the sensors based on the latitude and longitude
sf_sensors <- sensors_df[sensors_df$Lat >= (sf_lat - margin) & 
                           sensors_df$Lat <= (sf_lat + margin) &
                           sensors_df$Lon >= (sf_lon - margin) &
                           sensors_df$Lon <= (sf_lon + margin),]

library(osmdata)
sf_bb <- getbb("San Francisco")

sf_sensors <- sensors_df[sensors_df$Lat >= sf_bb[2] & 
                            sensors_df$Lat <= sf_bb[4] &
                            sensors_df$Lon >= sf_bb[1] &
                            sensors_df$Lon <= sf_bb[3],]
# Print the number of sensors in San Francisco
print(paste("There are", nrow(sf_sensors), "PurpleAir sensors in San Francisco (before 2020)."))
