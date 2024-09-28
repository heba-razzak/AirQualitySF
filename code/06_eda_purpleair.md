E PurpleAir
================

# Clean PurpleAir data points

Load required libraries

``` r
library(dplyr)         # For data manipulation
library(data.table)    # Working with large files
library(ggplot2)       # Plots
library(plotly)        # Interactive plots
library(lubridate)     # Dates
library(sf)            # Shapefiles
library(leaflet)       # Interactive maps
library(kableExtra)    # Printing formatted tables
library(zoo)           # for rolling calculations
library(purpleAirAPI)  # Download PurpleAir Data
library(tidyr)         # Reshape data
library(DataOverviewR) # Data dictionary and summary
library(reshape2)      # melt correlations
library(tidyverse)
library(timeDate)      # holidays
```

Read files

``` r
# Read files
epa_data <- read.csv(file.path("data", "raw", "EPA_airquality.csv"))
purpleair_data <- fread(file.path("data", "raw", "purpleair_2018-01-01_2019-12-31.csv"))
purpleair_df <- data.frame(purpleair_data)

# we'll use PM2.5 ALT, drop other pm2.5 columns
purpleair_df <- purpleair_df %>% 
  select(-pm2.5_atm, -pm2.5_atm_a, -pm2.5_atm_b,
         -pm2.5_cf_1, -pm2.5_cf_1_a, -pm2.5_cf_1_b)

# Get total number of rows for full dataset
total_rows <- nrow(purpleair_df)
```

| timestamp        | id          | state_code | county_code | site_number | poc | pm25 | latitude | longitude |
|:-----------------|:------------|-----------:|------------:|------------:|----:|-----:|---------:|----------:|
| 2018-01-01 00:00 | 06_001_0007 |          6 |           1 |           7 |   3 |   62 | 37.68753 | -121.7842 |
| 2018-01-01 01:00 | 06_001_0007 |          6 |           1 |           7 |   3 |   57 | 37.68753 | -121.7842 |
| 2018-01-01 02:00 | 06_001_0007 |          6 |           1 |           7 |   3 |   62 | 37.68753 | -121.7842 |

## **U.S. Environmental Protection Agency**

`461,708` rows

`15,512` rows with missing values

|  Variable   |  Mean   |   Min   |   P25   | Median  |   P75    |   Max    | NA_Count | NA_Percentage |
|:-----------:|:-------:|:-------:|:-------:|:-------:|:--------:|:--------:|:--------:|:-------------:|
| state_code  |  6.00   |  6.00   |  6.00   |  6.00   |   6.00   |   6.00   |    0     |               |
| county_code |  55.41  |  1.00   |  13.00  |  67.00  |  85.00   |  97.00   |    0     |               |
| site_number | 460.78  |  1.00   |  4.00   |  9.00   | 1,001.00 | 5,003.00 |    0     |               |
|     poc     |  3.03   |  1.00   |  3.00   |  3.00   |   3.00   |   4.00   |    0     |               |
|    pm25     |  9.52   | -10.00  |  4.00   |  7.00   |  11.00   |  494.00  |  15,512  |      3%       |
|  latitude   |  37.87  |  36.98  |  37.69  |  37.86  |  38.10   |  38.94   |    0     |               |
|  longitude  | -121.92 | -122.82 | -122.28 | -122.03 | -121.57  | -121.10  |    0     |               |

numeric

| Variable | N_Unique | Min_Char | Max_Char |                         Top_Counts                         | NA_Count | NA_Percentage |
|:--------:|:--------:|:--------:|:--------:|:----------------------------------------------------------:|:--------:|:-------------:|
|    id    |    25    |    11    |    11    | 06_077_1002: 35040, 06_095_0004: 34826, 06_067_0012: 27696 |    0     |               |

character

