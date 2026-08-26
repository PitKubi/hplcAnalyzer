#' Read the sample name ChemStation recorded for an Agilent .D run
#'
#' Agilent ChemStation writes the name that the operator typed into the sequence table
#' into `SAMPLE.XML` inside the acquisition folder. That name survives in full, whereas
#' the folder name on disk is truncated by the acquisition software.
#'
#' @param d_folder_path Character. Path to an Agilent `.D` acquisition folder.
#' @return Character. The text of the `<Name>` element, or `NA` when the file is absent,
#'   unreadable, unparseable or carries an empty name.
#' @export
read_chemstation_sample_name <- function(d_folder_path) {
  if (length(d_folder_path) != 1L || is.na(d_folder_path)) return(NA_character_)
  # The folders come off Windows, where file names are case insensitive, so a batch copied
  # onto a Linux box can carry either SAMPLE.XML or sample.xml.
  xml_path <- list.files(d_folder_path, pattern = "^sample\\.xml$",
                         ignore.case = TRUE, full.names = TRUE)
  if (!length(xml_path)) return(NA_character_)

  # A missing or damaged SAMPLE.XML must never abort a batch: the caller can still fall
  # back to the folder name, so every failure here degrades to NA rather than an error.
  doc <- tryCatch(xml2::read_xml(xml_path[1]), error = function(e) NULL)
  if (is.null(doc)) return(NA_character_)

  node <- xml2::xml_find_first(doc, "/Sample/Name")
  if (inherits(node, "xml_missing")) return(NA_character_)
  name <- trimws(xml2::xml_text(node))
  if (!nzchar(name)) return(NA_character_)
  name
}

#' Extract the peptide sequence from a ChemStation sample name
#'
#' @param sample_name Character. A ChemStation `<Name>` value, e.g.
#'   `"MRMP-00000001-002_2TESTPEPTIDEAK"`.
#' @return Character. The one-letter peptide sequence, or `NA` when the name does not
#'   describe a peptide injection.
#' @export
peptide_sequence_from_chemstation_sample_name <- function(sample_name) {
  if (length(sample_name) != 1L || is.na(sample_name)) return(NA_character_)

  # The MRMP id prefix, not the letters themselves, is what tells a peptide injection
  # apart from the washes, blanks and standby runs in the same sequence. Those are named
  # WASH1, BLANK0, standby and so on, and W, A, S and H are all valid one-letter amino
  # acid codes, so a letters-only test would happily turn WASH1 into the peptide "WASH".
  # The optional digits between the underscore and the sequence are ChemStation's
  # replicate counter: "MRMP-00000001-002_2TESTPEPTIDEAK" is replicate 2 of
  # TESTPEPTIDEAK, and the counter is not part of the peptide.
  peptide_injection <- "^MRMP[-_]?[0-9]{8}[-_]?[0-9]{3}_[0-9]*([ACDEFGHIKLMNPQRSTVWY]+)$"
  matched <- regmatches(sample_name,
                        regexec(peptide_injection, sample_name, ignore.case = TRUE))[[1]]
  if (length(matched) != 2L) return(NA_character_)
  toupper(matched[2])
}

#' Resolve the peptide sequence recorded in an Agilent .D folder's SAMPLE.XML
#'
#' @param d_folder_path Character. Path to an Agilent `.D` acquisition folder.
#' @return Character. The one-letter peptide sequence, or `NA` when the folder holds no
#'   usable sample name or the name is not a peptide injection.
#' @export
peptide_sequence_from_sample_xml <- function(d_folder_path) {
  peptide_sequence_from_chemstation_sample_name(read_chemstation_sample_name(d_folder_path))
}
