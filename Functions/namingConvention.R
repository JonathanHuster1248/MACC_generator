# I just want to have a location to document my 
# typical naming conventions so I can remain 
# consistent 
# 
# CONSTANTS   <- ALL CAPITAL       (eg MAXCOST <- 500)
# conversions <- from_to           (eg kg_tonne <- 1/1000)
# dataframes  <- camelCaseName     (eg plantDataClean) 
# columns     <- snake_name_scheme (eg plant_cost_total)
# functions   <- camelCaseToo      (eg colConvention <- function)

library(tidyverse)

colConvention <- function(df){
  df %>% 
    rename_with(snake_case) %>%
    rename_with(tolower) %>%
    return()
}

snake_case <- function(string){
  string %>% 
    gsub('[.*() ]+', '_', .) %>%
    gsub('[.*()_ ]+$', '', .) %>%
    return()
}

xlsx_csv <- function(df){
  return(rename_with(df, remove_xlsx_char))
}

remove_xlsx_char <- function(string){
  return(gsub("ï..", "", string)) 
}
