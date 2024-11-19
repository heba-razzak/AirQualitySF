# Preprocessing PurpleAir

# Clean PurpleAir data points

## Load required libraries

```r
library(dplyr)      # For data manipulation
library(data.table) # Faster than dataframes (for big files)
library(ggplot2)    # Plots
library(plotly)     # Interactive plots
library(lubridate)  # Dates
library(sf)         # Shapefiles
library(leaflet)    # Interactive maps
library(kableExtra) # Printing formatted tables
library(zoo)        # for rolling calculations
library(PurpleAirAPI)
```

## Read files

```r
# Read files
purpleair_data <- fread(paste0(purpleair_directory, "/purpleair_2018-01-01_2019-12-31.csv"))
epa_data <- read.csv(paste0(preprocessing_directory, "/EPA_airquality.csv"))

# convert timestamp to datetime
purpleair_data <- purpleair_data %>%
  mutate(time_stamp = lubridate::as_datetime(time_stamp))

# Get total number of rows for full dataset
total_rows <- nrow(purpleair_data)
```

## Summary Statistics

```r
quants_vals <- c(0.75, 0.95, 0.99, 0.999)
quants <- c("75%","95%","99%","99.9%")
summary_statistics <- purpleair_data %>%
  reframe(
    across(c(pm2.5_atm, pm2.5_atm_a, pm2.5_atm_b),
           ~tibble(val = round(quantile(.x, quants_vals, na.rm = TRUE),0)),
           .unpack = TRUE)) %>%
  mutate(`Quantiles` = quants,
         epa = quantile(epa_data$pm25, quants_vals, na.rm = TRUE)) %>%
  rename(`EPA PM2.5` = epa,
         `PurpleAir PM2.5` = pm2.5_atm_val,
         `Channel A PM2.5` = pm2.5_atm_a_val,
         `Channel B PM2.5` = pm2.5_atm_b_val) %>%
  select(`Quantiles`, `EPA PM2.5`, everything())

knitr::kable(summary_statistics,
             row.names = FALSE,
             format = "markdown")
```

| Quantiles | EPA PM2.5 | PurpleAir PM2.5 | Channel A PM2.5 | Channel B PM2.5 |
| :-------- | --------: | --------------: | --------------: | --------------: |
| 75%       |        11 |               8 |               8 |               9 |
| 95%       |        23 |              29 |              29 |              31 |
| 99%       |        69 |              69 |              61 |              66 |
| 99.9%     |       170 |            1784 |            3342 |            3356 |

## Drop empty columns

```r
# Drop columns that are all NA
purpleair_data <- purpleair_data %>% select(-pa_latency, -voc)
```

## Flag values over 500 and missing values

```r
purpleair_data <- purpleair_data %>%
  mutate(missinga = ifelse(is.na(pm2.5_atm_a), 1, 0),
         missingb = ifelse(is.na(pm2.5_atm_b), 1, 0),
         over500a = ifelse(missinga == 0 & pm2.5_atm_a > 500, 1, 0),
         over500b = ifelse(missingb == 0 & pm2.5_atm_b > 500, 1, 0),
         flag = case_when(
           is.na(pm2.5_atm_a) | is.na(pm2.5_atm_b) ~ "Missing",
           over500a == 1 | over500b == 1 ~ "PM2.5 > 500",
           TRUE ~ "Normal"),
         pm2.5_atm_a = ifelse(is.na(pm2.5_atm_a),-1,pm2.5_atm_a),
         pm2.5_atm_b = ifelse(is.na(pm2.5_atm_b),-1,pm2.5_atm_b)
  )
```

## Initial plot channel A vs B

