Preprocessing Uber
================

# Calculate Free Flow Speeds and Congestion Ratio

## Load required libraries

``` r
library(dplyr) # For data manipulation
library(data.table) # Faster than dataframes (for big files)
library(sf) # For working with spatial data
library(lubridate) # Dates
library(ggplot2) # Plots
library(leaflet) # Interactive maps
```

## Filter uber files and combine

``` r
# Read roads file
bayarea_roads <- st_read(paste0(osm_directory, "/bayarea_roads_osm.gpkg"), quiet = TRUE)

# Get a list of uber file paths
file_paths <- list.files(uber_directory, pattern = "movement-speeds-hourly-san-francisco-.*.csv", full.names = TRUE)

# Define a function to preprocess and filter each file
preprocess_and_filter_uber_file <- function(file) {
  data <- fread(file)
  # Select necessary columns, and filter by relevant_osm_ids
  data <- data %>% 
          select(utc_timestamp, osm_way_id, speed_mph_mean) %>%
          filter(osm_way_id %in% relevant_osm_ids) %>%
          filter(complete.cases(.))
  return(data)
}

# Ensure relevant_osm_ids are numeric
relevant_osm_ids <- as.numeric(unique(bayarea_roads$osm_id))

# Apply the preprocessing and filtering function to each file and combine
uber_data_list <- lapply(file_paths, preprocess_and_filter_uber_file)
uber_data <- rbindlist(uber_data_list, use.names = TRUE, fill = TRUE)
```

#### Calculate congestion based on free-flow speed (95th percentile of speed) for each osm_way_id

### Congestion:

### 1 = free flow speed

### \<1 = congestion

### \>1 = faster speed

``` r
# Calculate congestion
uber_congestion <- uber_data %>%
  group_by(osm_way_id) %>%
  mutate(
    free_flow_speed = quantile(speed_mph_mean, 0.95),
    congestion_ratio = speed_mph_mean / free_flow_speed
  ) %>%
  ungroup()
```

## Save filtered & combined Uber traffic file

``` r
# Save the combined data
fwrite(uber_congestion, paste0(preprocessing_directory, "/traffic.csv"))
```

## Read files

``` r
# Read traffic file
uber_congestion <- fread(paste0(preprocessing_directory, "/traffic.csv"))

# Read roads file
bayarea_roads <- st_read(paste0(osm_directory, "/bayarea_roads_osm.gpkg"), quiet = TRUE)

bbox <- c(xmin = -122.55, ymin = 37.82, xmax = -122.35, ymax = 37.7)
bbox_polygon <- st_as_sfc(st_bbox(bbox))
st_crs(bbox_polygon) <- 4326
sanfran_roads <- st_intersection(bayarea_roads, bbox_polygon)
```

## Visualize congestion by hour and day

``` r
uber_congestion$local_timestamp <- with_tz(uber_congestion$utc_timestamp, tzone = "America/Los_Angeles")

road_congestion_dailyhourly <- uber_congestion %>%
  mutate(DayOfWeek = factor(lubridate::wday(local_timestamp, label=TRUE, abbr = TRUE)),
         HourOfDay = hour(local_timestamp)) %>% 
  group_by(DayOfWeek, HourOfDay) %>%
  summarize(congestion_ratio_mean = mean(congestion_ratio), .groups = 'drop')

hour_labels <- c("12 AM", "1 AM", "2 AM", "3 AM", "4 AM", "5 AM", "6 AM", 
                 "7 AM", "8 AM", "9 AM", "10 AM", "11 AM", "12 PM", 
                 "1 PM", "2 PM", "3 PM", "4 PM", "5 PM", "6 PM", 
                 "7 PM", "8 PM", "9 PM", "10 PM", "11 PM")

heatmap_plot <- ggplot(road_congestion_dailyhourly, aes(x = HourOfDay, y = DayOfWeek, fill = congestion_ratio_mean)) +
  geom_tile() +
  scale_fill_gradientn(
    colours = c("red", "yellow", "forestgreen"),
    name = "Congestion Ratio Mean") +
  labs(
    title = "Congestion Heatmap (local time)",
    x = "Hour of Day",
    y = "Day of Week"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  scale_x_continuous(breaks = 0:23, labels = hour_labels) 

print(heatmap_plot)
```

![](PreprocessingUber_files/congestion-heatmap-1.png){width=600px height=400px}

## Prepare data for maps