| Variable  |    Min     |    Max     |   Median   | N_Unique | NA_Count | NA_Percentage |
|:---------:|:----------:|:----------:|:----------:|:--------:|:--------:|:-------------:|
| timestamp | 2018-01-01 | 2019-12-31 | 2018-12-28 |   730    |    0     |               |

date

## Comparing PurpleAir air quality measurements with EPA

### EPA: U.S. Environmental Protection Agency

``` r
quants_vals <- c(0.75, 0.95, 0.99, 0.999, 1)
quants <- c("75%","95%","99%","99.9%", "max")
summary_statistics <- purpleair_df %>%
  reframe(
    across(c(pm2.5_alt, pm2.5_alt_a, pm2.5_alt_b),
           ~tibble(val = round(quantile(.x, quants_vals, na.rm = TRUE),0)),
           .unpack = TRUE)) %>%
  mutate(`Quantiles` = quants,
         epa = quantile(epa_data$pm25, quants_vals, na.rm = TRUE)) %>%
  rename(`EPA PM2.5` = epa,
         `PurpleAir ALT` = pm2.5_alt_val,
         `Channel A ALT` = pm2.5_alt_a_val,
         `Channel B ALT` = pm2.5_alt_b_val
  ) %>%
  select(`Quantiles`, `EPA PM2.5`, everything())

summary_statistics_long <- summary_statistics |> 
  pivot_longer(`EPA PM2.5`:`Channel B ALT`) |> 
  pivot_wider(names_from = Quantiles, values_from = value)

knitr::kable(summary_statistics_long,
             row.names = FALSE,
             format = "markdown")
```

| name          | 75% | 95% | 99% | 99.9% |  max |
|:--------------|----:|----:|----:|------:|-----:|
| EPA PM2.5     |  11 |  23 |  69 |   170 |  494 |
| PurpleAir ALT |   5 |  16 |  41 |   145 |  958 |
| Channel A ALT |   5 |  16 |  42 |   146 | 1052 |
| Channel B ALT |   5 |  17 |  46 |   152 | 1001 |

### Box Plots

``` r
img_path <- file.path("../docs", "plots", "boxplots.png")

if (!file.exists(img_path)) {
  # Combine relevant columns into a single data frame
  combined_data <- data.frame(
    ALT = purpleair_df$pm2.5_alt,
    ALT_A = purpleair_df$pm2.5_alt_a,
    ALT_B = purpleair_df$pm2.5_alt_b
  )
  
  # Reshape the data to long format for plotting
  long_data <- combined_data %>%
    pivot_longer(cols = everything(),  # All columns
                 names_to = "Measurement", 
                 values_to = "Value")
  
  # Add EPA data
  epa <- data.frame(Measurement = "EPA", Value = epa_data$pm25)
  long_data <- rbind(long_data, epa)
  long_data <- long_data %>% na.omit()
  
  # Box plots
  p <- ggplot(long_data, aes(x = Measurement, y = Value)) +
    geom_boxplot(fill = "lightblue") +
    # ylim(0, 50) +
    coord_cartesian(ylim = c(0, 30)) +
    labs(title = "Boxplot Comparison: PurpleAir and EPA PM2.5 Data",
         subtitle = "y-axis limit set to 30; more data points beyond the limit",
         x = "",
         y = "PM2.5 Value (µg/m³)") +
    theme_minimal()
  ggsave(filename = img_path, plot = p, width = 6, height = 4)
}
knitr::include_graphics(img_path)
```

<img src="../docs/plots/boxplots.png" width="1800" />

## Plot Sensors by Month

