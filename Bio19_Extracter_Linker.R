# ==============================================================================
# Script to Perform PCA on BioClim Grid and Extract for Centroids (Manual PCA)
# ==============================================================================

# --- (Previous code sections 1-2 remain the same) ---

# --- 1. SETUP: Load Libraries and Define Paths ---
library(sf)
library(terra)
library(geodata)
library(dplyr)
library(stats) # Explicitly load for prcomp
library(WorldClimData)

DATA_DIR <- "data"
CENTROIDS_INPUT_FILE <- "zip3_all_centroids.gpkg"
FINAL_OUTPUT_FILE <- file.path(DATA_DIR, "zip3_centroids_with_bioclim_pca_GRID.gpkg")

if (!dir.exists(DATA_DIR)) {
  dir.create(DATA_DIR, recursive = TRUE)
}

# --- 2. DOWNLOAD BIOCLIM DATA & LOAD CENTROIDS ---
cat("--- Step 2: Loading data ---\n")

bioclim_data <- download_worldclim(period = "current",
                                   variable = "bio",
                                   resolution = 2.5,
                                   folder_path = "./data/climate_download")


# Load the raster data 
data_dir <- "./data/climate_download_unzipped/worldclim_base_v21_current_bio_2_5m/"

# Get all bioclim TIF files
bio_files <- list.files(path = data_dir, 
                        pattern = "wc2.1_2.5m_bio_.*\\.tif$", 
                        full.names = TRUE)

# Load as multi-layer raster
bioclim_stack <- rast(bio_files)

# --- 2. DOWNLOAD BIOCLIM DATA & LOAD CENTROIDS ---
cat("--- Step 2: Loading data ---\n")
bioclim_data <- bioclim_stack
centroids <- st_read(CENTROIDS_INPUT_FILE)


# --- 3. PREPARE THE DATA (CROP & MASK TO CONUS) ---
cat("\n--- Step 3: Cropping and masking BioClim data to CONUS ---\n")
centroids_proj <- st_transform(centroids, "EPSG:5070")
conus_boundary <- st_union(centroids_proj) %>%
  st_buffer(500000) %>%
  st_transform(st_crs(bioclim_data))

bioclim_conus <- crop(bioclim_data, conus_boundary) %>%
  mask(vect(conus_boundary))
cat("BioClim data prepared for CONUS.\n")

plot(bioclim_conus[[1]])


# check location of complete data
# Create a raster showing number of valid layers per pixel
valid_count_raster <- app(bioclim_conus, fun = function(x) sum(!is.na(x)))

# Plot the missing data pattern
# Create binary raster: 1 if >18 valid layers, 0 otherwise
valid_count_raster <- app(bioclim_conus, fun = function(x) sum(!is.na(x)))
binary_complete <- valid_count_raster > 18

# Plot binary version
plot(binary_complete,
     main = "Complete Bioclimate Data (>18 layers)",
     col = c("red", "darkgreen"),
     legend = TRUE,
     legend.args = list(text = "", side = 4),
     axes = TRUE)

# Add custom legend labels
legend("topright", 
       legend = c("Incomplete (≤18 layers)", "Complete (19 layers)"),
       fill = c("red", "darkgreen"),
       cex = 0.8)

#shows missing data over water 










# --- 4. Run PCA on entire dataset 
complete_pixels <- valid_count_raster > 18

# Extract values only from complete pixels
land_data <- terra::extract(bioclim_conus, which(values(complete_pixels) == 1))

# Remove ID column if present
if("ID" %in% colnames(land_data)) {
  land_data <- land_data[, -1]
}

# Run PCA
pca_model <- prcomp(land_data, center = TRUE, scale. = TRUE)
cat("PCA completed on", nrow(land_data), "land pixels\n")


# --- 5. PREDICT PCA SCORES ACROSS THE ENTIRE RASTER ---
cat("\n--- Step 5: Predicting PC scores across the entire landscape using the PCA model ---\n")
# Use the trained PCA model to predict the PC scores for every cell in the raster.
# This creates our final PC raster layers.
# We must use the version of the raster that has the zero-variance columns removed.
if (length(zero_var_cols) > 0) {
  bioclim_conus_filtered <- bioclim_conus[[ -zero_var_cols ]]
} else {
  bioclim_conus_filtered <- bioclim_conus
}

pca_rasters <- predict(bioclim_conus_filtered, pca_model, index = 1:10)
cat("PCA rasters created.\n")

# --- 6. EXTRACT VALUES AT CENTROID LOCATIONS ---
cat("\n--- Step 6: Extracting original and PCA values at centroid locations ---\n")
centroids_wgs84 <- st_transform(centroids, crs = st_crs(bioclim_conus))

# Extract from the filtered raster for consistency
raw_values <- as.data.frame(terra::extract(bioclim_conus_filtered, centroids_wgs84))[, -1]
pca_values <- as.data.frame(terra::extract(pca_rasters, centroids_wgs84))[, -1]
cat("Extraction complete.\n")

# Create RGB plot with PC1, PC2, PC3 as Red, Green, Blue channels
plotRGB(pca_rasters, r = 1, g = 2, b = 3, 
        main = "RGB Composite: PC1 (Red) + PC2 (Green) + PC3 (Blue)",
        stretch = "hist")  # Histogram stretch for better contrast



# --- 7. COMBINE AND SAVE THE FINAL DATASET ---
cat("\n--- Step 7: Combining all data and saving ---\n")
complete_mask <- complete.cases(raw_values) & complete.cases(pca_values)

final_data <- bind_cols(
  centroids[complete_mask, ],
  raw_values[complete_mask, ],
  pca_values[complete_mask, ]
)

cat(nrow(final_data), "centroids with complete data are being saved.\n")
st_write(final_data, FINAL_OUTPUT_FILE, delete_layer = TRUE, append = FALSE)

final_data_latlong <- st_transform(final_data, crs = 4326)

# Extract coordinates and add as separate columns
coords <- st_coordinates(final_data_latlong)
final_data_latlong$longitude <- coords[, "X"]
final_data_latlong$latitude <- coords[, "Y"]

write.csv(st_drop_geometry(final_data_latlong), 
          "./data_export/zip3_centroids_climate.csv", 
          row.names = FALSE)


cat("\n--- All Done! ---")
cat("\nFinal enriched data (using robust grid-based PCA) saved to:", FINAL_OUTPUT_FILE, "\n")

