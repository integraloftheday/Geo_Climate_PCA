# -----------------------------------------------------------------------------
# SCRIPT 1 (V3): Download, Process, and Save US Tract Data - CORRECTED
#
# Goal: Iterates through each state to download tract data, respecting
#       the Census API hierarchy. Provides progress feedback.
#
# Date: 2025-06-13
# -----------------------------------------------------------------------------

# Step 1: Setup - Load all necessary libraries
# install.packages(c("tidycensus", "sf", "ggplot2", "dplyr", "purrr", "viridis", "units"))

library(tidycensus)
library(sf)
library(ggplot2)
library(dplyr)
library(purrr)   # A great package for iteration/looping
library(viridis)
library(units)

# -----------------------------------------------------------------------------

# Step 2: Census API Key
#census_api_key("c6ed1644310a39153b62ae50b2ec5263425875c4", install = TRUE)

# -----------------------------------------------------------------------------

# --- START OF TIMED PROCESS ---
cat("=================================================================\n")
cat("Starting state-by-state data acquisition...\n")
start_time <- Sys.time()

# Step 3: Get a List of States to Iterate Over
# We'll use the built-in 'fips_codes' dataset and filter out territories
# we don't need for the lower 48 map.
states_to_get <- fips_codes %>%
  select(state_code, state_name) %>%
  distinct() %>%
  filter(!state_code %in% c("02", "15", "60", "66", "69", "72", "78")) # AK, HI, and territories

cat(paste("Found", nrow(states_to_get), "states/districts to process (Lower 48 + DC).\n"))

# Step 4: Download Data for Each State Using a Loop
# We use purrr::map() which is a clean and powerful way to loop.
# It will call get_acs for each state_code and return a list of data frames.
cat("-> Starting download loop...\n")

# Use 'safely' to make the loop robust. If one state fails, it won't crash.
safe_get_acs <- safely(get_acs)

all_tracts_list <- map(states_to_get$state_code, ~{
  state_fips <- .x
  state_name <- states_to_get$state_name[states_to_get$state_code == state_fips]
  
  cat(paste("   - Processing:", state_name, "(FIPS:", state_fips, ")...\n"))
  
  result <- safe_get_acs(
    geography = "tract",
    variables = "B01003_001",
    state = state_fips,
    year = 2022,
    geometry = TRUE
  )
  
  if (!is.null(result$error)) {
    cat(paste("   !!! ERROR for", state_name, ":", result$error, "\n"))
    return(NULL) # Return NULL if there was an error
  }
  
  return(result$result) # Return the successful data frame
})

cat("-> Download loop complete.\n")

# Step 5: Combine, Process, and Save the Final Data
cat("-> Combining and processing the downloaded data...\n")

# Combine the list of data frames into a single sf object
us_tracts_processed <- all_tracts_list %>%
  # Remove any NULLs from failed downloads
  compact() %>%
  # Bind all data frames together
  bind_rows() %>%
  # Transform to a standard US projection
  st_transform(crs = 2163) %>%
  # Calculate area and density
  mutate(
    area_sq_km = set_units(st_area(.), "km^2"),
    density = estimate / area_sq_km
  ) %>%
  # Final column selection and renaming
  select(
    GEOID,
    NAME,
    population = estimate,
    pop_error = moe,
    area_sq_km,
    density,
    geometry
  )

cat("-> Saving processed data to 'us_tracts_population_density_2022.gpkg'...\n")
st_write(us_tracts_processed, "./data/us_tracts_population_density_2022.gpkg", delete_dsn = TRUE, quiet = TRUE)
cat("   ...File successfully saved.\n")

# --- END OF TIMED PROCESS ---
end_time <- Sys.time()
total_time <- difftime(end_time, start_time, units = "mins")

cat("=================================================================\n")
cat("All steps complete!\n")
cat(paste0("Total execution time: ", round(total_time, 2), " minutes.\n"))
cat("The file 'us_tracts_population_density_2022.gpkg' is ready.\n")
cat("=================================================================\n")
