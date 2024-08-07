Preprocessing Weather
================

# PurpleAir Sensors & Nearest Weather Station

## Load required libraries

``` r
library(dplyr) # For data manipulation
library(data.table) # Faster than dataframes (for big files)
library(sf) # For working with spatial data
library(leaflet) # For interactive maps
library(lubridate) # Dates
```

## Read files

``` r
purpleair_data <- fread(paste0(preprocessing_directory,"/purpleair_filtered_2018-2019.csv"))
purpleair_sensors <- st_read(paste0(purpleair_directory, "/purpleair_sensors.gpkg"), quiet = TRUE)
weather_stations <- st_read(paste0(weather_directory, "/weather_stations.gpkg"), quiet = TRUE)
weather_data <- fread(paste0(weather_directory,"/weather.csv"))
```

## Filter PurpleAir sensors

``` r
# filter purpleair_sensors for our selected data
filtered_sensors <- purpleair_sensors %>% 
  filter(sensor_index %in% unique(purpleair_data$sensor_index))
```

## Nearest Weather Stations

``` r
# Find the index of the nearest weather station for each sensor
nearest_station_index <- st_nearest_feature(filtered_sensors, weather_stations)

# Calculate the distance to the nearest weather station for each sensor
distances <- st_distance(filtered_sensors, weather_stations[nearest_station_index, ], by_element = TRUE)

# Add nearest weather stations and distances to PurpleAir data frame
filtered_sensors$weatherstation <- weather_stations$id[nearest_station_index]
filtered_sensors$station_distance <- as.numeric(distances)

# Add station elevation
weather_stations <- weather_stations %>% 
  select(id, station_elevation = elevation) %>% 
  mutate(station_elevation = round(station_elevation,2)) %>% st_drop_geometry()
filtered_sensors <- filtered_sensors %>%
  left_join(weather_stations, by = c("weatherstation" = "id"))

# Save PurpleAir sensors and weather stations shapefile
st_write(filtered_sensors, 
         paste0(preprocessing_directory, "/pasensors_weatherstations.gpkg"),
         driver = "GPKG", append = FALSE, quiet = TRUE)
```

## Filter weather data and save

``` r
# remove wind gust since it's mostly NA
weather_data <- weather_data %>%
  filter(station %in% unique(filtered_sensors$weatherstation)) %>%
  select(-wind_gust)

write.csv(weather_data, paste0(preprocessing_directory,"/weather_filtered.csv"), row.names = FALSE)
```

## Map PurpleAir Sensors and nearest Weather Stations

``` r
weather_stations <- st_read(paste0(weather_directory, "/weather_stations.gpkg"), quiet = TRUE)
filtered_sensors <- st_read(paste0(preprocessing_directory,"/pasensors_weatherstations.gpkg"), quiet = TRUE)

# Convert weather stations to a data frame
weather_stations_df <- as.data.frame(st_coordinates(weather_stations))
colnames(weather_stations_df) <- c("wlon", "wlat")
weather_stations_df$weatherstation <- weather_stations$id

# Convert filtered sensors to a data frame
filtered_sensors_df <- as.data.frame(st_coordinates(filtered_sensors))
colnames(filtered_sensors_df) <- c("plon", "plat")
filtered_sensors_df$sensor_index <- filtered_sensors$sensor_index
filtered_sensors_df$weatherstation <- filtered_sensors$weatherstation

# Join filtered sensors and weather stations data frames
result <- left_join(filtered_sensors_df, weather_stations_df, by = "weatherstation")

# Connect sensors with closest weather stations with lines
sensor_coords <- result[, c("plon", "plat")]
names(sensor_coords) <- c("long", "lat")
station_coords <- result[, c("wlon", "wlat")]
names(station_coords) <- c("long", "lat")

# Add lines as geometry
result$geometry <- do.call("c", lapply(seq(nrow(sensor_coords)), function(i) {
  st_sfc(st_linestring(as.matrix(rbind(sensor_coords[i, ], station_coords[i, ]))), crs = 4326)
}))

# Convert the result to a simple feature object
closest_station <- st_as_sf(result)

# Map of PurpleAir sensors and nearest weather stations
leaflet() %>%
  addPolylines(data = closest_station, color = "lightblue", weight = 0.5, opacity = 1) %>%
  addCircleMarkers(data = filtered_sensors, popup = ~paste("Sensor Index:", sensor_index),
                   fillColor = "#9933CC", fillOpacity = 1, color = "#9933CC", weight = 2, opacity = 1, radius = 2) %>%
  addCircleMarkers(data = weather_stations, popup = ~paste("Weather Station:", id),
                   fillColor = "blue", fillOpacity = 1, color = "blue", weight = 3, opacity = 1, radius = 3) %>%
  addProviderTiles("CartoDB") %>%
  addLayersControl(overlayGroups = c("PurpleAir Sensors and Nearest Weather Stations"),
                   options = layersControlOptions(collapsed = F)) %>%
  addLegend(colors = c("#9933CC", "blue"), 
            labels = c("PurpleAir Sensors", "Weather Stations"),
            position = "bottomleft") %>% 
    setView(lng = -122.44, lat =  37.76, zoom = 10)
```

![](PreprocessingWeather_files/figure-gfm/map-pa-weather-1.png)<!-- -->
