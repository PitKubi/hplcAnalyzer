test_that("the baseline column pairs with the trace it was fitted to", {
  als <- data.frame(intensity = 1:3, baseline = c(0.1, 0.2, 0.3), corrected = 1:3)
  expect_identical(baseline_fitted_to_least_corrected_trace(als), als$baseline)

  hybrid <- data.frame(raw_diff = 1:3, baseline_local = c(9, 9, 9), corrected = 1:3)
  expect_identical(baseline_fitted_to_least_corrected_trace(hybrid), hybrid$baseline_local)

  expect_null(baseline_fitted_to_least_corrected_trace(data.frame(corrected = 1:3)))
})

test_that("a baseline above its own trace is measured, not hidden", {
  above <- summarise_baseline_above_trace(trace = c(10, 10, 10, 10),
                                          baseline = c(9, 9, 9, 12))
  expect_equal(above$fraction_of_points, 0.25)
  expect_equal(above$largest_excess, 2)
})

test_that("a baseline that never rises above its trace reports zero, not a negative excess", {
  below <- summarise_baseline_above_trace(trace = c(10, 20), baseline = c(1, 2))
  expect_equal(below$fraction_of_points, 0)
  expect_equal(below$largest_excess, 0)
})

test_that("the plot draws the raw trace and its baseline together, and the corrected trace apart", {
  df <- data.frame(time = seq(0, 1, length.out = 50))
  df$intensity <- 100 + sin(df$time * 10)
  df$baseline  <- rep(100, 50)
  df$corrected <- df$intensity - df$baseline

  p <- plot_baseline_subtraction(df)
  expect_s3_class(p, "ggplot")

  drawn <- p$data
  before <- unique(drawn$series[drawn$panel == "Raw signal, with the fitted baseline"])
  after  <- unique(drawn$series[drawn$panel == "After subtraction"])
  expect_setequal(as.character(before), c("Raw signal", "Fitted baseline"))
  expect_identical(as.character(after), "Corrected")
})
