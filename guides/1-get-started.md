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

## Installation troubleshooting

| Error message | Explanation |
|---|---|
| `cannot remove prior installation of package`, or `Permission denied` | A package being updated is in use. Close all R and RStudio windows, reopen RStudio, and run the two installation lines before running any other code. |
| `this R is version ..., package 'epiviewVPD' requires R >= 4.5.0` | Install R version 4.5 or newer. |
| `dependencies ... are not available for package 'epiviewVPD'` | A required package did not install. Scroll up to the first error message and check whether it appears in this table. If your R version is older than 4.5, install R version 4.5 or newer. You can check your version with `R.version.string`. |
| `there is no package called 'remotes'` | Run `install.packages("remotes")` first. |

For other issues, open a [GitHub
Issue](https://github.com/MADM-C/epiviewVPD/issues) with the code, full error
message, and output of `R.version.string` and `packageVersion("epiviewVPD")`.
Please don't attach real data. You can also email our team at:
[madmc@umn.edu](mailto:madmc@umn.edu).
