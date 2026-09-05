# ──────────────────────────────────────────────────────────
# 05_import_llm_results.R — Merge LLM-coded results
#
# After running each batch through Claude.ai, save the JSON
# responses as data/llm_results/batch_01.json, batch_02.json,
# etc. This script merges them into a single coded dataset.
#
# Usage:
#   source("01_config.R")
#   source("05_import_llm_results.R")
#   coded <- merge_llm_results()
# ──────────────────────────────────────────────────────────

library(jsonlite)
library(dplyr)
library(tidyr)

if (!exists("CORPUS_DIR")) source("01_config.R")
if (!exists("JUNCTURES")) source("01_config.R")

# ── Parse a single LLM response file ────────────────────
parse_llm_response <- function(json_path) {
  raw <- readLines(json_path, warn = FALSE, encoding = "UTF-8")
  text <- paste(raw, collapse = "\n")

  # Strip markdown code fences if present
  text <- str_replace(text, "^\\s*```json\\s*\n?", "")
  text <- str_replace(text, "\n?\\s*```\\s*$", "")
  text <- trimws(text)

  tryCatch({
    data <- fromJSON(text, simplifyDataFrame = TRUE)
    if (is.data.frame(data)) return(data)
    if (is.list(data)) return(bind_rows(data))
    stop("Unexpected format")
  }, error = function(e) {
    cat(sprintf("  Warning: could not parse %s: %s\n", json_path, e$message))
    return(NULL)
  })
}

# ── Assign juncture period ───────────────────────────────
assign_juncture <- function(date) {
  if (is.na(date) || date == "" || date == "unknown") return("unknown")
  for (jname in names(JUNCTURES)) {
    jrange <- JUNCTURES[[jname]]
    if (date >= jrange[1] && date <= jrange[2]) return(jname)
  }
  "outside_junctures"
}

