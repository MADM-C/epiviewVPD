# Data format

This guide is the full reference for the data files. The basic dashboard needs
only the first three; [Adding more](5-adding-more.md) covers the optional
extras. It uses the `app_data` folder and `my_settings.R` file from
[Run the dashboard with your data](3-own-data.md).

The made-up example files show the format. To find them on your computer, run:

```r
library(epiviewVPD)
example_data_dir()         # the three basic files
example_data_dir("full")   # every file
```

## Which files you need

The basic dashboard needs three files: `counties.csv`, `schools.csv`, and
`cases.csv`. Everything else is optional. Save all of them in your `app_data`
folder.

| File | One row per | What it's for |
|---|---|---|
| `counties.csv` | County | Basic dashboard: county coverage map |
| `schools.csv` | School | Basic dashboard: school map and table |
| `cases.csv` | County, year, and age group | Basic dashboard: case map, table, and chart |
| `facilities.csv` | Child care program | [Child cares](5-adding-more.md#child-cares) |
| `grades.csv` | School and grade | [Grade-level coverage](5-adding-more.md#grade-level-coverage) |
| `districts.csv` | School district | [School districts](5-adding-more.md#school-districts) |
| `healthcare_centers.csv` | Healthcare location | [Proximity search](5-adding-more.md#proximity-search) |
| `county_boundaries.geojson` | County | Optional. Downloads from the Census if left out |
| `district_boundaries.geojson` | School district | Optional. Downloads from the Census if left out |

If a feature is turned on and its file is missing, the dashboard stops and
names the file.

## Rules for every file

- Save CSV files as comma-separated text with a header row. In Excel, choose
  "CSV UTF-8". A plain "CSV" file still loads, with a warning to check its
  accented names.
- File and column names must match exactly, including capitalization.
- **Required** columns must be in the file. **Optional** columns can be left
  out.
- **Leave unknown values blank** and keep the column. IDs and names can't be
  blank.
- Extra columns are ignored, but every column needs its own nonblank header.

| Kind of value | How to write it |
|---|---|
| IDs | Text. Excel removes leading zeros from codes like `01001`, so check them before saving. Leading zeros aren't added for you |
| Counts | Whole numbers, `0` or more, without commas: `1250` |
| Coverage percentages (`full_vax_pct`, `partial_vax_pct`, `medical_pct`, `nonmedical_pct`) | `0` to `100`: `92.4`, not `0.924` (which loads, but means under 1%). A trailing `%` is allowed. Can be a range such as `>95` or `<5` |
| Demographic percentages (`students_of_color_pct`, `frl_eligible_pct`) | Plain numbers from `0` to `100`, without `%` or ranges |
| Latitude, longitude | Decimal degrees: `44.95`, `-93.09`. Every school needs both. A child care program with no known location can leave both blank |
| Years | Whole calendar years: `2024` |

### Blank, zero, and withheld values

`0` means a real zero, and blank means unknown. Don't write `0` for a value you
don't have or can't share.

If your data marks withheld values with a code, such as `*`, list it in
`my_settings.R`. Find this line:

```r
redacted_codes = character(0),
```

and change it to list your codes:

```r
redacted_codes = c("*", "S"),
```

Those codes then count as blank. Other text in a number column, such as `N/A`,
stops the dashboard.

Ranges such as `>95` show as written. To choose a map color, the dashboard
moves a range 1 point past its number, so `>95` counts as 96 and `<5` as 4. To
change that 1, change `blurred_offset = 1` in `my_settings.R`.

### Schools and counties that didn't report

`counties.csv`, `schools.csv`, `facilities.csv`, `grades.csv`, and
`districts.csv` can have a `reporting_status` column. Write `reported`,
`not_reported`, or leave it blank.

A `not_reported` row shows its vaccination values as unknown, and keeps its
name and enrollment. Each file stands on its own: a school marked
`not_reported` in `schools.csv` doesn't change its rows in `grades.csv`.

### Coverage and counts

Enter `full_vax_pct` as reported. The dashboard doesn't recalculate it from
counts. If a percentage is withheld, leave its count blank too, so the count
doesn't give it away.

The statewide rate above the county map is the sum of `full_vax` divided by
the sum of `enroll`. It needs both filled in for every county, and reads
"Unknown" if some are blank.

## How counties are matched

Each row finds its county in this order:

1. `county_fips`, matching exactly.
2. `county_name`, ignoring capitalization.
3. Latitude and longitude, for schools and child cares with both county
   columns blank.

A `county_fips` with no match stops the dashboard. It doesn't fall back to the
name. Fill in a county for schools near a county line, where the coordinates
may place them in the wrong county.

- **Census boundaries:** `county_fips` is the 5-character code (`"01001"`).
  `county_name` is the Census name without "County". Where a city and county
  share a name, such as Baltimore, MD, `Baltimore` is the county and
  `Baltimore city` is the city.
- **Your own boundaries:** use the exact names or codes in your file.

Each county can appear in `counties.csv` only once. A county with no row shows
unknown coverage.

## School districts

`district_id` must match exactly in `districts.csv`, `schools.csv`, and the
district boundaries. There is no matching by name.

- Census boundaries use the 7-character Census district code.
- Your own boundaries can use any text ID that matches across files, such as
  `"0001"`.
- A `districts.csv` ID with no boundary stops the dashboard. A boundary with no
  row shows unknown coverage.
- A school with a blank `district_id` has no district. It still shows in county
  maps, tables, and reports. A `district_id` that matches nothing gives a
  warning.

## Boundary files

**Census boundaries.** Leave the boundary files out, and the dashboard
downloads them for the state on the `geography` line of `my_settings.R`
([step 4](3-own-data.md#step-4-set-your-state)). You can also choose the type
of school district (`"unified"`, `"elementary"`, or `"secondary"`) and the
Census year:

```r
geography = list(state = "WI", district_type = "unified", year = 2023),
```

The download needs internet the first time and is saved for later. Match the
district type and year to your data.

**Your own boundaries.** A boundary file in your `app_data` folder is used
instead of the download. It needs:

- One shape per county or district, with no repeats.
- Valid Polygon or MultiPolygon shapes.
- Coordinates in longitude and latitude (EPSG:4326). A file in another
  coordinate system is converted if the file says which one it uses.
- The properties below.

### `county_boundaries.geojson`

| Property | Needed? | What to put in it |
|---|---|---|
| `county_name` | Required | County name, different for each county |
| `county_fips` | Optional | County code as text. Needed if your CSV files use `county_fips` |

### `district_boundaries.geojson`

| Property | Needed? | What to put in it |
|---|---|---|
| `district_id` | Required | District ID, different for each district |

### Convert a shapefile

To turn a shapefile into a GeoJSON file:

```r
bounds <- sf::st_read("my_counties.shp")
bounds <- sf::st_transform(bounds, 4326)
# Replace NAME with the column that holds your county names.
names(bounds)[names(bounds) == "NAME"] <- "county_name"
sf::st_write(bounds, "app_data/county_boundaries.geojson", delete_dsn = TRUE)
```

## `counties.csv`

One row per county, for one reporting period.

| Column | Needed? | What to put in it |
|---|---|---|
| `county_fips`, `county_name` | One of them | County code or name. Each row needs at least one |
| `enroll` | Required | Number of students enrolled |
| `full_vax_pct` | Required | Percent fully vaccinated |
| `full_vax` | Optional | Number fully vaccinated. Adds the statewide rate above the county map |
| `students_of_color_pct` | Optional | Percent students of color. Shown in the county pop-up |
| `frl_eligible_pct` | Optional | Percent eligible for free or reduced-price meals. Shown in the county pop-up |
| `reporting_status` | Optional | `reported` or `not_reported` |

## `schools.csv`

One row per school.

| Column | Needed? | What to put in it |
|---|---|---|
| `school_id` | Required | A unique ID. Links to `grades.csv` |
| `school_name` | Required | The name to display |
| `latitude`, `longitude` | Required | Decimal degrees. Needed to place the school on the map |
| `enroll` | Required | Number of students enrolled |
| `full_vax_pct` | Required | Percent fully vaccinated |
| `county_fips`, `county_name` | Optional | The school's county. Found from the coordinates if both are blank |
| `school_type` | Optional | A label such as `Public`, `Private`, or `Charter` |
| `full_vax` | Optional | Number fully vaccinated |
| `partial_vax` | Optional | Number partly vaccinated or with no doses |
| `partial_vax_pct` | Optional | Percent partly vaccinated or with no doses |
| `medical_pct`, `nonmedical_pct` | Optional | Percent with medical or nonmedical exemptions |
| `grade_range` | Optional | A label such as `K-5`, shown in the school map pop-up |
| `district_id` | Optional | The school's district. Blank if it has none |
| `home_languages` | Optional | Languages spoken at home, such as `"English, Spanish"` (in quotes, because of the comma). Shown in the school details panel |
| `contact_info` | Optional | Contact information, such as an email address. Shown in the proximity search |
| `address` | Optional | The school's address |
| `reporting_status` | Optional | `reported` or `not_reported` |

## `cases.csv`

One row per county, year, and age group.

| Column | Needed? | What to put in it |
|---|---|---|
| `county_fips`, `county_name` | One of them | County code or name. Each row needs at least one |
| `year` | Required | Calendar year. Can't be blank |
| `n_cases` | Required | Number of cases |
| `age_group` | Optional | A label such as `0-4` or `Unknown` |

- **No repeats.** Two rows with the same county, year, and age group stop the
  dashboard.
- **No totals alongside age groups.** Rows are added together, so an all-ages
  row counts those cases twice. With no age groups, leave out `age_group`.
- **Keep labels identical.** `0-4` with a hyphen and `0–4` with a long dash are
  two different groups.
- **Missing rows count as zero.** A county and year with no row counts as `0`
  cases. If your data leaves out places that didn't report, change
  `case_data = list(missing_records = "zero"),` in `my_settings.R` to
  `case_data = list(missing_records = "unknown"),`. A blank `n_cases` is always
  unknown.
- **Age group order.** Groups sort by their first number. To set the order
  yourself, change `case_age_groups = NULL,` in `my_settings.R` to list every
  group: `case_age_groups = c("0-4", "5-17", "18+", "Unknown"),`. Any other
  group in `cases.csv` then stops the dashboard.
- **Years.** The dashboard shows every year from the first to the last in
  `cases.csv`. To change the years on the map slider, change `case_years = NULL,`
  in `my_settings.R`, giving all three values:
  `case_years = list(min = 2015, max = 2025, selected = c(2020, 2025)),`.

## `facilities.csv`

One row per child care program.

| Column | Needed? | What to put in it |
|---|---|---|
| `facility_id` | Required | A unique ID, such as a license number |
| `facility_name` | Required | The name to display |
| `latitude`, `longitude` | Required | Decimal degrees. Leave both blank for a program with no known location |
| `enroll` | Required | Number of children enrolled |
| `full_vax_pct` | Required | Percent fully vaccinated among eligible children |
| `full_vax` | Optional | Number fully vaccinated |
| `enroll_eligible` | Optional | Number of children old enough for the vaccine. Fills the "MMR Eligible" column in the child care table, which shows `NA` without it. If every enrolled child is eligible, use the same number as `enroll` |
| `county_fips`, `county_name` | Optional | The program's county. Found from the coordinates if both are blank |
| `reporting_status` | Optional | `reported` or `not_reported` |

## `grades.csv`

One row per grade in each school. Don't include an all-grades row.

| Column | Needed? | What to put in it |
|---|---|---|
| `school_id` | Required | Must match a `school_id` in `schools.csv` |
| `grade` | Required | `K` or `0` for kindergarten (pick one), then `1` through `12` |
| `enroll` | Required | Number enrolled in that grade |
| `full_vax_pct` | Required | Percent fully vaccinated in that grade |
| `full_vax` | Optional | Number fully vaccinated |
| `partial_vax_pct` | Optional | Percent partly vaccinated or with no doses |
| `medical_pct`, `nonmedical_pct` | Optional | Percent with medical or nonmedical exemptions |
| `reporting_status` | Optional | `reported` or `not_reported` |

## `districts.csv`

One row per school district.

| Column | Needed? | What to put in it |
|---|---|---|
| `district_id` | Required | A unique ID that matches the boundaries and `schools.csv` |
| `district_name` | Required | The name to display |
| `enroll` | Required | Number of students enrolled |
| `full_vax_pct` | Required | Percent fully vaccinated |
| `full_vax` | Optional | Number fully vaccinated |
| `reporting_status` | Optional | `reported` or `not_reported` |

## `healthcare_centers.csv`

One row per location.

| Column | Needed? | What to put in it |
|---|---|---|
| `name` | Required | The name to display |
| `latitude`, `longitude` | Required | Decimal degrees. Can't be blank |

## Troubleshooting

When something needs fixing, the dashboard stops and lists the file, column,
and rows. Row 1 is the header. It can't tell whether your counts and
percentages agree, or whether a school's county matches its location, so check
those yourself.

| The message says | What to do |
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

The dashboard still starts with these two warnings:

| The warning says | What to do |
|---|---|
| `have a district_id not in` | Those schools have no linked district. Fix any mistyped IDs |
| `isn't saved as UTF-8` | Check the file's accented names, and save it as "CSV UTF-8" |
