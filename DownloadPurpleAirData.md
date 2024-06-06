Download PurpleAir Data
================

## Load required libraries

``` r
library(dplyr) # For data manipulation
library(sf) # For working with spatial data
library(ggplot2) # For visualizing data
library(lubridate) # For working with dates
library(tigris) # Counties map data

# install package from github
library(devtools)
suppressMessages({devtools::install_github("heba-razzak/getPurpleairApiHistoryV2")})
library(getPurpleairApiHistoryV2)
```

# Download purple air sensor id, lat, lon, date created, last seen

``` r
pa <- getPurpleairSensors(apiReadKey = auth_key)

# CRS (coordinate reference system)
crs = 4326

# Convert the PurpleAir data frame to an sf object
pa <- pa %>% na.omit() 
pa_sf <- st_as_sf(pa, coords=c("longitude", "latitude"), crs = crs)
head(pa_sf)
```

    ## Simple feature collection with 6 features and 3 fields
    ## Geometry type: POINT
    ## Dimension:     XY
    ## Bounding box:  xmin: -124.2666 ymin: 39.43402 xmax: -104.7324 ymax: 49.48426
    ## Geodetic CRS:  WGS 84
    ##   sensor_index date_created  last_seen                   geometry
    ## 1           53   2016-02-04 2024-05-31 POINT (-111.7048 40.24674)
    ## 2           77   2016-03-02 2024-05-31 POINT (-111.8253 40.75082)
    ## 3          182   2016-08-01 2024-05-31 POINT (-123.7423 49.16008)
    ## 4          195   2016-08-01 2024-05-31    POINT (-124.1288 41.06)
    ## 5          286   2016-09-06 2024-05-30 POINT (-124.2666 49.48426)
    ## 6          314   2016-09-15 2024-05-31 POINT (-104.7324 39.43402)

``` r
# Save PurpleAir sensors shapefile (sensor index & location)
pa_sensors <- pa %>% select(sensor_index, latitude, longitude)
pa_sensors_sf <- st_as_sf(pa_sensors, coords=c("longitude", "latitude"), crs = crs)
st_write(pa_sensors_sf, "purpleair_sensors.gpkg", driver = "GPKG", append=FALSE)
```

    ## Deleting layer `purpleair_sensors' using driver `GPKG'
    ## Writing layer `purpleair_sensors' to data source 
    ##   `purpleair_sensors.gpkg' using driver `GPKG'
    ## Writing 25715 features with 1 fields and geometry type Point.

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
purpleairs_sf <- st_intersection(pa_sf, bbox_sf)

ca <- counties("California", cb = TRUE)
```

    ##   |                                                                              |                                                                      |   0%  |                                                                              |                                                                      |   1%  |                                                                              |=                                                                     |   1%  |                                                                              |=                                                                     |   2%  |                                                                              |==                                                                    |   2%  |                                                                              |==                                                                    |   3%  |                                                                              |===                                                                   |   4%  |                                                                              |===                                                                   |   5%  |                                                                              |====                                                                  |   5%  |                                                                              |=====                                                                 |   7%  |                                                                              |======                                                                |   8%  |                                                                              |======                                                                |   9%  |                                                                              |=======                                                               |  10%  |                                                                              |========                                                              |  11%  |                                                                              |=================                                                     |  25%  |                                                                              |===========================                                           |  39%  |                                                                              |=====================================                                 |  53%  |                                                                              |===============================================                       |  67%  |                                                                              |=========================================================             |  81%  |                                                                              |===================================================================   |  95%  |                                                                              |======================================================================| 100%

``` r
ggplot() + 
  geom_sf(data = ca, color="black", fill="antiquewhite", size=0.25) +
  # geom_sf(data = purpleairs_buffers, fill = "lavender") +
  geom_sf(data = purpleairs_sf, color = "purple", size = 0.1) +
  coord_sf(xlim = c(-123.8, -121.0), ylim = c(36.9, 39.0)) +
  theme(panel.background = element_rect(fill = "aliceblue")) + 
  xlab("Longitude") + ylab("Latitude") +
  ggtitle("PurpleAir in San Francisco") 
```

![](DownloadPurpleAirData_files/figure-gfm/san-fran-bounding-box-1.png)<!-- -->

## Number of sensors

``` r
cat("Total number of sensors: ", length(unique(purpleairs_sf$sensor_index)))
```

    ## Total number of sensors:  7299

``` r
# Inputs for purple air function
apiReadKey <- auth_key
fields <- c("pm2.5_atm, pm2.5_atm_a, pm2.5_atm_b")
average <- "60"
```

``` r
# Date range of historical purple air data
start_date <- as.Date("2019-08-01")
  end_date <- as.Date("2019-12-31")
current_date <- start_date
```

``` r
# Iterate over each 1 month period
while (current_date <= end_date) {
  
  next_date <- current_date + months(1) - days(1)
  
  # Ensure we don't go beyond the end date
  if (next_date > end_date) {
    next_date <- end_date
  }
  
  # Print the dates we're processing
  print(paste("Processing:", current_date, "-", next_date))
  start_time <- Sys.time()
  
  filtered_purpleairs_sf <- purpleairs_sf %>% filter(last_seen >= current_date) %>% filter(date_created <= next_date)
  sensorIndex <- unique(filtered_purpleairs_sf$sensor_index)
  
  # Get the data
  purple_air <- getPurpleairApiHistoryV2(
    sensorIndex=sensorIndex,
    apiReadKey=apiReadKey,
    startDate=current_date,
    endDate=next_date,
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
file_paths <- list.files(purpleair_directory, pattern = "purple_air_sanfran_.*.csv", full.names = FALSE)

# Read files
dfs <- lapply(file_paths, read.csv)

# Bind to 1 dataframe
fulldata <- do.call(rbind, dfs)

# initialize from and to
from = "9999-99-99"
to = "0000-00-00"

for (f in file_paths) {
  from = min(from,substr(f,20,23))
  to = max(to,substr(f,31,34))
}

# Save full df to csv
write.csv(fulldata, file = paste0(preprocessing_directory, "/purple_air_sanfran_", from, "-", to, ".csv"), row.names = FALSE)
```

``` r
# Read purple air data
fulldata <- read.csv(paste0(preprocessing_directory, "/purple_air_sanfran_2018-2019.csv"))

# Add column for month
fulldata$month <- format(as.Date(fulldata$time_stamp), "%Y-%m")

# Sensors for each month
monthly_sensors <- fulldata %>% select(month, sensor_index) %>% distinct()
head(monthly_sensors)
```

    ##     month sensor_index
    ## 1 2018-01          767
    ## 2 2018-01         1742
    ## 3 2018-01         1860
    ## 4 2018-01         1874
    ## 5 2018-01         2031
    ## 6 2018-01         2574

``` r
sensor_counts <- monthly_sensors %>%
  group_by(month) %>%
  summarise(sensor_count = n_distinct(sensor_index))

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
