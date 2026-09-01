# hplcAnalyzer 0.7.0

* **The chord is now anchored at the peak's own foot, not at the valley it shares with a
  neighbour.** This changes every area and concentration again, upward, and it is the fix for the
  baseline still cutting into peaks.

  The walk was being stopped at the neighbouring peak's valley, and the endpoint level was then
  fitted at that stop point. On a crowded run that point is partway up a flank, so the chord was
  anchored at the flank's height rather than the baseline's. Measured across 47 runs, the chord
  sat a median **33.6 mAU** above the local baseline, more than 20 mAU on **32 of 47** runs.
  Anchoring at the true foot instead: median **3.1 mAU**, more than 20 mAU on **2 of 47**.
  Main peak areas rise by a median of 17 percent, which is the signal that was being cut off.

  Fitting the endpoint with a straight line, a median or a lower quartile instead of the
  quadratic changes the anchor by under 2 mAU, so the curve shape was never the problem. The foot
  location was.

  The shared valley is still honoured, but as a bound on what gets integrated rather than on
  where the baseline is measured.

* Two consequences of the longer walk, both fixed here. The counted slice is the one holding the
  peak's **own apex**, not the tallest slice, because a small peak's envelope can now reach past
  a larger neighbour and "tallest" handed it the neighbour's area. And no cut may land within six
  points of the apex, which was halving peaks where the detector had put two apexes on one
  shoulder.

* Verified on 47 runs, both baseline paths: 47 of 47 complete, the integrated span contains the
  peak's apex on 47 of 47, median main peak Area (%) 53.1.

