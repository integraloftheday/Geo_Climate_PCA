# -----------------------------------------------------------------------------
# Script: Plot US Census Tract Population Density Map
# Author: Perplexity AI
# Date: 2025-06-13
# -----------------------------------------------------------------------------

# 1. Load Libraries
# install.packages(c("sf", "ggplot2", "viridis", "units"))
library(sf)
library(ggplot2)
library(viridis)
library(units)

# 2. Read the GeoPackage
cat("Loading tract data...\n")
tracts <- st_read("us_tracts_population_density_2022.gpkg", quiet = TRUE)

# 3. Quick Data Check (optional)
cat(paste("Tracts loaded:", nrow(tracts), "\n"))

# 4. Plot the Map
cat("Generating population density map...\n")
plot_obj <- ggplot(tracts) +
  geom_sf(aes(fill = as.numeric(density)), color = NA) +
  scale_fill_viridis_c(
    trans = "log10",
    name = "Population per km² (log)",
    labels = scales::comma,
    guide = guide_colorbar(direction = "horizontal",
                           barheight = unit(2, "mm"),
                           barwidth = unit(50, "mm"),
                           title.position = "top",
                           title.hjust = 0.5)
  ) +
  theme_void() +
  labs(
    title = "U.S. Population Density by Census Tract",
    subtitle = "2018–2022 ACS, Lower 48 States",
    caption = "Perplexity | Data: tidycensus"
  ) +
  theme(legend.position = "bottom")

# 5. Display the Map
print(plot_obj)

# 6. Save to Disk
cat("Saving map as 'us_tracts_density_map.png'...\n")
ggsave("us_tracts_density_map.png", plot = plot_obj, width = 12, height = 8, dpi = 300)
cat("Done! Map saved.\n")
