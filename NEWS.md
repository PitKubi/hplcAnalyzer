# hplcAnalyzer 0.6.2

* **Fixed: the blank-subtracting path errored on every run.** `align_subtract_then_hybrid()`
  returns a frame carrying `raw_diff` and no `intensity`, and 0.6.0 asked for `intensity`
  unconditionally, so a batch containing a blank, which is the ordinary case, failed on every
  sample with "missing value where TRUE/FALSE needed". Both pipelines and both plots now go
  through a new `least_corrected_trace()`, which takes `intensity` where it exists and
  `raw_diff` where it does not. Pinned by a test, because the two frames are built in different
  files and nothing else connected them.

  Verified on 47 runs of a production batch: **47 of 47 on both paths**, where the
  blank-subtracting path previously managed none.

* **Corrected a wrong number in the README.** It claimed the global ALS baseline cost a median
  9.6 percent of peak area, worst 52. That was measured on a prototype and does not describe the
  shipped code: measured properly it is a median of **1.0 percent**, interquartile 0.4 to 1.8,
  worst 3.6, and negative on 9 of 47 runs. The real argument for a local chord is robustness, and
  it is now stated with its own measurement: the two baseline paths now give areas within a
  median of **0.1 percent** of each other, where under the previous scheme the choice moved
  concentrations by 5 to 15 percent.

