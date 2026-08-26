#' Read Chromeleon “UV_VIS_1.txt” export
#'
#' Parses the header to grab injection volume (µl → mL) and then reads the
#' 3-column table under “Chromatogram Data: [signal subtracted]”.
#'
#' @param file Path to a “*_UV_VIS_1.txt” export.
#' @return A data.frame with **time** (min) and **intensity** (mAU).
#'         Has an attribute `inj_vol_ml` (numeric).
#' @export
read_hplc_thermo <- function(file) {
  lines <- readLines(file)
  # 1) injection volume line: "Volume (µl)\t100.00"
  iv_line <- grep("^Volume.*\\t", lines, value=TRUE)
  inj_ul  <- if (length(iv_line)) {
    as.numeric(sub(".*\\t([0-9\\.]+).*", "\\1", iv_line[1]))
  } else 0.1
  inj_ml <- inj_ul / 1000
  
  # 2) find where data table begins
  idx <- grep("^Chromatogram Data:", lines)
  if (!length(idx)) {
    stop("Cannot find 'Chromatogram Data:' block in ", basename(file))
  }
  # header is two lines below
  header_line <- idx + 2
  
  # 3) read from there on
  df <- utils::read.table(
    file,
    skip      = header_line - 1,
    header    = TRUE,
    sep       = "\t",
    stringsAsFactors = FALSE,
    comment.char = ""
  )
  
  # expect columns like "Time..min.", "Step..s.", "Value..mAU"
  # normalize to time & intensity
  names(df)[1:3] <- c("time", "step_s", "value")
  df2 <- df[, c("time","value"), drop=FALSE]
  names(df2) <- c("time","intensity")
  
  attr(df2, "inj_vol_ml") <- inj_ml
  df2
}
