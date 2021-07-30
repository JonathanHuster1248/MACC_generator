# Introduction ---------------------------
##
## Script name: USPlantStateMapping.R
##
## Purpose of script:
## Join WRI and EIA data to add states to US data
##
## Author: Jonathan Huster
##
## Date Created: 2021-06-02
##
## Email: jhuster@stanford.edu
##
## 


# Set Working Directory ---------------------------

DIR       <- file.path("C:", "Users", "jonat", "Box Sync","Research","MACC","Model","DataProcessing")
INPUTDIR  <- file.path(DIR, "..", "DataRaw")
OUTPUTDIR <- file.path(DIR, "..", "DataProcessed")

# Load Necessary Packages ---------------------------

require(tidyverse)
require(openxlsx)

## File Locations ---------------------------
WRIFILE <- file.path(INPUTDIR, "WRI", "global_power_plant_database.csv")
EIAFILE <- file.path(INPUTDIR, "EIA", "emissions2019.xlsx")

FUELMAPPINGFILE <- file.path(OUTPUTDIR, "mappings", "EIA_WRI_fuel_map.csv")

OUTPUTFILE <- file.path(OUTPUTDIR, "mappings", "wri_state_nerc_map.csv")

## Read Files ---------------------------
wri <- read.csv(WRIFILE)
eia <- read.xlsx(EIAFILE, sheet = "CO2", startRow = 2)

fuelMap <- read.csv(FUELMAPPINGFILE)

## Process Files ---------------------------
wri %>%
  select(country, country_long, name, latitude, longitude, primary_fuel) %>%
  filter(country == "USA") ->
  wri_USA

eia %>%
  select(name = Plant.Name, state = State, nerc = NERC.Region) %>%
  mutate(name = gsub(",", "", name)) %>%
  unique() ->
  eia_USA

## Join Datasets ---------------------------

wri_USA %>%
  left_join(eia_USA, by = c("name")) ->
  wri_state_nerc_map
  
  # This leaves 740 fossil fuel/waste plants without a mapping file.
  # This includes plants in Puerto Rico and around the continential US.
  # Why these plants don't have corresponding plants is unknown, but 
  # it doesn't appear to be simple errors in joining. 

## Write outputs ---------------------------
wri_state_nerc_map %>% write.csv(OUTPUTFILE, row.names = FALSE)
