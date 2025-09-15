# ————————————————————————————————————————————————————————————————
# 0) Load libraries
# ————————————————————————————————————————————————————————————————
# remotes::install_github("hypertidy/L3bin")  # if not yet installed
library(L3bin)
library(tidyr)
library(dplyr)
library(ncdf4)
library(data.table)
library(ggplot2)

# ————————————————————————————————————————————————————————————————
# 1) Define your helper functions
# ————————————————————————————————————————————————————————————————

convert_mapped_to_binned <- function(filen, resolution) {
  nc <- nc_open(filen)
  
  # read coordinates
  lat <- ncvar_get(nc, "lat")   # length 1440
  lon <- ncvar_get(nc, "lon")   # length 4896
  
  # bands to extract
  bands <- c("rrs_412", "rrs_443", "rrs_490", "rrs_510", "rrs_560", "rrs_665")
  
  # read & flip each band
  band_data <- lapply(bands, function(band) {
    m <- ncvar_get(nc, band)
    # if needed: m <- m[rev(seq_len(nrow(m))), ]
    m
  })
  
  nc_close(nc)
  
  # build coordinate grid
  grid <- expand.grid(lat = lat, lon = lon)
  
  # combine bands into one data.table
  df <- as.data.table(grid)
  for (i in seq_along(bands)) {
    df[[bands[i]]] <- as.vector(band_data[[i]])
  }
  
  # drop any rows with NA across bands
  df <- df[complete.cases(df), ]
  
  # determine number of rows for binning
  if (resolution == 1) NUMROWS <- 17280
  if (resolution == 2) NUMROWS <- 8640
  if (resolution == 4) NUMROWS <- 4320
  if (resolution == 9) NUMROWS <- 2160
  
  # compute OBPG bin index
  df[, bin_num := bin_from_lonlat(lon, lat, NUMROWS)]
  
  # aggregate by bin_num
  df_binned <- df[, c(
    list(lon = mean(lon, na.rm = TRUE),
         lat = mean(lat, na.rm = TRUE)),
    lapply(.SD, mean, na.rm = TRUE)
  ),
  by = bin_num,
  .SDcols = bands
  ]
  
  # rename / interpolate bands
  df_final <- df_binned %>%
    transmute(
      lat       = lat,
      lon       = lon,
      bin_index = bin_num,
      Rrs412    = rrs_412,
      Rrs443    = rrs_443,
      Rrs488    = rrs_490,
      Rrs490    = rrs_490,
      Rrs510    = rrs_510,
      # linear interp from 510→560 to get 531
      Rrs531    = rrs_510 + (531 - 510) / (560 - 510) * (rrs_560 - rrs_510),
      Rrs555    = rrs_560,
      Rrs560    = rrs_560,
      Rrs665    = rrs_665,
      Rrs667    = rrs_665
    )
  
  return(df_final)
}


