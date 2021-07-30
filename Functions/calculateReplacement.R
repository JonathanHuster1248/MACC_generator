
calculateReplacement <- function(historicalPlants, replacementOptions, replacementFuel){
  
  #The mutates calculate (in order) 
  # 1) costs of the old plant, 
  # 2) cost of the new plant,
  # 3) total cost of replacing,
  # 4) annualized cost
  # 5) difference in emissions
  
  historicalPlants %>%
    left_join(replacementOptions %>% 
                filter(replacement_primary_fuel == replacementFuel) %>% 
                select(-replacement_primary_fuel),
              by = c("country"="replacement_country")) %>%
    # old plant costs
    mutate(remaining_capital = if_else(age < pay_off_age, capacity_mw*MW_kW*capital_cost_per_kw*(1-age/pay_off_age), 0),
           fix_om = capacity_mw*MW_kW*fixed_om_per_kw_year,
           variable_om = generation_kwh/MW_kW*variable_om_per_mwh) %>% 
    # New plant costs
    mutate(replacement_capital = capacity_mw*MW_kW*replacement_capital_cost_per_kw,
           replacement_fix_om = capacity_mw*MW_kW*replacement_fixed_om_per_kw_year,
           replacement_variable_om = generation_kwh/MW_kW*replacement_variable_om_per_mwh) %>%
    # Total costs
    mutate(total_capital = remaining_capital + replacement_capital,
           total_om = (replacement_fix_om + replacement_variable_om) - (fix_om + variable_om),
           total_fuel = (replacement_heat_rate_btu_per_kwh*replacement_fuel_price_per_btu*generation_kwh)- (fuel_consumption_btu*fuel_price_per_btu)) %>%
    # Annualized cost
    mutate(annuity_factor = calculate_annuity_factor(discount_rate, replacement_pay_off_age),
           total_annual_cost = total_capital/annuity_factor + total_om + total_fuel) %>%
    # Emissions 
    mutate(replacement_emissions = replacement_co2_kg_per_kwh*kg_tonne*generation_kwh,
           total_emissions_reduction = (emissions_co2_tonne - replacement_emissions)/giga_unit) -> # Units of Gt
    replacementPlant
  
  replacementPlant %>%
    select(-c("replacement_emissions","annuity_factor","total_fuel","total_om",
              "total_capital","replacement_variable_om",'replacement_fix_om',
              "replacement_capital","variable_om","fix_om","remaining_capital",
              tail(names(replacementOptions), n=-2))) %>%
    rename_with(~paste0(.x,"_", replacementFuel), all_of(c("total_emissions_reduction", "total_annual_cost"))) %>%
    return()
}

calculateReplacementVec <- function(historicalPlants, replacementOptions, replacementFuels){
  holder <- historicalPlants
  for(replacementFuel in replacementFuels){
    holder <- calculateReplacement(holder, replacementOptions, replacementFuel)
  }
  return(holder)
}
