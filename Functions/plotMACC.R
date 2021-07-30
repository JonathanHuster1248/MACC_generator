# oderedDF must have columns called "cum_reduction", "emissions_reduction", and "annual_cost_per_emission" to create the boxes
# as well as a column called "primary_fuel" to color the boxes
plotMACC <- function(orderedDF, 
                     fig_title = "MACC for Plant Removal and Replacement",
                     fig_xlab = "Emissions Avoided (Gt CO2/Year)",
                     fig_ylab = "Annual Cost (USD/tonne CO2)"){
  giga_unit <- 1e9;
  
  lab_xloc <- max(pull(orderedDF, cum_reduction))/2; # We want a label in the middle of the plot's x axis
  lab_yloc <- -190 # min(pull(orderedDF, annual_cost_per_emission))*2; # We want a label in the middle of the plot's x axis
  lab_val  <- sum(pull(orderedDF, emissions_co2_tonne))/giga_unit;
  
  ggplot(orderedDF) +
    geom_rect(aes(xmin = (cum_reduction - emissions_reduction), 
                  xmax = cum_reduction, 
                  ymin = 0, 
                  ymax =annual_cost_per_emission,
                  fill = ori_rep, 
                  colour = ori_rep)) +
    geom_label(aes(x = lab_xloc, y = lab_yloc, label = round(lab_val, 3)), size = 5)+
    ggtitle(fig_title) +
    xlab(fig_xlab) +
    ylab(fig_ylab)
}