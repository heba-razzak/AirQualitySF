Download EPA Air Quality Data
================

## Load required libraries

``` r
library(dplyr)      # For data manipulation
library(sf)         # For working with spatial data
library(RAQSAPI)    # EPA Air Quality API
library(leaflet)    # For interactive maps
```

``` r
# Define the Bay Area bounding box coordinates
bbox <- c(xmin = -123.8, ymin = 36.9, xmax = -121.0, ymax = 39.0)

# Convert the bounding box to an sf object and set the CRS (WGS 84)
bbox_sf <- st_as_sfc(st_bbox(bbox))
st_crs(bbox_sf) <- 4326

# Create a buffered area around the bounding box (25 km buffer)
new_bbox_sf <- st_buffer(bbox_sf, 25000)

# Extract min and max latitudes and longitudes for the buffered area
minlon <- bbox["xmin"]
maxlon <- bbox["xmax"]
minlat <- bbox["ymin"]
maxlat <- bbox["ymax"]
```

``` r
# Set AQS credentials
aqs_credentials(username = aqs_creds[1], key = aqs_creds[2])

# aqs_classes()
# PM2.5 MASS/QA: PM2.5 Mass and QA Parameters   

# aqs_parameters_by_class(class = "PM2.5 MASS/QA")
# https://aqs.epa.gov/aqsweb/documents/codetables/parameter_classes.html
# 88101:    PM2.5 - Local Conditions

# aqs_sampledurations()
# 1:    1 HOUR

# Get PM2.5 monitors in the Bay Area for the specified date range
monitor_info <- aqs_monitors_by_box(
  parameter = "88101",
  bdate = as.Date("20180101", "%Y%m%d"),
  edate = as.Date("20191231", "%Y%m%d"),
  minlat = minlat, maxlat = maxlat,
  minlon = minlon, maxlon = maxlon
)
```

``` r
# Convert monitor data to an sf object for mapping
monitors_sf <- monitor_info %>%
  select(si_id, latitude, longitude) %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

# Create a leaflet map showing the monitors
leaflet() %>%
  addCircleMarkers(data = monitors_sf, popup = ~si_id,
                   fillColor = "blue", fillOpacity = 1,
                   color = "blue", weight = 2, opacity = 1, radius = 2) %>%
  addProviderTiles("CartoDB")
```

![](DownloadEPAData_files/figure-gfm/map-aqs-1.png)<!-- -->

