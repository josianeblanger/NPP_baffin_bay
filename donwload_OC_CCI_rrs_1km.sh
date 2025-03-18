#dowload CCI data via plymouth server
#Author : Josiane Lavoie-Bélanger
#!/usr/bin/env bash

# Local folder for downloaded files
BASE_DIR="/Volumes/JLB_SSD/master/chla_data/rrs_1km_cci"

# Start/end years
START_YEAR=1998
END_YEAR=2024

# Variables you want from NCSS (separated by &var=)
VARS="var=Rrs_412&var=Rrs_443&var=Rrs_490&var=Rrs_510&var=Rrs_560&var=Rrs_665"

# Geographic bounding box
NORTH="79.994789"
WEST="-96.994789"
EAST="-46.005207"
SOUTH="65.005211"

# Server root (ncss)
SERVER_ROOT="https://www.oceancolour.org/thredds/ncss/cci/v6.0-1km-release/geographic"

# File naming pattern
FILENAME_PREFIX="ESACCI-OC-L3S-OC_PRODUCTS-MERGED-1D_DAILY_1km_GEO_PML_OCx_QAA-"
FILENAME_SUFFIX="-fv6.0_1km.nc"

for year in $(seq $START_YEAR $END_YEAR); do
    echo "=== YEAR $year ==="

    # Make directory for this year
    mkdir -p "$BASE_DIR/$year"

    # Loop from April (04) to October (10)
    for month in $(seq -w 4 10); do

        # Loop over possible days (1..31)
        for day in $(seq -w 1 31); do
            # Construct YYYYMMDD, e.g. 20100501
            date_yyyymmdd="${year}${month}${day}"

            # Construct yyyy-mm-dd, e.g. 2010-05-01
            date_yyyy_mm_dd="${year}-${month}-${day}"

            # Build filename, e.g. ESACCI-OC-...-20100501-fv6.0_1km.nc
            filename="${FILENAME_PREFIX}${date_yyyymmdd}${FILENAME_SUFFIX}"

            # Full NCSS URL for this day
            url="${SERVER_ROOT}/${year}/${filename}?${VARS}&north=${NORTH}&west=${WEST}&east=${EAST}&south=${SOUTH}&horizStride=1&time_start=${date_yyyy_mm_dd}T00%3A00%3A00Z&time_end=${date_yyyy_mm_dd}T00%3A00%3A00Z&timeStride=1&addLatLon=true&accept=netcdf"

            # Local output path
            outpath="$BASE_DIR/$year/$filename"

            echo "Trying date: $date_yyyy_mm_dd"
            wget -q --show-progress -O "$outpath" "$url"

            # If wget returned an error (e.g. 404), remove file & skip
            if [[ $? -ne 0 ]]; then
                rm -f "$outpath"
                echo "  -> Not found or error. Skipped."
            fi
        done
    done
done

echo "All done!"
