Model Building
================

# Model Building

## Load required libraries

``` r
library(lubridate) # For dates
library(dplyr) # For data manipulation
library(sf) # For working with spatial data
library(mapview) # to view maps
library(tidyr) # pivot
library(ggplot2) # plots
library(data.table) # Faster than dataframes (for big files)
```

## Read files

``` r
dataset <- fread(paste0(preprocessing_directory, "/final_dataset.csv"))

# devtools::install_github("heba-razzak/createDataDict")
# library(createDataDict)
# 
# print_data_dict(dataset)
# # get dataframe for descriptions
# descriptions <- descriptions_df(dataset)
# 
# # update descriptions dataframe
# descriptions <- update_description(descriptions,
#                                    c("time_stamp", "pm2.5_atm", "pm2.5_atm_a", "pm2.5_atm_b", "sensor_index", "dow", "hour", 
#                                      "day", "month", "year", "wknd", "holiday", "building_area", "b_yes", "b_apartments", 
#                                      "b_house", "b_NA", "b_residential", "b_terrace", "b_other", "road_length", "r_footway", 
#                                      "r_residential", "r_service", "r_secondary", "r_primary", "r_tertiary", "r_steps", 
#                                      "r_path", "r_motorway_link", "r_other", "num_trees", "mean_speed", "median_speed", 
#                                      "mean_congestion", "median_congestion", "weatherstation", "station_distance", 
#                                      "station_elevation", "x", "y", "z", "temp_fahrenheit", "rel_humidity", 
#                                      "wind_direction", "wind_speed"),
#                                    c("Timestamp of the measurement", 
#                                      "PM2.5 concentration from the air sensor", 
#                                      "PM2.5 concentration from channel A of the air sensor", 
#                                      "PM2.5 concentration from channel B of the air sensor", 
#                                      "Unique identifier for the sensor", 
#                                      "Day of the week (1 = Sunday, 2 = Monday, ...)", 
#                                      "Hour of the day (0-23)", 
#                                      "Day of the month", 
#                                      "Month of the year", 
#                                      "Year of the measurement", 
#                                      "Weekend indicator (1 if weekend, 0 otherwise)", 
#                                      "Holiday indicator (1 if holiday, 0 otherwise)", 
#                                      "Total building area in square meters around the sensor", 
#                                      "Count of buildings classified as 'yes'", 
#                                      "Count of apartments", 
#                                      "Count of houses", 
#                                      "Count of buildings with NA classification", 
#                                      "Count of residential buildings", 
#                                      "Count of terrace buildings", 
#                                      "Count of other types of buildings", 
#                                      "Total length of roads in meters around the sensor", 
#                                      "Length of footways in meters around the sensor", 
#                                      "Length of residential roads in meters around the sensor", 
#                                      "Length of service roads in meters around the sensor", 
#                                      "Length of secondary roads in meters around the sensor", 
#                                      "Length of primary roads in meters around the sensor", 
#                                      "Length of tertiary roads in meters around the sensor", 
#                                      "Length of steps in meters around the sensor", 
#                                      "Length of paths in meters around the sensor", 
#                                      "Length of motorway links in meters around the sensor", 
#                                      "Length of other types of roads in meters around the sensor", 
#                                      "Number of trees around the sensor", 
#                                      "Mean speed of vehicles in mph", 
#                                      "Median speed of vehicles in mph", 
#                                      "Mean congestion ratio", 
#                                      "Median congestion ratio", 
#                                      "Weather station identifier", 
#                                      "Distance to the weather station in meters", 
#                                      "Elevation of the weather station in meters", 
#                                      "X-coordinate of the weather station", 
#                                      "Y-coordinate of the weather station", 
#                                      "Z-coordinate of the weather station", 
#                                      "Temperature in Fahrenheit", 
#                                      "Relative humidity in percentage", 
#                                      "Wind direction in degrees", 
#                                      "Wind speed in mph"))
# 
# # Print data dictionary
# print_data_dict(dataset, data_title="Final Dataset", descriptions=descriptions, show_na = FALSE)

library(skimr)
s <- skim(dataset, .data_name = "Final Dataset")
# 
# skim(dataset) %>%
#   dplyr::select(skim_type, skim_variable, n_missing)
# 
s
```

|                                                  |               |
|:-------------------------------------------------|:--------------|
| Name                                             | Final Dataset |
| Number of rows                                   | 204717        |
| Number of columns                                | 46            |
| Key                                              | NULL          |
| \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_   |               |
| Column type frequency:                           |               |
| numeric                                          | 45            |
| POSIXct                                          | 1             |
| \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ |               |
| Group variables                                  | None          |

Data summary