```r
if (FALSE) {
  p <- ggplot(purpleair_data, aes(x = pm2.5_atm_a, y = pm2.5_atm_b)) +
    geom_point(data = subset(purpleair_data, flag == "Normal"), color = "black") +
    geom_point(data = subset(purpleair_data, flag == "PM2.5 > 500"), color = "orange") +
    geom_point(data = subset(purpleair_data, flag == "Missing"), color = "red") +
    labs(x = "Channel A PM2.5",
         y = "Channel B PM2.5",
         title = "PM2.5 Channel A vs B") +
    theme_minimal()

  ggsave(filename = paste0(preprocessing_directory, "/plots/purpleair_avsb1.png"),
         plot = p, width = 6, height = 4)
}
img_path <- paste0(preprocessing_directory, "/plots/purpleair_avsb1.png")
knitr::include_graphics(img_path)
```

<img src="Preprocessing/plots/purpleair_avsb1.png" width="1800" />

## Channel A vs B limited to 1000 PM2.5

```r
if (FALSE) {
  p <- ggplot(purpleair_data, aes(x = pm2.5_atm_a, y = pm2.5_atm_b)) +
    geom_point(data = subset(purpleair_data, flag == "Normal"), color = "black") +
    geom_point(data = subset(purpleair_data, flag == "PM2.5 > 500"), color = "orange") +
    geom_point(data = subset(purpleair_data, flag == "Missing"), color = "red") +
    labs(
      x = "Channel A PM2.5",
      y = "Channel B PM2.5",
      title = "PM2.5 Channel A vs B",
      subtitle = "Axes limits set to 1000; more data points beyond the limit"
    ) +
    theme_minimal() +
    xlim(-1, 1000) +
    ylim(-1, 1000)

  ggsave(filename = paste0(preprocessing_directory, "/plots/purpleair_avsb2.png"),
         plot = p, width = 6, height = 4)
}

img_path <- paste0(preprocessing_directory, "/plots/purpleair_avsb2.png")
knitr::include_graphics(img_path)
```

<img src="Preprocessing/plots/purpleair_avsb2.png" width="1800" />

## Flag outliers with different thresholds of relative change between channel A and B

### Relative Change

$$
\text{Relative Change} = \frac{\lvert \text{Channel A}_{\text{PM2.5}} - \text{Channel B}_{\text{PM2.5}} \rvert}{\text{avg}(\text{Channel A}_{\text{PM2.5}}, \text{Channel B}_{\text{PM2.5}})}
$$

```r
# flag outliers using different thresholds and compare
# Initialize an empty data frame to store results
outlier_summary <- data.frame(
  threshold = numeric(0),
  num_outliers = numeric(0),
  percentage = numeric(0)
)

# Set thresholds for PM2.5 relative change
# Relative change - Arithmetic mean change  (https://en.wikipedia.org/wiki/Relative_change#Indicators_of_relative_change)
thresholds <- c(0.1, 0.15, 0.2, 0.25, 0.3, 0.4, 0.5, 0.6)
for (threshold in thresholds) {
  outliers <- purpleair_data %>%
    mutate(abs_diff = abs(pm2.5_atm_a - pm2.5_atm_b),
           relativechange = round(abs_diff / pm2.5_atm, 2),
           flag = ifelse(flag == "Normal" & relativechange > threshold & abs_diff > 2,
                         "Outlier", flag))

  # Merge with original data and flag outliers
  pa_outliers <- purpleair_data %>% select(-flag) %>%
    left_join(outliers %>% select(time_stamp, sensor_index, flag, abs_diff, relativechange),
              by = c("time_stamp", "sensor_index")) %>%
    select(time_stamp, pm2.5_atm_a, pm2.5_atm_b, abs_diff, relativechange,
           flag, everything())

  num_outliers <- pa_outliers %>% filter(flag == "Outlier") %>% nrow()
  percentage <- paste0(round(100 * num_outliers / total_rows, 2),"%")

  # Add the results to the data frame
  outlier_summary <- rbind(outlier_summary,
                           data.frame(threshold = threshold,
                                      num_outliers = format(num_outliers, big.mark = ","),
                                      percentage = percentage))
}

data_summary <- purpleair_data %>%
  group_by(flag) %>%
  summarize(count = n(), .groups = 'drop') %>%
  mutate(percentage = paste0(round(100 * count / total_rows), "%")) %>%
  arrange(desc(count)) %>%
  rbind(data.frame(flag = "Total", count = total_rows, percentage = "100%")) %>%
  mutate(count = format(count, big.mark = ","))

knitr::kable(data_summary,
             row.names = FALSE,
             format = "markdown",
             align = 'lrr',
             col.names = c("Flag", "Count", "Percentage")) %>%
  kable_styling()
```

