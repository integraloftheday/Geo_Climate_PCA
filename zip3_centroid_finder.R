# ==============================================================================
# Script to Calculate and Map Centroids for All US ZIP3s
# ==============================================================================

# --- 1. SETUP: Load Libraries ---
# Make sure these packages are installed: install.packages(c("sf", "dplyr", "ggplot2", "purrr"))
library(sf)
library(dplyr)
library(ggplot2)
library(purrr)

# --- 2. SETUP: Define Input and Output Paths ---
INPUT_FILE <- "./data/zip3_conus.gpkg"
OUTPUT_DIR_MAPS <- file.path("data", "Zip3_Population_Maps")
OUTPUT_FILE_CENTROIDS <- "./data/zip3_all_centroids.gpkg"

# Create the output directory for maps if it doesn't exist
if (!dir.exists(OUTPUT_DIR_MAPS)) {
  dir.create(OUTPUT_DIR_MAPS, recursive = TRUE)
  cat("Created directory:", OUTPUT_DIR_MAPS, "\n")
}

# --- 3. DATA LOADING ---
cat("Loading data from", INPUT_FILE, "...\n")
zip3_conus <- st_read(INPUT_FILE) %>%
  st_make_valid() # Ensure all geometries are valid from the start

# --- 4. DEFINE THE PROCESSING FUNCTION ---
# This function will be applied to the data for EACH ZIP3 code.
process_zip3 <- function(zip3_data, zip3_code) {
  
  cat("Processing ZIP3:", zip3_code, "...\n")
  
  # --- a. Calculate Population-Weighted Centroid ---
  # Check if there is population data to avoid division by zero
  total_pop <- sum(zip3_data$population, na.rm = TRUE)
  
  if (total_pop > 0) {
    pw_centroid <- zip3_data %>%
      mutate(
        piece_centroid_x = st_coordinates(st_centroid(geom))[,1],
        piece_centroid_y = st_coordinates(st_centroid(geom))[,2]
      ) %>%
      st_drop_geometry() %>% # Convert to a regular data frame for summarization
      summarize(
        pw_x = sum(piece_centroid_x * population, na.rm = TRUE) / total_pop,
        pw_y = sum(piece_centroid_y * population, na.rm = TRUE) / total_pop,
        .groups = "drop"
      ) %>%
      st_as_sf(coords = c("pw_x", "pw_y"), crs = st_crs(zip3_data))
  } else {
    # If no population, the population-weighted centroid doesn't exist.
    # We will create an empty sf object to handle this case gracefully.
    pw_centroid <- st_sf(geometry = st_sfc(), crs = st_crs(zip3_data))
  }
  
  # --- b. Calculate Geometric Centroid ---
  geo_centroid <- zip3_data %>%
    st_union() %>%
    st_centroid()
  
  # --- c. Create and Save the Plot ---
  tryCatch({
    map_plot <- ggplot() +
      geom_sf(data = zip3_data, aes(fill = density), color = "gray50", linewidth = 0.1) +
      geom_sf(data = geo_centroid, fill = "white", color = "red", shape = 21, size = 4, stroke = 1.5, inherit.aes = FALSE) +
      geom_sf_text(data = geo_centroid, label = "Geo", color = "red", nudge_y = 5000, size = 3) +
      scale_fill_viridis_c(option = "plasma", trans = "log10", labels = scales::comma, na.value = "lightgrey") +
      labs(
        title = paste("Population Density and Centroids for ZIP3:", zip3_code),
        subtitle = "Red = Geometric Center, Blue = Population-Weighted Center",
        fill = "Density\n(log scale)"
      ) +
      theme_minimal()
    
    # Add the population-weighted centroid only if it exists
    if (nrow(pw_centroid) > 0) {
      map_plot <- map_plot +
        geom_sf(data = pw_centroid, fill = "white", color = "blue", shape = 21, size = 4, stroke = 1.5, inherit.aes = FALSE) +
        geom_sf_text(data = pw_centroid, label = "Pop", color = "blue", nudge_y = -5000, size = 3)
    }
    
    plot_filename <- file.path(OUTPUT_DIR_MAPS, paste0("map_zip3_", zip3_code, ".png"))
    ggsave(plot_filename, plot = map_plot, width = 8, height = 7, dpi = 150, bg = "white")
    
  }, error = function(e) {
    cat("  Could not create plot for ZIP3:", zip3_code, "- Error:", e$message, "\n")
  })
  
# --- d. Prepare Centroids for Final Output ---
# Make sure both centroids use the standard geometry column name
geo_centroid_out <- st_sf(
  ZIP3 = zip3_code, 
  centroid_type = "Geometric",
  geometry = st_geometry(geo_centroid)
)

if (nrow(pw_centroid) > 0) {
  pw_centroid_out <- st_sf(
    ZIP3 = zip3_code, 
    centroid_type = "Population-Weighted",
    geometry = st_geometry(pw_centroid)
  )
  return(bind_rows(geo_centroid_out, pw_centroid_out))
} else {
  return(geo_centroid_out)
}

}

# --- 5. EXECUTE THE PROCESSING ---
# Split the main data frame into a list, where each element is a data frame for one ZIP3

zip3_conus_test <- zip3_conus #%>% filter(ZIP3 == "852")
zip_list <- split(zip3_conus_test, zip3_conus_test$ZIP3)
zip_codes <- names(zip_list)

# Use map2 to apply our function to each data frame and its corresponding ZIP code
# This returns a list of sf data frames.
all_centroids_list <- map2(zip_list, zip_codes, ~process_zip3(.x, .y))

# Combine the list of sf objects into a single sf data frame
final_centroids_sf <- bind_rows(all_centroids_list)

# --- 6. SAVE THE FINAL CENTROID DATA ---
cat("\nSaving all calculated centroids to", OUTPUT_FILE_CENTROIDS, "...\n")
st_write(final_centroids_sf, OUTPUT_FILE_CENTROIDS, delete_layer = TRUE)

cat("\n--- Script Finished Successfully! ---\n")

