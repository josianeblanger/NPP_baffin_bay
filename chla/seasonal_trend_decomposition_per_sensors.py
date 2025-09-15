from statsmodels.tsa.seasonal import seasonal_decompose
from scipy.stats import linregress
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

# Load the data
df = pd.read_csv("/Volumes/JLB_SSD/master/interpolation_data/dineof_plus/baffin_bay_sm_js_ls/chla_dineofplus_bb_js_ls/Baffin_rct_raster/mean_chl_values.csv")

# Create a datetime index from year and month
df['date'] = pd.to_datetime(df[['Year', 'Month']].assign(day=1))  # assuming day=1 for monthly data
df.set_index('date', inplace=True)

# Perform seasonal decomposition
result = seasonal_decompose(df['MeanChl'], model='additive', period=5)

# Convert the datetime index to numerical years
df['numeric_year'] = df.index.year + (df.index.month - 1) / 12.0  # Fractional year representation
numeric_years = df['numeric_year'].values
chl = df['MeanChl'].values

# Perform linear regression to find the trend
slope, intercept, r_value, p_value, std_err = linregress(numeric_years, chl)

# Calculate the trend line
trend_line = intercept + slope * numeric_years

# Calculate R-squared from the r_value
r_squared = r_value**2

# Access trend, seasonal, and residual components
trend = result.trend
residual = result.resid

# Define sensor periods and their colors
sensor_periods = [
    ('1998-01-01', '2003-12-31', '#5DCACF', 'SeaWiFS'),
    ('2003-01-01', '2008-12-31', '#488759', 'SeaWiFS + MODIS + MERIS'),
    ('2008-01-01', '2012-12-31', '#E8A769', 'MERIS + MODIS'),
    ('2012-01-01', '2016-12-31', '#BF625F', 'MODIS'),
    ('2016-01-01', '2020-12-31', 'black', 'MODISS3A-OLCI'),
]

# Helper function to plot colored sections
def plot_colored_sections(ax, x, y, periods):
    for start, end, color, label in periods:
        start_date = pd.to_datetime(start)
        end_date = pd.to_datetime(end)
        section = (x >= start_date) & (x < end_date)
        ax.plot(x[section], y[section], color=color, label=label, linewidth=2)

# Plot each component separately
fig, axes = plt.subplots(4, 1, figsize=(12, 12), sharex=True)
fig.suptitle('Time Series Components of MeanChl', fontsize=16)

# Original with sections and linear trend
axes[0].plot(df.index, df['MeanChl'], color='white', alpha=0.5, label='Original')
plot_colored_sections(axes[0], df.index, df['MeanChl'], sensor_periods)

# Add linear trend line with R²
axes[0].plot(df.index, trend_line, color='black', linestyle='--', label=f'Trend Line (R²={r_squared:.2f})')

# Adjust legend to the right side
axes[0].legend(loc='center left', bbox_to_anchor=(1.0, 0.5), fontsize=10)
axes[0].set_ylabel('MeanChl')

# Trend with sections
axes[1].plot(df.index, trend, color='white', alpha=0.5, label='Trend')
plot_colored_sections(axes[1], df.index, trend, sensor_periods)
axes[1].legend(loc='center left', bbox_to_anchor=(1.0, 0.5), fontsize=10)
axes[1].set_ylabel('Trend')


# Residual with sections
axes[3].plot(df.index, residual, color='gray', alpha=0.5, label='Residual')
plot_colored_sections(axes[3], df.index, residual, sensor_periods)
axes[3].legend(loc='center left', bbox_to_anchor=(1.0, 0.5), fontsize=10)
axes[3].set_ylabel('Residual')

# Set x-axis ticks to show all years
all_years = pd.date_range(start='1998', end='2020', freq='YS')
plt.xticks(all_years, [year.year for year in all_years], rotation=90)

plt.xlabel('Year')
plt.tight_layout(rect=[0, 0.05, 1, 0.95])
plt.show()
