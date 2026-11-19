# Format Data

This guide describes the files and variables used by epiviewVPD. The core
dashboard requires `counties.csv`, `schools.csv`, and `cases.csv`; additional
files support optional features described in the [Adding
more](5-adding-more.md) guide.

The instructions use the `app_data` folder and `my_settings.R` file described
in the [Dashboard guide](3-own-data.md). For further guidance, the included
artificial data provides examples of the required data formats. To view these,
run the following code in the R Console:

```r
library(epiviewVPD)
example_data_dir()         # the three core files
example_data_dir("full")   # every file
```

## Data files

| File | One row per | Description | Purpose |
|---|---|---|---|
| `counties.csv` | County | County-level vaccination coverage map | Provides county geographic information and county vaccination coverage |
| `schools.csv` | School | School-level vaccination coverage map and tables | Provides each school’s location, enrollment, vaccination coverage, and optional school details |
| `cases.csv` | County, year, and age group | Surveillance map, table, and charts with past cases | Provides the county location and total number of historic measles cases |
| `facilities.csv` | Child care program | [Child care](5-adding-more.md#child-cares) vaccination coverage map and tables | Provides each child care program’s location, enrollment, and vaccination coverage |
| `grades.csv` | School and grade | [Grade-level vaccination coverage](5-adding-more.md#grade-level-coverage) tables and figures | Provides enrollment and vaccination coverage by grade within each school |
| `districts.csv` | School district | [School districts](5-adding-more.md#school-districts) vaccination coverage map and tables | Provides district-level enrollment and vaccination coverage, linked to schools and district boundaries by `district_id` |
| `healthcare_centers.csv` | Healthcare location | [Proximity map tab](5-adding-more.md#proximity-search) to identify nearby healthcare clinics | Provides names and locations of healthcare facilities displayed on the proximity map |
| `county_boundaries.geojson` | County | Optional county boundaries; downloaded from the census if omitted | Defines county shapes used to draw maps and match data records to counties |
| `district_boundaries.geojson` | School district | Optional school district boundaries; downloaded from the census if omitted | Defines school district shapes used to draw maps and match district data by `district_id` |

If an enabled feature requires a missing file, the dashboard stops and
identifies the file.

## File specifications

### `counties.csv`

One row per county for one reporting period.

| Variable | Requirement | Description |
|---|---|---|
| `county_fips`, `county_name` | At least one | County code or name; each row requires at least one |
| `enroll` | Required | Number of students enrolled |
| `full_vax_pct` | Required | Percentage of students fully vaccinated |
| `full_vax` | Optional | Number fully vaccinated; used to calculate the statewide rate above the county map |
| `students_of_color_pct` | Optional | Percentage of students of color |
| `frl_eligible_pct` | Optional | Percent eligible for free or reduced-price meals |
| `reporting_status` | Optional | `reported` or `not_reported` |

### `schools.csv`

One row per school.

| Variable | Requirement | Description |
|---|---|---|
| `school_id` | Required | Unique ID used to link to `grades.csv` |
| `school_name` | Required | School name to display |
| `latitude`, `longitude` | Required | Coordinates in decimal degrees. Required to place the school on the map |
| `enroll` | Required | Number of students enrolled |
| `full_vax_pct` | Required | Percentage of students fully vaccinated |
| `county_fips`, `county_name` | Optional | School's county; determined from coordinate if neither fips or name are included |
| `school_type` | Optional | A label such as `Public`, `Private`, or `Charter` |
| `full_vax` | Optional | Number fully vaccinated |
| `partial_vax` | Optional | Number partly vaccinated or with no doses |
| `partial_vax_pct` | Optional | Percentage partly vaccinated or with no doses |
| `medical_pct` | Optional | Percentage with medical exemptions |
| `nonmedical_pct` | Optional | Percentage with nonmedical exemptions |
| `grade_range` | Optional | A label such as `K-5`, shown in the school map pop-up |
| `district_id` | Optional | School's district; blank if the school does not belong to any district |
| `home_languages` | Optional | Languages spoken at home, such as `"English, Spanish"` (in quotes, because of the comma). Shown in the school details panel |
| `contact_info` | Optional | Contact information for the school administration, such as an email address. Displayed in the proximity search |
| `address` | Optional | School address, used to differentiate between schools with the same name |
| `reporting_status` | Optional | `reported` or `not_reported` |

### `cases.csv`

One row per county, year, and age group.

| Variable | Requirement | Description |
|---|---|---|
| `county_fips`, `county_name` | One of them | County code or name; each row requires at least one |
| `year` | Required | Calendar year; cannot be blank |
| `n_cases` | Required | Number of cases |
| `age_group` | Optional | A label such as `0-4` or `Unknown` |

- **Unique records:** Do not include multiple rows for the same county, year,
  and age group.
- **All-ages totals:** Do not include all-ages totals alongside age-group rows.
  Rows are summed, so totals would count cases twice. If the data is not
  stratified by age, omit `age_group`.
- **Age-group labels:** Use consistent labels. For example, `0-4` with a hyphen
  and `0–4` with a long dash are treated as different groups.
- **Missing records:** By default, a county and year without a row is treated
  as having zero cases. If missing records represent places that did not
  report, change `case_data = list(missing_records = "zero"),` to `case_data =
  list(missing_records = "unknown"),` in `my_settings.R`. A blank `n_cases` is
  always treated as unknown.
- **Age-group order.** Groups sort by their first number. To set the order
  yourself, change `case_age_groups = NULL,` in `my_settings.R` to list every
  group: `case_age_groups = c("0-4", "5-17", "18+", "Unknown"),`. This must
  include all age groups in `cases.csv`, or else the dashboard does not run.
- **Years.** The dashboard displays every year from the first to the last in
  `cases.csv`. To change the years on the map slider, change `case_years =
  NULL,` in `my_settings.R`, giving all three values: `case_years = list(min =
  2015, max = 2025, selected = c(2020, 2025)),`.

### `facilities.csv`

One row per child care program.

| Variable | Requirement | Description |
|---|---|---|
| `facility_id` | Required | A unique ID, such as a license number |
| `facility_name` | Required | The facility name to display |
| `latitude`, `longitude` | Required | Decimal degrees. Leave both blank for a facility with no known location |
| `enroll` | Required | Number of children enrolled |
| `full_vax_pct` | Required | Percent fully vaccinated among eligible children |
| `full_vax` | Optional | Number fully vaccinated |
| `enroll_eligible` | Optional | Number of children old enough for the vaccine. Fills the "MMR Eligible" column in the child care table, which shows `NA` without it. If every enrolled child is eligible, use the same number as `enroll` |
| `county_fips`, `county_name` | Optional | The facility's county. Found from the coordinates if both are blank |
| `reporting_status` | Optional | `reported` or `not_reported` |

### `grades.csv`

One row per grade in each school. Don't include an all-grades row.

| Variable | Requirement | Description |
|---|---|---|
| `school_id` | Required | Must match a `school_id` in `schools.csv` |
| `grade` | Required | `K` or `0` for kindergarten (pick one), then `1` through `12` |
| `enroll` | Required | Number enrolled in that grade |
| `full_vax_pct` | Required | Percent fully vaccinated in that grade |
| `full_vax` | Optional | Number fully vaccinated |
| `partial_vax_pct` | Optional | Percent partially vaccinated or with no doses |
| `medical_pct`, `nonmedical_pct` | Optional | Percent with medical or nonmedical exemptions |
| `reporting_status` | Optional | `reported` or `not_reported` |

### `districts.csv`

One row per school district.

| Variable | Requirement | Description |
|---|---|---|
| `district_id` | Required | A unique ID that matches the boundaries and `schools.csv` |
| `district_name` | Required | The district name to display |
| `enroll` | Required | Number of students enrolled |
| `full_vax_pct` | Required | Percent fully vaccinated |
| `full_vax` | Optional | Number fully vaccinated |
| `reporting_status` | Optional | `reported` or `not_reported` |

### `healthcare_centers.csv`

One row per location.

| Variable | Requirement | Description |
|---|---|---|
| `name` | Required | The facility name to display |
| `latitude`, `longitude` | Required | Decimal degrees. Can't be blank |

### `county_boundaries.geojson`

| Property | Needed? | What to put in it |
|---|---|---|
| `county_name` | Required | County name, different for each county |
| `county_fips` | Optional | County code as text. Needed if your CSV files use `county_fips` |

### `district_boundaries.geojson`

| Property | Needed? | What to put in it |
|---|---|---|
| `district_id` | Required | District ID, different for each district |

## General formatting requirements

- Save CSV files with a header row. UTF-8 encoding is recommended. Files saved
  in another encoding can still load, but the dashboard issues a warning to
  check accented names.
- File and variable/column names must match the names in this guide exactly,
  including capitalization.
- Include all **required** columns. **Optional** columns may be omitted.
- **Leave unknown values blank** while retaining the variable. IDs and names
  cannot be blank.
- Extra columns are ignored, but every column must have a nonblank header

| Value | Format |
|---|---|
| IDs | Text. Preserve leading zeros, such as `01001`; they are not added automatically. Excel may remove them. |
| Counts | Nonnegative whole numbers without commas, such as `1250` |
| Coverage percentages (`full_vax_pct`, `partial_vax_pct`, `medical_pct`, `nonmedical_pct`) | Values from `0` to `100`: `92.4`. A trailing `%` is allowed. A value of `0.924` is interpreted as less than 1%. |
| Demographic percentages (`students_of_color_pct`, `frl_eligible_pct`) | Numeric values from `0` to `100`, without `%` signs or ranges. |
| Latitude, longitude | Decimal degrees: `44.95`, `-93.09`. Both are required for schools. Both may be blank for a child care program with no known location. |
| Years | Whole calendar years, such as `2024` |

### Missing, zero, and withheld values

Use `0` for a true zero and leave unknown or withheld values blank.

If the data uses characters for withheld (or redacted) values, such as `*`,
`S`, or `NA`, specify them in `my_settings.R` (approx. line 118). For example,
replace:

```r
redacted_codes = character(0),
```

with:

```r
redacted_codes = c("*", "S", "NA"),
```

These codes are treated as blank. Other text in a numeric column, such as
`N/A`, stops the dashboard.

Ranges such as `>95` are displayed as entered. For map coloring, the dashboard
assigns a value one percentage point beyond the stated threshold: `>95` is
treated as 96, and `<5` as 4. To change this offset, update `blurred_offset =
1` in `my_settings.R`.

### Reporting status

The files `counties.csv`, `schools.csv`, `facilities.csv`, `grades.csv`, and
`districts.csv` may include a `reporting_status` variable. For this variable,
enter `reported`, `not_reported`, or leave it as a blank value.

For a row marked `not_reported`, vaccination values are displayed as unknown
while the name and enrollment are retained. Reporting status applies within
each file: marking a school as `not_reported` in `schools.csv` will not remove
or modify its corresponding rows in `grades.csv` where grade-level enrollment
counts may be stored.

### Coverage percentages and counts

Enter `full_vax_pct` as reported; the dashboard does not recalculate it from
provided enrollment and vaccination counts.

The statewide rate displayed above the county map is the sum of `full_vax`
divided by the sum of `enroll`. Both columns need to be filled in for every
county; it reads "Unknown" if some entries are blank.

## County matching

The dashboard matches records to counties in the following order:

- `county_fips`, using an exact match.
- `county_name`, ignoring capitalization.
- Latitude and longitude, for schools and child cares when both county
  variables are blank.

An unmatched `county_fips` stops the dashboard; it does not fall back to the
`county_name`. Specify the county for schools near a county line, where
coordinates may place a school in the wrong county.

- **Census boundaries:** `county_fips` is the 5-character code (`"01001"`).
  `county_name` is the Census name without "County". Where a city and county
  share a name, such as Baltimore, MD, `Baltimore` is the county and `Baltimore
  city` is the city.
- **Custom boundaries:** Use the names or codes in the boundary file.

Each county may appear in `counties.csv` only once. A county with no row shows
unknown coverage.

## School districts matching

`district_id` must match exactly in `districts.csv`, `schools.csv`, and the
district boundaries. Districts are not matched by name.

- Census boundaries use the 7-character district code from the U.S. Census.
- Custom boundaries may use any text ID that matches across files, such as
  `"0001"`.
- A `districts.csv` ID with no boundary stops the dashboard. A boundary with no
  row shows unknown coverage.
- A school with a blank `district_id` has no district. It still shows in county
  maps, tables, and reports.
- A `district_id` that matches nothing gives a warning.

## Boundary files

**Census boundaries.** If you don’t include your own boundary files, epiviewVPD
will download them from the U.S. Census based on the state specified in the
geography line of `my_settings.R` ([Configure
settings](3-own-data.md#configure-settings)). This also includes an option to
select the type of school district boundaries (`"unified"`, `"elementary"`, or
`"secondary"`) and the specific Census year:

```r
geography = list(state = "WI", district_type = "unified", year = 2023),
```

**Your own boundaries:** If a boundary file is included in your `app_data`
folder, epiviewVPD will use this instead of downloading boundaries from the
U.S. Census.

A boundary file needs:

- One shape per county or district, with no repeats.
- Valid Polygon or MultiPolygon shapes.
- Coordinates in longitude and latitude (EPSG:4326). A file in another
  coordinate system is converted if the file says which one it uses.
- Properties required for [county](#county_boundariesgeojson) and
  [district](#district_boundariesgeojson) boundary files are listed above.

### Convert a shapefile

It’s recommended for epiviewVPD users to utilize the option for downloading
county and district boundary data from the U.S. Census. If you prefer to
utilize your own shapefile data, ensure the shapefile is converted to a GeoJSON
file (`4326` instructs R to convert to the appropriate geocoordinate reference
system):

```r
bounds <- sf::st_read("my_counties.shp")
bounds <- sf::st_transform(bounds, 4326)
# Replace NAME with the column that holds your county names.
names(bounds)[names(bounds) == "NAME"] <- "county_name"
sf::st_write(bounds, "app_data/county_boundaries.geojson", delete_dsn = TRUE)
```

## Troubleshooting

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

The dashboard still starts with these two warnings:

| The warning says | What to do |
|---|---|
| `have a district_id not in` | Those schools have no linked district. Fix any mistyped IDs |
| `isn't saved as UTF-8` | Check the file's accented names, and save it as "CSV UTF-8" |
