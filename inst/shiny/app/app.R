library(shiny)
library(shinyFiles)
library(fs)
library(hplcAnalyzer)
library(ggplot2)
library(dplyr)
library(pracma)   # for trapz()
library(DT)
## ---- FORCE dplyr verbs so filter(), arrange(), slice_head(), desc() are the right ones:
filter      <- dplyr::filter
arrange     <- dplyr::arrange
slice_head  <- dplyr::slice_head
desc        <- dplyr::desc

# Every Agilent run the app has ever quantified used 0.1 mL, because run_hplc_analysis_agilent()
# defaults to that and the app never passed anything else. Starting the control at the same
# 100 µL is what makes an untouched sidebar reproduce the numbers the app produced before this
# input existed. It is also what the instrument actually injects.
DEFAULT_INJECTION_VOLUME_UL <- 100

# The min slider has shipped at 30 percent of the run since it was added, and the max bound is
# added at 100 percent, which is the whole run. Both are named here because the sanitiser has to
# fall back to exactly the number the slider starts at; two copies of that number would be free
# to drift apart.
DEFAULT_MIN_ANALYTE_RT_PERCENT <- 30
DEFAULT_MAX_ANALYTE_RT_PERCENT <- 100

ui <- fluidPage(
  titlePanel("HPLC-UV Analyzer"),
  sidebarLayout(
    sidebarPanel(
      shinyDirButton("dir", "Choose folder directory (Agilent .D or Thermo export", "Browse..."),
      verbatimTextOutput("selectedDir"),
      fileInput("mapfile", "Optional CSV map (Thermo: Well→Sequence; Agilent: MRMP→Sequence)", accept = ".csv"),
      downloadButton("downloadSeqTemplate", "Download CSV map template"),

      radioButtons(
        "wavelength",
        "Detection wavelength / ε formula:",
        choices  = c("214 nm (Kuipers & Gruppen)" = 214,
                     "280 nm (Edelhoch)"          = 280),
        selected = 214,
        inline   = TRUE
      ),
      selectInput(
        "thermo_channel",
        "Thermo UV channel (matches *_UV_VIS_N.txt):",
        choices  = c("1" = 1, "2" = 2, "3" = 3, "4" = 4),
        selected = 1,
        width    = "100%"
      ),
      numericInput(
        "dilution_factor",
        "Dilution factor (×):",
        value = 1, min = 0.0001, step = 1,
        width = "100%"
      ),
      helpText("Final conc shown = raw conc × dilution factor. e.g. enter 10 for 1:10 dilution."),

      numericInput(
        "injection_volume_ul",
        "Injection volume (µL):",
        value = DEFAULT_INJECTION_VOLUME_UL, min = 0.1, step = 10,
        width = "100%"
      ),
      helpText("Volume injected on column. Concentration scales inversely with it. Applies to Agilent .D runs; Thermo exports carry their own injection volume in the file header."),

      actionButton("load", "Load samples"),
      hr(),

      selectInput(
        "blank_override",
        "Override blank (optional):",
        choices  = c("Auto" = "AUTO"),
        selected = "AUTO",
        width    = "100%"
      ),
      hr(),

      ## ← NEW: min‐RT slider (default 30%)
      sliderInput(
        "min_rt_perc",
        "Min analyte RT (% of run):",
        min   = 0,
        max   = 100,
        value = DEFAULT_MIN_ANALYTE_RT_PERCENT,
        step  = 1
      ),
      sliderInput(
        "max_rt_perc",
        "Max analyte RT (% of run):",
        min   = 0,
        max   = 100,
        value = DEFAULT_MAX_ANALYTE_RT_PERCENT,
        step  = 1
      ),
      helpText("Both bounds are a percentage of the run length, so one setting fits methods of different duration. 100% keeps the whole run. Lower it to drop the column regeneration step every method ends with, which the detector otherwise reports as a peak and which then takes a share of Area (%)."),
      hr(),

      ## ← NEW: Reset manual integration
      actionButton("resetWin", "Reset integration", icon = icon("undo")),
      hr(),
      actionButton("markBad", "Mark as bad", icon = icon("times-circle")),
      hr(),


      actionButton("btn_prev", "Previous Sample"),
      actionButton("btn_next", "Next Sample"),
      hr(),
      downloadButton("downloadResults", "Download Results CSV"),
      hr(),
      h5(textOutput("metricsHeader")),
      tableOutput("metricsTable")
    ),

    mainPanel(
      DTOutput("samplesDT"),
      tags$style(HTML("#samplesDT {font-size: 12px;}.dataTables_wrapper .dataTables_scrollBody {border: 1px solid #eee;}")),
      hr(),
      plotOutput("rawOverlay", height = "300px"),
      hr(),
      h4(textOutput("currentSample")),
      plotOutput(
        "peakPlot",
        brush = brushOpts(
          id         = "peakBrush",
          direction  = "x",
          resetOnNew = TRUE
        )
      )
    )
  )
)


