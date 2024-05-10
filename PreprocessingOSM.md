Preprocessing OSM
================

# PurpleAir Sensors and OSM roads, buildings, trees

## Load required libraries

``` r
library(dplyr) # For data manipulation
library(data.table) # Faster than dataframes (for big files)
library(sf) # For working with spatial data
library(mapview) # For interactive maps
library(lubridate) # Dates
library(purrr) 
```

## Read files

``` r
purpleair_data <- fread(paste0(purpleair_directory,"/purple_air_sanfran_2018-2019.csv"))
purpleair_sensors <- st_read(paste0(purpleair_directory, "/purpleair_sensors.gpkg"), quiet = TRUE)
osm_roads <- st_read(paste0(osm_directory, "/sanfrangrid_roads_osm.gpkg"), quiet = TRUE)
```

## Filter PurpleAir sensors

``` r
# filter purpleair_sensors for our selected data
filtered_sensors <- purpleair_sensors %>% 
  filter(sensor_index %in% unique(purpleair_data$sensor_index))
```

## Create Buffers around Purple Air Sensors

``` r
# buffer radius in meters
buffer = 500
purpleairs_buffers <- st_buffer(filtered_sensors, dist=buffer)
```

## Get intersections of PurpleAir buffers and OSM roads, buildings, trees

``` r
# Get a list of file paths
file_paths <- list.files(path = paste0(osm_directory,"/grid"), pattern = "^grid.*_osm\\.gpkg$", full.names = TRUE)
for (f in file_paths) {
  new_f <- sub("_osm.gpkg", "_pa.gpkg", f)
  # check if file exists before getting intersection
  if (!file.exists(new_f)) {
    osm_i <- st_read(f, quiet = TRUE)
    osm_i <- st_intersection(osm_i, purpleairs_buffers)
    st_write(osm_i, new_f, driver = "GPKG", append=FALSE)
  }
}
```

## Read OSM/PurpleAir grid files and save to one file

``` r
osm_type <- c("roads", "buildings", "trees")

for (o in osm_type) {
  # Get a list of file paths
  file_paths <- list.files(path = paste0(osm_directory,"/grid"), pattern = paste0("^grid.*_", o, "_pa\\.gpkg$"), full.names = TRUE)
  
  # Read all shapefiles into a list
  sf_list <- lapply(file_paths, st_read)
  
  # Merge the spatial objects
  merged_sf <- do.call(rbind, sf_list)
  
  # Write the merged spatial object to a new shapefile
  st_write(merged_sf, paste0(preprocessing_directory, "/sanfran_", o, "_pa.gpkg"), driver = "GPKG", append=FALSE)
}
```
