# Load R libraries
library(httr);
library(rjson);
library(jsonlite);
library(rstudioapi);
library(stringr);


# library(readxl)
# library(dplyr)
# library(data.table)
# library(SafeGraphR) # expand_integer_json

dir = '/Users/heba/Desktop/Uni/Lim Lab/Weekly Patterns'
setwd(dir)

#############################
# Download files from Dewey #
#############################

# Define global variables
DEWEY_TOKEN_URL = "https://marketplace.deweydata.io/api/auth/tks/get_token";
DEWEY_MP_ROOT   = "https://marketplace.deweydata.io";
DEWEY_DATA_ROOT = "https://marketplace.deweydata.io/api/data/v2/list";

# Get access token
get_access_token = function(username, passw) {
  response = POST(DEWEY_TOKEN_URL, authenticate(username, passw));
  response_content = content(response);
  
  return(response_content$access_token);
}

# Return file paths in the sub_path folder
get_file_paths = function(token, sub_path = NULL) {
  response = GET(paste0(DEWEY_DATA_ROOT, sub_path),
                 headers=add_headers(Authorization = paste0("Bearer ", token)));
  
  json_text = content(response, as = "text", encoding = "UTF-8");
  
  response_df = as.data.frame(fromJSON(json_text));
  response_df;
  
  return(response_df);
}

# Download a single file from Dewey (src_url) to a local destination file (dest_file).
download_file = function(token, src_url, dest_file) {
  options(timeout=200); # increase the timeout if you have a large file to download
  download.file(src_url, dest_file, mode = "wb",
                headers = c(Authorization = paste0("Bearer ", token)));
}

# Dewey credentials
user_name = "";
pass_word = "";

# Get access token
tkn = get_access_token(user_name, pass_word);
tkn;

# Download files
# for each month (1:12)
for(m in 1:1){
  month = sprintf("%02d", m)
  cat('month: ',month)
  # for each day
  for(d in 15:31){
    day = sprintf("%02d", d)
    print(day)
    file_paths = get_file_paths(token = tkn,
                                sub_path = paste0("/2019/",month,"/",day,"/SAFEGRAPH/WP"));
    # if month-day contains files:
    if (nrow(file_paths) > 0){
      print(colnames(file_paths))
      # filter files to only core_poi-geometry-patterns
      file_paths <- filter(file_paths,grepl("core_poi-geometry-patterns", name, ignore.case = TRUE))
      for (i in seq_len(nrow(file_paths))){
        print(paste0("file # ",i,"/",nrow(file_paths)))
        src_url = paste0(DEWEY_MP_ROOT, file_paths$url[i])
        dest_file = paste0(dir,"/2019",month,day,file_paths$name[i])
        start_time = Sys.time()
        download_file(tkn, src_url, dest_file)
        end_time = Sys.time()
        print("time to download:")
        print(end_time-start_time)
      }
    }
  }
}

# https://www.naics.com/search/
#   https://www.naics.com/naics-code-description/?v=2022&code=712190
# NAICS code 712190 - Nature Parks and Other Similar Institutions


