
#Takes a double (discount_rate) and a double (lifetime)
# and calculates an annuity factor to get an annual 
# cost from a capital investment. 
calculate_annuity_factor <- function(discount_rate, lifetime){
  annuity_factor = (1- (1/((1+discount_rate)^lifetime)))/discount_rate
  return(annuity_factor)
}