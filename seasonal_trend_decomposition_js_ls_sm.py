# Python code for Multiple Seasonal-Trend decomposition using LOESS (MSTL) with statsmodels v.0.15.0 (Skipper, S., & Josef, P. (2010). statsmodels: Econometric and statistical modeling with python. 9th Python in Science Conference) 
# Apply on Surface Chlorophyll-a OC-CCI dataset
# Monthly Mean chl-a values for each year were compiled into a CSV 
# Cluster with study area (Jones Sound, Lancaster Sound and Smith Sound) and the absence of sea ice arch in the ROI for a specific year 
#Author : Josiane Lavoie-Bélanger

# ---------------------------
from statsmodels.tsa.seasonal import seasonal_decompose
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# ---------------------------
# 1. LOAD MAIN CHLOROPHYLL DATA
# ---------------------------
# CSV with columns: Year, Month, Region, MeanChl
chl_csv = r"/Volumes/JLB_SSD/master/interpolation_data/dineof_plus/baffin_bay_sm_js_ls/chla_dineofplus_bb_js_ls/Baffin_rct_raster/mean_chl_values_LS_JS_SS.csv"
df = pd.read_csv(chl_csv)  # assumed comma-delimited
# Create a datetime index (assume day=1 for each month)
df['date'] = pd.to_datetime(df[['Year', 'Month']].assign(day=1))
df.set_index('date', inplace=True)
df.sort_index(inplace=True)

# ---------------------------
# 2. LOAD ARCH INFO DATA (csv ; semicolon-delimited)
# ---------------------------
arch_csv = r"/Volumes/JLB_SSD/master/sea_ice_arch/arch_or_not_year.csv"
arch_df = pd.read_csv(arch_csv, sep=';')
# Clean column names
arch_df.columns = arch_df.columns.str.strip()
print("Arch info columns:", arch_df.columns.tolist())
print(arch_df.head())

# ---------------------------
# 3. SETUP REGION MAPPING AND COLORS
# ---------------------------
# In the main CSV, regions are full names ("Lancaster", "Jones", "Smith").
# In the arch CSV, regions are given as "LS", "JS", "SS".
region_mapping = {"Lancaster": "LS", "Jones": "JS", "Smith": "SS"}
regions = df['Region'].unique()
print("Regions in main CSV:", regions)

# Define default colors for each region (used for plotting continuous lines)
region_colors = {"Lancaster": "blue", "Jones": "orange", "Smith": "green"}

# ---------------------------
# 4. PREPARE FIGURE WITH 3 PANELS
# ---------------------------
fig, axes = plt.subplots(3, 1, figsize=(14, 12), sharex=True)
fig.suptitle("Chlorophyll-a: Time Series, Decomposed Trend, and Residual", fontsize=16)

# ---------------------------
# 5. PROCESS EACH REGION
# ---------------------------
for region in regions:
    df_region = df[df['Region'] == region].copy()
    if df_region.empty:
        continue
    df_region.sort_index(inplace=True)
    
    # --- Panel 1: Plot continuous observed MeanChl time series ---
    axes[0].plot(df_region.index, df_region['MeanChl'],
                 color=region_colors.get(region, 'black'),
                 linestyle='-', linewidth=1.5,
                 label=region)
    
    # --- Seasonal decomposition for Panels 2 & 3 ---
    try:
        result = seasonal_decompose(df_region['MeanChl'], model='additive', period=5)
        trend_decomp = result.trend
        resid = result.resid
    except Exception as e:
        print(f"Error decomposing region {region}: {e}")
        trend_decomp = np.full_like(df_region['MeanChl'], np.nan)
        resid = np.full_like(df_region['MeanChl'], np.nan)
    
    axes[1].plot(df_region.index, trend_decomp,
                 color=region_colors.get(region, 'black'),
                 linestyle='-', linewidth=1.5,
                 label=region)
    axes[2].plot(df_region.index, resid,
                 color=region_colors.get(region, 'black'),
                 linestyle='-', linewidth=1.5,
                 label=region)
    
    # ---------------------------
    # Overlay tick markers (squares) on each panel if "no arch" for that year
    # ---------------------------
    # Compute annual means for the original series, decomposed trend, and residual
    annual_mean = df_region.resample('A')['MeanChl'].mean()
    annual_trend = trend_decomp.resample('A').mean()
    annual_resid = resid.resample('A').mean()
    # Change indices to integer years
    years_annual = annual_mean.index.year
    
    # Map region to arch code (e.g., "Lancaster" -> "LS")
    arch_code = region_mapping.get(region, region)
    arch_region_df = arch_df[arch_df['Region'] == arch_code]
    
    for yr, orig_val, trend_val, resid_val in zip(years_annual, annual_mean, annual_trend, annual_resid):
        marker_date = pd.to_datetime(f"{yr}-07-01")
        # Lookup arch info for this year
        arch_info = arch_region_df[arch_region_df['Year'] == yr]
        if not arch_info.empty:
            arch_status = str(arch_info.iloc[0]['Arch']).strip().lower()
        else:
            arch_status = "arch"  # assume arch if missing
        
        # Only plot tick if arch is "no arch"
        if arch_status == "no arch":
            # Plot on Panel 1 using original series annual mean
            axes[0].scatter(marker_date, orig_val,
                            color=region_colors.get(region, 'black'),
                            marker='s', s=100, edgecolors='black', zorder=5)
            # Plot on Panel 2 using decomposed trend annual mean
            axes[1].scatter(marker_date, trend_val,
                            color=region_colors.get(region, 'black'),
                            marker='s', s=100, edgecolors='black', zorder=5)
            # Plot on Panel 3 using residual annual mean
            axes[2].scatter(marker_date, resid_val,
                            color=region_colors.get(region, 'black'),
                            marker='s', s=100, edgecolors='black', zorder=5)

# ---------------------------
# 6. FINALIZE THE PLOTS
# ---------------------------
axes[0].set_ylabel("MeanChl")
axes[1].set_ylabel("Decomposed Trend")
axes[2].set_ylabel("Residual")
axes[2].set_xlabel("Year")

# Set x-axis ticks to show each year from min to max date
all_years = pd.date_range(start=df.index.min(), end=df.index.max(), freq='YS')
axes[2].set_xticks(all_years)
axes[2].set_xticklabels([d.year for d in all_years], rotation=45)

# Remove duplicate legend entries for each subplot
for ax in axes:
    handles, labels = ax.get_legend_handles_labels()
    unique = dict(zip(labels, handles))
    ax.legend(unique.values(), unique.keys(), loc='upper left', fontsize=9)

plt.tight_layout(rect=[0, 0.03, 1, 0.95])
plt.show()