``` r
img_path <- file.path("../docs", "plots", "sensors-by-month.png")

if (!file.exists(img_path)) {
  # Add column for month
  purpleair_df$month <- format(as.Date(purpleair_df$time_stamp), "%Y-%m")
  
  # Sensors for each month
  monthly_sensors <- purpleair_df %>% select(month, sensor_index) %>% distinct()
  
  sensor_counts <- monthly_sensors %>%
    group_by(month) %>%
    summarise(sensor_count = n_distinct(sensor_index))
  
  p <- ggplot(sensor_counts, aes(x = month, y = sensor_count)) +
    geom_bar(stat = "identity", fill = "lavender", color = "black") +
    labs(title = "Active PurpleAir Sensors By Month",
         x = "Month",
         y = "Number of Sensors") +
    scale_y_continuous(breaks = seq(0, max(sensor_counts$sensor_count) + 100, by = 100)) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  ggsave(filename = img_path, plot = p, width = 6, height = 4)
  
}
knitr::include_graphics(img_path)
```

<img src="../docs/plots/sensors-by-month.png" width="1800" />

# create temporal features

``` r
# Get holidays for 2018 and 2019
holidays <- as.Date(c(holidayNYSE(2019), holidayNYSE(2018)))

purpleair_df <- purpleair_df %>%
  mutate(
    time_stamp = lubridate::as_datetime(time_stamp),
    local_timestamp = with_tz(time_stamp, tzone = "America/Los_Angeles"),
    local_date = as.Date(local_timestamp, tz="America/Los_Angeles"),
    dow = lubridate::wday(local_timestamp),
    hour = lubridate::hour(local_timestamp),
    day = lubridate::day(local_timestamp),
    month = lubridate::month(local_timestamp),
    year = lubridate::year(local_timestamp),
    holiday = ifelse(local_date %in% holidays, 1, 0)
  ) %>% select(-local_timestamp, -local_date)
```

Histograms for numerical columns

``` r
cols <- c("pm2.5_alt", "pm2.5_alt_a", "pm2.5_alt_b", "rssi", "uptime", 
          "memory", "humidity", "temperature", "pressure", "analog_input")

# Loop through the columns and plot histograms
for (col in cols) {
  x <- purpleair_df[[col]]
  
  # If max is much larger than the 99th percentile, filter the data for plotting
  p99 <- quantile(x, 0.99, na.rm = TRUE)
  if (max(x, na.rm = TRUE) > 2 * p99) {
    x <- x[x >= quantile(x, 0.01, na.rm = TRUE) & x <= p99]
  }
  hist(x, main = paste("Histogram of", col))
}
```

![](../docs/plots/hist-1.png)<!-- -->![](../docs/plots/hist-2.png)<!-- -->![](../docs/plots/hist-3.png)<!-- -->![](../docs/plots/hist-4.png)<!-- -->![](../docs/plots/hist-5.png)<!-- -->![](../docs/plots/hist-6.png)<!-- -->![](../docs/plots/hist-7.png)<!-- -->![](../docs/plots/hist-8.png)<!-- -->![](../docs/plots/hist-9.png)<!-- -->![](../docs/plots/hist-10.png)<!-- -->

Bar Plots for categorical columns

``` r
cols <- c("dow", "hour", "day", "month", "holiday", "year", "location_type")
for (col in cols) {
  # Plot the histogram using barplot for categorical data
  barplot(table(purpleair_df[[col]]), main = paste("Histogram of", col), ylab = "Frequency")
}
```

![](../docs/plots/bar-plots-1.png)<!-- -->![](../docs/plots/bar-plots-2.png)<!-- -->![](../docs/plots/bar-plots-3.png)<!-- -->![](../docs/plots/bar-plots-4.png)<!-- -->![](../docs/plots/bar-plots-5.png)<!-- -->![](../docs/plots/bar-plots-6.png)<!-- -->![](../docs/plots/bar-plots-7.png)<!-- -->

## ALT: Channel A vs B limited to 1000 PM2.5

<img src="../docs/plots/purpleair_alt_avsb.png" width="1800" />

## Look at associations between variables

