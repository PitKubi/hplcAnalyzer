# hplcAnalyzer 0.7.7

* **The ALS baseline overlay panel is gone from the app.** It sat at the top of the main panel and
  drew the ALS baseline against the *corrected* trace, so the dashed line ran above the black one
  over most of the chromatogram and read as a baseline eating into the peaks. It was not: a
  baseline plotted on the signal it has already been subtracted from is above that signal by
  exactly the amount it subtracted. Measured on real runs it lay above the corrected trace on
  78.5 percent of points, by up to 33.7 mAU, but above the **raw** trace, the one it was fitted
  to, on only 4.0 percent, by at most 0.31 mAU.

  Since 0.7.x the ALS pass only seeds peak detection. Every reported area comes from the endpoint
  chord drawn on the raw trace. The panel therefore showed an intermediate step that decides no
  reported number, at the cost of repeatedly implying the tool was broken.

* No numbers change. The two remaining panels, the full run and the integration detail, both draw
  the raw trace with the chord that does decide the area.

# hplcAnalyzer 0.7.6

* **`sample_als_lambda` 4.5 and `sample_als_p` 10^-6.5**, chosen at the instrument on three test
  runs rather than by fitting a summary statistic. Better than the previous 5.5 and 1e-4 on every
  measure, at no cost. Over 47 runs: the baseline's climb into the main peak falls from 2.51 mAU
  to **0.34**, the worst it gets above the raw trace near the peak from 0.31 to **0.02**, and the
  offset it leaves in the first minute from 119 to **78**. Reported areas are unchanged, because
  they come from each peak's own chord.

  p is the parameter that keeps a baseline off a peak, and no amount of lambda substitutes for it;
  the lambda-only sweeps done earlier could not find this setting because they held p fixed.

