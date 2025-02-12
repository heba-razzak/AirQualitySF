OpenStreetMap Data
================

Load required libraries

``` r
library(osmdata)       # Download OpenStreetMap Data
library(dplyr)         # Data manipulation
library(data.table)    # Working with large files
library(sf)            # Spatial data manipulation
library(leaflet)       # Interactive maps
library(tigris)        # Counties map data
library(ggplot2)       # Data visualization
library(htmlwidgets)   # Creating HTML widgets
library(webshot)       # Convert URL to image
library(DataOverviewR)
library(tidyverse)
# library(terra)
# library(tidyterra)
# library(tibble)
library(here)          # Robust file paths
```

Download OSM Roads

``` r
filepath <- here("code", "data", "raw", "bayarea_osm_roads.gpkg")

if (!file.exists(filepath)) {
  # Download OSM roads data for each sensor buffer
  for (i in 1:nrow(purpleairs_buffers)) {
    sensor_index <- purpleairs_buffers$sensor_index[i]
    filename <- here("code", "data", "raw", "OSM", paste0("roads_sensor", sensor_index, ".gpkg"))
    
    if (file.exists(filename)) next
    
    osm <- opq(bbox = purpleairs_buffers[i, ]$geom) %>%
      add_osm_feature(key = 'highway') %>%
      osmdata_sf()
    
    if (is.null(osm$osm_lines) || nrow(osm$osm_lines) == 0) next
    
    # If OSM id is missing, fill with row names
    if(!"osm_id" %in% names(osm$osm_lines)) {
      osm$osm_lines$osm_id <- rownames(osm$osm_lines)
    }
    
    # If other column is missing, fill with NA
    cols <- c("name", "highway", "lanes", "maxspeed")
    for (c in cols) {
      if(!c %in% names(osm$osm_lines)) {
        osm$osm_lines[[c]] <- NA
      }
    }
    
    selected_columns <- osm$osm_lines %>%
      select(osm_id, name, highway, lanes, maxspeed)
    
    # Intersect with buffer
    sf_obj <- st_intersection(st_as_sf(selected_columns), purpleairs_buffers[i, ]$geom)
    
    if (is.null(sf_obj) || nrow(sf_obj) == 0) next
    
    sf_obj$sensor_index <- purpleairs_buffers$sensor_index[i]
    st_write(sf_obj, filename, driver = "GPKG", append = FALSE, quiet = TRUE)
  }
  
  # Save OSM road data for sensors into a single file
  file_paths <- list.files(here("code", "data", "raw", "OSM"),
                           pattern = "^roads_sensor.*\\.gpkg$", full.names = TRUE)
  sf_list <- lapply(file_paths, st_read, quiet = TRUE)
  merged_sf <- do.call(rbind, sf_list) %>% distinct()
  st_write(merged_sf, filepath, driver = "GPKG", append = FALSE, quiet = TRUE)
}
```

``` r
desc <- data_description(osm_roads, 
                         var_desc = c(
                           "osm_id" = "Unique OpenStreetMap identifier for road segment",
                           "name" = "Street name or route designation",
                           "highway" = "Road classification (motorway, primary, residential, etc.)",
                           "lanes" = "Number of traffic lanes",
                           "maxspeed" = "Posted speed limit in km/h",
                           "sensor_index" = "Unique identifier for PurpleAir sensors",
                           "geometry" = "Road linestring segment geometry"
                         ))

data_dictionary(osm_roads, 
                data_title = "OSM Roads", 
                descriptions = desc, 
                hide = c("top_n", "NA_Percentage", "NA_Count", "n_unique"))
```

#### OSM Roads

`570,519` rows

`523,886` rows with missing values

| Column | Type | Description |
|:--:|:--:|:--:|
| osm_id | character | Unique OpenStreetMap identifier for road segment |
| name | character | Street name or route designation |
| highway | character | Road classification (motorway, primary, residential, etc.) |
| lanes | character | Number of traffic lanes |
| maxspeed | character | Posted speed limit in km/h |
| sensor_index | integer | Unique identifier for PurpleAir sensors |
| geom | sfc_MULTILINESTRING |  |

``` r
# Head osm roads
knitr::kable(head(osm_roads, 3), row.names = FALSE, format = "markdown")
```

| osm_id | name | highway | lanes | maxspeed | sensor_index | geom |
|:---|:---|:---|:---|:---|---:|:---|
| 5149025 | Upper Jordan Fire Trail | track | NA | NA | 1004 | MULTILINESTRING ((-122.2438… |
| 5149902 | Grizzly Peak Boulevard | tertiary | 2 | 30 mph | 1004 | MULTILINESTRING ((-122.2433… |
| 6318815 | Gridiron Way | service | NA | NA | 1004 | MULTILINESTRING ((-122.2529… |

``` r
data_dictionary(osm_roads, data_title = "OSM Roads")
```

#### OSM Roads

`570,519` rows

`523,886` rows with missing values

| Column | Type | NA_Count | NA_Percentage | N_Unique | Top_5 |
|:--:|:--:|:--:|:--:|:--:|:--:|
| osm_id | character | 0 |  | 283,372 | 38895987, 570319196, 1158358578, 1158358579, 570319197 |
| name | character | 384,577 | 67% | 29,892 | Market Street, El Camino Real, San Pablo Avenue, Broadway, Shattuck Avenue |
| highway | character | 120 | 0% | 30 | service, footway, residential, secondary, tertiary |
| lanes | character | 488,209 | 86% | 13 | 2, 3, 1, 4, 5 |
| maxspeed | character | 500,490 | 88% | 23 | 25 mph, 35 mph, 30 mph, 65 mph, 20 mph |
| sensor_index | integer | 0 |  | 931 | 28485, 21555, 44089, 20473, 23509 |
| geom | sfc_MULTILINESTRING | 0 |  | 322,353 |  |

Road types: Major, Moderate, Minor

``` r
osm_roads <- st_read(here("code", "data", "raw", "bayarea_osm_roads.gpkg"), quiet = TRUE)
osm_roads_data <- osm_roads %>%
  select(sensor_index, osm_id, highway) %>% 
  mutate(road_type = case_when(
    highway %in% c("motorway", "motorway_link", "trunk", "trunk_link") ~ "major",
    highway %in% c("primary", "primary_link", "secondary", "tertiary") ~ "moderate",
    highway %in% c("residential", "unclassified", "service", "living_street",
                   "secondary_link", "tertiary_link") ~ "minor",
    TRUE ~ "minor"))
```

Calculate road lengths per sensor

``` r
road_lengths <- osm_roads_data %>%
  select(sensor_index, osm_id, highway, road_type) %>%
  mutate(road_length_m = round(st_length(geom),2)) %>% 
  st_drop_geometry()

# Remove units from road_length
attributes(road_lengths$road_length_m) = NULL

knitr::kable(head(road_lengths, 3), row.names = FALSE, format = "markdown")
```

| sensor_index | osm_id  | highway  | road_type | road_length_m |
|-------------:|:--------|:---------|:----------|--------------:|
|         1004 | 5149025 | track    | minor     |        160.27 |
|         1004 | 5149902 | tertiary | moderate  |         43.93 |
|         1004 | 6318815 | service  | minor     |         96.33 |

Save OSM roads as CSV

``` r
write.csv(road_lengths, here("code", "data", "processed", "osm_roads.csv"), row.names = FALSE)
```
