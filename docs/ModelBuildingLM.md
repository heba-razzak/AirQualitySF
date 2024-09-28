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
library(randomForest) # random forest model
library(xgboost)
library(mlr)
library(caTools) # Split train and test groups
library(car)
# devtools::install_github("heba-razzak/createDataDict")
# library(createDataDict)
```

``` r
dataset <- fread(paste0(preprocessing_directory, "/final_dataset.csv"))
dataset <- dataset %>% rename(target = pm2.5_atm)
```

## Linear Regression

``` r
# Linear Regression
dataset_lr <- dataset %>%
  select(-starts_with("mean_speed"),
         -starts_with("median_speed"),
         -starts_with("mean_congestion"),
         -starts_with("median_congestion"))

dataset_lr <- na.omit(dataset_lr)

dataset_lr <- dataset_lr %>% filter(target < 150)

# Determine the index for the 70% split
split_index <- floor(0.7 * nrow(arrange(dataset_lr, time_stamp)))

# Find the date at this index
split_time <- dataset_lr %>% arrange(time_stamp) %>%
  pull(time_stamp) %>% .[floor(0.7 * nrow(dataset_lr))]

# Split the data into training and testing sets based on the split_time
train <- subset(dataset_lr, time_stamp <= split_time) %>% dplyr::select(-time_stamp, -sensor_index)
test <- subset(dataset_lr, time_stamp > split_time)

# Save timestamp and sensor index for identifying problem areas
test_time_sensor <- test %>% select(time_stamp, sensor_index)

# Remove timestamp and sensor index from test set for model training
test <- test %>% dplyr::select(-time_stamp, -sensor_index)

# True labels for test data
test_label <- test$target

# Drop target column from test
test <- test %>% dplyr::select(-target)

# Linear Regression Model
linear_model <- lm(target ~ ., data = train)

