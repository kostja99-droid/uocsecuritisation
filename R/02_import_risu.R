# ──────────────────────────────────────────────────────────
# 02_import_risu.R — Update RISU corpus files with browser-fetched body text
#
# The RISU site (risu.ua) delivers article content via JS,
# so the original R scraper captured only ~30 chars of body.
# This script imports the browser console export and updates
# existing corpus files with the full body text.
#
# Usage:
#   source("01_config.R")
#   source("02_import_risu.R")
#   import_risu_articles("data/risu_articles.json")
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

#' Import/update RISU articles from browser-exported JSON
#'
#' Updates existing corpus files with full body text fetched via
#' the browser console script. Creates new corpus entries for any
#' articles not already in the corpus.
#'
#' @param json_path Path to risu_articles.json (from browser console script)
#' @return A tibble of imported/updated articles
import_risu_articles <- function(json_path = file.path("data", "risu_articles.json")) {
  stopifnot(file.exists(json_path))
  dir.create(CORPUS_DIR, recursive = TRUE, showWarnings = FALSE)

  data <- fromJSON(json_path)
  articles <- data$articles
  cat(sprintf("\nLoaded %d RISU articles from %s\n", nrow(articles), json_path))

  if (!is.null(data$failed) && length(data$failed) > 0) {
    n_fail <- if (is.data.frame(data$failed)) nrow(data$failed) else length(data$failed)
    cat(sprintf("  (%d URLs failed during browser fetch)\n", n_fail))
  }

  updated  <- 0
  created  <- 0
  skipped  <- 0
  all_docs <- list()

  for (i in seq_len(nrow(articles))) {
    row <- articles[i, ]
    url   <- row$url
    title <- if (is.null(row$title) || is.na(row$title)) "" else row$title
    date  <- if (is.null(row$date) || is.na(row$date)) NA_character_ else parse_uk_date(row$date)
    body  <- if (is.null(row$body) || is.na(row$body)) "" else row$body

    if (nchar(body) < 50) {
      skipped <- skipped + 1
      next
    }

    did <- doc_id(url)
    doc_path <- file.path(CORPUS_DIR, paste0(did, ".json"))

    if (file.exists(doc_path)) {
      existing <- fromJSON(doc_path)
      existing$body_text  <- body
      existing$word_count <- length(strsplit(body, "\\s+")[[1]])
      if (!is.null(title) && nchar(title) > 0) existing$title <- title
      if (!is.na(date)) existing$date <- date
      existing$updated_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
      write_json(existing, doc_path, auto_unbox = TRUE, pretty = TRUE)
      all_docs[[length(all_docs) + 1]] <- existing
      updated <- updated + 1
    } else {
      doc <- list(
        id           = did,
        url          = url,
        title        = title,
        date         = date,
        content_type = "risu_article",
        source       = "risu.ua",
        body_text    = body,
        word_count   = length(strsplit(body, "\\s+")[[1]]),
        scraped_at   = format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
      )
      write_json(doc, doc_path, auto_unbox = TRUE, pretty = TRUE)
      all_docs[[length(all_docs) + 1]] <- doc
      created <- created + 1
    }
  }

  cat(sprintf("\nUpdated: %d, Created: %d, Skipped (empty body): %d\n",
              updated, created, skipped))
  cat(sprintf("Total RISU articles processed: %d\n", updated + created))

  if (length(all_docs) == 0) return(tibble())
  bind_rows(lapply(all_docs, function(d) {
    for (nm in names(d)) {
      if (is.null(d[[nm]]) || length(d[[nm]]) == 0)
        d[[nm]] <- NA_character_
    }
    as_tibble(d)
  }))
}