write_l3bin_netdcf <- function(df_final, filen) {
  # define dimensions
  lat_dim <- ncdim_def("lat", "degrees_north", df_final$lat)
  lon_dim <- ncdim_def("lon", "degrees_east", df_final$lon)
  bin_dim <- ncdim_def("bin", "index", df_final$bin_index)
  
  # helper to create a variable
  make_var <- function(name, longname, units="sr^-1") {
    ncvar_def(name, units, bin_dim, missval = -999L, longname = longname, prec="float")
  }
  
  vars <- list(
    make_var("Rrs412", "Remote sensing reflectance at 412 nm"),
    make_var("Rrs443", "Remote sensing reflectance at 443 nm"),
    make_var("Rrs488", "Remote sensing reflectance at 488 nm"),
    make_var("Rrs490", "Remote sensing reflectance at 490 nm"),
    make_var("Rrs510", "Remote sensing reflectance at 510 nm"),
    make_var("Rrs531", "Remote sensing reflectance at 531 nm"),
    make_var("Rrs555", "Remote sensing reflectance at 555 nm"),
    make_var("Rrs560", "Remote sensing reflectance at 560 nm"),
    make_var("Rrs665", "Remote sensing reflectance at 665 nm"),
    make_var("Rrs667", "Remote sensing reflectance at 667 nm"),
    ncvar_def("lat",       "degrees_north", bin_dim, missval = -9999., longname="latitude",  prec="float"),
    ncvar_def("lon",       "degrees_east",  bin_dim, missval = -9999., longname="longitude", prec="float"),
    ncvar_def("bin_index","1",              bin_dim, missval = -999L, longname="bin index",   prec="integer")
  )
  
  # create & write
  nc_out <- nc_create(filen, vars)
  ncvar_put(nc_out, "Rrs412",    df_final$Rrs412)
  ncvar_put(nc_out, "Rrs443",    df_final$Rrs443)
  ncvar_put(nc_out, "Rrs488",    df_final$Rrs488)
  ncvar_put(nc_out, "Rrs490",    df_final$Rrs490)
  ncvar_put(nc_out, "Rrs510",    df_final$Rrs510)
  ncvar_put(nc_out, "Rrs531",    df_final$Rrs531)
  ncvar_put(nc_out, "Rrs555",    df_final$Rrs555)
  ncvar_put(nc_out, "Rrs560",    df_final$Rrs560)
  ncvar_put(nc_out, "Rrs665",    df_final$Rrs665)
  ncvar_put(nc_out, "Rrs667",    df_final$Rrs667)
  ncvar_put(nc_out, "lat",       df_final$lat)
  ncvar_put(nc_out, "lon",       df_final$lon)
  ncvar_put(nc_out, "bin_index", df_final$bin_index)
  nc_close(nc_out)
}


# ————————————————————————————————————————————————————————————————
# 2) Set working directory for your mapped‐.nc inputs
# ————————————————————————————————————————————————————————————————
setwd("/Volumes/aquatel-data/homeData/PP_res/CCI/rrs_geo_dineof_plus_daily_nc")


# ————————————————————————————————————————————————————————————————
# 3) Single‐file test (optional)
# ————————————————————————————————————————————————————————————————
test_file    <- "20030710_rrs_1km_rct.nc"
test_binned  <- convert_mapped_to_binned(test_file, resolution = 1)
test_out     <- sub("\\.nc$", "_l3bin.nc", test_file)
write_l3bin_netdcf(test_binned, test_out)


# ————————————————————————————————————————————————————————————————
# 4) Batch‐process all daily .nc from May–Oct 2003–2011 → SMB share
# ————————————————————————————————————————————————————————————————
# (a) list all inputs
all_ncs <- list.files(pattern = "\\.nc$", full.names = TRUE)

# (b) filter by date in filename
batch_files <- tibble(filen = all_ncs) %>%
  mutate(
    fname = basename(filen),
    date  = as.Date(substr(fname, 1, 8), format = "%Y%m%d"),
    year  = as.integer(format(date, "%Y")),
    month = as.integer(format(date, "%m"))
  ) %>%
  filter(year >= 2021, year <= 2024, month >= 4, month <= 10) %>%
  pull(filen)

# (c) define and prepare output directory
out_dir <- "/Volumes/aquatel-data/homeData/PP_res/CCI/rrs_sin_dineof_plus_daily_nc"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# (d) loop through and convert
for (f in batch_files) {
  message("→ Processing ", basename(f))
  out_name <- sub("\\.nc$", "_l3bin.nc", basename(f))
  out_path <- file.path(out_dir, out_name)
  
  df_bin <- convert_mapped_to_binned(f, resolution = 1)
  write_l3bin_netdcf(df_bin, out_path)
}


# ————————————————————————————————————————————————————————————————
# 5) Facultatif: quick ggplot check of the last‐processed 'test_binned'
# ————————————————————————————————————————————————————————————————
if (interactive()) {
  ggplot(test_binned, aes(x = lon, y = lat, color = Rrs510)) +
    geom_point(size = 0.1) +
    scale_color_viridis_c(trans="log10", limits = c(1e-4, 2e-2)) +
    coord_fixed() +
    labs(
      title = "Produit L3bin - Rrs443",
      x     = "Longitude",
      y     = "Latitude"
    ) +
    theme_minimal()
}