# ── Merge all batch results ──────────────────────────────
merge_llm_results <- function(results_dir = file.path("data", "llm_results"),
                               output_dir = OUTPUT_DIR) {
  if (!dir.exists(results_dir)) {
    stop(sprintf("Results directory not found: %s\nSave Claude's JSON outputs there first.",
                 results_dir))
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  files <- list.files(results_dir, pattern = "\\.json$", full.names = TRUE)
  files <- sort(files)
  cat(sprintf("Found %d result files in %s\n", length(files), results_dir))

  all_coded <- list()
  for (f in files) {
    cat(sprintf("  Parsing %s...", basename(f)))
    df <- parse_llm_response(f)
    if (!is.null(df) && nrow(df) > 0) {
      df$batch_file <- basename(f)
      all_coded[[length(all_coded) + 1]] <- df
      cat(sprintf(" %d entries\n", nrow(df)))
    } else {
      cat(" EMPTY or FAILED\n")
    }
  }

  if (length(all_coded) == 0) {
    cat("No valid results found.\n")
    return(invisible(NULL))
  }

  coded <- bind_rows(all_coded)
  cat(sprintf("\nTotal coded entries: %d\n", nrow(coded)))

  # Standardise column names
  expected_cols <- c("doc_id", "passage", "is_securitising", "securitisation_type",
                     "referent_object", "threat_actor", "extraordinary_measure",
                     "confidence", "coder_notes")
  for (col in expected_cols) {
    if (!(col %in% names(coded))) coded[[col]] <- NA
  }

  # Ensure logical type for is_securitising
  if (!is.logical(coded$is_securitising)) {
    coded$is_securitising <- tolower(as.character(coded$is_securitising)) %in% c("true", "1", "yes")
  }

  # Ensure numeric confidence
  coded$confidence <- as.integer(coded$confidence)

  # ── Enrich with document metadata ──────────────────────
  corpus_files <- list.files(CORPUS_DIR, pattern = "\\.json$", full.names = TRUE)
  doc_meta <- list()
  for (f in corpus_files) {
    d <- tryCatch(fromJSON(f), error = function(e) NULL)
    if (!is.null(d) && !is.null(d$id)) {
      doc_meta[[d$id]] <- list(
        title        = if (!is.null(d$title)) d$title else "",
        date         = if (!is.null(d$date) && length(d$date) > 0 && !is.na(d$date[1])) d$date[1] else NA_character_,
        source       = if (!is.null(d$source)) d$source else "",
        content_type = if (!is.null(d$content_type)) d$content_type else "",
        url          = if (!is.null(d$url)) d$url else ""
      )
    }
  }

  coded$doc_title <- sapply(coded$doc_id, function(id) {
    if (id %in% names(doc_meta)) doc_meta[[id]]$title else NA_character_
  })
  coded$doc_date <- sapply(coded$doc_id, function(id) {
    if (id %in% names(doc_meta)) doc_meta[[id]]$date else NA_character_
  })
  coded$doc_source <- sapply(coded$doc_id, function(id) {
    if (id %in% names(doc_meta)) doc_meta[[id]]$source else NA_character_
  })
  coded$doc_content_type <- sapply(coded$doc_id, function(id) {
    if (id %in% names(doc_meta)) doc_meta[[id]]$content_type else NA_character_
  })
  coded$doc_url <- sapply(coded$doc_id, function(id) {
    if (id %in% names(doc_meta)) doc_meta[[id]]$url else NA_character_
  })

  # Assign juncture
  coded$juncture <- sapply(coded$doc_date, assign_juncture)

  # Assign year
  coded$year <- substr(coded$doc_date, 1, 4)

  # ── Summary statistics ─────────────────────────────────
  cat(sprintf("\n%s\nLLM CODING SUMMARY\n%s\n", strrep("=", 60), strrep("=", 60)))

  securitising <- coded %>% filter(is_securitising == TRUE)
  cat(sprintf("\nTotal entries: %d\n", nrow(coded)))
  cat(sprintf("Securitising moves: %d (%.1f%%)\n",
              nrow(securitising),
              100 * nrow(securitising) / max(nrow(coded), 1)))
  cat(sprintf("Unique documents with moves: %d\n",
              n_distinct(securitising$doc_id)))

  if (nrow(securitising) > 0) {
    cat("\nBy securitisation type:\n")
    print(table(securitising$securitisation_type))

    cat("\nBy referent object:\n")
    print(table(securitising$referent_object))

    cat("\nBy threat actor:\n")
    print(table(securitising$threat_actor))

    cat("\nBy extraordinary measure:\n")
    print(table(securitising$extraordinary_measure))

    cat("\nBy confidence level:\n")
    print(table(securitising$confidence))

    cat("\nBy juncture:\n")
    juncture_summary <- securitising %>%
      group_by(juncture) %>%
      summarise(
        n_moves = n(),
        n_docs = n_distinct(doc_id),
        pct_material = round(100 * mean(securitisation_type == "material", na.rm = TRUE), 1),
        pct_ontological = round(100 * mean(securitisation_type == "ontological", na.rm = TRUE), 1),
        pct_both = round(100 * mean(securitisation_type == "both", na.rm = TRUE), 1),
        avg_confidence = round(mean(confidence, na.rm = TRUE), 2),
        .groups = "drop"
      )
    print(as.data.frame(juncture_summary))

    cat("\nBy source:\n")
    source_summary <- securitising %>%
      group_by(doc_source) %>%
      summarise(
        n_moves = n(),
        n_docs = n_distinct(doc_id),
        .groups = "drop"
      )
    print(as.data.frame(source_summary))
  }

  # ── Save outputs ───────────────────────────────────────
  # Full coded dataset
  write.csv(coded, file.path(output_dir, "llm_coded_full.csv"),
            row.names = FALSE, fileEncoding = "UTF-8")
  cat(sprintf("\nFull dataset: %s\n", file.path(output_dir, "llm_coded_full.csv")))

  # Securitising moves only
  if (nrow(securitising) > 0) {
    write.csv(securitising, file.path(output_dir, "llm_coded_securitising.csv"),
              row.names = FALSE, fileEncoding = "UTF-8")
    cat(sprintf("Securitising only: %s\n",
                file.path(output_dir, "llm_coded_securitising.csv")))
  }

  # JSON version
  write_json(coded, file.path(output_dir, "llm_coded_full.json"),
             auto_unbox = TRUE, pretty = TRUE)

  cat(sprintf("\n%s\nDone.\n%s\n", strrep("=", 60), strrep("=", 60)))

  invisible(coded)
}
