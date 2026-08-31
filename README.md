# hplcAnalyzer

[![License: GPL-3](https://img.shields.io/badge/License-GPL%203-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![R](https://img.shields.io/badge/R-%E2%89%A5%204.1-blue)](https://www.r-project.org/)

hplcAnalyzer turns a peptide HPLC-UV chromatogram into a concentration and a purity number
without a standard curve. It reads the raw instrument files, corrects the baseline, integrates
the peaks, and converts the main peak area to molarity using a molar absorptivity predicted
from the peptide sequence. Everything runs locally, either from the R console or from a Shiny
app aimed at bench chemists rather than R programmers.

Version 0.3.2. See [NEWS.md](NEWS.md) for the version history.

---

## Supported input

| Instrument | Files read | Reader |
|---|---|---|
| Agilent ChemStation | a folder of `.D` acquisition folders | `read_hplc_agilent()`, via `chromConverter` |
| Thermo / Chromeleon | `*_UV_VIS_N.txt` UV text exports | `read_hplc_thermo()` |

Both readers are found automatically in whichever folder you point the app at. Agilent `.D`
folders are picked up as immediate subdirectories; Thermo exports are picked up as files
directly inside the folder. Neither search recurses.

**A real wavelength choice exists for Agilent only.** For an Agilent `.D` folder,
`read_hplc_agilent()` searches the DAD signals for one whose `detector_range` attribute
matches both the requested signal wavelength and the reference wavelength, so asking for
280 nm genuinely extracts the 280 nm trace. The Thermo reader has no wavelength concept at
all: `read_hplc_thermo(file)` takes a path and nothing else, and the app's "Thermo UV channel"
control selects a **file number** (`N` in `*_UV_VIS_N.txt`), not a wavelength. On the Thermo
path the wavelength radio button therefore only chooses which epsilon formula is applied to
whatever trace the channel number pulled in.

---

## Installation

The package is pure R. No compiler, and no Rtools on Windows, is needed for hplcAnalyzer
itself, though some of its CRAN dependencies compile from source on Linux.

`DESCRIPTION` declares no minimum R version, but `chromConverter`, `dplyr` and `ggplot2` all
require **R 4.1 or newer**, so that is the effective floor. Developed and tested on R 4.5.2.

### From a git checkout (recommended)

```bash
git clone git@github.com:PitKubi/hplc_analyzer.git
cd hplc_analyzer
Rscript install.R
```

`install.R` reads the dependency list out of `DESCRIPTION`, installs from CRAN whatever is
missing, then installs the package from the working tree. It is written in base R so that a
machine with nothing but R on it can run it. It also works from inside R or RStudio:

```r
setwd("/path/to/hplc_analyzer")
source("install.R")
```

### Directly from GitHub

**This repository is private.** A plain `remotes::install_github("PitKubi/hplc_analyzer")`
will fail with a 404 for anyone without access, because GitHub returns 404 rather than 403 for
private repositories. Use a personal access token with the `repo` scope:

```r
install.packages("remotes")
remotes::install_github("PitKubi/hplc_analyzer",
                        auth_token = Sys.getenv("GITHUB_PAT"))
```

Put the token in `~/.Renviron` as `GITHUB_PAT=ghp_...` rather than typing it into a script.
Never commit it. If the repository is ever made public, the plain call without `auth_token`
works and the token can be dropped.

Note the repository is named `hplc_analyzer` while the package is named `hplcAnalyzer`.

### As a source tarball

This is how the package currently reaches collaborators on macOS and Windows. Build it once
on any machine:

```bash
cd hplc_analyzer
R CMD build .
```

That writes `hplcAnalyzer_0.3.2.tar.gz`. Send that file. The recipient installs the CRAN
dependencies once and then the tarball:

```r
install.packages(c("chromConverter","dplyr","baseline","signal","pracma","ggplot2",
                   "gridExtra","shiny","shinyFiles","fs","DT","tibble","xml2","magrittr"))
install.packages("C:/path/to/hplcAnalyzer_0.3.2.tar.gz", repos = NULL, type = "source")
```

On Windows, close and reopen R before installing over an existing version. A loaded package
cannot be overwritten and the install fails quietly. Check what you ended up with:

```r
packageVersion("hplcAnalyzer")
```

`INSTALL.md` carries the same instructions in a longer, step by step form for users who are
new to R.

---

## Quick start

```r
library(hplcAnalyzer)
run_hplc_app()
```

The app opens in your browser. Then:

1. **Choose folder directory** and pick the folder holding your `.D` folders or your
   `*_UV_VIS_N.txt` exports.
2. Set the **detection wavelength**, and for Agilent the **injection volume** if it is not
   100 microlitres.
3. Click **Load samples**. Every sample is analysed once and the table fills in.
4. Click a row, or use **Previous** / **Next**, to inspect one run. The upper plot shows the
   raw trace, the fitted baseline and the corrected trace. The lower plot shows the corrected
   trace with the main peak shaded and a metrics box.
5. The sidebar table lists the top ten peaks with RT, height, area, Area (%), and
   concentration.
6. **Download Results CSV** when done.

Nothing leaves your machine.

### Scripted use

```r
library(hplcAnalyzer)

result <- run_hplc_analysis_agilent(
  sample_d_path     = "batch/004-P2-A1-MRMP-00000001-001_SAMPLEPEPTIDEK.D",
  blank_d_path      = "batch/003-1-BLANK0.D",
  peptide_sequence  = "SAMPLEPEPTIDEK",
  use_hybrid        = TRUE,
  signal_wavelength = 214,
  inj_vol_ml        = 0.1,
  min_rt_frac       = 0.30,
  max_rt_frac       = 0.80
)

result$peak_table        # one row per detected peak
result$epsilon           # molar absorptivity used, M^-1 cm^-1
result$concentration_uM  # main peak concentration, micromolar
result$plot              # annotated ggplot
main_peak_area_percent(result$peak_table)   # purity, percent
```

`run_hplc_analysis_thermo()` takes `sample_file` instead of `sample_d_path` and accepts no
blank.

---

## The analysis chain

Both pipelines run the same steps in the same order.

1. **Read.** `read_hplc_agilent()` or `read_hplc_thermo()` returns a data frame of `time`
   (min) and `intensity` (mAU). The Agilent reader also parses the injection volume out of
   `acq.txt` and stamps it on the frame as the `inj_vol_ml` attribute.
2. **Baseline correction.**
   - `baseline_als()` fits an asymmetric least squares baseline to the whole trace and
     subtracts it. This is the default and the only path at 280 nm.
   - `align_subtract_then_hybrid()` is the blank-subtracting path, used at 214 nm when a
     blank run is available. It aligns the blank to the sample on the injector peak midpoint,
     subtracts it only after the injector window, bridges the positive/negative artefact pairs
     that over-subtraction creates, then calls `baseline_hybrid_sm()` to fit piecewise ALS
     baselines between the minima of the difference trace. A one minute guard ramps the
     baseline up from zero just after the injector so the subtraction does not open with a dip.
   - Thermo exports are taken as already baseline corrected by the instrument, so `corrected`
     is set equal to `intensity`.
3. **Peak detection.** `detect_peaks_on_smoothed()` smooths the corrected trace with a
   Savitzky-Golay filter (11 point window, 3rd order by default), estimates the noise as the
   standard deviation of the first 50 points, and calls `pracma::findpeaks()` with a threshold
   of `snr` times that noise (default 5). Peaks outside the analyte retention time window are
   dropped.
4. **Area.** Trapezoidal integration (`pracma::trapz()`) between the peak start and end indices
   that `findpeaks()` reports, on the smoothed trace. Units are mAU times min.
5. **Concentration.** `estimate_epsilon_214()` or `estimate_epsilon_280()` predicts the molar
   absorptivity from the sequence, and `calculate_peak_conc()` applies Beer-Lambert.

`filter_top_peaks()` ranks peaks by height and keeps the top ten; `peak_area_percent()` and
`main_peak_area_percent()` turn that ranked set into the Area (%) purity column.

---

## The science

### Molar absorptivity at 214 nm

Two functions cover 214 nm. `published_epsilon_214()` is the literature model, untouched.
`estimate_epsilon_214()` is what the pipelines and the app actually call, and it applies a
recalibration measured on our own data; see [Recalibration of eps214](#recalibration-of-eps214)
below for what changed, why, and how to change it back.

`published_epsilon_214()` implements the additive residue model of

> Kuipers, B. J. H. and Gruppen, H. (2007). Prediction of molar extinction coefficients of
> proteins and peptides using UV absorption of the constituent amino acids at 214 nm to enable
> quantitative reverse phase high-performance liquid chromatography-mass spectrometry analysis.
> *Journal of Agricultural and Food Chemistry* **55**(14), 5445-5451.

At 214 nm the peptide bond itself is the dominant chromophore, so absorptivity is built up
term by term rather than from aromatic residues alone:

- **923** M<sup>-1</sup> cm<sup>-1</sup> per peptide bond, that is `nchar(sequence) - 1` bonds.
- **2675** M<sup>-1</sup> cm<sup>-1</sup> per proline that is **not** N-terminal. Proline is
  deliberately absent from the per-residue table below and carried by this term instead.
- Per-residue contributions, summed over the sequence:

  | Residue | eps | Residue | eps | Residue | eps | Residue | eps |
  |---|---|---|---|---|---|---|---|
  | W | 29050* | H | 5125 | N | 136 | K | 41 |
  | Y | 5375 | M | 980 | C | 225 | T | 41 |
  | F | 5200 | R | 102 | G | 21 | E | 78 |
  | Q | 142 | V | 43 | I | 45 | L | 45 |
  | A | 32 | S | 34 | D | 58 | | |

  \* Tryptophan is the one value `estimate_epsilon_214()` does not use as printed. See
  [Recalibration of eps214](#recalibration-of-eps214).

- Four tripeptides are special-cased to the measured values from the paper's Table 3 and
  bypass the additive model entirely: GGG 1080, GPG 3620, PGG 950, GGP 3880. They carry no
  tryptophan, so the recalibration scales them like any other tryptophan-free peptide.

Both functions return `NA` for anything that is not a string of the twenty standard one-letter
codes, so blanks, washes and unresolved sequences fall through cleanly.

### Recalibration of eps214

**The tryptophan term shipped here is not the published one.** `estimate_epsilon_214()` returns

```
NON_TRYPTOPHAN_EPSILON_214_SCALE * (published - 29050 * nTrp)  +  MEASURED_TRYPTOPHAN_EPSILON_214 * nTrp
```

with `MEASURED_TRYPTOPHAN_EPSILON_214 = 17340` and `NON_TRYPTOPHAN_EPSILON_214_SCALE = 1.118`.
Both constants sit at the top of `R/estimate_epsilon_214.R`, and the same two numbers appear in
`peptide-calculator/src/calculations.js`. Change them together or the desktop calculator and the
Shiny app will disagree.

![eps214 recalibration](man/figures/eps214_tryptophan_recalibration.png)

**Where the numbers come from.** A peptide measured at both 214 and 280 nm gives two independent
concentrations from one injection, so sample amount, dilution and any whole-batch offset cancel in
their ratio and what is left is the extinction model. On 130 such injections that ratio tracks
tryptophan and nothing else, at rho = -0.76, p < 1e-13: median 1.17 with no tryptophan, 0.82 with
one, 0.68 with two. Tyrosine, phenylalanine, histidine, methionine and peptide length add nothing.

A reported concentration is inversely proportional to the extinction coefficient used, so the
coefficient a peptide would have needed is its published value times that ratio. Fitting one
replacement tryptophan term and one scale on everything else, by least squares over the 71
injections passing an 80 percent purity gate, with a 4000-draw bootstrap:

| Parameter | Fitted | 95 % CI | Published |
|---|---|---|---|
| eps214 tryptophan | 17,340 | 14,519 to 19,569 | 29,050 |
| scale on the rest | 1.118 | 1.01 to 1.26 | 1 |

Tyrosine and phenylalanine, freed in the same fit, come back at 5,080 and 3,813 with intervals
covering their published 5,375 and 5,200, so they are left alone.

**Why it is believable.** Fitting each batch separately gives 15,300 and 18,200 for the tryptophan
term, so it is not one batch misbehaving. Amino acid analysis, which is not used in the fit at all,
agrees independently: tryptophan drags the 214 nm channel away from it while the 280 nm channel
stays put. And the correction closes that gap too, from 26 to 11 percentage points in one batch and
20 to 7 in the other.

**What it buys.** Across the 130 injections, 214 nm against 280 nm improves from R2 0.68 to 0.87,
and the median absolute difference between the two channels, as a percentage of the mean of the
pair, from 17.3 to 8.1 percent. Those are the numbers the shipped constants actually produce, not
the unrounded fit.

**The scale is the soft number.** The tryptophan term is well determined and its interval is
nowhere near 29,050. The 1.118 scale is not: its interval nearly touches 1, and anchored on amino
acid analysis instead, using the 170 tryptophan-free peptides of a clean batch, it comes out 1.078.
Treat 1.08 to 1.12 as the range and set it from a batch you trust. Shipping 1 instead of 1.118
leaves the two channels 15 percent apart, so it is not a safe default; the two parameters belong
together.

**What changes in your numbers.** Concentrations move as `published / calibrated`:

| Peptide | Trp | Published eps | Calibrated eps | Reported concentration |
|---|---|---|---|---|
| `DIAAYIK` | 0 | 11,166 | 12,484 | 10.6 % lower |
| `GSEMVVAGK` | 0 | 8,677 | 9,701 | 10.6 % lower |
| `INEWLTK` | 1 | 34,974 | 23,963 | 45.9 % higher |
| `AWVNQLETQTGEASK` | 1 | 42,878 | 32,800 | 30.7 % higher |

Every tryptophan-free peptide moves by the same 10.6 percent, so purity, `Area (%)` and any
ratio between peptides in one run are unaffected. Only tryptophan peptides change relative to
the rest, and they are the point of the exercise.

**To go back to the literature model**, either call `published_epsilon_214()` directly, or set
`MEASURED_TRYPTOPHAN_EPSILON_214 <- 29050` and `NON_TRYPTOPHAN_EPSILON_214_SCALE <- 1` and
reinstall. `tests/testthat/test-estimate_epsilon_214.R` pins the published model separately, so
it keeps passing either way.

The figure above was produced by
`~/Documents/project_workspaces/hplcanalyzer/analysis_aaa_vs_uv_20260831/plot_repository_figure.py`,
which also holds the full 20-slide analysis it is drawn from. The source data are collaborator
purity batches and are deliberately not in this repository.

### Molar absorptivity at 280 nm

`estimate_epsilon_280()` implements the Edelhoch method as revised by

> Pace, C. N., Vajdos, F., Fee, L., Grimsley, G. and Gray, T. (1995). How to measure and
> predict the molar absorption coefficient of a protein. *Protein Science* **4**(11),
> 2411-2423.

```
eps280 = 5500 * nTrp + 1490 * nTyr
```

Two things about this matter more than anything else in the package:

- **Cystine is not included.** The full Pace formula adds 125 M<sup>-1</sup> cm<sup>-1</sup>
  per disulfide bond. The disulfide state of a synthetic purity-check peptide is not known
  from its sequence, so this implementation assumes all cysteines are free and contributes
  nothing for them.
- **A peptide with no Trp and no Tyr returns `NA`, and cannot be quantified at 280 nm at all.**
  There is no chromophore, so there is no concentration to compute, and the app says
  `NA (missing eps)` rather than showing a number. In one production batch of 47 distinct
  peptides, **25 had neither Trp nor Tyr**, so more than half the plate is unquantifiable at
  280 nm. Use 214 nm unless you have a specific reason not to.

For those peptides the Area (%) purity column still works, because purity is a ratio of two
areas and needs no absorptivity.

### Area to concentration

`calculate_peak_conc()` is Beer-Lambert with the units cancelled explicitly:

```
c [M] = (area [mAU*min] * flow [mL/min] / 1000) / (eps [M^-1 cm^-1] * pathlength [cm] * V_inj [mL])
```

The chain of units is:

1. `area * flow` gives mAU times mL, the total absorbance-volume swept through the cell.
2. Dividing by 1000 converts mAU to AU, giving AU times mL.
3. Dividing by `eps * pathlength` converts absorbance to molarity, leaving mol/L times mL.
4. Dividing by the injection volume in mL cancels the mL and leaves mol/L.

The result is multiplied by 1e6 for the reported micromolar value. Defaults are 1 mL/min flow
and 1 cm pathlength; neither is exposed in the app, so change them in a script if your method
differs.

---

## Behaviour that will surprise you

**At 280 nm the blank is never subtracted, even if you ask for it.**
`run_hplc_analysis_agilent()` computes `use_hybrid && signal_wavelength != 280`, so an explicit
`use_hybrid = TRUE` is overridden at 280 nm. The reason is that there is nothing there to
subtract and the subtraction does harm. Measured over the eight blank runs of a production
batch, between 3 and 18 minutes, the blank baseline drifts about **2.8 mAU/min at 214 nm but
about 0.011 mAU/min at 280 nm**, some 250 times less. Against hand-integrated areas on eight
well-resolved peaks during development, the hybrid path came out biased high on every one
(median +6.6 percent, worst +12.2 percent) while ALS alone stayed within 2.6 percent. The
override is unconditional rather than a changed default because the app sets `use_hybrid` from
"a blank folder exists in this batch", which is a fact about the plate layout and not a
scientific judgement.

**The peptide sequence is resolved from three places, in order.** The uploaded CSV map wins,
then `SAMPLE.XML` inside the `.D` folder, then the folder name. ChemStation truncates the
folder name at 40 characters, and it also caps the `<Name>` element in `SAMPLE.XML` at 40
characters. In the production batch tested, the longest folder basename is 42 characters
(40 plus `.D`) and the longest XML name is exactly 40; the XML resolved 57 of 69 runs against
47 for the folder name, was never shorter, and never disagreed. But five names sit at exactly
40 characters, and two of those sequences are visibly cut mid-peptide. For those, an uploaded
CSV map is the only way to get the real sequence in. The **Download CSV map template** button
writes a CSV prefilled with whatever the app resolved, so correcting them means editing two
cells rather than typing the whole plate.

**Area (%) is against the ten peaks shown, not every peak detected.** The denominator in
`peak_area_percent()` is the sum of the ranked peak areas that `filter_top_peaks()` returned,
which is the main peak plus its nine largest impurities. Dividing by every detected peak
instead sounds more rigorous but is not: on a 280 nm trace the detector reports dozens of
sub-mAU baseline features, and including them drags a peptide that is better than 95 percent
pure down to about 59 percent. The ranked set is the population a purity number is actually
about.

**The on-screen peak table also drops anything before 6 minutes.** That 6 minute floor is
absolute and separate from the Min analyte RT slider, which is a percentage. A peak passing
the slider can still be missing from the table if it elutes before 6 minutes.

**In the app, the sidebar injection volume always wins.** The value parsed from `acq.txt` is
used only when a script calls `run_hplc_analysis_agilent(inj_vol_ml = NA)`. The app always
passes the sidebar value, so the file value is never consulted there.

---

## The controls

| Control | What it does |
|---|---|
| Choose folder directory | Picks the batch folder. Agilent `.D` subfolders and Thermo `*_UV_VIS_N.txt` files are both detected. |
| Optional CSV map | Uploads sequence assignments. Highest priority sequence source. |
| Download CSV map template | Writes a CSV prefilled with the sequences the app resolved on its own. |
| Detection wavelength | 214 nm (Kuipers and Gruppen) or 280 nm (Edelhoch). Chooses the extracted trace on Agilent and the epsilon formula on both. |
| Thermo UV channel | The `N` in `*_UV_VIS_N.txt`. A file number, not a wavelength. |
| Dilution factor | Multiplies the reported concentration. Enter 10 for a 1:10 dilution. Non-finite or non-positive values fall back to 1. |
| Injection volume (uL) | Volume injected on column, default 100. Concentration scales inversely with it. Agilent only. |
| Load samples | Analyses every sample in the folder and fills the table. |
| Override blank | Forces one specific `BLANK` folder instead of the nearest preceding one. |
| Min analyte RT (% of run) | Drops peaks before this fraction of the run. Default 30. |
| Max analyte RT (% of run) | Drops peaks after this fraction of the run. Default 100, which keeps everything. |
| Reset integration | Clears the manual window for this sample and un-marks it as bad. |
| Mark as bad | Blanks the concentration for this sample and sets its status to `Marked bad`. |
| Previous / Next Sample | Navigation, synced with the table selection. |
| Download Results CSV | Exports the accumulated results. |

Both retention time bounds are percentages of run length rather than minutes, so one setting
travels across methods of different duration. A single production batch already mixes 20.01
and 24.11 minute runs. If the maximum is set at or below the minimum, both revert to the
defaults rather than reporting "no peaks detected" for the whole plate.

**Manual integration.** Brush horizontally across the lower peak plot to integrate a region by
hand. The metrics box switches to that window's area and concentration and the results row is
replaced. A hand-drawn window reports no Area (%), because it is not one of the ranked peaks
and has no share of their summed area. Click **Reset integration** to return to the detector.

### Results CSV columns

`sample`, `rt`, `height`, `area`, `main_peak_area_pct`, `conc_uM_raw`, `sequence`, `status`,
`dilution_factor`, `conc_uM_final`, `wavelength_nm`.

`status` distinguishes `OK`, `NA (missing eps)`, `Marked bad`, `No peaks detected` and an
error string, so an empty concentration always carries its reason.

### CSV map format

Column names are matched case-insensitively. Agilent runs are keyed on the MRMP id, Thermo
runs on the plate well.

```csv
MRMP,Sequence
MRMP-00000001-001,SAMPLEPEPTIDEK
MRMP-00000001-002,TESTPEPTIDEAK
```

```csv
Well,Peptide Sequence
P1-A1,SAMPLEPEPTIDEK
P1-B1,TESTPEPTIDEAK
```

The template the app writes carries `MRMP`, `Well`, `Sequence` and `Run` so that one file
serves both instruments. Extra columns are ignored.

---

## Recommended settings

| Setting | Recommended | Why |
|---|---|---|
| Detection wavelength | 214 nm | More than half of a typical peptide plate has no Trp or Tyr and cannot be quantified at 280 nm at all. |
| Min analyte RT | 30 percent | The shipped default. Keeps the injector and void region out of the peak table. |
| Max analyte RT | **80 percent** | See below. |
| Injection volume | whatever the method injects | The app does not read it from the file. |

**Why 80 percent for the maximum.** Every method here ends with a column regeneration step at
high organic, and the detector reports that step as a peak like any other. It appears in all
runs including blanks, so it is instrument behaviour and not sample. Re-measured on this
package at 214 nm over the 56 of 57 peptide runs of batch `a 57 peptide production batch`
that complete, and across the ranked peaks the app actually reports, the latest genuine
analyte peak sits at **74.6 percent** of the run and the next ranked peak at **86.5 percent**. Nothing at all falls in
between, so any cutoff from about 75 to 86 percent separates them with no analyte lost, and 80
percent sits comfortably in the middle. Left at the default of 100 percent, the regeneration
peak is the largest peak on many 280 nm runs and takes a share of Area (%) on all of them.

The default remains 100 percent so that upgrading the package never silently moves a number
that has already been reported. Set it yourself.

---

## Known limitations

- **The Thermo path shares the wavelength control but uses it only for the epsilon formula.**
  Selecting 280 nm while the Thermo channel selector is pointing at a 214 nm export will
  compute an Edelhoch eps280 against a 214 nm trace and report a concentration for it. Nothing
  in the code can detect this, because the Thermo reader never learns what wavelength it read.
- **Two sequences in the production batch tested remain truncated at source**, because
  ChemStation caps the `SAMPLE.XML` name at the same 40 characters as the folder name. Only an
  uploaded CSV map can fix those.
- **The `acq.txt` injection volume parser requires a unit.** The regex demands `uL` or `mL`
  after the number, so an instrument that writes the number alone silently falls back to
  100 uL. The instrument in the batch tested does write the unit and parses correctly, but the
  sidebar control exists so that this is never load bearing.
- **The reference wavelength is fixed at 360 nm in the app.** `read_hplc_agilent()` accepts a
  `signal_ref` argument, but the app never sets it, so a `.D` folder without a `Sig=<wl>,Ref=360`
  signal fails with "No matching DAD signal". Non-injection runs such as standby files fail
  this way by design.
- **Flow rate and pathlength are not exposed in the app**, and default to 1 mL/min and 1 cm.
  A method running at a different flow rate needs the scripted interface.
- **The hybrid baseline path can fail on individual runs.** One of 58 runs in the batch tested
  errors inside `baseline_hybrid_sm()` with `invalid 'times' argument`. The app catches it, and
  the row carries the error text rather than a number.
- **The noise estimate is the standard deviation of the first 50 points** of the trace. A run
  whose first 50 points are not baseline will have its detection threshold set wrongly.
- **No automated tests.** There is no `tests/` directory. Behaviour is verified by re-running
  production batches and comparing results.

---

## Repository layout

```
R/                      package source
inst/shiny/app/app.R    the Shiny front end, launched by run_hplc_app()
man/                    roxygen-generated help pages
install.R               dependency and package installer for a fresh clone
INSTALL.md              step by step install guide for users new to R
NEWS.md                 version history
aaa_hplc_compare/       amino acid analysis versus UV-HPLC comparison outputs
peptide-calculator/     an Electron desktop peptide calculator, separate from the R package
```

`aaa_hplc_compare/` and `peptide-calculator/` are excluded from the built package by
`.Rbuildignore`.

---

## License and citation

GPL-3. Copyright Peter Kubiniok.

If you use hplcAnalyzer, please cite the two methods it implements alongside the software:

> Kuipers, B. J. H. and Gruppen, H. (2007). Prediction of molar extinction coefficients of
> proteins and peptides using UV absorption of the constituent amino acids at 214 nm to enable
> quantitative reverse phase high-performance liquid chromatography-mass spectrometry analysis.
> *Journal of Agricultural and Food Chemistry* **55**(14), 5445-5451.
> doi:10.1021/jf070337l

> Pace, C. N., Vajdos, F., Fee, L., Grimsley, G. and Gray, T. (1995). How to measure and
> predict the molar absorption coefficient of a protein. *Protein Science* **4**(11),
> 2411-2423. doi:10.1002/pro.5560041120

> Kubiniok, P. (2026). hplcAnalyzer: automated HPLC-UV analysis and peptide concentration
> estimation. R package version 0.3.2.

Contact: Peter Kubiniok, peterkubiniok@gmail.com
