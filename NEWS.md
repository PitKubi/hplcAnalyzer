# hplcAnalyzer 0.7.5

* **The global ALS baseline is stiffer: `sample_als_lambda` 4.0 to 5.5.** At 4.0 it arced up into
  the main peak instead of passing under it, rising from about 23 mAU either side of a peak to 40
  beneath it. Measured over 24 runs it climbed a median of 6.2 mAU above the straight line joining
  its own values at the peak's feet; at 5.5 that is 0.9 mAU.

  One global λ cannot both follow the injector disturbance and stay stiff under a peak. The trade
  is monotone: from λ 4 to 6.5 the climb falls 6.2 to 0.5 mAU while the corrected trace's offset
  in the first minute rises 13 to 138. 5.5 is the knee.

  This moves reported areas by 0.3 percent, because areas come from each peak's own chord rather
  than from this baseline. What it changes is what the overlay plot shows, which is the first
  thing anyone looks at, and it should not look like the baseline is eating the peak.

