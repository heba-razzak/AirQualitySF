Preprocessing Weather
================

# PurpleAir Sensors & Nearest Weather Station

## Load required libraries

``` r
library(dplyr)      # For data manipulation
library(data.table) # Faster than dataframes (for big files)
library(sf)         # For working with spatial data
library(leaflet)    # For interactive maps
library(lubridate)  # Dates
library(purpleAirAPI)
```

## Read files

``` r
purpleair_data <- fread(paste0(preprocessing_directory,"/purpleair_filtered_2018-2019.csv"))
weather_stations <- st_read(paste0(weather_directory, "/weather_stations.gpkg"), quiet = TRUE)
weather_data <- fread(paste0(weather_directory,"/weather.csv"))
```

## Get PurpleAir sensors

``` r
pa <- getPurpleairSensors(apiReadKey = api_key) %>% na.omit()
pa_sf <- st_as_sf(pa, coords=c("longitude", "latitude"), crs = 4326)
bay_area_sf <- st_as_sfc(st_bbox(c(xmin = -123.8, ymin = 36.9, xmax = -121.0, ymax = 39.0)))
st_crs(bay_area_sf) <- 4326
purpleair_sensors <- st_intersection(pa_sf, bay_area_sf)
```

    ## Warning: attribute variables are assumed to be spatially constant throughout
    ## all geometries

``` r
filtered_sensors <- purpleair_sensors %>% 
  filter(sensor_index %in% unique(purpleair_data$sensor_index))
```

## Visualize weather station counts

``` r
# Count rows of weather data for stations and filter out stations with <17,000 rows
weather_n <- weather_data %>%
  group_by(station) %>%
  summarise(count = n(), .groups = 'drop')

# Join weather_stations with weather_n to visualize the count
weather_stations_n <- weather_stations %>%
  left_join(weather_n, by = c("id" = "station")) %>%
  mutate(count = ifelse(is.na(count), 0, count))

# Define a color palette based on the count
station_palette <- function(count) {
  ifelse(count >= 17000, "yellow", "red")
}

# Visualize the stations with a count threshold
leaflet() %>%
  addCircleMarkers(data = filtered_sensors, popup = ~paste("Sensor Index:", sensor_index),
                   fillColor = "#9933CC", fillOpacity = 1, color = "#9933CC", weight = 2, opacity = 1, radius = 2) %>%
  addCircleMarkers(data = weather_stations_n, popup = ~paste("Weather Station:", id, "<br>Count:", count),
                   fillColor = ~station_palette(count), fillOpacity = 1, color = ~station_palette(count), 
                   weight = 3, opacity = 1, radius = 3) %>%
  addProviderTiles("CartoDB") %>%
  addLegend(colors = c("yellow", "red"), 
            labels = c("Count >= 17000", "Count < 17000"), 
            title = "Weather Station Data Count", position = "bottomleft") %>%
  setView(lng = -122.44, lat = 37.76, zoom = 7)
```

![](PreprocessingWeather_files/figure-gfm/weather-counts-1.png)<!-- -->

## Filter weather data and save

``` r
# Filter out stations with <17,000 rows
keep_stations <- weather_n %>% filter(count >= 17000)

# Filter weather data and remove wind_gust
filtered_weather_data <- weather_data %>%
  filter(station %in% keep_stations$station) %>%
  select(-wind_gust)

# Save the filtered weather data to a CSV file
write.csv(filtered_weather_data, paste0(preprocessing_directory, "/weather_filtered.csv"), row.names = FALSE)
```

## Nearest weather stations

``` r
# Filter weather stations shapefile
filtered_weather_stations_sf <- weather_stations %>%
  filter(id %in% keep_stations$station)

# Find the index of the nearest weather station for each sensor
nearest_station_index <- st_nearest_feature(filtered_sensors, filtered_weather_stations_sf)

# Calculate the distance to the nearest weather station for each sensor
distances <- st_distance(filtered_sensors, filtered_weather_stations_sf[nearest_station_index, ], by_element = TRUE)

# Add nearest weather stations and distances to PurpleAir data frame
filtered_sensors$weatherstation <- filtered_weather_stations_sf$id[nearest_station_index]
filtered_sensors$station_distance <- as.numeric(distances)

# Add station elevation
filtered_weather_stations <- filtered_weather_stations_sf %>% 
  select(id, station_elevation = elevation) %>% 
  mutate(station_elevation = round(station_elevation, 2)) %>% st_drop_geometry()
filtered_sensors <- filtered_sensors %>%
  left_join(filtered_weather_stations, by = c("weatherstation" = "id"))

# Save PurpleAir sensors and weather stations shapefile
st_write(filtered_sensors, 
         paste0(preprocessing_directory, "/pasensors_weatherstations.gpkg"),
         driver = "GPKG", append = FALSE, quiet = TRUE)
```

## Map PurpleAir Sensors and nearest Weather Stations

``` r
# Convert weather stations to a data frame
weather_stations_df <- as.data.frame(st_coordinates(filtered_weather_stations_sf))
colnames(weather_stations_df) <- c("wlon", "wlat")
weather_stations_df$weatherstation <- filtered_weather_stations_sf$id

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
  addCircleMarkers(data = filtered_weather_stations_sf, popup = ~paste("Weather Station:", id),
                   fillColor = "blue", fillOpacity = 1, color = "blue", weight = 3, opacity = 1, radius = 3) %>%
  addProviderTiles("CartoDB") %>%
  addLayersControl(overlayGroups = c("PurpleAir Sensors and Nearest Weather Stations"),
                   options = layersControlOptions(collapsed = FALSE)) %>%
  addLegend(colors = c("#9933CC", "blue"), 
            labels = c("PurpleAir Sensors", "Weather Stations"), 
            title = "Legend", position = "bottomleft") %>%
  setView(lng = -122.44, lat = 37.76, zoom = 10)
```

![](PreprocessingWeather_files/figure-gfm/map-pa-weather-1.png)<!-- -->