<table class="table" style="margin-left: auto; margin-right: auto;">
<thead>
<tr>
<th style="text-align:left;">
Flag
</th>
<th style="text-align:right;">
Count
</th>
<th style="text-align:right;">
Percentage
</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:left;">
Normal
</td>
<td style="text-align:right;">
4,240,584
</td>
<td style="text-align:right;">
83%
</td>
</tr>
<tr>
<td style="text-align:left;">
Missing
</td>
<td style="text-align:right;">
856,355
</td>
<td style="text-align:right;">
17%
</td>
</tr>
<tr>
<td style="text-align:left;">
PM2.5 \> 500
</td>
<td style="text-align:right;">
17,096
</td>
<td style="text-align:right;">
0%
</td>
</tr>
<tr>
<td style="text-align:left;">
Total
</td>
<td style="text-align:right;">
5,114,035
</td>
<td style="text-align:right;">
100%
</td>
</tr>
</tbody>
</table>

```r
knitr::kable(outlier_summary,
             row.names = FALSE,
             format = "markdown",
             col.names = c("Threshold", "Number of Outliers", "Percentage")) %>%
  kable_styling() %>%
  row_spec(1, bold = TRUE, background = "#FFFF99")
```

<table class="table" style="margin-left: auto; margin-right: auto;">
<thead>
<tr>
<th style="text-align:right;">
Threshold
</th>
<th style="text-align:left;">
Number of Outliers
</th>
<th style="text-align:left;">
Percentage
</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:right;font-weight: bold;background-color: rgba(255, 255, 153, 255) !important;">
0.10
</td>
<td style="text-align:left;font-weight: bold;background-color: rgba(255, 255, 153, 255) !important;">
318,070
</td>
<td style="text-align:left;font-weight: bold;background-color: rgba(255, 255, 153, 255) !important;">
6.22%
</td>
</tr>
<tr>
<td style="text-align:right;">
0.15
</td>
<td style="text-align:left;">
269,813
</td>
<td style="text-align:left;">
5.28%
</td>
</tr>
<tr>
<td style="text-align:right;">
0.20
</td>
<td style="text-align:left;">
239,748
</td>
<td style="text-align:left;">
4.69%
</td>
</tr>
<tr>
<td style="text-align:right;">
0.25
</td>
<td style="text-align:left;">
220,418
</td>
<td style="text-align:left;">
4.31%
</td>
</tr>
<tr>
<td style="text-align:right;">
0.30
</td>
<td style="text-align:left;">
207,465
</td>
<td style="text-align:left;">
4.06%
</td>
</tr>
<tr>
<td style="text-align:right;">
0.40
</td>
<td style="text-align:left;">
189,551
</td>
<td style="text-align:left;">
3.71%
</td>
</tr>
<tr>
<td style="text-align:right;">
0.50
</td>
<td style="text-align:left;">
175,739
</td>
<td style="text-align:left;">
3.44%
</td>
</tr>
<tr>
<td style="text-align:right;">
0.60
</td>
<td style="text-align:left;">
164,374
</td>
<td style="text-align:left;">
3.21%
</td>
</tr>
</tbody>
</table>

## Plot different thresholds to compare

