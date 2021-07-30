Date Updated: 2021/05/24
Author: Jonathan Huster (jhuster@stanford.edu)

This document briefly details the MACC model created by Jonathan Huster for Ines Azevedo at Stanford University. 
The model attempts to create a marginal abatement cost curve methodology at a global scale for power plants. 
The essential question it is attempting to answer is "What are the cost and emission impacts from replacing
electricity plants with new lower emissions sources?" Below are some key assumptions and data sources.

Data :

Powerplant name/age/capacity/generation - Data/WRI/global_power_plant_database.csv (https://datasets.wri.org/dataset/globalpowerplantdatabase)
Emissions by plant - Data/EIA_Emissions/emissions2019.xlsx (https://www.eia.gov/electricity/data/emissions/)
Replacement heatrate - ToyModel/Assumptions/plantCost.csv (https://www.eia.gov/electricity/annual/html/epa_08_01.html)
Replacement emissions - ToyModel/Assumptions/plantCost.csv (https://www.eia.gov/analysis/studies/powerplants/capitalcost/pdf/capital_cost_AEO2020.pdf)
Fuel cost - ToyModel/Assumptions/plantCost.csv ( NG-https://www.eia.gov/dnav/ng/ng_pri_sum_dcu_nus_m.htm, coal-https://www.eia.gov/coal/data/browser/#/topic/45?agg=1,0&geo=vvvvvvvvvvvvo&freq=A&start=2008&ctype=linechart&ltype=pin&rtype=s&pin=&rse=0&maptype=0, Oil-https://www.eia.gov/dnav/pet/pet_pri_refoth_dcu_nus_m.htm)
Capital cost - ToyModel/Assumptions/plantEmissions.csv (https://www.eia.gov/analysis/studies/powerplants/capitalcost/pdf/capital_cost_AEO2020.pdf)

Plant payoff age - ASSUMPTION


Assumptions:

Only analyzing the US currently. Emissions based on EIA emissions by plant rather than from Brinkerink heat rates.

All plants are replaced with the national average gas plant.  