``` r
# Loop through each monitor and download, process, and save data to CSV
for (i in 1:nrow(monitor_info)) {
  monitor_data <- aqs_sampledata_by_site(
    parameter = "88101",
    bdate = as.Date("20180101", "%Y%m%d"),
    edate = as.Date("20181231", "%Y%m%d"),
    stateFIPS = monitor_info$state_code[i],
    countycode = monitor_info$county_code[i],
    sitenum = monitor_info$site_number[i],
    duration = "1"
  )
  
  # Stop if monitor_data is empty
  if (nrow(monitor_data) == 0) {
    next
  }
  
  # Process data by creating a timestamp and selecting relevant columns
  processed_data <- monitor_data %>%
    mutate(timestamp = paste(date_local, time_local),
           pm25 = sample_measurement,
           id = paste0(state_code,"_",county_code,"_",site_number)) %>%
    select(timestamp, id, state_code, county_code, site_number, poc, pm25, latitude, longitude)

  # Save processed data to CSV
  write.csv(processed_data,
            file = paste0(preprocessing_directory, "/AQS/aqs_2018_", processed_data$id[i], ".csv"),
            row.names = FALSE)
}
```

    ## Waiting 2s to retry ■■■■■■■■■■■■■■■ Waiting 2s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■ Waiting 6s to retry
    ## ■■■■■■ Waiting 6s to retry ■■■■■■■ Waiting 6s to retry ■■■■■■■■ Waiting 6s to
    ## retry ■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■ Waiting
    ## 6s to retry ■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■ Waiting 6s
    ## to retry ■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■ Waiting 6s
    ## to retry ■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting
    ## 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■ Waiting 4s to
    ## retry ■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■
    ## Waiting 4s to retry ■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■ Waiting
    ## 4s to retry ■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■■■ Waiting 4s
    ## to retry ■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■■ Waiting
    ## 4s to retry ■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting
    ## 4s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 3s to retry ■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■ Waiting 3s to
    ## retry ■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to
    ## retry ■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■ Waiting 4s to retry
    ## ■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■
    ## Waiting 4s to retry ■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■
    ## Waiting 4s to retry ■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■
    ## Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s
    ## to retry ■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting
    ## 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■ Waiting 3s to
    ## retry ■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to
    ## retry ■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■
    ## Waiting 6s to retry ■■■■■■■ Waiting 6s to retry ■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■ Waiting 6s
    ## to retry ■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to
    ## retry ■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■
    ## Waiting 4s to retry ■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■ Waiting 4s to
    ## retry ■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■ Waiting 4s to retry
    ## ■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■■■ Waiting 4s to retry
    ## ■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■ Waiting 4s to
    ## retry ■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■
    ## Waiting 3s to retry ■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■
    ## Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting
    ## 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■ Waiting 3s to
    ## retry ■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s
    ## to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■ Waiting 6s to retry
    ## ■■■■■■ Waiting 6s to retry ■■■■■■■ Waiting 6s to retry ■■■■■■■■ Waiting 6s to
    ## retry ■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■ Waiting 6s
    ## to retry ■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■ Waiting 6s to
    ## retry ■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■ Waiting 6s to
    ## retry ■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■ Waiting 6s to
    ## retry ■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■ Waiting
    ## 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■ Waiting 6s to retry
    ## ■■■■■■■ Waiting 6s to retry ■■■■■■■■ Waiting 6s to retry ■■■■■■■■■ Waiting 6s
    ## to retry ■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to
    ## retry ■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■
    ## Waiting 6s to retry ■■■■■■■ Waiting 6s to retry ■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■ Waiting 6s
    ## to retry ■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to
    ## retry ■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■
    ## Waiting 3s to retry ■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■
    ## Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■ Waiting 3s to
    ## retry ■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s
    ## to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■ Waiting 4s to retry
    ## ■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■
    ## Waiting 4s to retry ■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■ Waiting
    ## 4s to retry ■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■■■ Waiting 4s
    ## to retry ■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■■ Waiting
    ## 4s to retry ■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■
    ## Waiting 6s to retry ■■■■■■ Waiting 6s to retry ■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■ Waiting
    ## 6s to retry ■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■ Waiting 6s to
    ## retry ■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting
    ## 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 2s to retry ■■■■■■■■■■■■■■■ Waiting 2s
    ## to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■ Waiting
    ## 3s to retry ■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■ Waiting 3s to
    ## retry ■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■ Waiting 3s
    ## to retry ■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■ Waiting 4s to retry
    ## ■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■
    ## Waiting 4s to retry ■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■ Waiting
    ## 4s to retry ■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■■■ Waiting 4s
    ## to retry ■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■■ Waiting
    ## 4s to retry ■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting
    ## 4s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■ Waiting 3s to
    ## retry ■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to
    ## retry ■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■ Waiting 3s to
    ## retry ■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to
    ## retry ■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■ Waiting 6s to retry ■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■ Waiting 6s to retry ■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■ Waiting
    ## 6s to retry ■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■ Waiting 6s to
    ## retry ■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■ Waiting
    ## 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting
    ## 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■ Waiting 3s to
    ## retry ■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s
    ## to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 3s to retry ■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■ Waiting 3s to
    ## retry ■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to
    ## retry ■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■
    ## Waiting 6s to retry ■■■■■■ Waiting 6s to retry ■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■ Waiting
    ## 6s to retry ■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■ Waiting 6s to
    ## retry ■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 6s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 6s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 5s to retry ■■■■■■■ Waiting 5s to retry
    ## ■■■■■■■ Waiting 5s to retry ■■■■■■■■■ Waiting 5s to retry ■■■■■■■■■■ Waiting 5s
    ## to retry ■■■■■■■■■■■ Waiting 5s to retry ■■■■■■■■■■■■ Waiting 5s to retry
    ## ■■■■■■■■■■■■■■ Waiting 5s to retry ■■■■■■■■■■■■■■ Waiting 5s to retry
    ## ■■■■■■■■■■■■■■■■ Waiting 5s to retry ■■■■■■■■■■■■■■■■■ Waiting 5s to retry
    ## ■■■■■■■■■■■■■■■■■■ Waiting 5s to retry ■■■■■■■■■■■■■■■■■■■■ Waiting 5s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■ Waiting 5s to retry ■■■■■■■■■■■■■■■■■■■■■■ Waiting 5s to
    ## retry ■■■■■■■■■■■■■■■■■■■■■■■ Waiting 5s to retry ■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 5s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 5s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 5s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 5s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 5s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■ Waiting 3s to
    ## retry ■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s
    ## to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 5s to retry ■■■■■■■ Waiting 5s to retry ■■■■■■■■ Waiting 5s to retry
    ## ■■■■■■■■■ Waiting 5s to retry ■■■■■■■■■■ Waiting 5s to retry ■■■■■■■■■■■■
    ## Waiting 5s to retry ■■■■■■■■■■■■ Waiting 5s to retry ■■■■■■■■■■■■■■ Waiting 5s
    ## to retry ■■■■■■■■■■■■■■■ Waiting 5s to retry ■■■■■■■■■■■■■■■■ Waiting 5s to
    ## retry ■■■■■■■■■■■■■■■■■■ Waiting 5s to retry ■■■■■■■■■■■■■■■■■■■ Waiting 5s to
    ## retry ■■■■■■■■■■■■■■■■■■■■ Waiting 5s to retry ■■■■■■■■■■■■■■■■■■■■■ Waiting 5s
    ## to retry ■■■■■■■■■■■■■■■■■■■■■■ Waiting 5s to retry ■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 5s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 5s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 5s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 5s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 5s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■ Waiting 4s to retry
    ## ■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■
    ## Waiting 4s to retry ■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■
    ## Waiting 4s to retry ■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■
    ## Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s
    ## to retry ■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
    ## Waiting 4s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■
    ## Waiting 3s to retry ■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■
    ## Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting
    ## 3s to retry ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Waiting 3s to retry
    ## ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