``` r
# Prepare congestion shapefile for mapping
sanfran_roads$osm_id <- as.numeric(sanfran_roads$osm_id)

congestion_sf <- inner_join(sanfran_roads, uber_congestion, 
                            by = c("osm_id" = "osm_way_id"))
```

``` r
# Traffic color palette
trafficpalette <- colorRampPalette(c("red", "yellow", "forestgreen"), 
                                   space = "Lab")(10)

# Traffic palette for congestion (0-1)
palette_func_cong <- colorNumeric(palette = trafficpalette, domain = c(0, 1))

# Function to cap congestion values to fall in color scale
cap_cong <- function(x) {
  pmax(pmin(x, 1), 0)
}

# Traffic palette for speed (0-75mph)
palette_func_ff <- colorNumeric(palette = trafficpalette, domain = c(0, 75))

# Function to cap free flow speeds values to fall in color scale
cap_ff <- function(x) {
  pmax(pmin(x, 75), 0)
}
```

## Map average congestion on Wednesdays at 4 PM

``` r
# Average congestion on Wednesdays at 4 PM
congestion_wed4pm <- congestion_sf %>% 
  filter(weekdays(local_timestamp) == "Wednesday", 
         hour(local_timestamp) == 16) %>%
  group_by(osm_id) %>%
  summarize(avg_speed = mean(speed_mph_mean, na.rm = TRUE),
            free_flow_speed = mean(free_flow_speed, na.rm = TRUE)) %>%
  mutate(congestion = avg_speed / free_flow_speed)

leaflet(congestion_wed4pm) %>%
  addPolylines(color = ~palette_func_cong(cap_cong(congestion)), weight = 2, opacity = 1, 
               label = ~paste("Congestion: ", round(congestion,2))) %>%
  addLegend(pal = palette_func_cong, values = ~cap_cong(congestion), opacity = 1, 
            title = "Average Congestion", position = "bottomright") %>% 
  addLayersControl(overlayGroups = c("Wednesdays at 4 PM"),
                   options = layersControlOptions(collapsed = F)) %>%
  addProviderTiles("CartoDB") %>%
  setView(lng = -122.44, lat =  37.76, zoom = 13)
```

![](PreprocessingUber_files/congestion-wed4pm-1.png)

## Map average congestion on Sundays at 7 AM

``` r
# Average congestion on Sundays at 7 AM
congestion_sun7am <- congestion_sf %>% 
  filter(weekdays(local_timestamp) == "Sunday", hour(local_timestamp) == 7) %>%
  group_by(osm_id) %>%
  summarize(avg_speed = mean(speed_mph_mean, na.rm = TRUE),
            free_flow_speed = mean(free_flow_speed, na.rm = TRUE)) %>%
  mutate(congestion = avg_speed / free_flow_speed)

leaflet(congestion_sun7am) %>%
  addPolylines(color = ~palette_func_cong(cap_cong(congestion)), weight = 2, opacity = 1, 
               label = ~paste("Congestion: ", round(congestion,2))) %>%
  addLegend(pal = palette_func_cong, values = ~cap_cong(congestion), opacity = 1, 
            title = "Average Congestion", position = "bottomright") %>% 
  addLayersControl(overlayGroups = c("Sundays at 7 AM"),
                   options = layersControlOptions(collapsed = F)) %>%
  addProviderTiles("CartoDB") %>%
  setView(lng = -122.44, lat =  37.76, zoom = 13)
```

![](PreprocessingUber_files/congestion-sun7am-1.png)

## Map free flow speeds

``` r
# Free flow data
freeflow <- uber_congestion %>% 
  select(osm_way_id, free_flow_speed) %>% distinct()
freeflow_sf <- inner_join(sanfran_roads, freeflow, 
                            by = c("osm_id" = "osm_way_id"))
# Free flow speed map
leaflet(freeflow_sf) %>%
  addPolylines(color = ~palette_func_ff(cap_ff(free_flow_speed)), weight = 2, opacity = 1, 
               label = ~paste("Free Flow Speed: ", round(free_flow_speed,2))) %>%
  addLegend(pal = palette_func_ff, values = ~cap_ff(free_flow_speed), opacity = 1, 
            title = "Free Flow Speed", position = "bottomright") %>% 
  addLayersControl(overlayGroups = c("Free Flow Speed"),
                   options = layersControlOptions(collapsed = F)) %>%
  addProviderTiles("CartoDB") %>% 
  setView(lng = -122.44, lat =  37.76, zoom = 13)
```

![](PreprocessingUber_files/free-flow-map-1.png)
