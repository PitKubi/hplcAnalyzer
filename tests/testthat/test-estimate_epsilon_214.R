# The two constants in R/estimate_epsilon_214.R are expected to be revisited: the global
# scale in particular is the soft half of the fit. These tests pin the published model, which
# must never move, and the arithmetic that turns it into the calibrated value, so a change to
# a constant shows up as a deliberate edit here rather than as silently different concentrations.

test_that("the published model reproduces Kuipers and Gruppen", {
  expect_equal(published_epsilon_214("KPFLLLAIK"), 15553)
  expect_equal(published_epsilon_214("DIAAYIK"), 11166)
  expect_equal(published_epsilon_214("INEWLTK"), 34974)
})

test_that("the four special tripeptides bypass the additive model", {
  expect_equal(published_epsilon_214("GGG"), 1080)
  expect_equal(published_epsilon_214("GPG"), 3620)
  expect_equal(published_epsilon_214("PGG"), 950)
  expect_equal(published_epsilon_214("GGP"), 3880)
})

test_that("a proline that is not N-terminal is worth 2675 and an N-terminal one is not", {
  expect_equal(published_epsilon_214("KPFLLLAIK") - published_epsilon_214("KAFLLLAIK"), 2675 - 32)
  expect_equal(published_epsilon_214("PKFLLLAIK"), published_epsilon_214("AKFLLLAIK") - 32)
})

test_that("anything that is not a standard sequence returns NA", {
  expect_true(is.na(published_epsilon_214("WASH1")))
  expect_true(is.na(estimate_epsilon_214("WASH1")))
  expect_true(is.na(estimate_epsilon_214(NA_character_)))
})

test_that("the calibration scales the non-tryptophan part and replaces the tryptophan term", {
  scale <- NON_TRYPTOPHAN_EPSILON_214_SCALE
  measured <- MEASURED_TRYPTOPHAN_EPSILON_214

  expect_equal(estimate_epsilon_214("DIAAYIK"), scale * 11166)
  expect_equal(estimate_epsilon_214("INEWLTK"), scale * (34974 - 29050) + measured)
  expect_equal(estimate_epsilon_214("GGG"), scale * 1080)
})

test_that("tryptophan now lowers the concentration a peptide reports, and by how much", {
  # eps and concentration are inversely proportional, so a smaller tryptophan term raises the
  # reported concentration of a Trp peptide. This is the change collaborators will see first.
  ratio <- published_epsilon_214("INEWLTK") / estimate_epsilon_214("INEWLTK")
  expect_gt(ratio, 1.4)
  expect_lt(ratio, 1.5)
})
