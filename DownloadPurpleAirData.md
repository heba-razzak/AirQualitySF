DownloadPurpleAirData
================

``` r
suppressPackageStartupMessages({
  library(mapview) # For interactive maps
  library(rjson) # For working with JSON data
  library(httr) # For making HTTP requests
  library(sf) # For working with spatial data
  library(dplyr)
  library(tidycensus) # For accessing US Census data
  library(tidyverse) # For data manipulation and visualization
  library(lubridate) # For working with dates
  library(ggplot2) # For visualizing data
  library(magick) # images/gifs
})
```

``` r
# load getPurpleairApiHistoryV2 function from folder it's in 
source("getPurpleairApiHistory/getPurpleairApiHistoryV2.R")
```

# Download purple air sensor id, lat, lon, date created, last seen

``` r
# Store the URL of the API endpoint to request data from for PurpleAir air quality sensors
all <- "https://api.purpleair.com/v1/sensors?fields=latitude%2C%20longitude%2C%20date_created%2C%20last_seen"

# Define the API key used to authenticate the user's request to the PurpleAir API
# auth_key  <- "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"

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

# CRS (coordinate reference system)
crs = 4326

# Convert the PurpleAir data frame to an sf object
pa <- pa %>% na.omit() 
dt <- st_as_sf(pa, coords=c("lon", "lat"), crs = crs)
head(dt)
```

    ## Simple feature collection with 6 features and 3 fields
    ## Geometry type: POINT
    ## Dimension:     XY
    ## Bounding box:  xmin: -124.1288 ymin: 39.43402 xmax: -104.7324 ymax: 49.16008
    ## Geodetic CRS:  WGS 84
    ##   sensor_id date_created  last_seen                   geometry
    ## 1        53   2016-02-04 2024-03-18 POINT (-111.7048 40.24674)
    ## 2        77   2016-03-02 2024-03-18 POINT (-111.8253 40.75082)
    ## 3        81   2016-06-11 2024-03-18 POINT (-111.6424 40.28764)
    ## 4       182   2016-08-01 2024-03-18 POINT (-123.7423 49.16008)
    ## 5       195   2016-08-01 2024-03-18    POINT (-124.1288 41.06)
    ## 6       314   2016-09-15 2024-03-18 POINT (-104.7324 39.43402)

# Get purple air sensors in san fran area (using bounding box)

``` r
# Greater san fran area
bbox <- c(xmin = -123.8, ymin = 36.9, xmax = -121.0, ymax = 39.0)

# Shapefile of bounding box
bbox_sf <- st_as_sfc(st_bbox(bbox))

# Set CRS (coordinate reference system)
crs = 4326
st_crs(bbox_sf) <- crs

# intersection of purple air sensors and bounding box
purpleairs_sf <- st_intersection(dt, bbox_sf)

# interactive map
mapview(purpleairs_sf)
```

![](DownloadPurpleAirData_files/figure-gfm/san-fran-bounding-box-1.png)<!-- -->

## number of sensors

``` r
cat("Total number of sensors: ", length(unique(purpleairs_sf$sensor_id)))
```

    ## Total number of sensors:  7485

``` r
# Inputs for purple air function
apiReadKey <- auth_key
fields <- c("pm2.5_atm, pm2.5_atm_a, pm2.5_atm_b")
average <- "60"
```

``` r
# Date range of historical purple air data
start_date <- as.Date("2018-01-01")
end_date <- as.Date("2019-12-31")
current_date <- start_date
```

``` r
# Iterate over each 1 month period
while (current_date <= end_date) {
  
  # Calculate next date
  next_date <- current_date + months(1) - days(1)
  
  # Ensure we don't go beyond the end date
  if (next_date > end_date) {
    next_date <- end_date
  }
  
  # Print the dates we're processing
  print(paste("Processing:", current_date, "-", next_date))
  start_time <- Sys.time()
  
  filtered_purpleairs_sf <- purpleairs_sf %>% filter(last_seen >= current_date) %>% filter(date_created <= next_date)
  sensorIndex <- unique(filtered_purpleairs_sf$sensor_id)
  
  # Get the data
  purple_air <- getPurpleairApiHistoryV2(
    sensorIndex=sensorIndex,
    apiReadKey=apiReadKey,
    startTimeStamp=format(current_date, "%Y-%m-%d %H:%M:%S"),
    endTimeStamp=format(next_date, "%Y-%m-%d %H:%M:%S"),
    average=average,
    fields=fields
  )
  
  # Save to CSV file
  write.csv(purple_air, file = paste0("purple_air_sanfran_", current_date, "_", next_date, ".csv"), row.names = FALSE)
  
  # Print time it took
  end_time <- Sys.time()
  time_difference <- end_time - start_time
  print(paste("Processing time:", current_date, "-", next_date))
  print(time_difference)
  
  # Update the current date
  current_date <- next_date + days(1)
}
```

``` r
# Get a list of file paths
file_paths <- list.files(file_directory, pattern = "purple_air_sanfran_.*.csv", full.names = TRUE)

# Read files
dfs <- lapply(file_paths, read.csv)

# Bind to 1 dataframe
fulldata <- do.call(rbind, dfs)

# Add column for month
fulldata$month <- format(as.Date(fulldata$time_stamp), "%Y-%m")

# Sensors for each month
monthly_sensors <- fulldata %>% select(month, sensor_id) %>% distinct()
head(monthly_sensors)
```

    ##     month sensor_id
    ## 1 2017-01       767
    ## 2 2018-01       767
    ## 3 2018-01      1742
    ## 4 2018-01      1860
    ## 5 2018-01      1874
    ## 6 2018-01      2031

``` r
sensor_counts <- monthly_sensors %>%
  group_by(month) %>%
  summarise(sensor_count = n_distinct(sensor_id))

ggplot(sensor_counts, aes(x = month, y = sensor_count)) +
  geom_bar(stat = "identity", fill = "lavender", color = "black") +
  labs(title = "Number of PurpleAir Sensors per Month",
       x = "Month",
       y = "Number of Sensors") +
  scale_y_continuous(breaks = seq(0, max(sensor_counts$sensor_count) + 100, by = 100)) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
```

![](DownloadPurpleAirData_files/figure-gfm/count-purpleair-monthly-1.png)<!-- -->
