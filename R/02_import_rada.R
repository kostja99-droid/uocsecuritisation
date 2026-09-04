# ──────────────────────────────────────────────────────────
# 02_import_rada.R — Import browser-fetched Rada stenograms
#
# Updates existing Rada corpus files with full stenogram text
# fetched via the browser console script (same approach as
# SBU and RISU imports).
#
# Usage:
#   source("R/01_config.R")
#   source("R/02_import_rada.R")
#   import_rada_articles("data/rada_articles.json")
# ──────────────────────────────────────────────────────────

library(jsonlite)
library(dplyr)

if (!exists("CORPUS_DIR")) source(file.path("R", "01_config.R"))

if (!exists("doc_id")) {
  doc_id <- function(url) {
    if (!requireNamespace("digest", quietly = TRUE)) install.packages("digest")
    substr(digest::digest(url, algo = "md5"), 1, 12)
  }
}

if (!exists("parse_uk_date")) {
  uk_months <- c(
    "січня" = "01", "лютого" = "02", "березня" = "03",
    "квітня" = "04", "травня" = "05", "червня" = "06",
    "липня" = "07", "серпня" = "08", "вересня" = "09",
    "жовтня" = "10", "листопада" = "11", "грудня" = "12"
  )

  parse_uk_date <- function(text) {
    if (is.na(text) || text == "") return(NA_character_)
    text <- trimws(text)
    if (grepl("^\\d{4}-\\d{2}-\\d{2}", text)) return(substr(text, 1, 10))
    if (grepl("^\\d{2}\\.\\d{2}\\.\\d{4}", text)) {
      parts <- strsplit(sub("\\s.*", "", text), "\\.")[[1]]
      return(sprintf("%s-%s-%s", parts[3], parts[2], parts[1]))
    }
    text <- stringr::str_replace(text, "\\s*(року|р\\.?)\\s*$", "")
    m <- stringr::str_match(text, "(\\d{1,2})\\s+(\\S+)\\s+(\\d{4})")
    if (!is.na(m[1, 1])) {
      day   <- sprintf("%02d", as.integer(m[1, 2]))
      month <- uk_months[tolower(m[1, 3])]
      year  <- m[1, 4]
      if (!is.na(month)) return(sprintf("%s-%s-%s", year, month, day))
    }
    return(NA_character_)
  }
}

import_rada_articles <- function(json_path = file.path("data", "rada_articles.json"),
                                  corpus_dir = CORPUS_DIR) {
  stopifnot(file.exists(json_path))
  dir.create(corpus_dir, recursive = TRUE, showWarnings = FALSE)

  data <- fromJSON(json_path)
  articles <- data$articles
  cat(sprintf("\nLoaded %d Rada articles from %s\n", nrow(articles), json_path))

  if (!is.null(data$failed) && length(data$failed) > 0) {
    n_fail <- if (is.data.frame(data$failed)) nrow(data$failed) else length(data$failed)
    cat(sprintf("  (%d URLs failed during browser fetch)\n", n_fail))
  }

  updated  <- 0
  created  <- 0
  skipped  <- 0
  still_short <- 0
  all_docs <- list()

  for (i in seq_len(nrow(articles))) {
    row <- articles[i, ]
    url   <- row$url
    title <- if (is.null(row$title) || is.na(row$title)) "" else row$title
    date  <- if (is.null(row$date) || is.na(row$date)) NA_character_ else parse_uk_date(row$date)
    body  <- if (is.null(row$body) || is.na(row$body)) "" else row$body
    rada_id <- if (!is.null(row$rada_id) && !is.na(row$rada_id)) as.integer(row$rada_id) else NA_integer_

    if (nchar(body) < 100) {
      skipped <- skipped + 1
      still_short <- still_short + 1
      next
    }

    did <- doc_id(url)
    doc_path <- file.path(corpus_dir, paste0(did, ".json"))

    if (file.exists(doc_path)) {
      existing <- fromJSON(doc_path)
      existing$body_text  <- body
      existing$word_count <- length(strsplit(body, "\\s+")[[1]])
      if (!is.null(title) && nchar(title) > 0) existing$title <- title
      if (!is.na(date)) existing$date <- date
      existing$updated_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
      existing$fetch_method <- "browser"
      write_json(existing, doc_path, auto_unbox = TRUE, pretty = TRUE)
      all_docs[[length(all_docs) + 1]] <- existing
      updated <- updated + 1
    } else {
      doc <- list(
        id           = did,
        url          = url,
        rada_id      = if (!is.na(rada_id)) rada_id else NULL,
        title        = if (nchar(title) > 0) title else sprintf("Rada stenogram %s", rada_id),
        date         = date,
        content_type = "rada_stenogram",
        source       = "rada.gov.ua",
        body_text    = body,
        word_count   = length(strsplit(body, "\\s+")[[1]]),
        fetch_method = "browser",
        scraped_at   = format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
      )
      write_json(doc, doc_path, auto_unbox = TRUE, pretty = TRUE)
      all_docs[[length(all_docs) + 1]] <- doc
      created <- created + 1
    }
  }

  cat(sprintf("\n%s\nRADA IMPORT SUMMARY\n%s\n", strrep("=", 50), strrep("=", 50)))
  cat(sprintf("Updated existing files: %d\n", updated))
  cat(sprintf("Created new files:      %d\n", created))
  cat(sprintf("Skipped (still empty):  %d\n", skipped))
  cat(sprintf("Total processed:        %d\n", updated + created))

  if (still_short > 0) {
    cat(sprintf("\nWarning: %d articles still had <100 chars of body text.\n", still_short))
    cat("These may be genuinely empty stenogram pages on rada.gov.ua.\n")
    cat("Consider removing them from the corpus if they have no content.\n\n")
  }

  cat("\nAfter import, regenerate LLM batches:\n")
  cat('  source("R/04_prepare_llm_batches.R")\n')
  cat("  batches <- prepare_all_batches()\n\n")

  if (length(all_docs) == 0) return(invisible(tibble()))
  invisible(bind_rows(lapply(all_docs, function(d) {
    for (nm in names(d)) {
      if (is.null(d[[nm]]) || length(d[[nm]]) == 0)
        d[[nm]] <- NA_character_
    }
    as_tibble(d)
  })))
}