``` r
# Correlation heatmap
img_path <- file.path("../docs", "plots", "purpleair-cor.png")

if (!file.exists(img_path)) {
  cor_vars <- purpleair_df %>% 
    select_if(is.numeric) %>% select(pm2.5_alt, everything(), -pm2.5_alt_a, -pm2.5_alt_b)
  
  correlation_matrix <- cor(cor_vars, use = "complete.obs")
  
  melted_correlation <- melt(correlation_matrix)
  
  p <- ggplot(data = melted_correlation, aes(Var1, Var2, fill = value)) + 
    geom_tile() + 
    scale_fill_gradient2(low = "red", high = "green", mid = "white",
                         midpoint = 0, limit = c(-1, 1), name = "Correlation") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust = 1))
  ggsave(filename = img_path, plot = p, width = 6, height = 4)
}

knitr::include_graphics(img_path)
```

<img src="../docs/plots/purpleair-cor.png" width="1800" />

``` r
img_path <- file.path("../docs", "plots", "purpleair-scatter-pm25-humidity.png")

if (!file.exists(img_path)) {
  x <- purpleair_df$pm2.5_alt
  y <- purpleair_df$humidity
  
  colors <- ifelse(purpleair_df$location_type == 1, 
                   rgb(173, 216, 230, maxColorValue = 255, alpha = 127),
                   rgb(144, 238, 144, maxColorValue = 255, alpha = 127))
  
  png(img_path, width = 800, height = 600)
  
  plot(purpleair_df$humidity, purpleair_df$pm2.5_alt,
       col = colors,
       pch = 19,
       xlab = "Humidity",
       ylab = "PM2.5 (alt)", 
       main = "Humidity vs PM2.5 by Location Type")
  
  legend("topright", legend = c("Indoor", "Outdoor"), fill = c("lightblue", "lightgreen"))
  
  dev.off()
}
```

    ## quartz_off_screen 
    ##                 2

``` r
knitr::include_graphics(img_path)
```

<img src="../docs/plots/purpleair-scatter-pm25-humidity.png" width="800" />

########################################################################################### 

########################################################################################### 

########################################################################################### 

########################################################################################### 