# Multicollinearity
vif_values <- vif(linear_model)
print("Variance Inflation Factors")
```

    ## [1] "Variance Inflation Factors"

``` r
print(vif_values)
```

    ##       pm2.5_atm_a       pm2.5_atm_b              rssi            uptime 
    ##        176.960694        177.187675          1.056332          1.624674 
    ##            memory          humidity       temperature          pressure 
    ##          2.817048          2.137094          1.005555          1.000154 
    ##      analog_input               dow              hour               day 
    ##          1.034634          2.657869          1.192462          1.023854 
    ##             month              year              wknd           holiday 
    ##          3.197207          2.991325          2.660532          1.020319 
    ##      length_major      length_minor      date_created         last_seen 
    ##          1.593070          3.329344          1.194953          1.014974 
    ##    weatherstation  station_distance station_elevation                 x 
    ##          2.061507          1.349798          1.665679       5444.650600 
    ##                 y                 z   temp_fahrenheit      rel_humidity 
    ##      14349.612311      20054.944601          3.328210          3.238128 
    ##    wind_direction        wind_speed        area_house        area_other 
    ##          1.750364          1.746513          1.350188          2.109524 
    ##    area_undefined    area_apartment         num_trees 
    ##          2.805706          1.162949          1.121452

``` r
cat("--------------------------------------------------------------")
```

    ## --------------------------------------------------------------

``` r
# Summarize the model
print("Model Summary")
```

    ## [1] "Model Summary"

``` r
summary(linear_model)
```

    ## 
    ## Call:
    ## lm(formula = target ~ ., data = train)
    ## 
    ## Residuals:
    ##              Min               1Q           Median               3Q 
    ## -0.0000000153152  0.0000000000000  0.0000000000000  0.0000000000000 
    ##              Max 
    ##  0.0000000008934 
    ## 
    ## Coefficients:
    ##                                        Estimate                    Std. Error
    ## (Intercept)       -0.00000000146673571213242753  0.00000000049191811953066288
    ## pm2.5_atm_a        0.49999999999899408242853838  0.00000000000000853801472992
    ## pm2.5_atm_b        0.50000000000001032507412901  0.00000000000000854848532900
    ## rssi               0.00000000000000037136949597  0.00000000000000036613917378
    ## uptime            -0.00000000000000000000353151  0.00000000000000000000981767
    ## memory             0.00000000000000000455958612  0.00000000000000000212911460
    ## humidity           0.00000000000000049923630572  0.00000000000000061854055447
    ## temperature        0.00000000000000000000001339  0.00000000000000000000037870
    ## pressure          -0.00000000000000000010229522  0.00000000000000000725801005
    ## analog_input      -0.00000000000017325051048719  0.00000000000037278310102403
    ## dow                0.00000000000000294620473039  0.00000000000000520297964549
    ## hour               0.00000000000000005010987004  0.00000000000000100648207815
    ## day                0.00000000000000142903489953  0.00000000000000073501451749
    ## month              0.00000000000001824920234970  0.00000000000000371135027700
    ## year               0.00000000000013324176480861  0.00000000000002955143997028
    ## wknd              -0.00000000000000625578114902  0.00000000000002306536722783
    ## holiday           -0.00000000000022919676545948  0.00000000000004018463760255
    ## length_major       0.00000000000000000188594580  0.00000000000000000188053609
    ## length_minor      -0.00000000000000000054221025  0.00000000000000000040907588
    ## date_created       0.00000000000000002182831586  0.00000000000000004444478734
    ## last_seen          0.00000000000006705567965933  0.00000000000002157663528857
    ## weatherstation    -0.00000000000000091821098053  0.00000000000000170341291300
    ## station_distance  -0.00000000000000000031247095  0.00000000000000000106844803
    ## station_elevation -0.00000000000000009772435725  0.00000000000000014852754491
    ## x                  0.00000000005708234801906363  0.00000000009335956074851323
    ## y                  0.00000000009014945000416014  0.00000000015047789350328018
    ## z                 -0.00000000008316057053393120  0.00000000013854101438662305
    ## temp_fahrenheit   -0.00000000000000131702936907  0.00000000000000103328590026
    ## rel_humidity      -0.00000000000000048822285960  0.00000000000000060030407345
    ## wind_direction    -0.00000000000000014446334235  0.00000000000000008295922772
    ## wind_speed         0.00000000000000265676756000  0.00000000000000180108704731
    ## area_house         0.00000000000000000006608312  0.00000000000000000009326361
    ## area_other         0.00000000000000000006584802  0.00000000000000000015656128
    ## area_undefined     0.00000000000000000002058272  0.00000000000000000004299460
    ## area_apartment    -0.00000000000000000014266278  0.00000000000000000033925824
    ## num_trees          0.00000000000000001356339305  0.00000000000000002549588630
    ##                              t value             Pr(>|t|)    
    ## (Intercept)                   -2.982              0.00287 ** 
    ## pm2.5_atm_a       58561623025386.375 < 0.0000000000000002 ***
    ## pm2.5_atm_b       58489893911803.344 < 0.0000000000000002 ***
    ## rssi                           1.014              0.31045    
    ## uptime                        -0.360              0.71906    
    ## memory                         2.142              0.03223 *  
    ## humidity                       0.807              0.41960    
    ## temperature                    0.035              0.97179    
    ## pressure                      -0.014              0.98875    
    ## analog_input                  -0.465              0.64211    
    ## dow                            0.566              0.57122    
    ## hour                           0.050              0.96029    
    ## day                            1.944              0.05187 .  
    ## month                          4.917         0.0000008783 ***
    ## year                           4.509         0.0000065196 ***
    ## wknd                          -0.271              0.78622    
    ## holiday                       -5.704         0.0000000117 ***
    ## length_major                   1.003              0.31592    
    ## length_minor                  -1.325              0.18502    
    ## date_created                   0.491              0.62333    
    ## last_seen                      3.108              0.00188 ** 
    ## weatherstation                -0.539              0.58986    
    ## station_distance              -0.292              0.76994    
    ## station_elevation             -0.658              0.51057    
    ## x                              0.611              0.54092    
    ## y                              0.599              0.54911    
    ## z                             -0.600              0.54833    
    ## temp_fahrenheit               -1.275              0.20245    
    ## rel_humidity                  -0.813              0.41605    
    ## wind_direction                -1.741              0.08162 .  
    ## wind_speed                     1.475              0.14019    
    ## area_house                     0.709              0.47860    
    ## area_other                     0.421              0.67405    
    ## area_undefined                 0.479              0.63213    
    ## area_apartment                -0.421              0.67411    
    ## num_trees                      0.532              0.59474    
    ## ---
    ## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
    ## 
    ## Residual standard error: 0.000000000009883 on 2409583 degrees of freedom
    ## Multiple R-squared:      1,  Adjusted R-squared:      1 
    ## F-statistic: 6.922e+28 on 35 and 2409583 DF,  p-value: < 0.00000000000000022

``` r
cat("--------------------------------------------------------------")
```

    ## --------------------------------------------------------------

``` r
# Make predictions
linear_predictions <- predict(linear_model, newdata = test)

# Calculate performance metrics
# Mean Absolute Error (MAE)
mae_linear <- mean(abs(linear_predictions - test_label))
cat("\nLinear Regression MAE:", mae_linear)
```

    ## 
    ## Linear Regression MAE: 0.000000000007188046

``` r
# Mean Absolute Percentage Error (MAPE)
# Replace zero values in test_label with a very small number
mape_test_label <- ifelse(test_label == 0, 0.00001, test_label)

