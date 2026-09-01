# hplcAnalyzer 0.6.1

* **The foot walk runs much further, so the baseline stops cutting into the peak.**
  `foot_fraction` goes from 0.02 to **0.002**. At 0.02 the walk stopped well up the flank and the
  chord was drawn above the real baseline: on one peak it sat at 44 mAU where the trace either
  side of the peak sits at 32, so 13 mAU was cut off across the peak's entire width. At 0.002 the
  chord sits within about 2 mAU of the local baseline.

  The value is measured rather than chosen. Integrating the same peak across a range of settings
  on six peptides, the area settles by 0.002 on all six and moves by no more than 0.15 percent
  below it, while above it the six diverge by up to 3 percent. The sweep is in the README.
  `foot_fraction` is an argument on `integrate_peak_against_endpoint_baseline()`.

* Verified on 47 runs: all 47 integrate, median main peak Area (%) 78.9.

