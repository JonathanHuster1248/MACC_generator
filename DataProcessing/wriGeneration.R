# Introduction ---------------------------
##
## Script name: wriGeneration.R
##
## Purpose of script:
## To identify errors and issues with WRI's powerplant
## dataset's generation columns
##
## Author: Jonathan Huster
##
## Date Created: 2021-05-29
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

## File Locations ---------------------------
WRIFILE <- file.path(INPUTDIR, "WRI", "global_power_plant_database.csv")

OUTPUTFILE <- file.path(OUTPUTDIR, "WRI_generation_issues.csv")

## Read Files ---------------------------
wri <- read.csv(WRIFILE)

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

# Process WRI data ---------------------------
gen_cols <- c("generation_gwh_2013", "generation_gwh_2014",
              "generation_gwh_2015", "generation_gwh_2016",
              "generation_gwh_2017", "estimated_generation_gwh")

wri %>%
  select(country, country_long, name, capacity_mw,
         latitude, longitude, primary_fuel, 
         other_fuel1, other_fuel2, other_fuel3,
         commissioning_year, year_of_capacity_data,
         generation_gwh_2013, generation_gwh_2014,
         generation_gwh_2015, generation_gwh_2016,
         generation_gwh_2017, estimated_generation_gwh) %>%
  gather(year, value, -c(country, country_long, name, capacity_mw,
                         latitude, longitude, primary_fuel, 
                         other_fuel1, other_fuel2, other_fuel3,
                         commissioning_year, year_of_capacity_data)) ->
  generation_long

generation_long %>%
  group_by_at(setdiff(names(generation_long), c("year", "value"))) %>%
  mutate(all_missing = all(is.na(value)),
         any_missing = any(is.na(value)),
         all_zero = if_else(!all_missing, all(value==0, na.rm = TRUE), NA),
         any_zero = if_else(!all_missing, any(value==0, na.rm = TRUE), NA),
         all_negative = if_else(!all_missing, all(value<0, na.rm = TRUE), NA),
         any_negative = if_else(!all_missing, any(value<0, na.rm = TRUE), NA)) %>% 
  select(-year, -value) %>% 
  unique() ->
  oddities

wri %>%
  left_join(oddities) %>%
  # group_by(country) %>% 
  summarise(all_missing = sum(all_missing, na.rm = FALSE)/n(),
            any_missing = sum(any_missing, na.rm = FALSE)/n(),
            all_zero = sum(all_zero, na.rm = TRUE)/sum(!is.na(all_zero)),
            any_zero = sum(any_zero, na.rm = TRUE)/sum(!is.na(any_zero)),
            all_negative = sum(all_negative, na.rm = TRUE)/sum(!is.na(all_negative)),
            any_negative = sum(any_negative, na.rm = TRUE)/sum(!is.na(any_negative))) ->
  wriIssuesSummary

