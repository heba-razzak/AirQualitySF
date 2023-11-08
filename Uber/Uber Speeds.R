library(dplyr)
library(data.table)
library(ggplot2)

dir = '/Users/heba/Desktop/Uni/Lim Lab/Uber/Speeds'
setwd(dir)

# Download files from 
# This selection may be missing data from 9/4/2019 - 9/5/2019
# https://movement.uber.com/cities/san_francisco/downloads/speeds

# list files in working directory
file_list <- list.files()

# # empty list to contain data
# data_list <- list() 
# 
# # fread all files from directory
# data_list <- lapply(file_list, fread)
# 
# # combine data to 1 file
# combined_data <- do.call(rbind, data_list)
# 
# Error: vector memory exhausted (limit reached?)

# first file name
file <- file_list[1]

# read file 
data <- fread(file)

glimpse(data)

# get average speed by osm_way_id, osm_start_node_id, osm_end_node_id
data <- data %>%
  group_by(osm_way_id, osm_start_node_id, osm_end_node_id) %>%
  mutate(average_speed = mean(speed_mph_mean, na.rm = TRUE))

# get ratio of each speed to the average speed
data <- data %>%
  mutate(speed_ratio = speed_mph_mean / average_speed)

plot_data <- ungroup(data) %>% select(hour, speed_ratio)

plot_data$speed_ratio <- round(plot_data$speed_ratio,1)

summary_data <- plot_data %>%
  group_by(hour) %>%
  summarize(mean_speed_ratio = mean(speed_ratio),
            median_speed_ratio = median(speed_ratio),
            min_speed_ratio = min(speed_ratio),
            max_speed_ratio = max(speed_ratio))

# Plotting the summarized data
ggplot(summary_data, aes(x = hour)) +
  geom_line(aes(y = mean_speed_ratio, color = "Mean")) +
  geom_line(aes(y = median_speed_ratio, color = "Median")) +
  # geom_line(aes(y = min_speed_ratio, color = "Min")) +
  # geom_line(aes(y = max_speed_ratio, color = "Max")) +
  labs(x = "Hour", y = "Speed Ratio") +
  scale_x_continuous(breaks = seq(min(summary_data$hour), max(summary_data$hour), by = 1), 
                     labels = seq(min(summary_data$hour), max(summary_data$hour), by = 1)) +
  scale_y_continuous(breaks = seq(0, 2, by = 0.1),
                     labels = seq(0, 2, by = 0.1)) +
  scale_color_manual(values = c("red", "blue", "green", "purple")) +
  theme_minimal() +
  ggtitle("Speed Ratio by Hour of Day (how much faster than avg speed)")

# 4 am  = super empty
# 8 am = rush hour
# 5 pm = rush hour

ggplot(plot_data, aes(x = hour, y = speed_ratio)) +
  geom_point() +
  geom_line() +
  xlab("Hour") +
  ylab("Speed Ratio") +
  ggtitle("Speed Ratio vs. Hour")


colnames(data)

# unique osm "way" with start and end nodes
road <- unique(data[, c("osm_way_id", "osm_start_node_id", "osm_end_node_id")])

# write.csv(road, "road.csv", row.names = FALSE)

#######
#######
tensor <- array(0, dim = c(nrow(road), max(data$day), 24))
k <- 1

for (i in 1:nrow(road)) {
  temp <- data[data$osm_way_id == road$osm_way_id[i] &
                 data$osm_start_node_id == road$osm_start_node_id[i] &
                 data$osm_end_node_id == road$osm_end_node_id[i], ]
  
  for (j in 1:nrow(temp)) {
    tensor[k, temp$day[j] - 1, temp$hour[j]] <- temp$speed_mph_mean[j]
  }
  
  k <- k + 1
  
  if (k %% 1000 == 0) {
    print(k)
  }
}

mat <- array(tensor, dim = c(nrow(road), max(data$day) * 24))
saveRDS(mat, paste0("hourly_speed_mat_2019_", month, ".rds"))

rm(data, tensor)






##################################################
df = read.csv('san_francisco-censustracts-2018-1-All-HourlyAggregate.csv')

# sourceid: source zone
# dstid: destination zone
# hod: hour of day
# travel times: in seconds

