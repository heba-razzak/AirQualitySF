Download Weather Data
================

## Load required libraries

``` r
library(riem) # For weather data
library(dplyr) # For data manipulation
library(sf) # For working with spatial data
library(mapview) # For interactive maps
```

``` r
# Networks where name contains "california"
riem_networks() %>% filter(grepl("California", name, ignore.case = TRUE))
```

``` r
stations <- riem_stations(network = "CA_ASOS") %>% select(id,name,elevation,county,lon,lat)
```

## Bounding box of san francisco and surrounding areas

``` r
# greater san fran area
bbox <- c(left = -123.8, bottom = 36.9, right = -121.0, top = 39.0)

x = list(rbind(c(bbox["left"],bbox["bottom"]),
               c(bbox["left"],bbox["top"]),
               c(bbox["right"],bbox["top"]),
               c(bbox["right"],bbox["bottom"]),
               c(bbox["left"],bbox["bottom"])))

# Create a polygon for san fran area
bbox_sf <- st_polygon(x)

# convert to sf object
crs = 4326
bbox_sf <- st_sfc(bbox_sf, crs=crs)

# create new area with additional buffer
new_bbox_sf <- st_buffer(bbox_sf, 25000)
new_bbox_sf <- st_sfc(new_bbox_sf, crs=crs)
```

``` r
# convert stations to sf object
stations_sf <- st_as_sf(stations, coords = c("lon", "lat"), crs = crs)
# map san fran & buffer area & stations
mapview(bbox_sf) + mapview(new_bbox_sf) + mapview(stations_sf)
```

``` r
# get intersection of buffer with stations
stations_within_bbox <- st_intersection(stations_sf, new_bbox_sf)

# Plot the intersection
mapview(stations_within_bbox)
```

``` r
measures_df <- data.frame()

# Collect weather data for 'SFO' station for the specified date range
for (id in stations_within_bbox$id) {
  # Get measures for the current station
  measures <- riem_measures(station = id, date_start = "2018-01-01", date_end = "2018-01-02")

  if (is.null(measures)) {
    next  # Move to the next iteration of the loop
  }

  # select needed columns
  new_df = measures %>% select(station, valid, tmpf, relh, drct, sknt, gust, lon, lat)

  # Add to measures_df
  measures_df <- rbind(measures_df, new_df)
}
```

``` r
measures_df$hour <- format(measures_df$valid, "%Y-%m-%d %H:00:00")
# Group by station and hour, and calculate the average for each variable
summary_df <- measures_df %>%
  group_by(station, hour) %>%
  summarize(
    tmpf_avg = mean(tmpf, na.rm = TRUE),
    relh_avg = mean(relh, na.rm = TRUE),
    drct_avg = mean(drct, na.rm = TRUE),
    sknt_avg = mean(sknt, na.rm = TRUE),
    gust_avg = mean(gust, na.rm = TRUE),
    lon = first(lon),
    lat = first(lat)
  ) %>%
  ungroup()

# View the resulting summary data frame
summary_df
```
