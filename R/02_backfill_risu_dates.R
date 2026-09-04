# ──────────────────────────────────────────────────────────
# 02_backfill_risu_dates.R — Recover missing dates for RISU articles
#
# Many RISU articles didn't have their date captured by the
# browser fetch script. This script tries to extract dates
# from the article body text (Ukrainian date patterns), and
# reports any that still need manual assignment.
#
# Usage:
#   source("01_config.R")
#   source("02_backfill_risu_dates.R")
#   backfill_risu_dates()
# ──────────────────────────────────────────────────────────

library(jsonlite)
library(stringr)

if (!exists("CORPUS_DIR")) source(file.path("R", "01_config.R"))

uk_months <- c(
  "січня" = "01", "лютого" = "02", "березня" = "03",
  "квітня" = "04", "травня" = "05", "червня" = "06",
  "липня" = "07", "серпня" = "08", "вересня" = "09",
  "жовтня" = "10", "листопада" = "11", "грудня" = "12",
  # Russian month names (some RISU articles are bilingual)
  "января" = "01", "февраля" = "02", "марта" = "03",
  "апреля" = "04", "мая" = "05", "июня" = "06",
  "июля" = "07", "августа" = "08", "сентября" = "09",
  "октября" = "10", "ноября" = "11", "декабря" = "12"
)

extract_date_from_text <- function(text) {
  if (is.null(text) || is.na(text) || nchar(text) < 20) return(NA_character_)

  # Pattern 1: "DD місяця YYYY" (Ukrainian)
  uk_pattern <- "(\\d{1,2})\\s+(січня|лютого|березня|квітня|травня|червня|липня|серпня|вересня|жовтня|листопада|грудня)\\s+(20[0-2]\\d)"
  m <- str_match(text, uk_pattern)
  if (!is.na(m[1, 1])) {
    day   <- sprintf("%02d", as.integer(m[1, 2]))
    month <- uk_months[tolower(m[1, 3])]
    year  <- m[1, 4]
    if (!is.na(month)) return(sprintf("%s-%s-%s", year, month, day))
  }

  # Pattern 2: "DD месяца YYYY" (Russian)
  ru_pattern <- "(\\d{1,2})\\s+(января|февраля|марта|апреля|мая|июня|июля|августа|сентября|октября|ноября|декабря)\\s+(20[0-2]\\d)"
  m <- str_match(text, ru_pattern)
  if (!is.na(m[1, 1])) {
    day   <- sprintf("%02d", as.integer(m[1, 2]))
    month <- uk_months[tolower(m[1, 3])]
    year  <- m[1, 4]
    if (!is.na(month)) return(sprintf("%s-%s-%s", year, month, day))
  }

  # Pattern 3: "DD.MM.YYYY"
  m <- str_match(text, "(\\d{2})\\.(\\d{2})\\.(20[0-2]\\d)")
  if (!is.na(m[1, 1])) {
    return(sprintf("%s-%s-%s", m[1, 4], m[1, 3], m[1, 2]))
  }

  # Pattern 4: "YYYY-MM-DD" already ISO
  m <- str_match(text, "(20[0-2]\\d)-(\\d{2})-(\\d{2})")
  if (!is.na(m[1, 1])) {
    return(sprintf("%s-%s-%s", m[1, 2], m[1, 3], m[1, 4]))
  }

  return(NA_character_)
}

backfill_risu_dates <- function(corpus_dir = CORPUS_DIR) {
  files <- list.files(corpus_dir, pattern = "\\.json$", full.names = TRUE)

  risu_files <- c()
  for (f in files) {
    d <- tryCatch(fromJSON(f), error = function(e) NULL)
    if (!is.null(d) && !is.null(d$source) && d$source == "risu.ua") {
      risu_files <- c(risu_files, f)
    }
  }

  cat(sprintf("Found %d RISU corpus files\n", length(risu_files)))

  missing_date  <- 0
  recovered     <- 0
  still_missing <- list()
  already_dated <- 0

  for (f in risu_files) {
    d <- fromJSON(f)

    has_date <- tryCatch({
      dv <- d$date
      !is.null(dv) && length(dv) == 1 && !is.na(dv[1]) && nchar(as.character(dv[1])) >= 10
    }, error = function(e) FALSE)
    if (has_date) {
      already_dated <- already_dated + 1
      next
    }

    missing_date <- missing_date + 1

    # Try to extract from body text
    body <- if (!is.null(d$body_text)) d$body_text else ""
    title <- if (!is.null(d$title)) d$title else ""
    search_text <- paste(title, substr(body, 1, 2000))

    extracted <- extract_date_from_text(search_text)

    if (!is.na(extracted)) {
      d$date <- extracted
      d$date_source <- "extracted_from_body"
      write_json(d, f, auto_unbox = TRUE, pretty = TRUE)
      recovered <- recovered + 1
      cat(sprintf("  Recovered: %s -> %s\n", basename(f), extracted))
    } else {
      url <- if (!is.null(d$url)) d$url else "unknown"
      title_short <- substr(title, 1, 60)
      still_missing[[length(still_missing) + 1]] <- list(
        file  = basename(f),
        url   = url,
        title = title_short
      )
    }
  }

  cat(sprintf("\n%s\nRISU DATE BACKFILL SUMMARY\n%s\n", strrep("=", 50), strrep("=", 50)))
  cat(sprintf("Total RISU files:    %d\n", length(risu_files)))
  cat(sprintf("Already had date:    %d\n", already_dated))
  cat(sprintf("Missing date:        %d\n", missing_date))
  cat(sprintf("Recovered from text: %d\n", recovered))
  cat(sprintf("Still missing:       %d\n", length(still_missing)))

  if (length(still_missing) > 0) {
    cat(sprintf("\n%s\nARTICLES STILL MISSING DATES\n%s\n", strrep("-", 50), strrep("-", 50)))
    cat("These need manual date assignment.\n\n")

    for (item in still_missing) {
      cat(sprintf("  %s\n    %s\n    %s\n\n", item$file, item$title, item$url))
    }

    cat("\nTo manually set a date, run:\n")
    cat('  set_risu_date("FILENAME.json", "YYYY-MM-DD")\n\n')
  }

  invisible(still_missing)
}

# Helper to manually set a date on a corpus file
set_risu_date <- function(filename, date_str, corpus_dir = CORPUS_DIR) {
  f <- file.path(corpus_dir, filename)
  if (!file.exists(f)) {
    cat(sprintf("File not found: %s\n", f))
    return(invisible(FALSE))
  }
  d <- fromJSON(f)
  d$date <- date_str
  d$date_source <- "manual"
  write_json(d, f, auto_unbox = TRUE, pretty = TRUE)
  cat(sprintf("Set date %s on %s (%s)\n", date_str, filename, d$title))
  invisible(TRUE)
}
