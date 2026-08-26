#' Launch the HPLC Analyzer Shiny App
#'
#' @export
run_hplc_app <- function() {
  app_dir <- system.file("shiny", "app", package = "hplcAnalyzer")
  if (app_dir == "") {
    stop("Could not find app directory. Try reinstalling hplcAnalyzer.")
  }
  shiny::runApp(app_dir, display.mode = "normal")
}

