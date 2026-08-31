# hplcAnalyzer 0.5.2

* **Documented how the integration window is chosen**, after the shaded region in the peak plot
  was read, reasonably, as the integration clipping the peak. It is not: the window runs between
  the two local minima either side of the apex, so a fused shoulder puts the boundary partway up
  the flank. That is a perpendicular drop and it keeps the neighbour out of the main peak.
  Worth stating plainly because **no parameter moves it**: raising `snr` from 5 to 100 on a test
  run leaves the start at 12.01 min and the area at 218.1 unchanged, and `min_peak_dist` and
  `post_win` only change which peaks are reported. The rule lives in `pracma::findpeaks()`.
  It is also common in purity samples: of roughly 70 runs in one production batch, four had a
  main peak whose integration began and ended below 2 percent of peak height.

* Screenshots reshot on four of those four cleanly resolved runs, so the walkthrough shows an
  integration running foot to foot rather than one that invites the wrong reading.

# hplcAnalyzer 0.5.1

* **The ALS asymmetry parameter goes from 1e-4 to 1e-6, and lambda settles at 5.5.** 0.5.0
  raised lambda alone, which fixed the peak but over-stiffened the rest of the trace. Gridding
  lambda against p on 20 runs, and looking at the fits rather than only the summary numbers,
  p is the better lever: it is the parameter that decides how hard the baseline is pushed under
  the data, so lowering it keeps the baseline off the peak without making it too rigid to follow
  the solvent front.

  Median climb of the fitted baseline above its own level 1.5 min either side of the apex:
  **10.0 mAU** at the original lambda 4.0 with p 1e-4, **5.0** at lambda 5.5 with p 1e-4, and
  **1.1** at lambda 5.5 with p 1e-6, the lowest of the grid. Raising lambda to 6.5 instead
  reaches a similar climb but the corrected trace then needs 9.6 min to settle back to zero
  after the injector rather than 6.5, and between peaks it sits 1.6 mAU off zero rather than
  0.6. Visual check of the fitted baseline through the peak is in the commit that made it.

# hplcAnalyzer 0.5.0

* **The global ALS baseline lambda goes from 4.0 to 5.5, which changes every 214 nm area and
  concentration.** At 4.0 the fitted baseline climbed into the main peak instead of passing
  under it. Measured on four runs, the baseline rose **17.8, 45.3, 13.8 and 71.1 mAU** at the
  peak apex above its own level 1.5 minutes either side, and the integrated area was still
  growing as lambda increased, which is the signature of a baseline eating signal.

  Sweeping lambda from 3.0 to 8.0 on those runs, area plateaus between about 5.5 and 6.5 and
  the climb falls to **3 to 12 mAU**, under 1.5 percent of peak height. Past 7 the baseline is
  too stiff and starts sweeping neighbouring signal into the peak: at lambda 8 the area jumps
  14 to 31 percent and Area (%) collapses as the ten ranked peaks merge. 5.5 sits on the
  plateau with margin at both ends.

  Effect on reported numbers: areas rise by **2.5 to 10.5 percent** on the runs measured, more
  where the peak sits on a busy stretch of baseline. Purity improves too, for example 92.9 to
  96.1 percent and 90.7 to 93.7 percent on two of the four. The piecewise lambda used by the
  blank-subtracting path was already 6.5 and is unchanged; 4.0 was the outlier.

* **A measured defect in the blank-subtracting path is now documented**, not fixed. At 214 nm
  with a blank present, `align_subtract_then_hybrid()` over-subtracts the blank's own injector
  peak and leaves about **-317 mAU at 3.28 min in every run**, varying by less than 2 mAU
  across a batch; the plain ALS path leaves -1.6 mAU. The one minute guard ramp does not reach
  it. It cannot corrupt a reported concentration, because it sits before the analyte window,
  but the two paths return concentrations 5 to 15 percent apart and it is the hybrid one that
  is biased high against hand integration. See the README, "The blank-subtracting path leaves
  an injector artefact".

* Documentation: the README gains use case scenarios, a screenshot walkthrough of the app, a
  worked data cases section and a references section. Sample identifiers in the examples and
  screenshots no longer contain anything that reads as a date.

# hplcAnalyzer 0.4.0

