# ──────────────────────────────────────────────────────────
# 02_import_sbu.R — Import SBU press releases from browser export
#
# The SBU site (ssu.gov.ua) blocks automated requests, so
# articles are fetched via a browser console script that
# produces sbu_articles.json. This file imports that JSON
# into the standard corpus format.
#
# Usage:
#   source("R/01_config.R")
#   source("R/02_import_sbu.R")
#   import_sbu_articles("data/sbu_articles.json")
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

#' Import SBU articles from browser-exported JSON
#'
#' @param json_path Path to sbu_articles.json (from browser console script)
#' @param overwrite If FALSE, skip articles already in corpus
#' @return A tibble of imported articles
import_sbu_articles <- function(json_path = file.path("data", "sbu_articles.json"),
                                 overwrite = FALSE) {
  stopifnot(file.exists(json_path))
  dir.create(CORPUS_DIR, recursive = TRUE, showWarnings = FALSE)

  data <- fromJSON(json_path)
  articles <- data$articles
  cat(sprintf("\nLoaded %d SBU articles from %s\n", nrow(articles), json_path))

  if (!is.null(data$failed) && length(data$failed) > 0) {
    n_fail <- if (is.data.frame(data$failed)) nrow(data$failed) else length(data$failed)
    cat(sprintf("  (%d URLs failed during browser fetch)\n", n_fail))
  }

  saved <- 0
  skipped <- 0
  all_docs <- list()

  for (i in seq_len(nrow(articles))) {
    row <- articles[i, ]
    url   <- row$url
    title <- if (is.null(row$title) || is.na(row$title)) "" else row$title
    date  <- if (is.null(row$date) || is.na(row$date)) NA_character_ else parse_uk_date(row$date)
    body  <- if (is.null(row$body) || is.na(row$body)) "" else row$body

    did <- doc_id(url)
    doc_path <- file.path(CORPUS_DIR, paste0(did, ".json"))

    if (!overwrite && file.exists(doc_path)) {
      skipped <- skipped + 1
      existing <- fromJSON(doc_path)
      for (nm in names(existing)) {
        if (is.null(existing[[nm]]) || length(existing[[nm]]) == 0)
          existing[[nm]] <- NA_character_
      }
      all_docs[[length(all_docs) + 1]] <- existing
      next
    }

    doc <- list(
      id           = did,
      url          = url,
      title        = title,
      date         = date,
      content_type = "sbu_press_release",
      source       = "ssu.gov.ua",
      body_text    = body,
      word_count   = length(strsplit(body, "\\s+")[[1]]),
      scraped_at   = format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
    )

    write_json(doc, doc_path, auto_unbox = TRUE, pretty = TRUE)
    all_docs[[length(all_docs) + 1]] <- doc
    saved <- saved + 1
  }

  cat(sprintf("Imported: %d, Skipped (already in corpus): %d\n", saved, skipped))
  cat(sprintf("Total SBU articles in corpus: %d\n", saved + skipped))

  if (length(all_docs) == 0) return(tibble())
  bind_rows(lapply(all_docs, as_tibble))
}
