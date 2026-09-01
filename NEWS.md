# hplcAnalyzer 0.7.6

* **`sample_als_lambda` 4.5 and `sample_als_p` 10^-6.5**, chosen at the instrument on three test
  runs rather than by fitting a summary statistic. Better than the previous 5.5 and 1e-4 on every
  measure, at no cost. Over 47 runs: the baseline's climb into the main peak falls from 2.51 mAU
  to **0.34**, the worst it gets above the raw trace near the peak from 0.31 to **0.02**, and the
  offset it leaves in the first minute from 119 to **78**. Reported areas are unchanged, because
  they come from each peak's own chord.

  p is the parameter that keeps a baseline off a peak, and no amount of lambda substitutes for it;
  the lambda-only sweeps done earlier could not find this setting because they held p fixed.

