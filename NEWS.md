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
