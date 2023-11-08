# Load Libraries
library(dplyr)
library(data.table)
library(SafeGraphR) # expand_integer_json
library(tidycensus)
library(lubridate)
library(tidyr)
library(jsonlite)
library(ggplot2)


# Set working directory
dir = '/Users/heba/Desktop/Uni/Lim Lab'
setwd(dir)

#################
# MEDIAN INCOME #
#################

# County: San Francisco
county_code <- '06075' # San Fran County
county_name <- 'sf'

# Set the API key for accessing Census Bureau data
census_api_key("")

# Get state and county code for tidycensus
data(fips_codes)
fips_codes[fips_codes$state=='CA' & fips_codes$county=='San Francisco County',]
# CA: 06
# San Francisco: 075

# median household income data for san francisco 2019
income_table <- get_acs(
  geography = "block group", 
  state = "06", # california
  county = "075", # san francisco
  variables = c(median_income = "B19013_001"), 
  year = 2019
)

# rename and drop columns
income_table <- income_table %>% rename(c(CBG = GEOID,median_income=estimate))
income_table <- select(income_table, -c(moe,variable,NAME))

# CBG as numeric
income_table <- transform(income_table, CBG = as.numeric(CBG))

# Number of NA rows:  21  out of  581  ( 3.61 %)
cat("Number of NA rows: ", sum(is.na(income_table$median_income)), " out of ",nrow(income_table)," (", round(100*sum(is.na(income_table$median_income))/nrow(income_table),2), "%)"  )

# income levels

# Method 1:
# low: <50,000
# medium: <75,000
# high: >75,000
# income_table$income_category <- cut(
#   income_table$median_income,
#   breaks = c(-Inf, 50000, 75000, Inf),
#   labels = c("Low", "Medium", "High")
# )

# Method 2:
income_table$income_category <- cut(
  income_table$median_income,
  quantile(income_table$median_income, probs = c(0, 0.25, 0.5, 0.75, 1), na.rm=TRUE),
  labels = c("$", "$$", "$$$", "$$$$")
)

# To see the range for each income quartile
income_ranges <- income_table %>% 
  group_by(income_category) %>% 
  summarize(min_income = min(median_income), 
            max_income = max(median_income),
            n = n())

income_ranges

income_categories <- income_table %>% select(CBG,income_category)

# income table containing CBG, median_income, income_category
glimpse(income_table)

###################
# WEEKLY PATTERNS #
###################

# save SF park files

path = '/Users/heba/Desktop/Uni/Lim Lab/Weekly Patterns/'
filenames <- list.files(path)

for (f in filenames){
  if (endsWith(f, ".gz")) {
    # read weekly patterns file
    print(paste0(path,f))
    wp = fread(paste0(path,f))
    # filter by USA, CA, San Francisco
    # NAICS code 712190 - Nature Parks and Other Similar Institutions
    wp <- wp %>% filter(region=='CA' & iso_country_code =='US' & city=='San Francisco', naics_code==712190)
    filename <- sub("\\.csv.gz$", "", f)
    filename <- paste0(path,filename,"_SF_Parks.csv")
    print(filename)
    fwrite(wp, filename)
    }
}

# aggregate files

path = '/Users/heba/Desktop/Uni/Lim Lab/Weekly Patterns/'
filenames <- list.files(path, pattern = "*.csv", full.names = TRUE)
df_list <- lapply(filenames, read.csv)

# select relevant columns
for (i in seq_along(df_list)) {
  df_list[[i]] <- df_list[[i]] %>% select(c(poi_cbg,placekey,location_name,postal_code,date_range_start,date_range_end,raw_visit_counts,raw_visitor_counts,
                                            visits_by_day,visits_by_each_hour,visitor_home_cbgs, visitor_country_of_origin))
}

df=df_list[[1]]
glimpse(df)

# fix data type
df_list <- lapply(df_list, function(df) {
  df$placekey <- as.character(df$placekey)
  return(df)
})

# bind dfs that are not empty
wp_county <- bind_rows(df_list[sapply(df_list, nrow) > 0])

glimpse(df)

# df <- bind_rows(df_list)
# df_list


# read weekly patterns file
read_file = paste0(dir,"/Weekly Patterns/core_poi-geometry-patterns-part1.csv.gz");
wp = fread(read_file)

# filter by USA, CA, San Francisco
# NAICS code 712190 - Nature Parks and Other Similar Institutions
wp_county <- wp %>% filter(region=='CA' & iso_country_code =='US' & city=='San Francisco', naics_code==712190)

# For privacy, we do not report any CBGs with only 1 visitor, and any CBGs with 2-4 visitors are always rounded up to 4 visitors
# Thats why visitor_home_aggregation has more data than visitor_home_cbgs

# select columns
# wp_county <- wp_county %>% select(c(placekey,parent_placekey,safegraph_brand_ids,location_name,
#                                     brands,top_category,sub_category,naics_code,city,region,iso_country_code,postal_code,
#                                     category_tags,date_range_start,date_range_end,raw_visit_counts,raw_visitor_counts,
#                                     visits_by_day,visits_by_each_hour,poi_cbg,visitor_home_cbgs, visitor_country_of_origin))
# columns to group by
# groupcols = c('placekey','parent_placekey','safegraph_brand_ids','location_name',
#               'brands','top_category','sub_category','naics_code','city','region','iso_country_code','postal_code',
#               'category_tags','date_range_start','date_range_end','raw_visit_counts','raw_visitor_counts',
#               'visits_by_day','visits_by_each_hour','poi_cbg', 'visitor_country_of_origin')

