## Introduction ---------------------------
##
## Script name: toyModel_Brinkerink_HR.R
##
## Purpose of script:
## Rebuild the toy model building a MAC curve, but rely solely on 
## Brinkerink (rather than brinkerink and EIA) data
##
## Author: Jonathan Huster
##
## Date Created: 2021-06-02
##
## Email: jhuster@stanford.edu
##
## ---------------------------
##
## Notes:
##   This script is a little unwieldy. I would like to 
##   make smaller functions for processing. 
## ---------------------------

## Set Working Directory -------

DIR <- file.path("C:","Users","jonat","Box Sync","Research","MACC", "MACC_generator")
DATADIR <- file.path(DIR,"DataProcessed")
FUNCTIONSDIR <- file.path(DIR,"Functions")
OUTPUTDIR <- file.path(DIR,"Output")


## Load Necessary Packages ---------------------------

require(tidyverse)

# Establish and read in files ---------------------------

PLANTFILE <- file.path(DATADIR, "WRI_heatrate.csv")
COSTFILE <- file.path(DATADIR, "plantCostGlobal.csv")
AGEFILE <- file.path(DATADIR, "plantAge.csv")
EMISSIONSFILE <- file.path(DATADIR, "plantEmissionsGlobal.csv")
CAPACITYFACTORFILE <- file.path(DATADIR, "plantCapacityFactor.csv")

USAFILE <- file.path(DATADIR, "detailed_data", "CEMS_gen_emiss.csv")

WRISTATEMAPPINGFILE <- file.path(DATADIR, "mappings", "wri_state_nerc_map.csv")

ANNUITY_FACTORFILE <- file.path(FUNCTIONSDIR, "calculate_annuity_factor.R")
CALCULATEREPLACEMENTFILE <- file.path(FUNCTIONSDIR, "calculateReplacement.R")
PLOTMACCFILE <- file.path(FUNCTIONSDIR, "plotMACC.R")

source(ANNUITY_FACTORFILE)
source(CALCULATEREPLACEMENTFILE)
source(PLOTMACCFILE)

plantData <- read.csv(PLANTFILE)
costData <- read.csv(COSTFILE, skip = 3)
ageData <- read.csv(AGEFILE)
emissionsData <- read.csv(EMISSIONSFILE, skip = 3)
capacityFactorData <- read.csv(CAPACITYFACTORFILE, skip = 3)

usa_data <- read.csv(USAFILE)

wriStateMap <- read.csv(WRISTATEMAPPINGFILE)

# Set constants and assumptions ---------------------------
DISCOUNT_RATE <- 0.06;
MW_kW <- 1000;
GWh_kWh <- 1000000;
giga_unit <- 1E9;
kila_unit <- 1E3;
lb_kg <- 0.453592;
kg_tonne <- 1/1000;
BTU_MMBTU <- 1/1E6;
CURRENT_YEAR <- as.integer(format(Sys.Date(), "%Y"))

cap_price <- 200
replacement_fuel <- c("Gas", "Solar", "Wind")

coreCols <- c("country", "name", "capacity_mw", "primary_fuel","commissioningYear", "age", "generation_kwh")


# Establish power plant dataframe ---------------------------

# Known issues/assumptions
# 1) This assumues the average cost for a US plant by fuel type, but it would be
#    better by plant
# 2) This assumes that costs are independent of founding year (eg a 500MW plant
#    opening today has the same costs as a plant that built in 1970). We may 
#    want to find data by founding date rather than a new plant

plantData %>%
  select(country, name, capacity_mw, # latitude, longitude, 
         primary_fuel, # commissioning_year, 
         # generation_gwh_2013, generation_gwh_2014,
         # generation_gwh_2015, generation_gwh_2016, 
         generation_gwh_2017, estimated_generation_gwh, 
         commissioningYear, heatRate, plantCapacity) %>%
  mutate(age = CURRENT_YEAR-commissioningYear, 
         generation_gwh = if_else(!is.na(generation_gwh_2017), 
                                  generation_gwh_2017,
                                  estimated_generation_gwh),
         generation_kwh = generation_gwh*GWh_kWh) %>%
  tibble() ->
  cleanPlantData

cleanPlantData %>% 
  left_join(emissionsData, by = c("country","primary_fuel")) %>%
  mutate(fuel_consumption_btu = generation_kwh*heatRate*kila_unit,
         emissions_co2_tonne = fuel_consumption_btu*BTU_MMBTU*co2_lb_per_mmbtu*lb_kg*kg_tonne) %>%
  unique() %>%
  select(c(all_of(coreCols), "heat_rate_btu_per_kwh", "fuel_consumption_btu", "emissions_co2_tonne"))->
  plantEmissions