**Variable type: numeric**

| skim_variable     | n_missing | complete_rate |      mean |       sd |        p0 |       p25 |       p50 |       p75 |      p100 | hist  |
|:------------------|----------:|--------------:|----------:|---------:|----------:|----------:|----------:|----------:|----------:|:------|
| pm2.5_atm         |         0 |             1 |      8.56 |    14.65 |      0.00 |      2.09 |      5.16 |      9.80 |    775.81 | ▇▁▁▁▁ |
| pm2.5_atm_a       |         0 |             1 |      8.60 |    14.64 |      0.00 |      2.08 |      5.24 |      9.85 |    772.85 | ▇▁▁▁▁ |
| pm2.5_atm_b       |         0 |             1 |      8.53 |    14.77 |      0.00 |      1.95 |      5.09 |      9.81 |    778.78 | ▇▁▁▁▁ |
| sensor_index      |         0 |             1 |  19192.21 |  8744.02 |   2031.00 |  17939.00 |  19727.00 |  23083.00 |  44089.00 | ▂▂▇▁▁ |
| dow               |         0 |             1 |      3.99 |     2.00 |      1.00 |      2.00 |      4.00 |      6.00 |      7.00 | ▇▅▃▃▇ |
| hour              |         0 |             1 |     11.48 |     6.93 |      0.00 |      5.00 |     11.00 |     18.00 |     23.00 | ▇▇▆▇▇ |
| day               |         0 |             1 |     15.97 |     8.79 |      1.00 |      8.00 |     16.00 |     24.00 |     31.00 | ▇▇▇▇▇ |
| month             |         0 |             1 |      7.41 |     3.43 |      1.00 |      5.00 |      8.00 |     11.00 |     12.00 | ▅▃▃▅▇ |
| year              |         0 |             1 |   2018.87 |     0.33 |   2017.00 |   2019.00 |   2019.00 |   2019.00 |   2019.00 | ▁▁▁▁▇ |
| wknd              |         0 |             1 |      0.28 |     0.45 |      0.00 |      0.00 |      0.00 |      1.00 |      1.00 | ▇▁▁▁▃ |
| holiday           |         0 |             1 |      0.02 |     0.15 |      0.00 |      0.00 |      0.00 |      0.00 |      1.00 | ▇▁▁▁▁ |
| building_area     |         0 |             1 | 224489.37 | 57328.85 | 108505.98 | 179825.58 | 207181.01 | 235771.51 | 359600.77 | ▁▇▅▁▂ |
| b_yes             |         0 |             1 |   1234.61 |   381.24 |    486.00 |    938.00 |   1359.00 |   1543.00 |   2112.00 | ▅▃▇▇▁ |
| b_apartments      |         0 |             1 |     43.93 |    62.92 |      0.00 |      1.00 |     13.00 |     57.00 |    324.00 | ▇▁▁▁▁ |
| b_house           |         0 |             1 |     39.70 |    85.37 |      0.00 |      0.00 |      3.00 |     44.00 |    395.00 | ▇▁▁▁▁ |
| b_NA              |         0 |             1 |     11.36 |    15.67 |      0.00 |      2.00 |      7.00 |     11.00 |     78.00 | ▇▂▁▁▁ |
| b_residential     |         0 |             1 |      5.96 |    16.12 |      0.00 |      0.00 |      1.00 |      3.00 |    119.00 | ▇▁▁▁▁ |
| b_terrace         |         0 |             1 |      0.68 |     2.48 |      0.00 |      0.00 |      0.00 |      0.00 |    109.00 | ▇▁▁▁▁ |
| b_other           |         0 |             1 |     16.19 |    11.38 |      0.00 |      6.00 |     15.00 |     23.00 |     46.00 | ▇▅▆▂▂ |
| road_length       |         0 |             1 |  23692.54 |  5625.06 |   9577.75 |  22259.28 |  24057.43 |  27139.96 |  37168.87 | ▃▁▇▆▁ |
| r_footway         |         0 |             1 |    158.19 |   115.96 |      9.00 |     73.00 |    149.00 |    182.00 |    536.00 | ▇▇▃▁▁ |
| r_residential     |         0 |             1 |     59.27 |    17.17 |     23.00 |     43.00 |     57.00 |     76.00 |     85.00 | ▂▆▃▃▇ |
| r_service         |         0 |             1 |     50.21 |    51.88 |      3.00 |     17.00 |     31.00 |     62.00 |    190.00 | ▇▂▁▁▁ |
| r_secondary       |         0 |             1 |     22.77 |    28.37 |      0.00 |      6.00 |     11.00 |     22.00 |    103.00 | ▇▂▁▁▂ |
| r_primary         |         0 |             1 |     17.12 |    12.94 |      0.00 |      7.00 |     16.00 |     31.00 |     43.00 | ▇▇▃▆▂ |
| r_tertiary        |         0 |             1 |     13.94 |    12.11 |      0.00 |      2.00 |     10.00 |     26.00 |     40.00 | ▇▃▂▂▂ |
| r_steps           |         0 |             1 |      8.85 |     7.25 |      0.00 |      2.00 |      8.00 |     14.00 |     50.00 | ▇▃▁▁▁ |
| r_path            |         0 |             1 |      2.49 |     4.71 |      0.00 |      0.00 |      0.00 |      2.00 |     21.00 | ▇▁▁▁▁ |
| r_motorway_link   |         0 |             1 |      3.11 |     5.04 |      0.00 |      0.00 |      0.00 |      5.00 |     17.00 | ▇▂▂▁▁ |
| r_other           |         0 |             1 |     13.04 |    17.40 |      0.00 |      4.00 |      6.00 |     12.00 |     68.00 | ▇▁▁▁▁ |
| num_trees         |         0 |             1 |     13.12 |    27.67 |      0.00 |      0.00 |      2.00 |     21.00 |    138.00 | ▇▁▁▁▁ |
| mean_speed        |         0 |             1 |     23.26 |     7.39 |      6.07 |     18.47 |     21.69 |     25.80 |     68.53 | ▃▇▁▁▁ |
| median_speed      |         0 |             1 |     22.87 |     7.76 |      6.07 |     18.46 |     21.39 |     24.83 |     68.55 | ▃▇▁▁▁ |
| mean_congestion   |         0 |             1 |      0.79 |     0.08 |      0.25 |      0.73 |      0.79 |      0.85 |      1.37 | ▁▂▇▁▁ |
| median_congestion |         0 |             1 |      0.83 |     0.08 |      0.25 |      0.77 |      0.83 |      0.89 |      1.37 | ▁▁▇▁▁ |
| weatherstation    |         0 |             1 |      1.99 |     0.12 |      1.00 |      2.00 |      2.00 |      2.00 |      2.00 | ▁▁▁▁▇ |
| station_distance  |         0 |             1 |  15497.79 |  2229.51 |  11949.99 |  13453.66 |  14670.40 |  17418.57 |  21350.90 | ▇▇▅▅▁ |
| station_elevation |         0 |             1 |      4.97 |     0.23 |      3.00 |      5.00 |      5.00 |      5.00 |      5.00 | ▁▁▁▁▇ |
| x                 |         0 |             1 |     -0.42 |     0.00 |     -0.42 |     -0.42 |     -0.42 |     -0.42 |     -0.42 | ▂▂▇▅▃ |
| y                 |         0 |             1 |     -0.67 |     0.00 |     -0.67 |     -0.67 |     -0.67 |     -0.67 |     -0.67 | ▃▇▃▁▂ |
| z                 |         0 |             1 |      0.61 |     0.00 |      0.61 |      0.61 |      0.61 |      0.61 |      0.61 | ▁▇▆▇▁ |
| temp_fahrenheit   |         0 |             1 |     58.76 |     7.78 |     35.00 |     54.00 |     58.00 |     63.00 |     97.00 | ▁▇▅▁▁ |
| rel_humidity      |         0 |             1 |     69.76 |    15.02 |      9.22 |     61.69 |     72.02 |     80.54 |    100.00 | ▁▁▃▇▃ |
| wind_direction    |         0 |             1 |    204.92 |    94.90 |      0.00 |    128.00 |    253.85 |    281.54 |    360.00 | ▃▃▂▇▃ |
| wind_speed        |         0 |             1 |      8.70 |     5.76 |      0.00 |      4.08 |      8.00 |     12.67 |     33.00 | ▇▆▃▁▁ |

