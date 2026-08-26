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