plantEmissions %>%
  filter(country != "USA") %>%
  rbind(usa_data %>% select(names(plantEmissions))) ->
  plantEmissionsCEMS



plantEmissionsCEMS %>% 
  left_join(costData, by = c("country", "primary_fuel")) %>%
  left_join(ageData, by = c("primary_fuel")) ->
  plantCost








# Establish replacement options ---------------------------
# Known issues/assumptions
# 1) We assume that a new natural gas plant of equal size 
#    of the plant we are replacing is opened. This maintains
#    total demand and capacity. If we want to increase demand
#    over time or add an intermittent source that requires 
#    an increased capacity we could do that. 
# 2) This assumes that the remaining capital was paid off in a linear fashion
#    rather than in an annualized rate. The remaining capital and new
#    capital is paid off in an annualized rate, but as a first assumption
#    the remaining cost will be linear. 

emissionsData %>%
  mutate(co2_kg_per_kwh = heat_rate_btu_per_kwh*BTU_MMBTU*co2_lb_per_mmbtu*lb_kg) ->
  fuel_emissions

costData %>%
  left_join(ageData, by = "primary_fuel") %>%
  left_join(fuel_emissions, c("country","primary_fuel")) ->
  holder 

holder %>%
  rename_all(funs(paste0("replacement_", make.names(names(holder)))))->
  replacement_options

# Apply replacements ---------------------------

calculateReplacementVec(plantCost,
                        replacement_options,
                        replacement_fuel,
                        capacityFactorData) %>%
  gather("param", "value", starts_with("total")) %>%
  mutate(replacement_primary_fuel = gsub(".*_", "", param),
         param = gsub("_[[:alpha:]]+$","",gsub("total_","",param))) %>%
  spread(param, value) ->
  replacementPlant



#A 2017 gas plant emits a power of 10 more than 
# a new gas plant. Need to ensure all the units
# align between our data sources. 

# Use the model  ---------------------------

# Plot the cost effectiveness of different replacements -----
replacementPlant %>%
  filter(country == "USA") %>%
  left_join(wriStateMap %>% select(country, name, primary_fuel, state, nerc)) %>%
  mutate(annual_cost_per_emission = annual_cost/(emissions_reduction*giga_unit)) %>%
  filter(emissions_reduction>0,
         generation_kwh>0, 
         state == "PA") ->
  costEffectivenes

# by US state ---------------------------
replacementPlant %>%
  filter(country == "USA") %>%
  left_join(wriStateMap %>% select(country, name, primary_fuel, state, nerc)) %>%
  mutate(annual_cost_per_emission = annual_cost/(emissions_reduction*giga_unit)) %>%
  group_by(country, name, capacity_mw, primary_fuel, commissioningYear) %>% 
  # Physical/Logic decisions
  filter(emissions_reduction>0,
         generation_kwh>0) %>%
  # Economic decisions
  filter(between(annual_cost_per_emission, -cap_price, cap_price),
         annual_cost_per_emission == min(annual_cost_per_emission)) %>%
  group_by(state) %>%
  arrange(state, annual_cost_per_emission) %>%
  mutate(cum_reduction = cumsum(emissions_reduction),
         state_GtCO2 = sum(emissions_co2_tonne)/giga_unit) %>%
  ungroup() %>%
  unite("ori_rep",primary_fuel,replacement_primary_fuel,remove = F) ->
  stateOrderedMACC

sanityCheck = stateOrderedMACC$state_GtCO2*giga_unit < stateOrderedMACC$cum_reduction

if (any(sanityCheck)){
  error("A state removed more than it's total emisssions")
}

states <- stateOrderedMACC %>% pull(state) %>% unique()

# by nation ---------------------------
replacementPlant %>%
  mutate(annual_cost_per_emission = annual_cost/(emissions_reduction*giga_unit)) %>%
  group_by(country, name, capacity_mw, primary_fuel, commissioningYear) %>% 
  # Physical/Logic decisions
  filter(emissions_reduction>0,
         generation_kwh>0) %>%
  # Economic decisions
  filter(between(annual_cost_per_emission, -cap_price, cap_price),
         annual_cost_per_emission == min(annual_cost_per_emission)) %>%
  group_by(country) %>%
  arrange(country, annual_cost_per_emission) %>%
  mutate(cum_reduction = cumsum(emissions_reduction),
         nation_GtCO2 = sum(emissions_co2_tonne)/giga_unit) %>% 
  ungroup() %>%
  unite("ori_rep",primary_fuel,replacement_primary_fuel,remove = F)->
  nationOrderedMACC

sanityCheck = nationOrderedMACC$nation_GtCO2*giga_unit < nationOrderedMACC$cum_reduction

