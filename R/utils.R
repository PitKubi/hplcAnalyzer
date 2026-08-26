#' Extract peptide sequence for a filename
#'
#' @param fname Character. Just the basename, e.g. "059-…_TESTPEPTIDEAK.D"
#' @param mapping Optional data.frame with columns filename, sequence
#' @return Character. The mapped or parsed sequence, or NA if none found
#' @export
extract_sequence <- function(fname, mapping = NULL) {
  # 1) mapping lookup
  if (!is.null(mapping)) {
    idx <- match(fname, mapping$filename)
    if (!is.na(idx)) return(mapping$sequence[idx])
  }
  # 2) parse trailing _ALLCAPS.D
  seq <- sub(".*_([A-Z]+)\\.D$", "\\1", fname)
  if (identical(seq, fname)) return(NA_character_)
  seq
}

#' Choose the “previous” blank for a given sample folder
#'
#' @param sample_fname Basename of the sample folder (e.g. "059-…_TESTPEPTIDEAK.D")
#' @param blank_folders Character vector of full paths to blank .D folders
#' @return Single path (or NULL)
#' @export
choose_blank_prev <- function(sample_fname, blank_folders) {
  sample_num <- as.numeric(sub("^(\\d+)-.*", "\\1", sample_fname))
  blank_nums <- as.numeric(sub("^(\\d+)-.*", "\\1", basename(blank_folders)))
  before     <- blank_folders[blank_nums < sample_num]
  if (length(before)) {
    before[which.max(blank_nums[blank_nums < sample_num])]
  } else if (length(blank_folders)) {
    blank_folders[1]
  } else {
    NULL
  }
}

#' Filter and rank peaks
#'
#' @param peaks_tbl Tibble from detect_peaks_on_smoothed
#' @param min_rt Numeric. Minimum apex_rt to keep.
#' @param top_n Integer. How many highest peaks to return.
#' @return A filtered & arranged tibble
#' @export
filter_top_peaks <- function(peaks_tbl, min_rt = 6, top_n = 10) {
  peaks_tbl %>%
    dplyr::filter(apex_rt > min_rt) %>%
    dplyr::arrange(dplyr::desc(height)) %>%
    dplyr::slice_head(n = top_n)
}

#' Share of the ranked peaks' summed area held by each peak
#'
#' @param top_peaks_tbl Tibble as returned by \code{\link{filter_top_peaks}}.
#' @return Numeric vector of percentages, one per row of \code{top_peaks_tbl}.
#' @export
peak_area_percent <- function(top_peaks_tbl) {
  # Each peak is measured against the sum of THESE peaks, not against every peak the detector
  # found. On a 280 nm trace the detector reports dozens of sub-mAU baseline features, and
  # dividing by all of them drags a >95 percent pure peptide down to about 59 percent. The
  # ranked set is the main peak plus its largest impurities, which is the population a purity
  # number is about.
  100 * top_peaks_tbl$area / sum(top_peaks_tbl$area, na.rm = TRUE)
}

#' Share of the ranked peaks' summed area held by the main peak
#'
#' @param peaks_tbl Tibble from \code{\link{detect_peaks_on_smoothed}}.
#' @param min_rt Numeric. Minimum apex_rt to keep.
#' @param top_n Integer. How many highest peaks to rank against each other.
#' @return Single numeric percentage, or NA when no peak survives the ranking.
#' @export
main_peak_area_percent <- function(peaks_tbl, min_rt = 6, top_n = 10) {
  # Why this exists rather than the caller ranking the peaks itself: the per-sample results
  # CSV and the on-screen peak table have to report the same purity for the same run, so both
  # reach it through this one function and cannot drift apart on the ranking rule.
  top_peaks <- filter_top_peaks(peaks_tbl, min_rt = min_rt, top_n = top_n)
  # A run with no ranked peak has no purity to report. NA rather than 0, which would read as a
  # measured absence of the main peak, and rather than 100, which would read as pure.
  if (nrow(top_peaks) == 0) return(NA_real_)
  peak_area_percent(top_peaks)[1]
}

