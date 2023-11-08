# Function to create plots
create_plots <- function(df, time_unit, facet_unit) {
  
  # Define time_label function
  get_time_label <- function(df, time_unit) {
    if (time_unit == "month") {
      return(month(df[[time_unit]], label = TRUE, abbr = TRUE))
    } else if (time_unit == "wday") {
      return(wday(df[[time_unit]], label = TRUE, abbr = TRUE))
    } else {
      return(as.character(df[[time_unit]])) # Keep as character initially
    }
  }
  
  # Create time_label
  df$time_label <- get_time_label(df, time_unit)
  df$facet_unit <- df[[facet_unit]]
  
  # Convert hour to numeric for correct ordering
  if (!(time_unit %in% c("month", "wday"))) {
    df$time_label <- as.numeric(df$time_label)
  }
  
  # Convert time_unit to symbol
  time_symbol <- rlang::sym(time_unit)

  # Aggregate by time_unit and sensor_id
  df_avg_sensor <- df %>%
    group_by(sensor_id, facet_unit, time_label) %>%
    summarise(avg_ratio = mean(ratio, na.rm = TRUE))
  
  # Convert sensor_id to factor
  df_avg_sensor$sensor_id <- as.factor(df_avg_sensor$sensor_id)
  
  # Calculate change in ratio
  df_avg_sensor <- df_avg_sensor %>%
    arrange(sensor_id, facet_unit, time_label) %>%
    group_by(sensor_id) %>%
    mutate(change = avg_ratio - lag(avg_ratio))
  
  # Aggregate by time_unit and facet_unit for all sensors
  df_avg_all <- df_avg_sensor %>%
    group_by(facet_unit, time_label) %>%
    summarise(avg_ratio = mean(avg_ratio, na.rm = TRUE),
              avg_change = mean(change, na.rm = TRUE))
  
  # PLOT AVERAGE RATIO
  
  # Line plot showing all sensors
  plot_ratio_sensor <- ggplot(df_avg_sensor, aes(x = time_label, y = avg_ratio, color = sensor_id)) +
    geom_line(aes(group = sensor_id)) +
    labs(title = paste("Average Ratio by", time_unit), x = time_unit, y = "Average Ratio") +
    facet_grid(facet_unit ~ .) +
    theme_bw()
  
  # Line plot showing average of all sensors
  plot_ratio_all <- ggplot(df_avg_all, aes(x = time_label, y = avg_ratio, color = as.factor(facet_unit), group = facet_unit)) +
    geom_line() +
    labs(title = paste("Average Ratio by", time_unit, "Across Sensors"), x = time_unit, y = "Average Ratio") +
    scale_color_discrete(name = paste(facet_unit)) +
    facet_grid(facet_unit ~ .) +
    theme_bw()
  
  # PLOT CHANGES IN RATIO
  
  # Plot change
  plot_change <- ggplot(df_avg_all, aes(x = time_label, y = avg_change, group = facet_unit)) +
    geom_line(aes(color = as.factor(facet_unit))) +
    geom_hline(yintercept = 0, linetype = "solid", color = "black", size = 0.5) +
    labs(title = paste("Average Change in Ratio by", time_unit), x = time_unit, y = "Change in Average Ratio") +
    scale_color_discrete(name = paste(facet_unit)) +
    facet_grid(facet_unit ~ .) +
    theme_bw()
  
  # Return plots as a list
  return(list(plot_ratio_sensor, plot_ratio_all, plot_change))
}

# Example usage:
time_unit = "hour"
facet_unit = "year"
plots <- create_plots(df, time_unit, facet_unit)
plots[[1]]  # plot_ratio_sensor
p <- plots[[2]]  # plot_ratio_all
plots[[3]]  # plot_change

# save hourly and monthly plots
ggsave(filename = "pm1pm2.5ratiobyhour.png", plot = p, width = 20, height = 8, dpi = 300)
ggsave(filename = "pm1pm2.5ratiobymonth.png", plot = p, width = 20, height = 8, dpi = 300)

