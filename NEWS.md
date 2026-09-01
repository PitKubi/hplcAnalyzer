# hplcAnalyzer 0.6.0

* **Peaks are now integrated against a baseline drawn between their own two feet**, not against
  zero after a global baseline has been subtracted. This changes every area, every purity and
  every concentration the package reports.

  The window is found by walking outward from the apex, carrying on past any dip that is still
  well above the local level because such a dip is a fused neighbour and not the end of the
  peak. Each such dip becomes a perpendicular drop and only the slice holding the tallest apex,
  the analyte, is counted. Where two detected peaks meet, the boundary is the valley between
  them, so no two peaks claim the same trace and Area (%) stays a ratio of comparable numbers.
  Each foot level is fitted from the ten nearest points on the side away from the apex.

  **Why.** A global ALS baseline rises under a peak instead of passing beneath it, and the area
  under that hump is lost: measured over 47 runs, a median of **9.6 percent** of the 214 nm peak
  area, about 2 percent on a well-resolved peak, 10 to 12 on a crowded one, 52 percent at worst.
  ALS is still applied for the overlay plot and for peak detection, where a flat trace is what a
  threshold needs, but it no longer decides any area.

  The approach is the one in Peter Kubiniok's Prism integration code and is standard
  chromatographic practice.

* **New `Integration detail` panel in the app**, and `plot_peak_integration_detail()` behind it.
  The run plot above it still shows the whole acquired chromatogram and always will, but at that
  scale the baseline is a few pixels tall, so the geometry that decides the number gets its own
  zoomed panel: the chord in orange, the counted area shaded, a dotted line at each perpendicular
  drop. A shaded area drawn against a baseline the viewer cannot see is how the previous
  integration went unquestioned for as long as it did.

* New exported functions: `integrate_peak_against_endpoint_baseline()`,
  `reintegrate_peaks_against_endpoint_baseline()`, `fit_baseline_level_at_edge()`,
  `plot_peak_integration_detail()`. Both pipelines return `peak_geometry` alongside the results.

* Verified on 47 runs of a production batch: all 47 integrate, median main peak Area (%) 78.9.