# The pipeline stamps the injection volume it actually used onto the corrected trace, so every
# display reads it back from there rather than from the input box and can never disagree with
# the concentrations next to it.
injection_volume_ml_used <- function(df_hybrid, fallback_ml) {
  stamped <- if (is.null(df_hybrid)) NULL else attr(df_hybrid, "inj_vol_ml")
  if (is.null(stamped) || !is.numeric(stamped) || is.na(stamped)) fallback_ml else stamped
}

# Why the reason is read off the sequence rather than off the wavelength: ε is NA both when the
# peptide has no chromophore at the detection wavelength and when no sequence was ever
# resolved, and naming the wrong one sends the user to fix the wrong thing.
missing_epsilon_reason <- function(peptide_sequence) {
  if (is.null(peptide_sequence) || length(peptide_sequence) != 1L ||
      is.na(peptide_sequence) || !nzchar(peptide_sequence)) {
    return("no peptide sequence was resolved for this run")
  }
  if (!grepl("[WY]", peptide_sequence)) {
    return(paste0("the peptide ", peptide_sequence, " contains no Trp and no Tyr"))
  }
  paste0("no ε could be computed for the sequence ", peptide_sequence)
}

# Why the chromatogram is withheld rather than drawn without a concentration: with no ε the
# peaks the detector still reports at this wavelength are sub-mAU baseline features, and drawn
# on an autoscaled axis they read as signal.
missing_epsilon_plot <- function(signal_wavelength, peptide_sequence) {
  ggplot() +
    annotate(
      "text", x = 0.5, y = 0.5, size = 4.5, lineheight = 1.5,
      label = sprintf(
        "NA (missing ε)\n\nNo extinction coefficient at %g nm:\n%s,\nso no concentration can be calculated.\n\nChromatogram not shown.",
        signal_wavelength, missing_epsilon_reason(peptide_sequence))
    ) +
    theme_void()
}

# main_peak_area_pct is the purity number the peak table shows on screen, carried into the
# per-sample results so that the downloaded CSV and the screen cannot report different
# purities for the same run. It is a ratio of two areas, so it stays valid on a run whose ε is
# NA and which therefore has no concentration at all.
empty_results <- function() {
  tibble::tibble(
    sample             = character(),
    rt                 = numeric(),
    height             = numeric(),
    area               = numeric(),
    main_peak_area_pct = numeric(),
    conc_uM            = numeric(),
    sequence           = character(),
    status             = character()
  )
}

# Why a row carries no concentration. A run with no channel at the selected
# wavelength, a run where the detector found no peaks and a peptide with no ε all
# used to collapse to the same all-NA row, so the user could not tell which had
# happened.
unquantified_result_row <- function(sample_name, sequence, status) {
  data.frame(
    sample             = sample_name,
    rt                 = NA_real_,
    height             = NA_real_,
    area               = NA_real_,
    main_peak_area_pct = NA_real_,
    conc_uM            = NA_real_,
    sequence           = sequence,
    status             = status,
    stringsAsFactors   = FALSE
  )
}

# Peptides with neither Trp nor Tyr have no 280 nm chromophore, so estimate_epsilon_280()
# returns NA and no concentration can be computed. Same wording as the metrics table.
concentration_status <- function(epsilon) {
  if (is.na(epsilon)) "NA (missing ε)" else "OK"
}


