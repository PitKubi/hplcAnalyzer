# hplcAnalyzer 0.6.3

* **The screenshots now exercise the blank-subtracting path**, which is what a real batch uses
  and what was broken in 0.6.0 and 0.6.1. Every screenshot in this README had been taken on a
  demo folder with no blank in it, which is precisely why the crash in that path went unseen
  through two releases. The demo now contains a blank, the peak plot names it, and the figures
  show the ordinary workflow rather than the one configuration that never failed.

  The same peak reads 214.36 with the blank and 213.94 without, a difference of 0.2 percent,
  which is the robustness the local chord is there to give.

* **Removed `baseline_tuning_check.png` and the paragraph around it.** It compared two global ALS
  settings for their effect on peak area. Since 0.6.0 the global baseline does not decide any
  area, so the figure documented a behaviour the package no longer has. The measurement that
  replaced it is in "Why not a global baseline".

