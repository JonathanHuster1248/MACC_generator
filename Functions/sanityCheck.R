netOrderedMACC %>%
  select(capacity_mw, primary_fuel, age) %>%
  mutate(ID = row_number(),
         ideal = 60 - 60/94*ID) ->
  test


ggplot(test) +
  geom_point(aes(x = ID, y = age, 
                 color = primary_fuel, size = capacity_mw)) +
  geom_line(aes(x = ID, y = ideal)) +
  facet_wrap(~primary_fuel) +
  ggtitle("Plant Age vs Removal Order") +
  xlab("Removal order") +
  ylab("Plant Age")


