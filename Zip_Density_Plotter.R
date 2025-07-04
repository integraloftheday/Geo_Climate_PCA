library(sf)
library(dplyr)
library(ggplot2)

# Load and validate the data (st_make_valid is still good practice)
zip3_boundaries <- st_read("us_zip3_boundaries.gpkg") |> st_make_valid()
tracts_population_density <- st_read("us_tracts_population_density_2022.gpkg") |> st_make_valid()

tracts_conus <- tracts_population_density 

zip3_conus <- st_intersection(zip3_boundaries, tracts_conus)

st_write(zip3_conus, "zip3_conus.gpkg", delete_layer = TRUE)

ca_zip3_fragmented <- filter(zip3_conus, startsWith(ZIP3, "94"))
zip3_boundaries_filtered <- filter(zip3_boundaries, startsWith(ZIP3,"94"))

# Plot with a log10 transformed color scale
ggplot() +
  geom_sf(data = ca_zip3_fragmented, aes(fill = density), color = NA) +
  geom_sf(data = zip3_boundaries_filtered, fill = NA, color = "black", size = 0.25) +
  scale_fill_viridis_c(
    option = "plasma", 
    name = "Population Density",
    trans = "log10"  # <-- The key addition for log transformation
  ) +
  labs(title = "Contiguous US Population Density (Log Scale)") +
  theme_minimal()


