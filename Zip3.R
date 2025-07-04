# -----------------------------------------------------------------------------
# SCRIPT (V2): Process the PRE-AGGREGATED Local Geodatabase - WITH FIX
#
# Goal: Reads your local .gdb file, using the correct 'Shape' geometry column.
#       This will still produce a fragmented map.
#
# Date: 2025-06-13
# -----------------------------------------------------------------------------

# Step 1: Load Libraries
library(sf)
library(dplyr)
library(ggplot2)
library(viridis)

# -----------------------------------------------------------------------------

cat("-> STEP 1 of 3: Reading the pre-aggregated ZIP3 data from the local .gdb...\n")

gdb_path <- "./data/v108/zip3.gdb"
layer_to_read <- st_layers(dsn = gdb_path)$name[1]
zip3_boundaries_fragmented <- st_read(dsn = gdb_path, layer = layer_to_read)

cat("   ...Data successfully read.\n")

# -----------------------------------------------------------------------------

cat("-> STEP 2 of 3: Preparing and saving the data...\n")

# The data is already at the ZIP3 level. We just need to select the
# correct columns and transform the projection.
# THE FIX IS HERE: We now select 'Shape' instead of 'geometry'.
zip3_final_fragmented <- zip3_boundaries_fragmented %>%
  select(ZIP3, Shape) %>% # <-- FIX: Use the correct column name 'Shape'
  rename(geometry = Shape) %>% # Best practice: rename 'Shape' to the standard 'geometry'
  st_transform(2163) # Match the CRS of your tract data

# Save this fragmented layer to a GeoPackage
st_write(zip3_final_fragmented, "./data/us_zip3_boundaries.gpkg", delete_dsn = TRUE)
cat("   ...Success! Saved fragmented boundaries to 'us_zip3_boundaries_fragmented.gpkg'.\n")

# -----------------------------------------------------------------------------

cat("-> STEP 3 of 3: Creating a validation plot...\n")
# This plot will look like the fragmented map you uploaded.
ca_zip3_fragmented <- filter(zip3_final_fragmented, startsWith(ZIP3, "8"))
ggplot(ca_zip3_fragmented) +
  geom_sf(aes(fill = ZIP3), color = "darkblue", linewidth = 0.2, show.legend = FALSE) +
  theme_void() +
  labs(
    title = "Fragmented ZIP3 Boundaries from Local GDB",
    subtitle = "This reflects the 'holes' in the source ZCTA data"
  )
ggsave("zip3_validation_fragmented_ca.png", width = 8, height = 10, dpi = 300)

cat("   ...Validation map 'zip3_validation_fragmented_ca.png' has been saved.\n")

cat("-> Creating a labeled validation plot for Arizona...\n")

# Step 3: Filter for Arizona ZIP3s
# Arizona ZIP3s are mostly in the 85xxx and 86xxx ranges.
# We use grepl() with a regular expression for a precise filter.
az_zip3_fragmented <- zip3_final_fragmented %>%
  filter(grepl("^8[56]", ZIP3))

# Step 4: Create the Plot with Labels
ggplot(az_zip3_fragmented) +
  # First, draw the filled polygons for each ZIP3 region.
  # We use a color scale but remove the legend since we will have labels.
  geom_sf(aes(fill = ZIP3), color = "white", linewidth = 0.5, show.legend = FALSE) +
  
  # Next, add the labels. geom_sf_label places text at the center of each polygon.
  geom_sf_label(
    aes(label = ZIP3),
    size = 2.5,               # Adjust font size to be smaller
    fontface = "bold",        # Make the text bold to stand out
    fill = "white",           # Give the label a white background
    alpha = 0.6,              # Make the background slightly transparent
    label.padding = unit(0.15, "lines") # Reduce padding around text
  ) +
  
  # Use a nice, colorblind-friendly color palette
  scale_fill_viridis_d() +
  
  # Use a clean theme
  theme_void() +
  
  # Add an informative title
  labs(
    title = "Fragmented ZIP3 Boundaries for Arizona",
    subtitle = "Source: Local GDB (illustrating data gaps)",
    caption = "Map"
  )

# -----------------------------------------------------------------------------

# Step 5: Save the New Map
ggsave("zip3_validation_fragmented_az_labeled.png", width = 8, height = 9, dpi = 300)

cat("   ...Validation map 'zip3_validation_fragmented_az_labeled.png' has been saved.\n")
