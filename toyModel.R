library(dplyr)
library(tidyr)
library(ggplot2)

#Set locations and read in files
##################################################################
DIR <- file.path("C:","Users","jonat","Box Sync","Research","MACC","Model")
DATADIR <- file.path(DIR,"DataProcessed")
FUNCTIONSDIR <- file.path(DIR,"Functions")
OUTPUTDIR <- file.path(DIR,"Output")


PLANTFILE <- file.path(DATADIR, "aggregatedData2.csv")
COSTFILE <- file.path(DATADIR, "plantCost.csv")
AGEFILE <- file.path(DATADIR, "plantAge.csv")
EMISSIONSFILE <- file.path(DATADIR, "plantEmissions.csv")

NAMINGCONVENTION <- file.path(FUNCTIONSDIR, "namingConvention.R")
ANNUITY_FACTORFILE <- file.path(FUNCTIONSDIR, "calculate_annuity_factor.R")

source(NAMINGCONVENTION)
source(ANNUITY_FACTORFILE)

plantData <- read.csv(PLANTFILE)
costData <- read.csv(COSTFILE)
ageData <- read.csv(AGEFILE)
emissionsData <- read.csv(EMISSIONSFILE)

##################################################################


#Set constants and assumptions
##################################################################

MAIN_FF <- c("Coal", "Gas", "Oil") 

DISCOUNT_RATE <- 0.06;
MW_kW <- 1000;
giga_unit <- 1E9;
lb_kg <- 0.453592;
kg_tonne <- 1/1000;
BTU_MMBTU <- 1/1E6;
CURRENT_YEAR <- as.integer(format(Sys.Date(), "%Y"))

cap_price <- 200
##################################################################


#Establish power plant dataframe
##################################################################

# Known issues/assumptions
# 1) This assumues the average cost for a US plant by fuel type, but it would be
#    better by plant
# 2) This assumes that costs are independent of founding year (eg a 500MW plant
#    opening today has the same costs as a plant that built in 1970). We may 
#    want to find data by founding date rather than a new plant

plantData %>%
  na.omit() %>%
  colConvention() %>%
  tibble() ->
  cleanPlantData

cleanPlantData %>% 
  left_join(costData, by = "primary_fuel") %>%
  left_join(ageData, by = "primary_fuel") %>%
  mutate(age = CURRENT_YEAR-commissioning_year) ->
  plantCost


##################################################################

#Establish replacement costs
##################################################################
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
  left_join(fuel_emissions, by = "primary_fuel") %>%
  filter(primary_fuel == "Gas") %>%
  select(-primary_fuel) ->
  holder 

holder %>%
  rename_all(funs(paste0("replacement_", make.names(names(holder)))))->
  replacement_Plant

#The mutates calculate (in order) 
# 1) costs of the old plant, 
# 2) cost of the new plant,
# 3) total cost of replacing,
# 4) annualized cost
# 5) difference in emissions

plantCost %>%
  bind_cols(replacement_Plant) %>%
  # old plant costs
  mutate(remaining_capital = if_else(capacity_mw*MW_kW*capital_cost_per_kw*(1-age/pay_off_age)>0, capacity_mw*MW_kW*capital_cost_per_kw*(1-age/pay_off_age), 0),
         fix_om = capacity_mw*MW_kW*fixed_om_per_kw_year,
         variable_om = generation_kwh/MW_kW*variable_om_per_mwh) %>% 
  # New plant costs
  mutate(replacement_capital = capacity_mw*MW_kW*replacement_capital_cost_per_kw,
         replacement_fix_om = capacity_mw*MW_kW*replacement_fixed_om_per_kw_year,
         replacement_variable_om = generation_kwh/MW_kW*replacement_variable_om_per_mwh) %>%
  # Total costs
  mutate(total_capital = remaining_capital + replacement_capital,
         total_om = (replacement_fix_om + replacement_variable_om) - (fix_om + variable_om),
         total_fuel = (replacement_heat_rate_btu_per_kwh*replacement_fuel_price_per_btu*generation_kwh)- (fuel_consumption_for_electric_generation_mmbtu/BTU_MMBTU *fuel_price_per_btu)) %>%
  # Annualized cost
  mutate(annuity_factor = calculate_annuity_factor(discount_rate, replacement_pay_off_age),
         total_annual_cost = total_capital/annuity_factor + total_om + total_fuel) %>%
  # Emissions 
  mutate(replacement_emissions = replacement_co2_kg_per_kwh*kg_tonne*generation_kwh,
         net_emissions = metric_tonnes_of_co2_emissions-replacement_emissions) ->
  replacementPlant

#A 2017 gas plant emits a power of 10 more than 
# a new gas plant. Need to ensure all the units
# align between our data sources. 



##################################################################

# Play with the toy model 
##################################################################
# For our first toy model, lets only look at PA (because it has coal, gas, and oil)
replacementPlant %>%
  mutate(annual_cost_per_emission = total_annual_cost/net_emissions) %>%
  filter(net_emissions>=0,
         between(annual_cost_per_emission, -cap_price, cap_price)) %>%
  group_by(state) %>% 
  arrange(state, annual_cost_per_emission) %>%
  mutate(cum_reduction = cumsum(net_emissions),
         state_GtCO2 = sum(metric_tonnes_of_co2_emissions)/giga_unit) %>% 
  ungroup() ->
  netOrderedMACC

sanityCheck = netOrderedMACC$state_GtCO2*giga_unit < netOrderedMACC$cum_reduction

if (any(sanityCheck)){
  error("A state removed more than it's total emisssions")
}

states <- netOrderedMACC %>% pull(state) %>% unique()
##################################################################


# Plotting
##################################################################
xMax <- netOrderedMACC %>% pull(cum_reduction) %>% max()/giga_unit
yMax <- cap_price
yMin <- -cap_price

for (state_name in states){
annual_cost_per_emission <- ggplot(netOrderedMACC %>% 
                                      filter(state == state_name)) +
  geom_rect(aes(xmin = (cum_reduction - net_emissions)/giga_unit, 
                xmax = cum_reduction/giga_unit, 
                ymin = 0, 
                ymax =annual_cost_per_emission,
                fill = primary_fuel), colour = "grey50") +
  ylim(yMin-10, yMax+10)+
  geom_label(aes(x = .0005, y = -200, label = round(state_GtCO2, 3)), size = 5)+
  ggtitle(paste0("MACC for ", state_name," Plant Removal and Replacement")) +
  xlab("Emissions Avoided (Gt CO2/Year)") +
  ylab("Annual Cost (USD/tonne CO2)")

ggsave(file.path(OUTPUTDIR, paste0("MACC_", state_name,".png")), width = 5, height = 3.66)
}


##################################################################