* **The 214 nm tryptophan extinction coefficient is recalibrated, from the published 29,050
  to a measured 17,340, together with a 1.118 scale on the rest of eps214.** This changes
  every concentration the package reports at 214 nm. Tryptophan-free peptides read 10.6
  percent lower; tryptophan peptides read 30 to 46 percent higher. Purity, `Area (%)` and any
  ratio between peptides within one run are unaffected, because the tryptophan-free shift is
  a single common factor.

  A peptide measured at both wavelengths gives two concentrations from one injection, so
  amount and batch offset cancel in their ratio and only the extinction model is left. On 130
  such injections that ratio tracks tryptophan and nothing else (rho -0.76, p < 1e-13): median
  1.17 with no Trp, 0.82 with one, 0.68 with two. Fitted on the 71 injections passing an 80
  percent purity gate, bootstrapped 4000 times, the tryptophan term comes out 17,340 (95 % CI
  14,519 to 19,569) and the scale on everything else 1.118 (95 % CI 1.01 to 1.26). Tyrosine
  and phenylalanine, freed in the same fit, return to their published values and are unchanged.
  Fitting each batch alone gives 15,300 and 18,200, and amino acid analysis, which is not in
  the fit, agrees independently. Across the 130 injections, 214 against 280 nm improves from
  R2 0.68 to 0.87 and the median absolute difference between the channels, as a percentage of
  the mean of the pair, from 17.3 to 8.1 percent.

  The scale of 1.118 is the soft half of the pair. Anchored on amino acid analysis instead it
  is 1.078, so 1.08 to 1.12 is the honest range and it should be set from a batch you trust.
  Shipping 1 is not a safe middle ground: it leaves the channels 15 percent apart. Both
  constants are named at the top of `R/estimate_epsilon_214.R`, and the same pair is repeated
  in `peptide-calculator/src/calculations.js`. See the README section "Recalibration of
  eps214" for the figure and the full argument.

* **New exported function `published_epsilon_214()`**, the Kuipers and Gruppen model exactly as
  printed, with no correction. `estimate_epsilon_214()` now builds on it. Keeping the two apart
  means the correction is visible and revertible without disturbing the published model.

* **First tests in this package**, `tests/testthat/`, pinning the published values, the proline
  rule, the special tripeptides, the NA behaviour and the calibration arithmetic. The two
  calibration constants are expected to be revisited, so a change to either now shows up as a
  deliberate edit to a test rather than as silently different concentrations.

* The wavelength selector in the Shiny app and the two references in the desktop calculator now
  say the 214 nm model is recalibrated, so a user reading the screen is not told it is the
  published one.

# hplcAnalyzer 0.3.2

* **Maximum analyte retention time.** A new `max_rt_frac` argument on
  `detect_peaks_on_smoothed()` and both pipelines, and a matching "Max analyte RT (% of run)"
  slider, drop peaks that elute after a given fraction of the run. Every method here ends with
  a column regeneration step at high organic, and the detector reports it as a peak. It appears
  in all runs including blanks, so it is instrument behaviour rather than sample. Left at
  100 percent it was the largest peak on 32 of 57 quantified rows at 280 nm, and on one 214 nm
  run it reported 135.51 uM for a peak that is really 36.22 uM at 11.36 min.
  The default is 100 percent, which keeps the whole run, so nothing changes until the bound is
  set. 80 percent is the recommended setting; see the README for the measurement behind it.
* **`main_peak_area_pct` in the results CSV**, the main peak against the sum of the ten shown.
  Screen and CSV both go through `main_peak_area_percent()` so the two cannot drift apart, and
  the value stays populated where epsilon is NA, since purity is a ratio and needs no epsilon.
* New exported helpers: `peak_area_percent()`, `main_peak_area_percent()`.

# hplcAnalyzer 0.3.1

* **Area (%) column** in the on-screen peak table, and the table widened from the top five
  peaks to the top ten. Purity is an area ratio, so it needs no extinction coefficient, which
  makes it the one number that still works for peptides that cannot be quantified at 280 nm
  for lack of Trp and Tyr.
* The denominator is the ten peaks shown, not every peak detected. On a 280 nm trace the
  detector reports dozens of sub-mAU baseline features, and dividing by all of them drags a
  peptide better than 95 percent pure down to about 59 percent.

# hplcAnalyzer 0.3.0

* **Fixed: `estimate_epsilon_214()` never applied the 2675 term for internal proline.**
  Proline is deliberately absent from the coefficient table because Kuipers and Gruppen count
  it only when it is not N-terminal, but it was also absent from the factor levels built from
  that table, so `table()` dropped every proline and `cnt["P"]` returned NA. The term never
  fired. Concentration is inversely proportional to epsilon, so 214 nm results were overstated:
  28 of the 47 peptides in the reference batch were affected, median 12 percent, worst
  28.5 percent. **214 nm concentrations from earlier versions are wrong for proline-containing
  peptides and should be recomputed.**