<img src="Preprocessing/plots/plot_threshold_0.1.png" width="49%" height="20%" style="display: block; margin: auto;" /><img src="Preprocessing/plots/plot_threshold_0.15.png" width="49%" height="20%" style="display: block; margin: auto;" /><img src="Preprocessing/plots/plot_threshold_0.2.png" width="49%" height="20%" style="display: block; margin: auto;" /><img src="Preprocessing/plots/plot_threshold_0.25.png" width="49%" height="20%" style="display: block; margin: auto;" /><img src="Preprocessing/plots/plot_threshold_0.3.png" width="49%" height="20%" style="display: block; margin: auto;" /><img src="Preprocessing/plots/plot_threshold_0.4.png" width="49%" height="20%" style="display: block; margin: auto;" /><img src="Preprocessing/plots/plot_threshold_0.5.png" width="49%" height="20%" style="display: block; margin: auto;" /><img src="Preprocessing/plots/plot_threshold_0.6.png" width="49%" height="20%" style="display: block; margin: auto;" />

## Using threshold of 0.1 relative change between channel A and B

## And maximum value of PM2.5 500 for channel A and B

```r
# flag outliers using selected threshold
threshold = 0.1
outliers <- purpleair_data %>%
  mutate(abs_diff = abs(pm2.5_atm_a - pm2.5_atm_b),
         relativechange = round(abs_diff / pm2.5_atm, 2),
         flag = ifelse(flag == "Normal" & relativechange > threshold & abs_diff > 2,
                       "Outlier", flag))
# Merge with flagged and original data
pa_outliers <- purpleair_data %>% select(-flag) %>%
  left_join(outliers %>% select(time_stamp, sensor_index, flag, abs_diff, relativechange),
            by = c("time_stamp", "sensor_index")) %>%
  select(time_stamp, pm2.5_atm_a, pm2.5_atm_b, abs_diff, relativechange, flag, everything())
```

## Filter out high PM2.5 values (\>500), missing channel data, and identified outliers

```r
# Remove outliers and keep relevant columns
pa_filtered <- pa_outliers %>%
  filter(flag == "Normal") %>%
  select(time_stamp, sensor_index, pm2.5_atm, pm2.5_atm_a, pm2.5_atm_b,
         rssi, uptime, memory, humidity, temperature, pressure, analog_input)
```

## Remove sensors with \< 24 data points

```r
low_data_sensors <- pa_filtered %>%
  group_by(sensor_index) %>% summarize(n = n()) %>% arrange(n) %>% filter(n < 24)
pa_filtered <- pa_filtered %>%
  filter(!(sensor_index %in% low_data_sensors$sensor_index))
```

```r
if (FALSE) {
  p <- ggplot(pa_filtered, aes(x = pm2.5_atm_a, y = pm2.5_atm_b)) +
    geom_point() +
    labs(x = "Channel A PM2.5",
         y = "Channel B PM2.5",
         title = "PM2.5 Channel A vs B") +
    theme_minimal()

  ggsave(filename = paste0(preprocessing_directory, "/plots/pa_filtered.png"),
         plot = p, width = 6, height = 4)
}

img_path <- paste0(preprocessing_directory, "/plots/pa_filtered.png")
knitr::include_graphics(img_path)
```

<img src="Preprocessing/plots/pa_filtered.png" width="1800" />

## Remove 24 hour periods of zeros or missing data

```r
start_time <- min(pa_filtered$time_stamp, na.rm = TRUE)
end_time <- max(pa_filtered$time_stamp, na.rm = TRUE)
all_timestamps <- seq(from = start_time, to = end_time, by = "hour")
all_sensor_indices <- unique(pa_filtered$sensor_index)
complete_timestamps <- expand.grid(sensor_index = all_sensor_indices,
                                   time_stamp = all_timestamps)
pa_complete <- complete_timestamps %>%
  left_join(pa_filtered, by = c("sensor_index", "time_stamp")) %>%
  mutate(pm2.5_atm = ifelse(is.na(pm2.5_atm), -1, pm2.5_atm))

pa_complete <- pa_complete %>%
  group_by(sensor_index) %>%
  mutate(
    is_zero_or_missing = ifelse(pm2.5_atm == 0 | pm2.5_atm == -1, 1, 0),
    is_normal = ifelse(pm2.5_atm != 0 & pm2.5_atm != -1, 1, 0),
    rolling_zeros_missing = rollapply(is_zero_or_missing, width = 24, FUN = sum,
                                      align = "right", fill = NA),
    rolling_normals = rollapply(is_normal, width = 24, FUN = sum, align = "right", fill = NA)
  ) %>%
  ungroup()

# threshold 0.8 means >=20 hours missing from a 24 hour time period
pa_complete <- pa_complete %>%
  mutate(
    proportion_zeros_missing = rolling_zeros_missing / 24,
    flag_high_proportion = ifelse(proportion_zeros_missing >= 0.8, 1, 0)
  )

pa_complete <- pa_complete %>% filter(flag_high_proportion != 1) %>%
  select(-is_zero_or_missing, -is_normal, -rolling_zeros_missing,
         -rolling_normals, -proportion_zeros_missing, -flag_high_proportion)
```