# Calculate Mean Absolute Percentage Error (MAPE)
mape_linear <- mean(abs((linear_predictions - mape_test_label) / mape_test_label)) * 100
cat("\nLinear Regression MAPE:", mape_linear)
```

    ## 
    ## Linear Regression MAPE: 0.8197716

``` r
# R-squared (R²)
ss_res_linear <- sum((linear_predictions - test_label)^2)
ss_tot_linear <- sum((test_label - mean(test_label))^2)
r2_linear <- 1 - (ss_res_linear / ss_tot_linear)
cat("\nLinear Regression R²:", r2_linear)
```

    ## 
    ## Linear Regression R²: 1

``` r
# Adjusted R-squared
n_linear <- length(test_label)
p_linear <- ncol(test)
adj_r2_linear <- 1 - ((1 - r2_linear) * (n_linear - 1) / (n_linear - p_linear - 1))
cat("\nLinear Regression Adjusted R²:", adj_r2_linear)
```

    ## 
    ## Linear Regression Adjusted R²: 1

``` r
# Root Mean Squared Error (RMSE)
rmse_linear <- sqrt(mean((linear_predictions - test_label)^2))
cat("\nLinear Regression RMSE:", rmse_linear, "\n")
```

    ## 
    ## Linear Regression RMSE: 0.00000000001075849

``` r
# Create a dataframe with actual values, predicted values, absolute differences, and identification columns
results <- test %>%
  mutate(
    Actual = test_label,
    Predicted = linear_predictions,
    AbsDifference = abs(test_label - linear_predictions)
  ) %>%
  bind_cols(test_time_sensor) %>% 
  arrange(desc(AbsDifference))

# Plot to show which days have the most errors
error_by_day <- results %>%
  mutate(date = as.Date(time_stamp)) %>%
  group_by(date) %>%
  summarize(TotalAbsDifference = sum(AbsDifference),
            AvgAbsDifference = mean(AbsDifference),
            MaxAbsDifference = max(AbsDifference),
            AbsDifference90p = quantile(AbsDifference, 0.9)) %>%
  arrange(date)

# Plot average, maximum, and 90th percentile absolute differences
ggplot(error_by_day, aes(x = date)) +
  geom_line(aes(y = AvgAbsDifference, color = "Average Absolute Difference")) +
  geom_line(aes(y = MaxAbsDifference, color = "Maximum Absolute Difference")) +
  geom_line(aes(y = AbsDifference90p, color = "90th Percentile Absolute Difference")) +
  labs(
    title = "Absolute Differences Over Time",
    x = "Date",
    y = "Absolute Difference"
  ) +
  scale_color_manual(
    values = c("Average Absolute Difference" = "blue",
               "Maximum Absolute Difference" = "red",
               "90th Percentile Absolute Difference" = "green")
  ) +
  theme_minimal()
```

![](ModelBuildingLM_files/figure-gfm/unnamed-chunk-2-1.png)<!-- -->

``` r
# Display the sorted results
print(error_by_day)
```

    ## # A tibble: 102 × 5
    ##    date       TotalAbsDifference AvgAbsDifference MaxAbsDifference
    ##    <date>                  <dbl>            <dbl>            <dbl>
    ##  1 2019-09-20       0.0000000253         5.36e-12         6.84e-11
    ##  2 2019-09-21       0.0000000442         5.03e-12         1.22e-10
    ##  3 2019-09-22       0.0000000332         3.71e-12         8.26e-11
    ##  4 2019-09-23       0.0000000405         4.51e-12         1.08e-10
    ##  5 2019-09-24       0.0000000420         4.65e-12         6.50e-11
    ##  6 2019-09-25       0.0000000403         4.44e-12         1.09e-10
    ##  7 2019-09-26       0.0000000241         2.74e-12         3.88e-11
    ##  8 2019-09-27       0.0000000293         3.30e-12         4.72e-11
    ##  9 2019-09-28       0.0000000353         3.95e-12         1.22e-10
    ## 10 2019-09-29       0.0000000517         5.55e-12         1.02e-10
    ## # ℹ 92 more rows
    ## # ℹ 1 more variable: AbsDifference90p <dbl>

``` r
# Plot residuals
residuals <- test_label - linear_predictions
plot(residuals, main = "Residuals Plot", ylab = "Residuals", xlab = "Index", col = "blue", pch = 20)
abline(h = 0, col = "red")
```

![](ModelBuildingLM_files/figure-gfm/unnamed-chunk-2-2.png)<!-- -->

``` r
# Histogram of residuals
hist(residuals, breaks = 50, main = "Histogram of Residuals", xlab = "Residuals", col = "blue")
```

![](ModelBuildingLM_files/figure-gfm/unnamed-chunk-2-3.png)<!-- -->

``` r
# Plot predictions vs actual values
plot(test_label, linear_predictions, main = "Predictions vs Actual Values", xlab = "Actual Values", ylab = "Predicted Values", col = "blue", pch = 19)
abline(0, 1, col = "red")
```

![](ModelBuildingLM_files/figure-gfm/unnamed-chunk-2-4.png)<!-- -->
