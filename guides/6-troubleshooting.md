# Troubleshooting

This guide brings together fixes for installation errors, data errors,
dashboard warnings, and problems saving visualizations. Find the message that
matches what you see, then follow the suggested steps.

- [Installation](#installation)
- [Data errors](#data-errors)
- [Warnings](#warnings)
- [Saving visualizations](#saving-visualizations)
- [Getting help](#getting-help)

## Installation

For installation instructions and requirements, see [Getting
started](1-get-started.md).

| Error message | Explanation |
|---|---|
| `cannot remove prior installation of package`, or `Permission denied` | A package being updated is in use. Close all R and RStudio windows, reopen RStudio, and run the two installation lines before running any other code. |
| `this R is version ..., package 'epiviewVPD' requires R >= 4.5.0` | Install R version 4.5 or newer. |
| `dependencies ... are not available for package 'epiviewVPD'` | A required package did not install. Scroll up to the first error message and check whether it appears in this table. If your R version is older than 4.5, install R version 4.5 or newer. You can check your version with `R.version.string`. |
| `there is no package called 'remotes'` | Run `install.packages("remotes")` first. |

## Data errors

If there’s a formatting issue with the data, the dashboard stops and lists the
file, column, and rows where the formatting issue was detected. **epiviewVPD is
not able to check if vaccination counts and percentages agree or whether a
school’s listed county or district matches its actual location.** These data
checks should be performed before inputting your own data into the package.

| Error Message | What to do |
|---|---|
| `missing files required by enabled features` | Add the file, or turn off the features that use it |
| `missing required column` | Add the column with that exact name, even if every value is blank |
| `CSV fields do not match the header` | A row has the wrong number of commas. Put quotes around text that contains commas, and write numbers without them |
| `should hold numbers but has` | Remove commas or text. If it's a withheld code, add it to `redacted_codes` in `my_settings.R` |
| `must contain percentages from 0 to 100` | Use a value like `92.4`, `>95`, or blank. Look for values over 100, `>=95`, or `N/A` |
| `county_fips value(s) not in` | Use the boundary's exact code. Check whether Excel removed leading zeros |
| `county name(s) not in` | Use the boundary's name, without "County", or fill in `county_fips` |
| `have no county_fips to match` | Add `county_fips` to the boundary file, or use `county_name` in the CSV |
| `neither county_fips nor county_name` | Fill in one of them |
| `appear more than once`, `records must be unique` | Remove the repeated row. For cases, check for an all-ages row |
| `isn't in the settings' case_age_groups` | Add the group to `case_age_groups` in `my_settings.R`, or fix its spelling. Check for a long dash |
| `have no latitude/longitude`, `only one of latitude and longitude` | Fill in both coordinates |
| `coordinates outside -90..90` | Check for swapped latitude and longitude |
| `must match a school_id` | Fix the `school_id` in `grades.csv`, or add the school to `schools.csv` |
| `grade must use K or 0` | Use `K` or `0`, then `1` to `12`. Remove all-grades rows |
| `district_id(s) not in` | Use the exact boundary ID. Check `district_type` on the `geography` line of `my_settings.R` |
| `reporting_status must be` | Use `reported`, `not_reported`, or blank, in lowercase |
| `isn't in the data folder`, `Couldn't download the Census` | Add the boundary file, or set your state on the `geography` line of `my_settings.R` and check your internet |
| `must use Polygon or MultiPolygon`, `must contain valid polygons` | Fix the shapes, for example with `sf::st_make_valid()`, and save again |

After correcting a data file, save it and rerun the dashboard command. For
file and variable requirements, see the [Data format guide](2-data-format.md).

## Warnings

The dashboard still starts with these two warnings:

| The warning says | What to do |
|---|---|
| `have a district_id not in` | Those schools have no linked district. Fix any mistyped IDs |
| `isn't saved as UTF-8` | Check the file's accented names, and save it as "CSV UTF-8" |

## Saving visualizations

Saving to an existing file produces an error. Add `overwrite = TRUE` to replace
it.

If a saved HTML map does not display correctly, check that its companion
folder (such as `coverage-map_files`) is kept beside the HTML file. Keep the
two together when copying or sharing the map.

For export examples, see [Save visualizations](4-visualizations.md#save-visualizations).
For the additional software needed to save maps as PNG or tables as PNG or
PDF, see [Build additional visualizations in
R](5-adding-more.md#build-additional-visualizations-in-r).

## Getting help

- **Found a bug or something unclear?** Open an issue on [GitHub
  Issues](https://github.com/MADM-C/epiviewVPD/issues). Include the code you
  ran, the full error message, and the output of `R.version.string` and
  `packageVersion("epiviewVPD")`. Please don't attach real data; use the
  pre-provided artificial data or a few made-up rows that show the problem.
- **Email:** Alternatively, you can email our team at
  [madmc@umn.edu](mailto:madmc@umn.edu)
