# hplcAnalyzer 0.7.4

* **The app no longer takes the blank-subtracting path just because a blank is in the folder.**
  That path's piecewise baseline is not a baseline: on a production run it jumps **171 mAU between
  two adjacent points** and dives to -171 at both ends of the chromatogram, where the plain ALS fit
  moves at most **0.8 mAU** between points. It also over-subtracts the blank's own injector peak,
  leaving about -317 mAU at 3.3 min in every run, which has been documented since 0.5.2.

  It was worth tolerating when a global baseline decided the area. It is not now: with each peak
  integrated against its own chord, choosing that path moves the reported area by a median of 1.6
  percent. The plain ALS baseline is smooth, continuous and sits on zero across the run, and it is
  what the overlay plot now shows.

  Still available as `use_hybrid = TRUE` on `run_hplc_analysis_agilent()`.