if (any(sanityCheck)){
  error("A nation removed more than it's total emisssions")
}

countries <- nationOrderedMACC %>% pull(country) %>% unique()

# Plot the model results ---------------------------

# Establish color palettes

# Original fuels:

# Coal, Gas, Cogeneration, Petcoke, Oil, 
# Solar, Wind, Hydro, Wave and Tidal, Nuclear, Geothermal,
# Biomass, Waste, 
# Other, Storage [15]

# Emmitters:
# Coal, Gas, Cogeneration, Petcoke, Oil, Biomass, Waste [7]

# Replacement fuels: 

# Gas, Solar, Wind [3]

# In pracitce only 5 are used 
# (Gas_Solar, Coal_Solar, Oil_Solar, Waste_Solar 
#  Oil_Gas)
# Color gradients are from:
# https://colordesigner.io/gradient-generator

colorscheme <- c(
  "Coal_Solar"         = "#01ff00", 
  "Gas_Solar"          = "#00dc0d",  
  "Cogeneration_Solar" = "#00ba12",  
  "Petcoke_Solar"      = "#009813",  
  "Oil_Solar"          = "#007811",  
  "Biomass_Solar"      = "#005a0e",  
  "Waste_Solar"        = "#013d09", 
  "Coal_Wind"          = "#0079ff", 
  "Gas_Wind"           = "#1265db",  
  "Cogeneration_Wind"  = "#1553b9",  
  "Petcoke_Wind"       = "#134197",  
  "Oil_Wind"           = "#0e3078",  
  "Biomass_Wind"       = "#062059",  
  "Waste_Wind"         = "#01113d",
  "Coal_Gas"           = "#ff0000", 
  "Gas_Gas"            = "#e20006",  
  "Cogeneration_Gas"   = "#c50009",  
  "Petcoke_Gas"        = "#a8000a",  
  "Oil_Gas"            = "#8d000a",  
  "Biomass_Gas"        = "#720006",  
  "Waste_Gas"          = "#580000")

# by US state ---------------------------
xMax <- stateOrderedMACC %>% pull(cum_reduction) %>% max()/giga_unit
yMax <- cap_price
yMin <- -cap_price

for(state_name in states){
  annual_cost_per_emission <-
    plotMACC(stateOrderedMACC %>% filter(state == state_name),
             fig_title = paste0("MACC for ", state_name),
             fig_xlab = "Emissions Avoided (tonnes CO2/Year)") +
    ylim(yMin-10, yMax+10) +
    scale_fill_manual(values = colorscheme)+
    scale_color_manual(values = colorscheme) +
    labs(fill='Conversion (from_to)',
         color='Conversion (from_to)')

  ggsave(file.path(OUTPUTDIR, "Brinkerink_states", paste0("MACC_", state_name,".png")), width = 5, height = 3.66)
}

# by nation ---------------------------

for(country_name in countries){
  annual_cost_per_emission <-
    plotMACC(nationOrderedMACC %>% filter(country == country_name),
             fig_title = paste0("MACC for ", country_name),
             fig_xlab = "Emissions Avoided (Gigatonnes CO2/Year)") +
    ylim(yMin-10, yMax+10) +
    scale_fill_manual(values = colorscheme)+
    scale_color_manual(values = colorscheme) +
    labs(fill='Conversion (from_to)',
         color='Conversion (from_to)')
  
  # annual_cost_vs_emissions <- 
  #   ggplot(nationOrderedMACC %>% filter(country == country_name), aes(x = annual_cost, y = emissions_reduction))+
  #   geom_point(aes(color = ori_rep)) +
  #   ggtitle(paste0("Cost vs Reductions for ", country_name)) +
  #   xlab("Annual Cost (USD)") +
  #   ylab("Annual Emissions Reduction (GtC)")

  ggsave(file.path(OUTPUTDIR, "Brinkerink_countries", paste0("MACC_", country_name,".png")),annual_cost_per_emission, width = 5, height = 3.66)
  # ggsave(file.path(OUTPUTDIR, "Brinkerink_countries", paste0("emissions_vs_reductions_", country_name,".png")), annual_cost_vs_emissions, width = 5, height = 3.66)
  
  }

ggplot(costEffectivenes %>% filter(primary_fuel == "Gas", between(annual_cost_per_emission, -200, 200)),#filter(name == "Fairless Energy Center"),
       aes(x = emissions_reduction,
                             y = annual_cost_per_emission)) +
  geom_polygon(aes(group = name), fill = NA, color = "black") +
  geom_point(aes(shape = replacement_primary_fuel))+
  ggtitle("Replacement cost vs emissions reduction") +
  # scale_y_log10()+
  xlab("Emissions reduction (GtCO2)") +
  ylab("Cost ($)")