wp_county <- wp_county %>% select(c(poi_cbg,placekey,location_name,postal_code,date_range_start,date_range_end,raw_visit_counts,raw_visitor_counts,
                                    visits_by_day,visits_by_each_hour,visitor_home_cbgs, visitor_country_of_origin))

# columns to group by (all except the one were expanding)
groupcols = c('poi_cbg','placekey','location_name','postal_code','date_range_start','date_range_end','raw_visit_counts','raw_visitor_counts',
              'visits_by_day','visits_by_each_hour', 'visitor_country_of_origin')
x<-wp_county
# # filter by one poi for testing
# x <- wp_county[wp_county$raw_visitor_counts != "NA",]
# x <- x[x$placekey =="zzz-222@5vg-835-vzz",]

# expand visitor_home_cbgs
x <- expand_cat_json(x,expand = 'visitor_home_cbgs',index = 'home_cbg',by = groupcols)

# home CBG as numeric
x <- transform(x, home_cbg = as.numeric(home_cbg))

# join with income categories
x <- merge(x,income_categories, by.x = "home_cbg",by.y = "CBG", all.x = TRUE)

# change date_range_start to date
x$date_range_start <- as_date(x$date_range_start)
x <- x %>% select(placekey,location_name,poi_cbg,wk_start_dt=date_range_start,income_category,visitor_home_cbgs,raw_visitor_counts)

# sum visitors by income category
x <- x %>% group_by(placekey,location_name,poi_cbg,wk_start_dt,income_category,raw_visitor_counts) %>% summarise(income_visitors = sum(visitor_home_cbgs))

# income long to wide format
wide_x <- pivot_wider(x, names_from = income_category, values_from = income_visitors)
wide_x <- wide_x %>% ungroup()

head(wide_x)

wide_x

x

fwrite(wide_x, "SF_Parks.csv")

# filter by one poi for testing
sf_zoo <- wide_x[wide_x$placekey =="zzz-222@5vg-835-vzz",]
sf_zoo <- x[x$placekey =="zzz-222@5vg-835-vzz",]

sf_zoo <- sf_zoo %>% mutate(visitors_perc = (income_visitors/raw_visitor_counts) * 100)


ggplot(sf_zoo, aes(x = wk_start_dt, y = visitors_perc, color = income_category)) +
  geom_line() +
  labs(x = "Date", y = "Visitors (%)", color = "Income Level") +
  theme_bw()

ggsave("sf_zoo_income.png", plot = last_plot(), dpi = 300, width = 4, height = 6, units = "in")


x[1]

# at a given park how does the income distribution change over time (hour/year)



glimpse(wp_county)

wp_county[1]


# # CBG as numeric
# income_table <- transform(income_table, CBG = as.numeric(CBG))






# read neighborhood patterns for SF county
for(m in 1:1){
  print(m)
  read_file = paste0(dir,"/neighborhood_patterns_",county_name,"_2019",sprintf("%02d", m),".csv");
  np_county = fread(read_file)
  # read full np file (checking if expand function will work):
  # read_file = paste0(dir,"/NP files/neighborhood_patterns_2019",sprintf("%02d", m),".csv.gz");
  # np = fread(read_file)
}

glimpse(np_county)

np_county2 <- np %>% select(area,device_home_areas)

glimpse(np_county2)

# columns to group by
groupcols = c('area')

# filter by one cbg for testing
x < - x[x$area==20200027021,]
x <- expand_cat_json(np_county2,expand = 'device_home_areas',index = 'origin_cbg',by = groupcols)



x = as.data.frame(x)







# date column = start date + 1 hr for each row
x['date'] = x['date_range_start']+(x['index']-1)*3600








###########
# drop date range start and end columns
x <- x %>% select(tract,date,popularity_by_each_hour)

# sum by tract and date (in case there were repeated tracts)
x <- x %>% group_by(tract,date) %>% summarise(popularity_each_hour = sum(popularity_by_each_hour))

# extract hour and weekday from date
x['hour'] <- hour(x$date)
x['wday'] <- lubridate::wday(x$date,label=TRUE)
# x: (tract,date,popularity_each_hour,hour,wday)

# hourly_sum: tract, hour, popularity
hourly_sum <- x %>% group_by(tract,hour) %>% summarise(popularity = sum(popularity_each_hour))

# hourly_sum_zip: tract, hour, popularity, zip, tot_ratio
hourly_sum_zip <- hourly_sum %>% left_join(y = la_tracts, by = c("tract"))

# multiple popularity by ratio of tract to zip
hourly_pop_zip <- hourly_sum_zip %>% mutate(popularity = popularity*tot_ratio) %>% as.data.frame() %>% select(zip,hour,popularity)

# add up popularity by zip code and hour
popularity_zip <- hourly_pop_zip %>% group_by(zip,hour) %>% summarise(popularity = sum(popularity)) %>% as.data.frame()

