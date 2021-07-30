# Introduction ---------------------------
##
## Script name: mergeHeatrates.R
##
## Purpose of script:
## Merge the heatrates derived by Brinkerink et al. 2020 to the WRI plant
## names in their original data set. Essentially we are attempting to aggregate
## the generation, carbon intensity, and location into a single file.
##
## Author: Jonathan Huster
##
## Date Created: 2021-05-29
##
## Email: jhuster@stanford.edu
##
## 


# Set Working Directory ---------------------------

DIR              <- file.path("C:", "Users", "jonat", "Box Sync","Research","MACC","Model","DataProcessing")
INPUTDIR       <- file.path(DIR, "..", "DataRaw")
OUTPUTDIR <- file.path(DIR, "..", "DataProcessed")

# Load Necessary Packages ---------------------------

require(tidyverse)
require(openxlsx)

## File Locations ---------------------------
WRIFILE <- file.path(INPUTDIR, "WRI", "global_power_plant_database.csv")
PLEXOSFILE <- file.path(INPUTDIR, "PLEXOS", "PLEXOS-World 2015_Gold_V1.1.xlsx")

CONTINENTMAPPINGFILE <- file.path(INPUTDIR, "PLEXOS", "mappings", "continentMapping.csv")
COUNTRYMAPPINGFILE <- file.path(INPUTDIR, "PLEXOS", "mappings", "countryMapping.csv")
FUELMAPPINGFILE <- file.path(INPUTDIR, "PLEXOS", "mappings", "fuelMapping.csv")

OUTPUTFILE <- file.path(OUTPUTDIR, "WRI_heatrate.csv")

## Read Files ---------------------------
wri <- read.csv(WRIFILE)
plexos_mapping <- read.xlsx(PLEXOSFILE, sheet = "CustomColumns")
plexos_data <- read.xlsx(PLEXOSFILE, sheet = "Properties")

continentMapping <- read.csv(CONTINENTMAPPINGFILE)
countryMapping <- read.csv(COUNTRYMAPPINGFILE)
fuelMapping <- read.csv(FUELMAPPINGFILE)



# Establish Constants and Sets ---------------------------
fossil_fuels <- c("Oil", "Gas", "Coal")

MW_kW <- 1000;
mega_giga <- 1E-3;
giga_unit <- 1E9;
lb_kg <- 0.453592;
kg_tonne <- 1/1000;
BTU_MMBTU <- 1/1E6;
CURRENT_YEAR <- as.integer(format(Sys.Date(), "%Y"))
days_year <- 1/365.24;
hour_sec <- 3600;
year_hour <- 8760;

#Clean Mapping Files
# Make Helper Functions ---------------------------

# Gsub is replacing characters with the empty string (""),
# but this is causing errors when joining with our origninal data. 
# This function removes the invisible empty strings to fix the join.

removeEmptyString <- function(input_string){
  holder <- ""
  splitString <- strsplit(input_string, "")[[1]]
  for(char in splitString){
    if(char != "­"){
      holder = paste0(holder, char)
    }
  }
  return(holder)
}

removeEmptyStringList <- function(string_vector){
  n <- string_vector %>% length()
  for(i in 1:n){
    string_vector[i] = removeEmptyString(string_vector[i])
  }
  return(string_vector)
}

# Clean Mapping Files ---------------------------

# Apparently R has a quirk where it will read strings of "NA" as NA (null). Because 
# we have NA (North America), let's make sure it is a string

countryMapping %>% 
  mutate(continent = if_else(is.na(continent), 
                             "NA", 
                             continent)) ->
  countryMappingNA

continentMapping %>% 
  mutate(continent = if_else(is.na(continent), 
                             "NA", 
                             continent)) ->
  continentMappingNA

plexos_mapping %>% 
  select(plexosName = object, wriName = value) ->
  plexos_mapping_clean

# List all countries and continents for sanity checks later
countries <- countryMappingNA %>% pull(iso) %>% unique()
continents <- countryMappingNA %>% pull(continent) %>% unique()


# Process Plexos Data ---------------------------
plexos_data %>%
  filter(child_class == "Generator", 
         property %in% c("Heat Rate", "Commission Date", "Max Capacity", "Units"),
         !grepl("Exclude", scenario), 
         !grepl("Include Nuclear Constraint", scenario)) %>% 
  select(child_object, property, value) %>% 
  spread(property, value) ->
  plexos_generator

plexos_generator %>%
  mutate(commissioningYear = round(`Commission Date`*days_year + 1900),
         plantCapacity = `Max Capacity`*Units) %>%
  select(plexosName = child_object,
         commissioningYear, 
         heatRate = `Heat Rate`,
         plantCapacity) ->
  plexos_generator_parameters

# Join Plexos Data to WRI Data ---------------------------

nWri <- nrow(wri)

wri %>%
  mutate(wriName = if_else(row_number()>=28665,
                           paste0(country,
                                  "_", 
                                  substr(primary_fuel,1,3),
                                  "_", 
                                  substr(name, 1,15), 
                                  row_number()+1),
                           paste0(country,
                                  "_", 
                                  substr(primary_fuel,1,3),
                                  "_", 
                                  substr(name, 1,15), 
                                  row_number())),
         wriName = if_else(wriName == "USA_Oil_Palaau Power Hy26593",
                           "USA_Oil_Palaau Power26593",
                           wriName)) %>%
  left_join(plexos_mapping_clean, by = "wriName") %>%
  left_join(plexos_generator_parameters, by = "plexosName") ->
  heatRateJoined



# There were 6 plants (in North Korea and Kuwait) that didn't have values 
heatRateJoined %>%
  filter(is.na(heatRate)) %>%
  nrow() ->
  nUnmatched

if(nrow(heatRateJoined) != nWri){
  error("The join added rows")
}
if(nUnmatched > 6){
  error("There are unexpected unmatched values")
}

# Write Outputs ---------------------------

heatRateJoined %>% write.csv(OUTPUTFILE, row.names = FALSE)
