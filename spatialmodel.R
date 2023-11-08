# Land Use Regression Model

# Load required libraries
library(lubridate) # For dates
library(dplyr) # For data manipulation
library(sf) # For working with spatial data
library(tidyr) # pivot

# read csv files
purpleair <- read.csv("/Users/heba/Desktop/Uni/Lim Lab/Purple Air/purple_air_sf_2019-06-01_2019-06-30.csv")
uber_data <- read.csv("/Users/heba/Desktop/Uni/Lim Lab/Uber/Speeds/movement-speeds-hourly-san-francisco-2019-6.csv")

# read spatial data
path = '/Users/heba/Desktop/Uni/Lim Lab/uber_purpleair/'
selected_ways_sf <- st_read(paste0(path,'selected_ways_sf.shp'))
purpleairs_sf <- st_read(paste0(path,'purpleairs_sf.shp'))
uber_ways_sf <- st_read(paste0(path,'uber_ways_sf.shp'))
purpleairs_buffers <- st_read(paste0(path,'purpleairs_buffers.shp'))
intersections <- st_read(paste0(path,'intersections.shp'))

# aggregate data by sensor id
purpleair_agg <- purpleair %>% group_by(sensor_id) %>% summarise(pm2.5 = mean(pm2.5_atm)) %>% ungroup

# uber data
# Calculate free-flow speed (95th percentile of speed) for each osm_way_id
free_flow_speeds <- uber_data %>%
  group_by(osm_way_id) %>%
  summarise(free_flow_speed = quantile(speed_mph_mean, 0.95)) %>%
  ungroup()

# Join free_flow_speeds with filtered_uber_data
uber_data <- uber_data %>%
  left_join(free_flow_speeds, by = "osm_way_id")

# Calculate congestion ratio for each observation (1 = free flow speed, <1 = congestion, >1 = faster speed)
uber_data$congestion_ratio <- uber_data$speed_mph_mean / uber_data$free_flow_speed

# Aggregate congestion ratio by osm way
uber_data_agg <- uber_data %>%
  group_by(osm_way_id) %>%
  summarise(
    mean_congestion = mean(congestion_ratio, na.rm = TRUE),
    max_congestion = max(congestion_ratio, na.rm = TRUE),
    min_congestion = min(congestion_ratio, na.rm = TRUE),
    mean_speed = mean(speed_mph_mean, na.rm = TRUE)
  ) %>%
  ungroup()

uber_data %>%filter(osm_way_id==7373736)

# uber_ways_sf way length
uber_ways_sf %>% filter(name=="James Lick Freeway") # length is not the full freeway, its segmented
uber_ways_sf$way_length <- st_length(uber_ways_sf$geometry)

# Convert uber_ways_sf to df
uber_ways <- as.data.frame(st_drop_geometry(uber_ways_sf)) %>% select(osm_id,highway,lanes, way_length) %>% mutate(lanes = as.numeric(lanes), way_length = as.numeric(way_length))

# fill in NA's of number of lanes with mean for that highway type
uber_ways <- uber_ways %>%
  group_by(highway) %>%
  mutate(lanes = ifelse(is.na(lanes), mean(lanes, na.rm = TRUE), lanes)) %>% ungroup()
  
# join uber_data_agg and uber_ways (inner join -> only keeps SF area)
# example of osm_id: 4304424 in uber_data https://www.openstreetmap.org/way/4304424 # really far away from SF

uber_data_agg <- uber_data_agg %>% mutate(osm_way_id=as.character(osm_way_id))
uber_data_agg2 <- uber_ways %>% inner_join(uber_data_agg, by = c("osm_id" = "osm_way_id")) 
# c("motorway", "trunk", "primary", "secondary", "tertiary", 	"unclassified",	"residential")

# convert intersections to df
intersections <- as.data.frame(st_drop_geometry(intersections)) %>% select(osm_id,sensr_d) 

result <- intersections %>%
  left_join(uber_data_agg2, by = "osm_id") %>%
  group_by(sensr_d, highway) %>%
  summarise(mean_congestion = mean(mean_congestion, na.rm = TRUE),
            avg_lanes = mean(lanes, na.rm = TRUE)) %>%
  pivot_wider(names_from = highway,
              values_from = c(mean_congestion, avg_lanes)) %>%
  ungroup()

model_data <- result %>%
  left_join(purpleair_agg, by = c("sensr_d" = "sensor_id"))

# remove missing values
model_data <- model_data[complete.cases(model_data$pm2.5), ]

model_data <- model_data %>%
  mutate_all(~ ifelse(is.na(.), -1, .))

head(model_data)

# split train and test
library(caTools)
set.seed(42)
split <- sample.split(model_data$pm2.5, SplitRatio = 0.7)
train_data <- subset(model_data, split == TRUE)
test_data  <- subset(model_data, split == FALSE)

# train random forest model
library(randomForest)
set.seed(42)
rf_model <- randomForest(pm2.5 ~ . - sensr_d, data = train_data, ntree = 500)

# make predictions
predictions <- predict(rf_model, test_data)

# mean absolute error
MAE <- mean(abs(predictions - test_data$pm2.5))

# Compute R squared
R2 <- 1 - sum((test_data$pm2.5 - predictions)^2) / sum((test_data$pm2.5 - mean(test_data$pm2.5))^2)

# Print R squared
cat("R squared:", R2)

importance_matrix <- importance(rf_model)

# Print the feature importance
print(importance_matrix)
importance_matrix[order(importance_matrix[, "IncNodePurity"], decreasing = TRUE), ]


# Visualize predictions
library(ggplot2)
plot(predictions,test_data$pm2.5)
