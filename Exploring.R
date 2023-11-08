# install.packages('remotes')
# install.packages('vtable')
# install.packages("tidycensus")
# remotes::install_github('SafeGraphInc/SafeGraphR')
# library(tidyverse) # Data manipulation and graphing
library(lubridate) # Handling dates
library(SafeGraphR) # expand_integer_json
library(data.table) # to use fread
library(vtable) # Looking at the data
# library(tidycensus)
library(ggplot2)
library(dplyr)
library(readxl) # read excel files
# library(purrr)
# detach("package:tidyverse", unload = TRUE)
# detach("package:lubridate", unload = TRUE)
# detach("package:data.table", unload = TRUE)
# detach("package:vtable", unload = TRUE)

# set working directory
# dir = '/Users/heba/Desktop/Uni/Lim Lab'
dir = '/Users/heba/Desktop/Uni/Lim Lab/Neighborhood Patterns'
setwd(dir)

# neighborhood patterns month 12
f <- "neighborhood_patterns 12.csv"
df <- fread(f)

# filter df by region = CA, then save to csv
df_ca <- df[region %in% "CA", ] 
fwrite(df_ca, "neighborhood_patterns_ca_201912.csv")

f_ca <- "neighborhood_patterns_ca_201912.csv"
df_ca <- fread(f_ca)

# LA COUNTY NUMBER: 06037
# https://transition.fcc.gov/oet/info/maps/census/fips/fips.txt

# files containing county to zip and zip to tract
q4zip_tract <- read_excel("ZIP_TRACT_122019.xlsx")
q4county_zip <- read_excel("ZIP_COUNTY_122019.xlsx")

# only keep relevant columns
q4zip_tract = subset(q4zip_tract, select = c(ZIP, TRACT))
q4county_zip = subset(q4county_zip, select = c(ZIP, COUNTY))

# filter county to la
q4county_zip_la = q4county_zip %>% filter(COUNTY=='06037')
q4zip_tract_la <- subset(q4zip_tract, ZIP %in% q4county_zip_la$ZIP)

# transform tract to numeric
q4zip_tract_la <- transform(q4zip_tract_la, TRACT = as.numeric(TRACT))

# tract = first 10 digits of CBG
df_ca = df_ca %>% mutate(TRACT = substr(x = area, start = 0, stop = 10))

# df_ca %>% select(TRACT) %>% arrange(TRACT) 
# q4zip_tract_la %>% select(TRACT) %>% arrange(TRACT)

# filter by tract in LA
df_la <- df_ca[TRACT %in% q4zip_tract_la$TRACT, ] 


glimpse(df_la)
df_ca[1]
colnames(df_ca)
df_ca$area


###################
# exploring files #
###################

# list file names
list.files()
f1 <- "core_poi-geometry-patterns-part1-2.csv"
f2 <- "neighborhood_patterns_000000000000-2.csv"
f3 <- "spend_patterns.csv"

# fast read file
df1 <- fread(f1)
df2 <- fread(f2)
df3 <- fread(f3)

# explore df
head(df)
colnames(df1)
colnames(df2)
colnames(df3)
# vtable(df, lush = TRUE) # includes values, missing, nunique
# vtable(df, missing = TRUE, summ=c('min(x)','max(x)','nuniq(x)'))
vtable(df2, missing = TRUE, summ='nuniq(x)')

glimpse(df1)

######################
# Popularity by hour #
######################  

groupcols = c('area','date_range_start','date_range_end','region')

df = df2[,.(date_range_start,date_range_end,region,area,popularity_by_each_hour)]

x = expand_integer_json(df, 'popularity_by_each_hour', by=groupcols)

x = as.data.frame(x)

x['date'] = x['date_range_start']+(x['index']-1)*3600

x2 <- x %>% select(area,region,date,popularity_by_each_hour)

x2['hour'] <- hour(x2$date)

x2['day'] <- lubridate::wday(x2$date,label=TRUE)

# x3 <- x2 %>% group_by(area,region,hour,day) %>% summarise(pop_hour = mean(popularity_by_each_hour))
x3 <- x2 %>% group_by(hour,day) %>% summarise(pop_hour = mean(popularity_by_each_hour))

head(x3)

# x3 <- x3 %>% ungroup()

glimpse(x3)

# heat map (not using area or region)

ggplot(x3, aes(x = hour, y = day, fill = pop_hour)) +
  geom_tile() +
  scale_fill_gradient(low = "white", high = "blue")


##############################
# Popularity by hour and dow #
##############################

# select columns from data table
df = df2[,.(date_range_start,date_range_end,region,area,popularity_by_hour_monday,popularity_by_hour_tuesday,popularity_by_hour_wednesday,popularity_by_hour_thursday,popularity_by_hour_friday,popularity_by_hour_saturday,popularity_by_hour_sunday)]
basedf = df2[,.(date_range_start,date_range_end,region,area)]

groupcols = c('area','date_range_start','date_range_end','region')
expandcols = c('popularity_by_hour_monday','popularity_by_hour_tuesday','popularity_by_hour_wednesday','popularity_by_hour_thursday','popularity_by_hour_friday','popularity_by_hour_saturday','popularity_by_hour_sunday')

new_dfs <- list()

for (i in seq_along(expandcols)) {
  # new_dfs[[i]] = expand_integer_json(df, (expandcols)[i], by=groupcols)
  dfi = expand_integer_json(df, (expandcols)[i], by=groupcols)
  basedf <- list(basedf,dfi) %>% reduce(inner_join, by = groupcols)
  }

mergeds <- new_dfs %>% reduce(inner_join, by = groupcols)


# new_dfs

# head(df,1)