* **Injection volume is now settable, in microlitres.** It had been fixed at 0.1 mL. The
  default is 100 uL, byte identical to the previous behaviour, and the metrics header shows the
  value the numbers were computed with.
* **A sample with no extinction coefficient no longer shows a chromatogram.** At 280 nm a
  peptide without Trp or Tyr cannot be quantified and the detected peaks are sub-mAU baseline
  features, so the plot invited a reading of data that is not there. Keyed on epsilon being NA
  rather than on the wavelength, so it also covers a sequence that failed to resolve.
* Packaging: `Author` and `Maintainer` added so `R CMD check` runs, and `magrittr` declared
  explicitly rather than arriving by accident through `dplyr`.

# hplcAnalyzer 0.2.0

First version under version control. Everything below shipped as part of it.

## 280 nm support

* `estimate_epsilon_280()`, the Edelhoch method as revised by Pace et al. 1995:
  `5500 * nTrp + 1490 * nTyr`. Cystine is not included because the disulfide state of a
  purity-check peptide is unknown. Returns NA when the peptide has neither Trp nor Tyr, since
  such a peptide cannot be quantified at 280 nm at all.
* `plot_largest_peak()` takes `signal_wavelength` as a **required** argument. It previously
  hardcoded "e214" in the metrics table, so a 280 nm run displayed an Edelhoch value under a
  Kuipers and Gruppen label. Required rather than defaulted, so a caller that forgets it fails
  loudly instead of silently mislabelling.
* **280 nm is never blank subtracted**, whatever the caller asks for. Over 69 production runs
  the gradient baseline drifts 1.81 mAU/min at 214 nm but only 0.003 mAU/min at 280 nm, and the
  blank accounts for under 0.04 percent of any 280 nm peak area. Against hand-integrated areas
  on eight well-resolved peaks the hybrid path is biased high on every one (median +6.6 percent,
  up to +12.2) while ALS alone stays within 2.6 percent. This overrides an explicit
  `use_hybrid = TRUE`, because `use_hybrid` is set from "a blank folder exists", which is a fact
  about the plate and not a scientific judgement. 214 nm behaviour is unchanged.
* Batch loading no longer collapses every failure to an all-NA row. Each row carries its
  reason: no channel at this wavelength, no peaks detected, or no extinction coefficient.

## Sequence resolution

* `read_chemstation_sample_name()`, `peptide_sequence_from_chemstation_sample_name()` and
  `peptide_sequence_from_sample_xml()` read the sequence from `SAMPLE.XML` inside the `.D`
  folder. ChemStation truncates the folder name at 40 characters, so parsing the sequence out
  of it was wrong for 40 of the 57 peptides in a production batch and returned nothing for the
  10 whose folder carries a replicate counter. Measured across that batch, the XML name is
  identical to the folder-derived sequence 15 times, longer 32 times, and disagrees never.
* Resolution order is now CSV map, then `SAMPLE.XML`, then the folder name, then NA. The CSV
  stays on top because ChemStation caps the XML name at 40 characters too, so two long peptides
  remain truncated at source.
* The discriminator for a non-peptide run is the MRMP id prefix, not the letters. WASH, BLANK
  and standby runs are spelled entirely in valid one-letter amino acid codes, so a letters-only
  test accepts WASH1 as the peptide "WASH".
* A downloadable CSV map template, prefilled with the resolved sequences.

## Core

* Readers for Agilent `.D` folders (`read_hplc_agilent()`, via `chromConverter`) and Thermo
  Chromeleon UV text exports (`read_hplc_thermo()`).
* Baseline correction: `baseline_als()`, `baseline_hybrid_sm()` and
  `align_subtract_then_hybrid()`.
* Peak detection on a Savitzky-Golay smoothed trace (`detect_peaks_on_smoothed()`), with
  trapezoidal areas and an SNR threshold.
* Sequence-specific eps214 after Kuipers and Gruppen 2007 (`estimate_epsilon_214()`), and
  Beer-Lambert area to concentration (`calculate_peak_conc()`).
* Injection volume parsed from `acq.txt`, handling UTF-16LE, UTF-16BE, UTF-8 and Latin-1.
* Shiny app (`run_hplc_app()`) with batch loading, manual brush integration, mark-as-bad, and
  CSV export.