**Variable type: POSIXct**

| skim_variable | n_missing | complete_rate | min        | max                 | median              | n_unique |
|:--------------|----------:|--------------:|:-----------|:--------------------|:--------------------|---------:|
| time_stamp    |         0 |             1 | 2018-01-01 | 2019-12-31 22:00:00 | 2019-07-10 21:00:00 |    17450 |

# Remove any unnecessary features

``` r
dataset <- dataset %>% select(-pm1.0_atm,-pm2.5_atm_a,-pm2.5_atm_b,-sensor_id,-TemperatureCelsius,-time_stamp)
glimpse(dataset)
```

# Split Train and Test data

``` r
suppressPackageStartupMessages({
  library(caTools)
})
set.seed(42)

# Define the time point at which to split the data (e.g., 70% for training)
split_time <- quantile(dataset$local_timestamp, 0.7)

# Split the data into training and testing sets based on the split_time
train_data <- subset(dataset, local_timestamp <= split_time)
test_data <- subset(dataset, local_timestamp > split_time)

train_data <- train_data %>% select(-local_timestamp)
test_data <- test_data %>% select(-local_timestamp)

# split <- sample.split(dataset$pm2.5_atm, SplitRatio = 0.7)
# train_data <- subset(dataset, split == TRUE)
# test_data  <- subset(dataset, split == FALSE)
```