## Plot sensors with \>20% zeros

```r
# Percentage of zero readings for each sensor
sensor_zero_readings <- pa_complete %>%
  group_by(sensor_index) %>%
  summarize(pct_zeros = round(100 * sum(pm2.5_atm == 0) / n(), 2),
            pct_missing = round(100 * sum(pm2.5_atm == -1) / n(), 2)) %>%
  filter(pct_zeros > 20)

# Loop through each sensor and create plots
for (i in 1:nrow(sensor_zero_readings)) {
  s <- sensor_zero_readings$sensor_index[[i]]
  data_sensor <- pa_complete %>% filter(sensor_index == s)
  n <- nrow(data_sensor)
  pz <- round(sensor_zero_readings$pct_zeros[i], 0)
  pm <- round(sensor_zero_readings$pct_missing[i], 0)

  # Create a data frame with segment information
  shifted_readings <- data.frame(
    time_stamp = head(data_sensor$time_stamp, -1),
    time_stamp_shifted = tail(data_sensor$time_stamp, -1),
    pm2.5_atm = head(data_sensor$pm2.5_atm, -1),
    pm2.5_atm_shifted = tail(data_sensor$pm2.5_atm, -1)
  )

  # Assign colors based on whether the pm2.5_atm value is zero or not
  shifted_readings <- shifted_readings %>%
    mutate(flag = ifelse(pm2.5_atm == 0, "Zero", ifelse(pm2.5_atm == -1, "Missing", "Normal")))

  # Plot the segments
  p <- ggplot(data=shifted_readings, aes(x=time_stamp, xend = time_stamp_shifted,
                                         y=pm2.5_atm, yend = pm2.5_atm_shifted,
                                         color=flag)) +
    geom_segment() +
    scale_color_manual(values = c("Normal" = "black", "Missing" = "yellow",
                                  "Zero" = "red"),
                       name = "") +
    labs(x = "Time", y = "PM2.5",
         title = paste0("Sensor ", s, "\n",
                        pz, "% zeros", "\n",
                        pm, "% missing",
                        "\nNumber of readings: ", n)) +
    theme_minimal()

  ggsave(filename = file.path(preprocessing_directory, "plots", paste0(
    "pct", pz, "_sensor", s, ".png")),
    plot = p, width = 8, height = 6)
}
```

## View plots of sensors with \>20% zeros

<img src="Preprocessing/plots/pct48_sensor20349.png" width="49%" height="20%" style="display: block; margin: auto;" /><img src="Preprocessing/plots/pct21_sensor21847.png" width="49%" height="20%" style="display: block; margin: auto;" /><img src="Preprocessing/plots/pct50_sensor26733.png" width="49%" height="20%" style="display: block; margin: auto;" /><img src="Preprocessing/plots/pct25_sensor26959.png" width="49%" height="20%" style="display: block; margin: auto;" />

## Remove sensor 20349 based on plots

```r
pa_complete <- pa_complete %>%
  filter(sensor_index != 20349) %>% filter(pm2.5_atm != -1)
```

## Save Filtered Data to CSV

```r
# Save filtered data
write.csv(pa_complete, file = file.path(preprocessing_directory, "purpleair_filtered_2018-2019.csv"), row.names = FALSE)
```
