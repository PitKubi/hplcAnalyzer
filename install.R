#!/usr/bin/env Rscript

# Install hplcAnalyzer from this git checkout.
#
#   From a shell:      Rscript install.R
#   From R or RStudio: setwd("/path/to/the/clone"); source("install.R")
#
# R is the only prerequisite. The package is pure R, so no compiler and no Rtools
# are needed on Windows or macOS.
#
# The script is written in base R on purpose. Anything it could delegate to
# remotes, devtools or pak would itself have to be installed first, which is the
# problem this script exists to remove.

CRAN_MIRROR <- "https://cloud.r-project.org"

# The DESCRIPTION file is the single declaration of what hplcAnalyzer needs. Reading it
# here rather than repeating the list keeps the two from drifting apart when a dependency
# is added.
dependency_names_from_description <- function(description_path) {
  description <- read.dcf(description_path)
  fields <- intersect(c("Depends", "Imports"), colnames(description))
  entries <- unlist(strsplit(paste(description[1, fields], collapse = ","), ","))
  entries <- trimws(sub("\\(.*\\)", "", entries))
  # "R (>= 3.6)" is a version constraint on the interpreter, not an installable package.
  setdiff(entries[nzchar(entries)], "R")
}

not_yet_installed <- function(package_names) {
  is_available <- vapply(package_names, requireNamespace, logical(1), quietly = TRUE)
  package_names[!is_available]
}

install_from_cran <- function(package_names) {
  if (!length(package_names)) {
    message("All dependencies are already installed.")
    return(invisible(NULL))
  }
  message("Installing from CRAN: ", paste(package_names, collapse = ", "))
  install.packages(package_names, repos = CRAN_MIRROR)
  still_missing <- not_yet_installed(package_names)
  if (length(still_missing)) {
    stop("These dependencies failed to install: ",
         paste(still_missing, collapse = ", "),
         "\nInstall them by hand and re-run this script.", call. = FALSE)
  }
  invisible(NULL)
}

install_package_from_source_tree <- function(source_tree) {
  message("Installing hplcAnalyzer from ", source_tree)
  install.packages(source_tree, repos = NULL, type = "source")
}

# Two ways in, so the script behaves the same whether it is run with Rscript or sourced
# from an R session, and says so plainly when it is neither.
source_tree_holding_this_script <- function() {
  invocation <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  candidate <- if (length(invocation)) {
    dirname(sub("^--file=", "", invocation[1]))
  } else {
    getwd()
  }
  candidate <- normalizePath(candidate, mustWork = TRUE)
  if (!file.exists(file.path(candidate, "DESCRIPTION"))) {
    stop("No DESCRIPTION file in ", candidate,
         ".\nRun this script from the root of the hplcAnalyzer checkout.", call. = FALSE)
  }
  candidate
}

main <- function() {
  source_tree <- source_tree_holding_this_script()
  dependencies <- dependency_names_from_description(file.path(source_tree, "DESCRIPTION"))
  install_from_cran(not_yet_installed(dependencies))
  install_package_from_source_tree(source_tree)
  message("Installed hplcAnalyzer ", as.character(utils::packageVersion("hplcAnalyzer")),
          " into ", .libPaths()[1],
          "\nStart the app with:  library(hplcAnalyzer); run_hplc_app()")
}

main()
