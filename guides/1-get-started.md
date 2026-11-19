# Getting started

Install epiviewVPD from GitHub and use the included artificial data to open and
explore the core interactive dashboard.

## Requirements

- R version 4.5 or newer
- An internet connection for installation and to generate the background maps
- RStudio is recommended because Pandoc is required to download dashboard
  reports

## Install epiviewVPD

```r
install.packages("remotes")
remotes::install_github("MADM-C/epiviewVPD", upgrade = "never")
```

The first line installs remotes, a tool for installing R packages from GitHub.
The second installs epiviewVPD and its required packages. Initial installation
may take several minutes. If prompted to install packages from source, enter
`no`.

To update epiviewVPD, rerun the `install_github()` command.

For installation errors, see [Troubleshooting](6-troubleshooting.md#installation).

## Open the interactive dashboard

In the R Console, run:

```r
library(epiviewVPD)
run_dashboard(data_dir = example_data_dir())
```

The example uses artificial data, including artificial vaccine coverage data
and artificial state and county boundaries. To stop the dashboard, close its
window and click **Stop** in the Console or press **Esc**.

The core dashboard includes county and school vaccination coverage, historical
case data, summary figures, and an About tab. To view the optional features
with the artificial data, including the Proximity Map and Resources tab, see
[View the full dashboard](5-adding-more.md#view-the-full-dashboard) in the
Adding more guide.

## Next steps

- [Data format](2-data-format.md): Review the required files and variables.
- [Dashboard guide](3-own-data.md): Configure the dashboard to use your data
- [Maps and charts without the dashboard](4-visualizations.md): Build and save
  standalone visualizations
- [Adding more](5-adding-more.md): Configure optional dashboard features.
