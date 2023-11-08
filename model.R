# Land Use Regression Model

# Load required libraries
library(lubridate) # For dates
library(dplyr) # For data manipulation
library(sf) # For working with spatial data
library(timeDate) # For holidays

holidays = holidayNYSE(2019)
print(holidays)

# read csv files
temps <- read.csv("/Users/heba/Desktop/Uni/Lim Lab/SanFranTemp.csv")
purpleair <- read.csv("/Users/heba/Desktop/Uni/Lim Lab/Purple Air/purple_air_sf_2019-06-01_2019-06-30.csv")
uber_data <- read.csv("/Users/heba/Desktop/Uni/Lim Lab/Uber/Speeds/movement-speeds-hourly-san-francisco-2019-6.csv")

# filter temps to june 2019 and create datetime column
temps <- temps %>% mutate(Date = ymd(Date)) %>% filter(year(Date) == 2019, month(Date) == 6) %>%
  mutate(datetime = ymd_hms(paste(Date, Time))) %>%
  select(datetime, everything(), -Date, -Time)

# read spatial data
path = '/Users/heba/Desktop/Uni/Lim Lab/uber_purpleair/'
selected_ways_sf <- st_read(paste0(path,'selected_ways_sf.shp'))
purpleairs_sf <- st_read(paste0(path,'purpleairs_sf.shp'))
uber_ways_sf <- st_read(paste0(path,'uber_ways_sf.shp'))
purpleairs_buffers <- st_read(paste0(path,'purpleairs_buffers.shp'))
intersections <- st_read(paste0(path,'intersections.shp'))

# Filtering data for specific sensor ID 2031
filtered_purpleair <- purpleair %>% filter(sensor_id==2031) %>% select(time_stamp,pm2.5_atm,sensor_id)
filtered_intersections <- intersections %>% filter(sensr_d==2031) %>% select(osm_id,name,sensr_d,bicycle,foot,highway,lanes,maxsped)
filtered_uber_data <- uber_data[uber_data$osm_way_id %in% unique(filtered_intersections$osm_id),]

glimpse(filtered_uber_data)
glimpse(filtered_purpleair)

# Converting timestamps to a date-time format
filtered_uber_data$utc_timestamp <- ymd_hms(filtered_uber_data$utc_timestamp)
filtered_purpleair$time_stamp <- ymd_hms(filtered_purpleair$time_stamp)

# Convert the OSM way IDs in the Uber speeds data to character type
filtered_uber_data$osm_way_id <- as.character(filtered_uber_data$osm_way_id)

# Calculate free-flow speed (95th percentile of speed) for each osm_way_id
free_flow_speeds <- filtered_uber_data %>%
  group_by(osm_way_id) %>%
  summarise(free_flow_speed = quantile(speed_mph_mean, 0.95)) %>%
  ungroup()

# # Calculating other speed statistics
# free_flow_speeds2 <- filtered_uber_data %>%
#   group_by(osm_way_id) %>%
#   summarise(min = min(speed_mph_mean),
#             s10 = quantile(speed_mph_mean, 0.1),
#             s20 = quantile(speed_mph_mean, 0.2),
#             s30 = quantile(speed_mph_mean, 0.3),
#             s50 = quantile(speed_mph_mean, 0.5),
#             s85 = quantile(speed_mph_mean, 0.85),
#             s90 = quantile(speed_mph_mean, 0.90),
#             s95 = quantile(speed_mph_mean, 0.95),
#             maxs = max(speed_mph_mean)
#             ) %>%
#   ungroup()

# Convert the OSM way IDs in the Uber speeds data to character type
# free_flow_speeds$osm_way_id <- as.character(free_flow_speeds$osm_way_id)

# Join free flow speeds to Uber ways spatial data
speed_map <- uber_ways_sf %>% left_join(free_flow_speeds, by = c("osm_id" = "osm_way_id"))

# Visualize the speed map
mapview(speed_map, zcol="free_flow_speed")

# Join free_flow_speeds with filtered_uber_data
filtered_uber_data <- filtered_uber_data %>%
  left_join(free_flow_speeds, by = "osm_way_id")

# Calculate congestion ratio for each observation (1 = free flow speed, <1 = congestion, >1 = faster speed)
filtered_uber_data$congestion_ratio <- filtered_uber_data$speed_mph_mean / filtered_uber_data$free_flow_speed

# Aggregate congestion ratio by timestamp
aggregated_uber_data <- filtered_uber_data %>%
  group_by(utc_timestamp) %>%
  summarise(
    congestion_ratio_mean = mean(congestion_ratio, na.rm = TRUE)
  ) %>%
  ungroup()


# merge uber and purple air data on time (since were only using 1 sensor and corresponding roads)
merged_data <- merge(aggregated_uber_data, filtered_purpleair, by.x = "utc_timestamp", by.y = "time_stamp")
merged_data <- merge(merged_data, temps, by.x = "utc_timestamp", by.y = "datetime")

head(merged_data)

# Create date variables for prediction
merged_data$day_of_week <- wday(merged_data$utc_timestamp)
merged_data$hour <- hour(merged_data$utc_timestamp)
merged_data$month <- month(merged_data$utc_timestamp)
merged_data$is_weekend <- ifelse(merged_data$day_of_week %in% c(6, 7), 1, 0) # Assuming 6 and 7 represent the weekend

head(merged_data,10)

# only keep columns well use
model_data <- merged_data[, c("congestion_ratio_mean", "hour", "day_of_week",
                              "month", "is_weekend","TemperatureFahrenheit", "pm2.5_atm")]
glimpse(model_data)

# split train and test
library(caTools)
set.seed(42)
split <- sample.split(model_data$pm2.5_atm, SplitRatio = 0.7)
train_data <- subset(model_data, split == TRUE)
test_data  <- subset(model_data, split == FALSE)

# train random forest model
library(randomForest)
set.seed(42)
rf_model <- randomForest(pm2.5_atm ~ congestion_ratio_mean + hour + day_of_week + month + is_weekend, data = train_data, ntree = 500)

# make predictions
predictions <- predict(rf_model, test_data)

# mean absolute error
MAE <- mean(abs(predictions - test_data$pm2.5_atm))

# Compute R squared
R2 <- 1 - sum((test_data$pm2.5_atm - predictions)^2) / sum((test_data$pm2.5_atm - mean(test_data$pm2.5_atm))^2)

# Print R squared
cat("R squared:", R2)

# Visualize predictions
library(ggplot2)
plot(predictions,test_data$pm2.5_atm)