# Random Forest Model

``` r
# Train random forest model
suppressPackageStartupMessages({
  library(randomForest)
})
set.seed(42)
rf_model <- randomForest(pm2.5_atm ~ ., data = train_data, ntree = 500)

# Make random forest predictions
predictions_rf <- predict(rf_model, test_data)

# Mean Absolute Error

MAE <- mean(abs(predictions_rf - test_data$pm2.5_atm))

# Compute R squared

R2 <- 1 - sum((test_data$pm2.5_atm - predictions_rf)^2) / sum((test_data$pm2.5_atm - mean(test_data$pm2.5_atm))^2)

# Print R squared

cat("R squared:", R2)

# Visualize predictions

suppressPackageStartupMessages({
  library(ggplot2)
})

# plot(predictions_rf,test_data$pm2.5_atm)

ggplot(data = test_data, aes(x = pm2.5_atm, y = predictions_rf)) +
  geom_point() +
  geom_abline(intercept = 0, slope = 1, color = "red") +  # Add a diagonal line for reference
  labs(x = "Actual PM2.5", y = "Predicted PM2.5") +
  ggtitle("Scatter Plot of Predicted vs. Actual PM2.5") +
  theme_minimal()
```

# Train XGBoost model

``` r
suppressPackageStartupMessages({
  library(xgboost)
})
set.seed(42)
target_variable <- "pm2.5_atm"
predictor_variables <- setdiff(names(train_data), target_variable)

train_matrix <- xgb.DMatrix(data = as.matrix(train_data[, predictor_variables]), label = train_data[, target_variable])
test_matrix <- xgb.DMatrix(data = as.matrix(test_data[, predictor_variables]))

# Define XGBoost parameters
xgb_params <- list(
  objective = "reg:squarederror",  # For regression tasks
  eval_metric = "rmse",            # Root Mean Squared Error as the evaluation metric
  eta = 0.1,                       # Learning rate (adjust as needed)
  max_depth = 6,                   # Maximum depth of trees (adjust as needed)
  nrounds = 500,                   # Number of boosting rounds (adjust as needed)
  verbosity = 0                    # Set to 0 to suppress output
)

# Train the XGBoost model
xgb_model <- xgboost(data = train_matrix, params = xgb_params, nrounds = xgb_params$nrounds)

predictions_xgb <- predict(xgb_model, newdata = test_matrix)

# Calculate MAE
MAE <- mean(abs(predictions_xgb - test_data$pm2.5_atm))

# Calculate RMSE
RMSE <- sqrt(mean((predictions_xgb - test_data$pm2.5_atm)^2))

# Calculate R-squared (R²)
SSE <- sum((predictions_xgb - test_data$pm2.5_atm)^2)
SST <- sum((test_data$pm2.5_atm - mean(test_data$pm2.5_atm))^2)
R2 <- 1 - SSE / SST

cat("Mean Absolute Error (MAE):", MAE, "\n")
cat("Root Mean Squared Error (RMSE):", RMSE, "\n")
cat("R-squared (R²):", R2, "\n")

ggplot(data = test_data, aes(x = pm2.5_atm, y = predictions_xgb)) +
  geom_point() +
  geom_abline(intercept = 0, slope = 1, color = "red") +  # Add a diagonal line for reference
  labs(x = "Actual PM2.5", y = "Predicted PM2.5") +
  ggtitle("Scatter Plot of Predicted vs. Actual PM2.5") +
  theme_minimal()
```

# XGBoost Feature importance

``` r
importance_scores <- xgb.importance(model = xgb_model)
xgb.plot.importance(importance_matrix = importance_scores)
```

# Investigate PM2.5 readings

``` r
hist_data <- hist(dataset$pm2.5_atm, breaks = 50, xlab = "PM2.5 Concentration", xaxt = 'n')
axis(side = 1, at = hist_data$mids, labels = hist_data$mids)

hist_table <- data.frame(
  Bin_Start = hist_data$breaks[-length(hist_data$breaks)],
  Bin_End = hist_data$breaks[-1],
  Frequency = hist_data$counts
)

# Print the histogram data as a table
print(hist_table)
```