<!-- purpleair_df$outlier_flag <- ifelse(abs(pm2.5_alt_a - pm2.5_alt_b) / pm2.5_alt > threshold | is.na(pm2.5_alt_a) | is.na(pm2.5_alt_b), 1, 0) -->
<!-- ## Flag outliers with different thresholds of relative change between channel A and B -->
<!-- ### Relative Change -->
<!-- \[ -->
<!-- \text{Relative Change} = \frac{\lvert \text{Channel A}_{\text{PM2.5}} - \text{Channel B}_{\text{PM2.5}} \rvert}{\text{avg}(\text{Channel A}_{\text{PM2.5}}, \text{Channel B}_{\text{PM2.5}})} -->
<!-- \] -->
<!-- ### Minimum *Absolute Difference* between A and B must be greater than 2 -->
<!-- ```{r, flag-outliers-thres} -->
<!-- # flag outliers using different thresholds and compare -->
<!-- # Initialize an empty data frame to store results -->
<!-- outlier_summary <- data.frame( -->
<!--   threshold = numeric(0), -->
<!--   num_outliers = numeric(0), -->
<!--   percentage = numeric(0) -->
<!-- ) -->
<!-- # Set thresholds for PM2.5 relative change  -->
<!-- # Relative change - Arithmetic mean change (https://en.wikipedia.org/wiki/Relative_change#Indicators_of_relative_change) -->
<!-- thresholds <- c(0.1, 0.15, 0.2, 0.25, 0.3, 0.4, 0.5, 0.6) -->
<!-- for (threshold in thresholds) { -->
<!--   outliers <- purpleair_df %>% -->
<!--     mutate(abs_diff = abs(pm2.5_atm_a - pm2.5_atm_b), -->
<!--            relativechange = round(abs_diff / pm2.5_atm, 2), -->
<!--            flag = ifelse(flag == "Normal" & relativechange > threshold & abs_diff > 2, -->
<!--                          "Outlier", flag)) -->
<!--   # Merge with original data and flag outliers -->
<!--   pa_outliers <- purpleair_df %>% select(-flag) %>% -->
<!--     left_join(outliers %>% select(time_stamp, sensor_index, flag, abs_diff, relativechange),  -->
<!--               by = c("time_stamp", "sensor_index")) %>% -->
<!--     select(time_stamp, pm2.5_atm_a, pm2.5_atm_b, abs_diff, relativechange, -->
<!--            flag, everything()) -->
<!--   num_outliers <- pa_outliers %>% filter(flag == "Outlier") %>% nrow() -->
<!--   percentage <- paste0(round(100 * num_outliers / total_rows, 2),"%") -->
<!--   # Add the results to the data frame -->
<!--   outlier_summary <- rbind(outlier_summary,  -->
<!--                            data.frame(threshold = threshold,  -->
<!--                                       num_outliers = format(num_outliers, big.mark = ","),  -->
<!--                                       percentage = percentage)) -->
<!-- } -->
<!-- ``` -->
<!-- ```{r, view-outlier-thres, echo = FALSE} -->
<!-- knitr::kable(outlier_summary, -->
<!--              row.names = FALSE, -->
<!--              format = "markdown", -->
<!--              col.names = c("Threshold", "Number of Outliers", "Percentage")) %>% -->
<!--   kable_styling() %>% -->
<!--   row_spec(1, bold = TRUE, background = "#FFFF99") -->
<!-- ``` -->
<!-- ## Plot different thresholds to compare -->
<!-- ```{r, plot-outliers-thres, echo=FALSE, out.width="49%", out.height="20%", fig.show='hold', fig.align='center'} -->
<!-- if (FALSE) { -->
<!--   for (threshold in thresholds) { -->
<!--     outliers <- purpleair_df %>% -->
<!--       mutate(abs_diff = abs(pm2.5_atm_a - pm2.5_atm_b), -->
<!--              relativechange = round(abs_diff / pm2.5_atm, 2), -->
<!--              flag = ifelse(flag == "Normal" & relativechange > threshold & abs_diff > 2, -->
<!--                            "Outlier", flag)) -->
<!--     # Merge with original data and flag outliers -->
<!--     pa_outliers <- purpleair_df %>% select(-flag) %>% -->
<!--       left_join(outliers %>% select(time_stamp, sensor_index, flag, abs_diff, relativechange),  -->
<!--                 by = c("time_stamp", "sensor_index")) %>% -->
<!--       select(time_stamp, pm2.5_atm_a, pm2.5_atm_b, abs_diff, relativechange, -->
<!--              flag, everything()) -->
<!--     p <- ggplot(pa_outliers, aes(x = pm2.5_atm_a, y = pm2.5_atm_b, color = flag)) + -->
<!--       geom_point() + -->
<!--       scale_color_manual(values = c("Normal" = "black", "Outlier" = "grey", -->
<!--                                     "Missing" = "red", "PM2.5 > 500" = "orange"), -->
<!--                          name = "") +  -->
<!--       labs(x = "Channel A PM2.5", -->
<!--            y = "Channel B PM2.5", -->
<!--            color = "Flag", -->
<!--            title = paste0("Threshold = ", threshold), -->
<!--            subtitle = paste0("PM2.5 Channel A vs B\n", -->
<!--                              "Axes limits set to 1000; more data points beyond the limit")) + -->
<!--       theme_minimal() + -->
<!--       xlim(-1, 1000) + -->
<!--       ylim(-1, 1000) -->
<!--     ggsave(filename = paste0(preprocessing_directory, "/plots/plot_threshold_", threshold, ".png"), -->
<!--            plot = p, width = 6, height = 4) -->
<!--   } -->
<!-- } -->
<!-- # compare plots of different thresholds -->
<!-- img_paths <- c() -->
<!-- for (threshold in c(0.1, 0.15, 0.2, 0.25, 0.3, 0.4, 0.5, 0.6)) { -->
<!--   img_path <- paste0(preprocessing_directory, "/plots/plot_threshold_", threshold, ".png") -->
<!--   img_paths <- c(img_paths, img_path) -->
<!-- } -->
<!-- knitr::include_graphics(img_paths) -->
<!-- ``` -->
<!-- ## Using threshold of 0.1 relative change between channel A and B -->
<!-- ## And maximum value of PM2.5 500 for channel A and B -->
<!-- ```{r, flag-outliers} -->
<!-- # flag outliers using selected threshold -->
<!-- threshold = 0.1 -->
<!-- outliers <- purpleair_df %>% -->
<!--   mutate(abs_diff = abs(pm2.5_atm_a - pm2.5_atm_b), -->
<!--          relativechange = round(abs_diff / pm2.5_atm, 2), -->
<!--          flag = ifelse(flag == "Normal" & relativechange > threshold & abs_diff > 2, -->
<!--                        "Outlier", flag)) -->
<!-- # Merge with flagged and original data -->
<!-- pa_outliers <- purpleair_df %>% select(-flag) %>% -->
<!--   left_join(outliers %>% select(time_stamp, sensor_index, flag, abs_diff, relativechange),  -->
<!--             by = c("time_stamp", "sensor_index")) %>% -->
<!--   select(time_stamp, pm2.5_atm_a, pm2.5_atm_b, abs_diff, relativechange, flag, everything()) -->
<!-- outliers %>% select(pm2.5_atm, pm2.5_atm_a, pm2.5_atm_b, abs_diff, relativechange) %>% filter(relativechange < threshold) %>% arrange(desc(abs_diff)) -->
<!-- ``` -->
<!-- ```{r, include = FALSE} -->
<!-- # # For checking specific examples -->
<!-- # options(digits=2) -->
<!-- #  -->
<!-- # x <- pa_outliers %>%  filter(!is.na(pm2.5_atm_a), !is.na(pm2.5_atm_b)) %>% -->
<!-- #     select(time_stamp, pm2.5_atm_a, pm2.5_atm_b, abs_diff, relativechange, outlier, everything()) -->
<!-- # x %>% filter(outlier==0) %>% slice_sample(n=10) %>% arrange(abs_diff) -->
<!-- # x %>% filter(outlier==1) %>% slice_sample(n=20) %>% arrange(abs_diff) -->
<!-- # x %>% sample_n(size=20, fac=pm2.5_atm) %>% arrange(outlier, abs_diff) -->
<!-- # x %>% sample_n(size=20, fac=relativechange) %>% arrange(outlier, abs_diff) -->
<!-- # x %>% filter(outlier==0, pm2.5_atm>100, abs_diff>10) %>% slice_sample(n=20) %>% arrange(abs_diff) -->
<!-- # x %>% filter(outlier==0, pm2.5_atm<150) %>% arrange(desc(abs_diff)) -->
<!-- ``` -->
<!-- ## Filter out high PM2.5 values (>500), missing channel data, and identified outliers -->
<!-- ```{r, remove-outliers} -->
<!-- # Remove outliers and keep relevant columns -->
<!-- pa_filtered <- pa_outliers %>%  -->
<!--   filter(flag == "Normal") %>% -->
<!--   select(time_stamp, sensor_index, pm2.5_atm, pm2.5_atm_a, pm2.5_atm_b, -->
<!--          rssi, uptime, memory, humidity, temperature, pressure, analog_input) -->
<!-- ``` -->
<!-- ## Remove sensors with < 24 data points -->
<!-- ```{r, low-data-sensors} -->
<!-- low_data_sensors <- pa_filtered %>%  -->
<!--   group_by(sensor_index) %>% summarize(n = n()) %>% arrange(n) %>% filter(n < 24) -->
<!-- pa_filtered <- pa_filtered %>%  -->
<!--   filter(!(sensor_index %in% low_data_sensors$sensor_index)) -->
<!-- ``` -->
<!-- ```{r, channel-a-b-plot, eval = TRUE, warning=FALSE} -->
<!-- if (FALSE) { -->
<!--   p <- ggplot(pa_filtered, aes(x = pm2.5_atm_a, y = pm2.5_atm_b)) + -->
<!--     geom_point() + -->
<!--     labs(x = "Channel A PM2.5", -->
<!--          y = "Channel B PM2.5", -->
<!--          title = "PM2.5 Channel A vs B") + -->
<!--     theme_minimal() -->
<!--   ggsave(filename = paste0(preprocessing_directory, "/plots/pa_filtered.png"), -->
<!--          plot = p, width = 6, height = 4) -->
<!-- } -->
<!-- img_path <- paste0(preprocessing_directory, "/plots/pa_filtered.png") -->
<!-- knitr::include_graphics(img_path) -->
<!-- ``` -->
<!-- ## Remove 24 hour periods of zeros or missing data -->
<!-- ```{r, rolling-zeros-missing} -->
<!-- start_time <- min(pa_filtered$time_stamp, na.rm = TRUE) -->
<!-- end_time <- max(pa_filtered$time_stamp, na.rm = TRUE) -->
<!-- all_timestamps <- seq(from = start_time, to = end_time, by = "hour") -->
<!-- all_sensor_indices <- unique(pa_filtered$sensor_index) -->
<!-- complete_timestamps <- expand.grid(sensor_index = all_sensor_indices, -->
<!--                                    time_stamp = all_timestamps) -->
<!-- pa_complete <- complete_timestamps %>% -->
<!--   left_join(pa_filtered, by = c("sensor_index", "time_stamp")) %>% -->
<!--   mutate(pm2.5_atm = ifelse(is.na(pm2.5_atm), -1, pm2.5_atm)) -->
<!-- pa_complete <- pa_complete %>% -->
<!--   group_by(sensor_index) %>% -->
<!--   mutate( -->
<!--     is_zero_or_missing = ifelse(pm2.5_atm == 0 | pm2.5_atm == -1, 1, 0), -->
<!--     is_normal = ifelse(pm2.5_atm != 0 & pm2.5_atm != -1, 1, 0), -->
<!--     rolling_zeros_missing = rollapply(is_zero_or_missing, width = 24, FUN = sum, -->
<!--                                       align = "right", fill = NA), -->
<!--     rolling_normals = rollapply(is_normal, width = 24, FUN = sum, align = "right", fill = NA) -->
<!--   ) %>% -->
<!--   ungroup() -->
<!-- # threshold 0.8 means >=20 hours missing from a 24 hour time period -->
<!-- pa_complete <- pa_complete %>% -->
<!--   mutate( -->
<!--     proportion_zeros_missing = rolling_zeros_missing / 24, -->
<!--     flag_high_proportion = ifelse(proportion_zeros_missing >= 0.8, 1, 0) -->
<!--   )  -->
<!-- pa_complete <- pa_complete %>% filter(flag_high_proportion != 1) %>% -->
<!--   select(-is_zero_or_missing, -is_normal, -rolling_zeros_missing, -->
<!--          -rolling_normals, -proportion_zeros_missing, -flag_high_proportion) -->
<!-- ``` -->
<!-- ## Plot sensors with >20% zeros  -->
<!-- ```{r, perc-zeros} -->
<!-- # Percentage of zero readings for each sensor -->
<!-- sensor_zero_readings <- pa_complete %>% -->
<!--   group_by(sensor_index) %>% -->
<!--   summarize(pct_zeros = round(100 * sum(pm2.5_atm == 0) / n(), 2), -->
<!--             pct_missing = round(100 * sum(pm2.5_atm == -1) / n(), 2)) %>% -->
<!--   filter(pct_zeros > 20) -->
<!-- # Loop through each sensor and create plots -->
<!-- for (i in 1:nrow(sensor_zero_readings)) { -->
<!--   s <- sensor_zero_readings$sensor_index[[i]] -->
<!--   data_sensor <- pa_complete %>% filter(sensor_index == s) -->
<!--   n <- nrow(data_sensor) -->
<!--   pz <- round(sensor_zero_readings$pct_zeros[i], 0) -->
<!--   pm <- round(sensor_zero_readings$pct_missing[i], 0) -->
<!--   # Create a data frame with segment information -->
<!--   shifted_readings <- data.frame( -->
<!--     time_stamp = head(data_sensor$time_stamp, -1),  -->
<!--     time_stamp_shifted = tail(data_sensor$time_stamp, -1),  -->
<!--     pm2.5_atm = head(data_sensor$pm2.5_atm, -1),  -->
<!--     pm2.5_atm_shifted = tail(data_sensor$pm2.5_atm, -1) -->
<!--   ) -->
<!--   # Assign colors based on whether the pm2.5_atm value is zero or not -->
<!--   shifted_readings <- shifted_readings %>%  -->
<!--     mutate(flag = ifelse(pm2.5_atm == 0, "Zero", ifelse(pm2.5_atm == -1, "Missing", "Normal"))) -->
<!--   # Plot the segments -->
<!--   p <- ggplot(data=shifted_readings, aes(x=time_stamp, xend = time_stamp_shifted, -->
<!--                                          y=pm2.5_atm, yend = pm2.5_atm_shifted,  -->
<!--                                          color=flag)) + -->
<!--     geom_segment() + -->
<!--     scale_color_manual(values = c("Normal" = "black", "Missing" = "yellow", -->
<!--                                   "Zero" = "red"), -->
<!--                        name = "") +  -->
<!--     labs(x = "Time", y = "PM2.5",  -->
<!--          title = paste0("Sensor ", s, "\n", -->
<!--                         pz, "% zeros", "\n",  -->
<!--                         pm, "% missing", -->
<!--                         "\nNumber of readings: ", n)) + -->
<!--     theme_minimal() -->
<!--   ggsave(filename = file.path(preprocessing_directory, "plots", paste0( -->
<!--     "pct", pz, "_sensor", s, ".png")), -->
<!--     plot = p, width = 8, height = 6) -->
<!-- } -->
<!-- ``` -->
<!-- ## View plots of sensors with >20% zeros -->
<!-- ```{r, zero-plots, echo=FALSE, out.width="49%", out.height="20%", fig.show='hold', fig.align='center'} -->
<!-- # compare plots of different thresholds -->
<!-- img_paths <- c() -->
<!-- for (i in 1:nrow(sensor_zero_readings)) { -->
<!--   s <- sensor_zero_readings$sensor_index[[i]] -->
<!--   pz <- round(sensor_zero_readings$pct_zeros[i], 0) -->
<!--   img_path <- file.path(preprocessing_directory, "plots", -->
<!--                         paste0("pct", pz, "_sensor", s, ".png")) -->
<!--   img_paths <- c(img_paths, img_path) -->
<!-- } -->
<!-- knitr::include_graphics(img_paths) -->
<!-- ``` -->
<!-- ## Remove sensor 20349 based on plots -->
<!-- ```{r, remove-sensor} -->
<!-- pa_complete <- pa_complete %>% -->
<!--   filter(sensor_index != 20349) %>% filter(pm2.5_atm != -1) -->
<!-- ``` -->
<!-- ## Save Filtered Data to CSV -->
<!-- ```{r, save-filtered-data, eval = TRUE} -->
<!-- # Save filtered data -->
<!-- write.csv(pa_complete, file = file.path(preprocessing_directory, "purpleair_filtered_2018-2019.csv"), row.names = FALSE) -->
<!-- ``` -->