server <- function(input, output, session) {
  # --- filesystem & sample list ---
  roots <- c(Home = fs::path_home(), Root = "/")
  shinyDirChoose(input, "dir", roots = roots, session = session)

  samples       <- reactiveVal(character())
  seq_map       <- reactiveVal(NULL)
  results       <- reactiveVal(empty_results())
  blank_folders <- reactiveVal(character())

  output$selectedDir <- renderText({
    req(input$dir)
    parseDirPath(roots, input$dir)
  })


  ## --- Helpers for mapping sequences from the uploaded CSV --------------------

  # Pull an MRMP id like "MRMP-00000001-001" out of a filename/folder name
  # -- Pull an MRMP id like "MRMP-00000001-001" out of a filename/folder name
  extract_mrmp_id <- function(x) {
    m <- regexpr("MRMP[-_]?\\d{8}[-_]?\\d{3}", x, ignore.case = TRUE)
    if (m[1] == -1) return(NA_character_)
    id <- substr(x, m[1], m[1] + attr(m, "match.length") - 1)
    toupper(gsub("_", "-", id))   # normalize
  }

  # Pull a plate well like "P1-C1" out of a Thermo export filename, inserting the hyphen
  # when the exporter wrote the run as "P1C1".
  extract_well_id <- function(x) {
    well <- regmatches(x, regexpr("P[0-9]+[-]?[A-H][0-9]+", x, ignore.case = TRUE))
    if (!length(well) || !nzchar(well)) return(NA_character_)
    sub("^(P[0-9]+)([A-H][0-9]+)$", "\\1-\\2", well, ignore.case = TRUE)
  }

  # -- Lookup sequence from uploaded CSV; warn on every fallback
  sequence_from_map <- function(sample_path, map_df, notify = TRUE, persist = 6) {
    n <- basename(sample_path)
    notify_fb <- function(reason) {
      if (notify) shiny::showNotification(
        paste0("Fallback to filename mapping for ", n, " – ", reason),
        type = "warning", duration = persist
      )
    }

    # Resolution order once the uploaded CSV has not answered: the sample name ChemStation
    # stored in SAMPLE.XML, then the truncated folder name. The XML name is never shorter
    # than the folder name, but ChemStation caps it at 40 characters, which is exactly why
    # an explicit CSV entry still has to win over it.
    agilent_sequence_below_csv <- function() {
      from_sample_xml <- hplcAnalyzer::peptide_sequence_from_sample_xml(sample_path)
      if (!is.na(from_sample_xml)) return(from_sample_xml)
      hplcAnalyzer::extract_sequence(n, map_df)
    }

    # THERMO (.txt) — Well -> Sequence
    if (grepl("\\.txt$", n, ignore.case = TRUE)) {
      if (is.null(map_df)) {
        notify_fb("no CSV loaded (Thermo).")
        return(hplcAnalyzer::extract_sequence(n, map_df))
      }
      well_col <- grep("well", names(map_df), ignore.case = TRUE, value = TRUE)[1]
      seq_col  <- grep("pept.*seq|peptide.*sequence|sequence",
                       names(map_df), ignore.case = TRUE, value = TRUE)[1]
      if (is.na(well_col) || is.na(seq_col)) {
        notify_fb("CSV missing Well and/or Sequence column(s).")
        return(hplcAnalyzer::extract_sequence(n, map_df))
      }
      well <- extract_well_id(n)
      if (is.na(well)) {
        notify_fb("could not parse Well from filename.")
        return(hplcAnalyzer::extract_sequence(n, map_df))
      }
      idx <- which(trimws(map_df[[well_col]]) == well)
      if (!length(idx)) {
        notify_fb(paste0("Well ", well, " not found in CSV."))
        return(hplcAnalyzer::extract_sequence(n, map_df))
      }
      return(map_df[[seq_col]][idx[1]])
    }

    # AGILENT (.D) — MRMP -> Sequence
    if (grepl("\\.D$", n, ignore.case = TRUE)) {
      if (is.null(map_df)) {
        notify_fb("no CSV loaded (Agilent/MRMP).")
        return(agilent_sequence_below_csv())
      }
      mrmp_col <- grep("mrmp", names(map_df), ignore.case = TRUE, value = TRUE)[1]
      seq_col  <- grep("pept.*seq|peptide.*sequence|sequence",
                       names(map_df), ignore.case = TRUE, value = TRUE)[1]
      if (is.na(mrmp_col) || is.na(seq_col)) {
        notify_fb("CSV missing MRMP and/or Sequence column(s).")
        return(agilent_sequence_below_csv())
      }
      key <- extract_mrmp_id(n)
      if (is.na(key)) {
        notify_fb("could not parse MRMP id from filename.")
        return(agilent_sequence_below_csv())
      }
      keys <- toupper(gsub("_", "-", trimws(as.character(map_df[[mrmp_col]]))))
      idx  <- which(keys == key)
      if (!length(idx)) {
        notify_fb(paste0("MRMP id ", key, " not found in CSV."))
        return(agilent_sequence_below_csv())
      }
      return(map_df[[seq_col]][idx[1]])
    }

    # Unknown file type
    notify_fb("unknown file type for mapping.")
    hplcAnalyzer::extract_sequence(n, map_df)
  }

  # A starting point for the CSV the user uploads, so the sequences only have to be
  # corrected rather than typed from scratch. Sequence is pre-filled with whatever the app
  # resolved on its own, which makes re-uploading an untouched template a no-op. Both key
  # columns are always written because the CSV is keyed on the MRMP id for Agilent .D runs
  # and on the plate well for Thermo exports, and one template has to serve both.
  sequence_map_template <- function(sample_paths, map_df) {
    resolved_sequence <- function(sample_path) {
      seq_one <- sequence_from_map(sample_path, map_df, notify = FALSE)
      if (is.null(seq_one) || length(seq_one) != 1L || is.na(seq_one)) return(NA_character_)
      as.character(seq_one)
    }
    data.frame(
      MRMP      = vapply(basename(sample_paths), extract_mrmp_id, character(1)),
      Well      = vapply(basename(sample_paths), extract_well_id, character(1)),
      Sequence  = vapply(sample_paths, resolved_sequence, character(1)),
      Run       = basename(sample_paths),
      stringsAsFactors = FALSE,
      row.names        = NULL
    )
  }



  observeEvent(input$load, {
    req(input$dir)
    dirpath  <- parseDirPath(roots, input$dir)
    subs     <- list.dirs(dirpath, full.names = TRUE, recursive = FALSE)
    d_folds  <- grep("\\.D$", subs, value = TRUE)

    blanks     <- d_folds[grepl("BLANK", basename(d_folds), ignore.case = TRUE)]
    samples_ls <- setdiff(d_folds, blanks)

    ## ← NEW: also find Thermo exports (channel chosen in sidebar)
    thermo_files <- list.files(
      dirpath,
      pattern    = paste0("UV_VIS_", input$thermo_channel, "\\.txt$"),
      full.names = TRUE
    )
    samples_ls <- c(samples_ls, thermo_files)


    samples(samples_ls)
    blank_folders(blanks)

    updateSelectInput(
      session, "blank_override",
      choices  = c("Auto" = "AUTO", setNames(blanks, basename(blanks))),
      selected = "AUTO"
    )

    if (!is.null(input$mapfile)) {
      seq_map(read.csv(input$mapfile$datapath, stringsAsFactors = FALSE))
    } else {
      seq_map(NULL)
    }

    # reset results, then auto‐compute one row per sample
    results(empty_results())
    {
      m <- seq_map()
      inj_ml <- injection_volume_ml()
      rt_window <- analyte_rt_window()
      auto_res <- lapply(samples_ls, function(sp) {
        fn <- basename(sp)
        # 1) figure out peptide sequence
        # seq_sp <- if (grepl("\\.txt$", fn, ignore.case=TRUE) && !is.null(m)) {
        #   well_col <- grep("Well", names(m), ignore.case=TRUE, value=TRUE)[1]
        #   seq_col  <- grep("Peptide.*Sequence", names(m), ignore.case=TRUE, value=TRUE)[1]
        #   well <- regmatches(fn,
        #                      regexpr("P[0-9]+-?[A-H][0-9]+", fn, ignore.case=TRUE))
        #   well <- sub("^(P[0-9]+)([A-H][0-9]+)$", "\\1-\\2", well, ignore.case=TRUE)
        #   idx <- which(m[[well_col]] == well)
        #   if (length(idx)) m[[seq_col]][idx[1]] else NA_character_
        # } else {
        #   hplcAnalyzer::extract_sequence(fn, m)
        # }

        # 1) figure out peptide sequence (Thermo well OR Agilent MRMP via uploaded CSV)
        seq_sp <- sequence_from_map(sp, m)


        # 2) pick blank for .D only
        blank_sp <- if (grepl("\\.D$", fn, ignore.case=TRUE)) {
          if (input$blank_override != "AUTO" && nzchar(input$blank_override))
            input$blank_override
          else
            hplcAnalyzer::choose_blank_prev(fn, blank_folders())
        } else NULL

        # 3) run the right pipeline
        wl <- as.numeric(input$wavelength)
        analysis <- tryCatch({
          if (grepl("\\.D$", sp, ignore.case=TRUE)) {
            run_hplc_analysis_agilent(
              sample_d_path           = sp,
              blank_d_path            = blank_sp,
              peptide_sequence        = seq_sp,
              use_hybrid              = !is.null(blank_sp),
              min_rt_frac             = rt_window$min_frac,
              max_rt_frac             = rt_window$max_frac,
              signal_wavelength       = wl,
              inj_vol_ml              = inj_ml,
              show_intermediate_plots = FALSE
            )
          } else {
            run_hplc_analysis_thermo(
              sample_file             = sp,
              peptide_sequence        = seq_sp,
              min_rt_frac             = rt_window$min_frac,
              max_rt_frac             = rt_window$max_frac,
              signal_wavelength       = wl,
              show_intermediate_plots = FALSE
            )
          }
        }, error = function(e) e)

        # 4) collapse to one row, keeping the failure reason. Same wording as the
        # single-sample view, which already notifies on these two conditions.
        if (inherits(analysis, "error")) {
          unquantified_result_row(fn, seq_sp,
                                  paste("❌ Error:", conditionMessage(analysis)))
        } else if (nrow(analysis$peak_table) == 0) {
          unquantified_result_row(fn, seq_sp, "⚠️ No peaks detected")
        } else {
          data.frame(
            sample             = fn,
            rt                 = analysis$peak_table$apex_rt[1],
            height             = analysis$peak_table$height[1],
            area               = analysis$peak_table$area[1],
            main_peak_area_pct = hplcAnalyzer::main_peak_area_percent(analysis$peak_table),
            conc_uM            = analysis$concentration_uM,
            sequence           = seq_sp,
            status             = concentration_status(analysis$epsilon),
            stringsAsFactors   = FALSE
          )
        }
      })
      results(do.call(rbind, auto_res))
    }

    isolate(update_sample_index(1))
  })

  # --- navigation ---
  current_index <- reactiveVal(1)
  update_sample_index <- function(i) {
    N <- length(samples()); current_index(pmax(1, pmin(i, N)))
  }
  observeEvent(input$btn_prev, update_sample_index(current_index() - 1))
  observeEvent(input$btn_next, update_sample_index(current_index() + 1))

  current_sample <- reactive({ samples()[current_index()] })
  output$currentSample <- renderText({
    fn <- basename(current_sample())
    sprintf("Sample %d of %d:\n%s",
            current_index(), length(samples()), fn)
  })

  chosen_blank <- reactive({
    sp <- current_sample()
    fn <- basename(sp)

    # if not an Agilent .D, never use a blank
    if (!grepl("\\.D$", fn, ignore.case=TRUE)) return(NULL)

    # if user manually overrode
    if (nzchar(input$blank_override) && input$blank_override != "AUTO") {
      return(input$blank_override)
    }

    # otherwise pick the previous blank
    hplcAnalyzer::choose_blank_prev(fn, blank_folders())
  })

  # — pick peptide sequence for both Agilent and Thermo
  # seq_used <- reactive({
  #   fname <- basename(current_sample())
  #   m     <- seq_map()
  #   # if it's a Thermo export and we have a map, do a Well→Peptide Sequence lookup:
  #   if (grepl("\\.txt$", fname, ignore.case=TRUE) && !is.null(m)) {
  #     # find the two relevant columns (case-insensitive):
  #     well_col <- grep("Well", names(m), ignore.case=TRUE, value=TRUE)[1]
  #     seq_col  <- grep("Peptide.*Sequence", names(m), ignore.case=TRUE, value=TRUE)[1]
  #     if (!is.na(well_col) && !is.na(seq_col)) {
  #       # extract “P1-C1” (or “P12-H10”, etc.) from the filename:
  #       well <- regmatches(fname,
  #                          regexpr("P[0-9]+[-]?[A-H][0-9]+", fname, ignore.case=TRUE))
  #       # if no hyphen, insert one (e.g. “P1A1” → “P1-A1”):
  #       well <- sub("^(P[0-9]+)([A-H][0-9]+)$", "\\1-\\2", well, ignore.case=TRUE)
  #       if (length(well)==1 && well != "") {
  #         idx <- which(m[[well_col]] == well)
  #         if (length(idx)) return(m[[seq_col]][idx[1]])
  #       }
  #     }
  #     warning("No sequence found for well “", fname,
  #             "” – your map needs a column named “", well_col,
  #             "” containing ", well, "\nMap has: ",
  #             paste(unique(m[[well_col]]), collapse=", "))
  #     return(NA_character_)
  #   }
  #   # otherwise fall back to the old filename→sequence logic:
  #   hplcAnalyzer::extract_sequence(fname, m)
  # })


  seq_used <- reactive({
    sequence_from_map(current_sample(), seq_map())
  })






  use_hybrid <- reactive({
    cb <- chosen_blank()
    !is.null(cb) && nzchar(cb) && dir.exists(cb)
  })

  # --- store per‐sample manual windows ---
  selected_windows <- reactiveVal(list())

  # track samples the user has explicitly marked bad
  bad_samples <- reactiveVal(character())

  observeEvent(input$markBad, {
    fn <- basename(current_sample())
    # record it in bad_samples()
    bad_samples(unique(c(bad_samples(), fn)))
    # immediately blank out its conc in results()
    res <- results()
    if (fn %in% res$sample) {
      res[res$sample == fn, "conc_uM"] <- NA_real_
      # Without this the row would keep its old status and claim the blanked
      # concentration was fine.
      res[res$sample == fn, "status"]  <- "Marked bad"
      results(res)
    }
  })


  # Sanitize dilution factor: NA / non-finite / non-positive → 1
  dilution <- reactive({
    df <- suppressWarnings(as.numeric(input$dilution_factor))
    if (!isTRUE(is.finite(df)) || df <= 0) 1 else df
  })

  # Same fallback rule as the dilution factor above. The UI asks for µL because that is the
  # unit the instrument reports and the unit a chemist types; the pipeline works in mL.
  injection_volume_ml <- reactive({
    ul <- suppressWarnings(as.numeric(input$injection_volume_ul))
    if (!isTRUE(is.finite(ul)) || ul <= 0) ul <- DEFAULT_INJECTION_VOLUME_UL
    ul / 1000
  })

  # Same fallback rule again, for one end of the analyte RT window. The sliders speak percent
  # of the run because that is what a chromatographer reads off a method; the pipeline takes a
  # fraction.
  sanitised_rt_fraction <- function(percent_input, fallback_percent) {
    percent <- suppressWarnings(as.numeric(percent_input))
    if (!isTRUE(is.finite(percent)) || percent < 0 || percent > 100) {
      percent <- fallback_percent
    }
    percent / 100
  }

  # Why the two bounds are sanitised together rather than one reactive each: a max at or below
  # the min describes an empty window, and honouring it would report "no peaks detected" for
  # every run in the batch. Falling back to the whole run reports the numbers the app reported
  # before either bound was touched, which is the one answer that is never silently wrong.
  analyte_rt_window <- reactive({
    min_frac <- sanitised_rt_fraction(input$min_rt_perc, DEFAULT_MIN_ANALYTE_RT_PERCENT)
    max_frac <- sanitised_rt_fraction(input$max_rt_perc, DEFAULT_MAX_ANALYTE_RT_PERCENT)
    if (max_frac <= min_frac) max_frac <- DEFAULT_MAX_ANALYTE_RT_PERCENT / 100
    list(min_frac = min_frac, max_frac = max_frac)
  })

  ####reactive for sample table
  samples_table <- reactive({
    req(samples())
    # base list of samples in original order (no blanks)
    base <- tibble::tibble(sample = basename(samples()))
    # join whatever results you have so far (may be NA initially)
    res  <- results()
    if (!is.null(res) && nrow(res)) {
      # keep original order of 'samples()'
      base <- dplyr::left_join(base, res, by = "sample")
    }
    df <- dilution()
    # pretty columns for the table
    base %>%
      transmute(
        Sample                 = sample,
        `RT (min)`             = round(rt, 2),
        `Area`                 = round(area, 2),
        `Conc raw (µM)`        = round(conc_uM, 1),
        `Conc final (µM)`      = round(conc_uM * df, 1),
        Sequence               = sequence,
        Status                 = status
      )
  })

  output$samplesDT <- DT::renderDT({
    df <- samples_table()
    DT::datatable(
      df,
      rownames  = FALSE,
      selection = "single",
      options   = list(
        dom            = "t",        # table only (no search/paging UI)
        scrollY        = 200,        # <- makes it scrollable
        scrollCollapse = TRUE,
        paging         = FALSE
      )
    )
  }, server = TRUE)

  observeEvent(input$samplesDT_rows_selected, {
    idx <- input$samplesDT_rows_selected
    if (length(idx)) update_sample_index(idx)
  })
  samples_proxy <- DT::dataTableProxy("samplesDT")

  observeEvent(current_index(), {
    # sync selection when user hits Next/Prev
    try(DT::selectRows(samples_proxy, current_index()), silent = TRUE)
  }, ignoreInit = TRUE)

  observeEvent(samples_table(), {
    # refresh data but keep current row highlighted
    try(DT::replaceData(samples_proxy, samples_table(), resetPaging = FALSE, rownames = FALSE), silent = TRUE)
    try(DT::selectRows(samples_proxy, current_index()), silent = TRUE)
  }, ignoreInit = TRUE)







  # --- main analysis reactive ---
  analysis_res <- reactive({
    req(current_sample())
    fn <- basename(current_sample())

    tryCatch({
      sp <- current_sample()
      wl <- as.numeric(input$wavelength)
      rt_window <- analyte_rt_window()
      if (grepl("\\.D$", sp, ignore.case = TRUE)) {
        ## Agilent .D pipeline
        res <- run_hplc_analysis_agilent(
          sample_d_path           = sp,
          blank_d_path            = chosen_blank(),
          peptide_sequence        = seq_used(),
          use_hybrid              = use_hybrid(),
          min_rt_frac             = rt_window$min_frac,
          max_rt_frac             = rt_window$max_frac,
          signal_wavelength       = wl,
          inj_vol_ml              = injection_volume_ml(),
          show_intermediate_plots = FALSE
        )

      } else if (grepl("UV_VIS_\\d+\\.txt$", sp, ignore.case = TRUE)) {
        ## Thermo‐export pipeline (no blank sub): re-uses your SG detector
        res <- run_hplc_analysis_thermo(
          sample_file             = sp,
          peptide_sequence        = seq_used(),
          min_rt_frac             = rt_window$min_frac,
          max_rt_frac             = rt_window$max_frac,
          signal_wavelength       = wl,
          show_intermediate_plots = FALSE
        )

      } else {
        stop("Unsupported sample type: ", basename(sp))
      }

      if (nrow(res$peak_table) == 0) {
        showNotification(paste("⚠️ No peaks detected in", fn), type = "warning")
      }
      res
    }, error = function(e) {
      showNotification(paste("❌ Error in", fn, ":", e$message),
                       type = "error", duration = NULL)
      list(
        df_hybrid        = NULL,
        peak_table       = tibble(
          peak      = integer(), height    = double(),
          apex_rt   = double(), start_rt  = double(),
          end_rt    = double(), area      = double()
        ),
        epsilon          = NA_real_,
        concentration_uM = NA_real_,
        plot             = ggplot() + labs(title = paste(fn, "– Error")) + theme_minimal()
      )
    })
  })

  # --- raw + baseline overlay ---
  output$rawOverlay <- renderPlot({
    ar <- analysis_res(); req(!is.null(ar$df_hybrid))
    df    <- ar$df_hybrid
    is_hyb <- all(c("raw_diff","baseline_local") %in% names(df))

    if (is_hyb) {
      ggplot(df, aes(time)) +
        geom_line(aes(y = raw_diff),       color = "gray70") +
        geom_line(aes(y = baseline_local), color = "blue", linetype = "dashed") +
        geom_line(aes(y = corrected),      color = "black") +
        labs(title = "Hybrid Baseline Correction",
             x = "Time (min)", y = "Absorbance (mAU)") +
        theme_minimal()
    } else {
      ggplot(df, aes(time)) +
        geom_line(aes(y = intensity), color = "gray70", alpha = 0.7) +
        geom_line(aes(y = baseline),  color = "blue",    linetype = "dashed") +
        geom_line(aes(y = corrected), color = "black") +
        labs(title = "ALS Baseline Correction",
             x = "Time (min)", y = "Absorbance (mAU)") +
        theme_minimal()
    }
  })

  #header
  output$metricsHeader <- renderText({
    ar <- analysis_res()
    inj_ml <- injection_volume_ml_used(ar$df_hybrid, injection_volume_ml())
    sprintf("Top peaks — Inj. Vol: %.1f µL", inj_ml * 1000)
  })

  # --- top‐5 metrics table ---
  output$metricsTable <- renderTable({
    name <- basename(current_sample())

    # if marked bad → simple message
    if (name %in% bad_samples()) {
      return(data.frame(Metric = "Sample marked bad", Value = NA_character_, check.names = FALSE))
    }

    ar <- analysis_res(); req(!is.null(ar$df_hybrid))

    inj_ml <- injection_volume_ml_used(ar$df_hybrid, injection_volume_ml())
    eps <- ar$epsilon; if (is.null(eps) || !is.finite(eps)) eps <- NA_real_

    # vectorized conc (returns plain numeric; no list/names)
    calc_conc_vec <- function(area_vec, eps, inj_ml) {
      if (is.na(eps)) return(rep(NA_real_, length(area_vec)))
      vapply(area_vec, function(a) {
        out <- try(calculate_peak_conc(a, eps, inj_vol_ml = inj_ml)$c_uM, silent = TRUE)
        if (inherits(out, "try-error") || length(out) == 0 || !is.finite(out)) NA_real_ else unname(out)
      }, numeric(1))
    }

    # A blank cell cannot be told apart from a genuine zero, so name the reason the
    # concentration is missing. ε is NA whenever the peptide has no chromophore at the
    # selected wavelength, which at 280 nm means no Trp and no Tyr.
    format_conc_or_reason <- function(conc_uM, epsilon) {
      ifelse(is.finite(conc_uM), sprintf("%.1f", conc_uM),
             ifelse(is.na(epsilon), "NA (missing ε)", "NA"))
    }

    df <- dilution()
    wl <- as.numeric(input$wavelength)

    # if manual window present, show manual stats as a 2‑col table
    br <- selected_windows()[[name]]
    if (!is.null(br)) {
      df_sel   <- dplyr::filter(ar$df_hybrid, time >= br$xmin, time <= br$xmax)
      area_sel <- if (nrow(df_sel)) pracma::trapz(df_sel$time, df_sel$corrected) else NA_real_
      conc_sel <- calc_conc_vec(area_sel, eps, inj_ml)
      conc_sel_final <- conc_sel * df

      return(data.frame(
        Metric = c("Manual area (mAU·min)", "Conc raw (µM)", "Conc final (µM, ×dilution)", "Dilution factor", "Inj. Vol (µL)"),
        Value  = c(
          ifelse(is.finite(area_sel),       sprintf("%.2f", area_sel), "NA"),
          format_conc_or_reason(conc_sel,       eps),
          format_conc_or_reason(conc_sel_final, eps),
          sprintf("%g", df),
          sprintf("%.1f", inj_ml * 1000)
        ),
        check.names = FALSE
      ))
    }

    # otherwise: top‑10 peak table (ensure atomic cols only)
    tab <- hplcAnalyzer::filter_top_peaks(ar$peak_table, min_rt = 6, top_n = 10)
    if (!is.data.frame(tab) || nrow(tab) == 0) {
      return(data.frame(Metric = "No peaks ≥ 6 min", Value = NA_character_, check.names = FALSE))
    }

    conc_raw   <- calc_conc_vec(tab$area, eps, inj_ml)
    conc_final <- conc_raw * df
    eps_col    <- sprintf("ε%d (M⁻¹ cm⁻¹)", wl)

    out <- data.frame(
      `RT (min)`            = round(tab$apex_rt, 2),
      `Height (mAU)`        = round(tab$height, 1),
      `Area (mAU·min)`      = round(tab$area, 2),
      `Area (%)`            = round(hplcAnalyzer::peak_area_percent(tab), 2),
      `Conc raw (µM)`       = format_conc_or_reason(conc_raw,   eps),
      `Conc final (µM)`     = format_conc_or_reason(conc_final, eps),
      `epsilon (M⁻¹ cm⁻¹)`  = rep(ifelse(is.na(eps), NA_real_, round(eps, 0)), nrow(tab)),
      check.names = FALSE
    )
    names(out)[ncol(out)] <- eps_col
    out
  })





  # --- interactive peak plot with brush & reset ---
  output$peakPlot <- renderPlot({
    name <- basename(current_sample())
    # if marked bad, show a blank plot with message
    if (name %in% bad_samples()) {
      return(
        ggplot() +
          annotate("text", x = 0.5, y = 0.5, label = "Sample marked bad", size = 6) +
          theme_void()
      )
    }


    ar <- analysis_res(); req(!is.null(ar$df_hybrid))

    # Keyed on ε being NA rather than on the wavelength, so a 214 nm run whose sequence never
    # resolved is caught too. Guarded on there being peaks because the pipeline reports ε as NA
    # whenever it found none, whatever the sequence, and such a run keeps its own
    # "No peaks detected" plot instead of being blamed on a missing ε.
    if (nrow(ar$peak_table) > 0 && is.na(ar$epsilon)) {
      return(missing_epsilon_plot(as.numeric(input$wavelength), seq_used()))
    }

    br <- selected_windows()[[name]]

    if (!is.null(br)) {
      # user has manually selected a window
      df    <- ar$df_hybrid
      df_sel <- df %>% filter(time >= br$xmin, time <= br$xmax)
      area_sel <- trapz(df_sel$time, df_sel$corrected)

      ggplot(df, aes(time, corrected)) +
        geom_line() +
        geom_ribbon(data = df_sel,
                    aes(x = time, ymin = 0, ymax = corrected),
                    alpha = 0.4) +
        labs(
          title    = paste0("Manual integration – ", name),
          subtitle = sprintf("Area = %.2f mAU·min", area_sel),
          x        = "Time (min)", y = "Corrected Absorbance (mAU)"
        ) +
        theme_minimal()
    } else {
      # no brush → fallback to the auto‐annotated plot
      ar$plot +
        labs(subtitle = paste0(
          "Blank: ",
          ifelse(is.null(chosen_blank()), "Auto", basename(chosen_blank())),
          " | Seq: ", seq_used()
        ))
    }
  })

  # --- when user brushes, save that window for the current sample ---
  observeEvent(input$peakBrush, {
    br   <- input$peakBrush
    name <- basename(current_sample())
    sw   <- selected_windows()
    sw[[name]] <- br
    selected_windows(sw)
  })

  # --- reset button clears the manual window for this sample ---
  observeEvent(input$resetWin, {
    name <- basename(current_sample())
    sw   <- selected_windows()
    sw[[name]] <- NULL
    selected_windows(sw)

    bad_samples(setdiff(bad_samples(), name))
  })


  # --- accumulate & download ---
  observe({
    fn <- basename(current_sample())
    if (fn %in% bad_samples()) return()

    ar <- analysis_res()
    if (is.null(ar$df_hybrid)) return()

    inj_ml <- injection_volume_ml_used(ar$df_hybrid, injection_volume_ml())
    eps <- ar$epsilon; if (is.null(eps) || !is.finite(eps)) eps <- NA_real_

    calc_conc_one <- function(area_val, eps, inj_ml) {
      if (is.na(eps) || !is.finite(area_val)) return(NA_real_)
      out <- try(hplcAnalyzer::calculate_peak_conc(area_val, eps, inj_vol_ml = inj_ml)$c_uM, silent = TRUE)
      if (inherits(out, "try-error") || length(out)==0 || !is.finite(out)) NA_real_ else unname(out)
    }

    br <- selected_windows()[[fn]]

    if (!is.null(br)) {
      # manual path (works even if auto detector found 0 peaks)
      df_sel   <- dplyr::filter(ar$df_hybrid, time >= br$xmin, time <= br$xmax)
      area_sel <- if (nrow(df_sel)) pracma::trapz(df_sel$time, df_sel$corrected) else NA_real_
      # A hand drawn window is not one of the ranked peaks, so it has no share of their summed
      # area to report. Dividing it by that sum would produce a number that looks like a purity
      # but answers no question the user asked.
      new <- tibble::tibble(
        sample             = fn,
        rt                 = NA_real_,
        height             = NA_real_,
        area               = area_sel,
        main_peak_area_pct = NA_real_,
        conc_uM            = calc_conc_one(area_sel, eps, inj_ml),
        sequence           = seq_used(),
        status             = concentration_status(eps)
      )
    } else {
      # auto path: only if there is at least one detected peak
      if (is.null(ar$peak_table) || !nrow(ar$peak_table)) return()
      new <- tibble::tibble(
        sample             = fn,
        rt                 = ar$peak_table$apex_rt[1],
        height             = ar$peak_table$height[1],
        area               = ar$peak_table$area[1],
        main_peak_area_pct = hplcAnalyzer::main_peak_area_percent(ar$peak_table),
        conc_uM            = calc_conc_one(ar$peak_table$area[1], eps, inj_ml),
        sequence           = seq_used(),
        status             = concentration_status(eps)
      )
    }

    # robust upsert: append if new, replace first match if existing
    res <- results()
    if (!nrow(res) || !"sample" %in% names(res) || !any(res$sample == fn)) {
      res <- dplyr::bind_rows(res, new)
    } else {
      idx <- which(res$sample == fn)[1]
      for (nm in names(new)) res[[nm]][idx] <- new[[nm]][1]
    }
    results(res)
  })



  output$downloadSeqTemplate <- downloadHandler(
    filename = function() paste0("sequence_map_template_", Sys.Date(), ".csv"),
    content  = function(file) {
      # na = "" leaves unknown cells empty rather than writing the text "NA", which the
      # user would otherwise have to delete before filling the sequence in.
      write.csv(sequence_map_template(samples(), seq_map()), file,
                row.names = FALSE, na = "")
    }
  )


  output$downloadResults <- downloadHandler(
    filename = function() paste0("hplc_results_", Sys.Date(), ".csv"),
    content  = function(file) {
      res <- results()
      df  <- dilution()
      wl  <- as.numeric(input$wavelength)
      if (nrow(res)) {
        res$dilution_factor   <- df
        res$conc_uM_final     <- res$conc_uM * df
        res$wavelength_nm     <- wl
        names(res)[names(res) == "conc_uM"] <- "conc_uM_raw"
      }
      write.csv(res, file, row.names = FALSE)
    }
  )
}


shinyApp(ui, server)
