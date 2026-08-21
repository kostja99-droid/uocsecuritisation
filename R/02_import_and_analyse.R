# ──────────────────────────────────────────────────────────
# 02_import_and_analyse.R — Import browser-exported JSON and run analysis
#
# Use this instead of 02_scrape.R when you've fetched article
# content via the browser console JS snippet.
#
# Usage:
#   source("01_config.R")
#   source("02_import_and_analyse.R")
#
#   # Import the JSON file from the browser export:
#   import_articles("../data/speech_articles_clean.json")
#
#   # Then run the analysis:
#   source("03_analyse.R")
#   results <- analyse_corpus()
# ──────────────────────────────────────────────────────────

library(jsonlite)
library(dplyr)
library(stringr)
library(digest)

# ── Ukrainian month names → numeric ──────────────────────
uk_months <- c(
  "січня"    = "01",
  "лютого"   = "02",
  "березня"  = "03",
  "квітня"   = "04",
  "травня"   = "05",
  "червня"   = "06",
  "липня"    = "07",
  "серпня"   = "08",
  "вересня"  = "09",
  "жовтня"   = "10",
  "листопада" = "11",
  "грудня"   = "12"
)

parse_uk_date <- function(text) {
  if (is.na(text) || text == "") return(NA_character_)
  text <- trimws(text)
  # ISO format: 2024-12-25 or 2024-12-25T10:00:00+02:00
  if (grepl("^\\d{4}-\\d{2}-\\d{2}", text)) return(substr(text, 1, 10))
  # Dot format: 25.12.2024
  if (grepl("^\\d{2}\\.\\d{2}\\.\\d{4}", text)) {
    parts <- strsplit(sub("\\s.*", "", text), "\\.")[[1]]
    return(sprintf("%s-%s-%s", parts[3], parts[2], parts[1]))
  }
  # Strip trailing "року" / "р." that Ukrainian dates often have
  text <- sub("\\s*(року|р\\.)\\s*$", "", text)
  # Ukrainian text: "25 грудня 2024" or "5 січня 2023"
  m <- str_match(text, "(\\d{1,2})\\s+(\\S+)\\s+(\\d{4})")
  if (!is.na(m[1, 1])) {
    day   <- sprintf("%02d", as.integer(m[1, 2]))
    month <- uk_months[tolower(m[1, 3])]
    year  <- m[1, 4]
    if (!is.na(month)) return(sprintf("%s-%s-%s", year, month, day))
  }
  # Try month-first: "грудня 2024" (day missing, use 1st)
  m2 <- str_match(text, "(\\S+)\\s+(\\d{4})")
  if (!is.na(m2[1, 1])) {
    month <- uk_months[tolower(m2[1, 2])]
    year  <- m2[1, 3]
    if (!is.na(month)) return(sprintf("%s-%s-01", year, month))
  }
  return(NA_character_)
}

# ── Extract a date from the first few lines of body text ──
extract_date_from_text <- function(text) {
  # Look in the first 500 chars for a Ukrainian date pattern
  snippet <- substr(text, 1, 500)

  # Try "25 грудня 2024 року" or "25 грудня 2024"
  m <- str_match(snippet, "(\\d{1,2})\\s+(січня|лютого|березня|квітня|травня|червня|липня|серпня|вересня|жовтня|листопада|грудня)\\s+(\\d{4})")
  if (!is.na(m[1, 1])) {
    day   <- sprintf("%02d", as.integer(m[1, 2]))
    month <- uk_months[tolower(m[1, 3])]
    year  <- m[1, 4]
    if (!is.na(month) && as.integer(year) >= 2018 && as.integer(year) <= 2025) {
      return(sprintf("%s-%s-%s", year, month, day))
    }
  }

  # Try dd.mm.yyyy
  m2 <- str_match(snippet, "(\\d{2})\\.(\\d{2})\\.(\\d{4})")
  if (!is.na(m2[1, 1])) {
    year <- m2[1, 4]
    if (as.integer(year) >= 2018 && as.integer(year) <= 2025) {
      return(sprintf("%s-%s-%s", m2[1, 4], m2[1, 3], m2[1, 2]))
    }
  }

  return(NA_character_)
}

# ── Resolve the best date from multiple sources ──────────
resolve_date <- function(json_date, map_date, body_text = NULL) {
  # 1. Try date_mapping (from fetch_dates_only.js — most reliable)
  if (!is.null(map_date) && nchar(map_date) > 3) {
    d <- parse_uk_date(map_date)
    if (!is.na(d) && !grepl("^202[6-9]", d)) return(d)
  }
  # 2. Try JSON-exported date (often wrong — picks up page header)
  if (!is.null(json_date) && nchar(json_date) > 3) {
    d <- parse_uk_date(json_date)
    if (!is.na(d) && !grepl("^202[6-9]", d)) return(d)
  }
  # 3. Try extracting from body text
  if (!is.null(body_text)) {
    d <- extract_date_from_text(body_text)
    if (!is.na(d)) return(d)
  }
  return(NA_character_)
}

# ── Import articles from browser-exported JSON ───────────
import_articles <- function(json_path = "speech_articles_clean.json",
                            csv_path  = NULL,
                            date_mapping_path = NULL) {
  dir.create(CORPUS_DIR, recursive = TRUE, showWarnings = FALSE)

  if (!file.exists(json_path)) {
    stop(sprintf(
      "JSON file not found: %s\n\nTo create it:\n  1. Open https://www.president.gov.ua in Chrome\n  2. F12 -> Console\n  3. Paste the contents of js/fetch_articles_quick.js\n  4. Wait for download, place the file in data/\n",
      json_path
    ))
  }

  cat(sprintf("Reading %s...\n", json_path))
  articles <- fromJSON(json_path, simplifyDataFrame = FALSE)
  cat(sprintf("  Loaded %d articles\n", length(articles)))

  # Load date mapping if available (from fetch_dates_only.js)
  date_map <- list()
  if (is.null(date_mapping_path)) {
    # Auto-detect: look next to the JSON file
    candidate <- file.path(dirname(json_path), "date_mapping.json")
    if (file.exists(candidate)) date_mapping_path <- candidate
    # Also check current directory
    if (is.null(date_mapping_path) && file.exists("date_mapping.json")) {
      date_mapping_path <- "date_mapping.json"
    }
  }
  if (!is.null(date_mapping_path) && file.exists(date_mapping_path)) {
    date_map <- fromJSON(date_mapping_path, simplifyDataFrame = FALSE)
    cat(sprintf("  Loaded %d date mappings from %s\n", length(date_map), date_mapping_path))
  } else {
    cat("  No date_mapping.json found — dates may be inaccurate.\n")
    cat("  Run js/fetch_dates_only.js in your browser to fix dates.\n")
  }

  # Diagnostic: show sample dates
  cat("\n  Sample date resolution (first 10 articles):\n")
  for (a in head(articles, 10)) {
    url <- a$url
    raw_json <- if (is.null(a$date)) "" else a$date
    raw_map  <- if (!is.null(date_map[[url]])) date_map[[url]] else ""
    # Prefer date_mapping, fall back to JSON, fall back to body text
    final <- resolve_date(raw_json, raw_map, a$body_text)
    cat(sprintf("    map: '%s' | final: %s\n",
                substr(raw_map, 1, 40),
                if (is.na(final)) "NA" else final))
  }
  cat("\n")

  # If a CSV with titles was also provided, use it to fill in missing titles
  csv_titles <- list()
  if (!is.null(csv_path) && file.exists(csv_path)) {
    csv_data <- read.csv(csv_path, stringsAsFactors = FALSE)
    for (i in seq_len(nrow(csv_data))) {
      csv_titles[[csv_data$url[i]]] <- csv_data$title[i]
    }
    cat(sprintf("  Loaded %d titles from CSV\n", length(csv_titles)))
  }

  saved <- 0
  skipped <- 0

  for (art in articles) {
    url <- art$url
    if (is.null(url) || url == "") { skipped <- skipped + 1; next }

    body_text <- art$body_text
    if (is.null(body_text) || nchar(body_text) < 50) { skipped <- skipped + 1; next }

    # Generate document ID from URL
    did <- substr(digest(url, algo = "md5"), 1, 12)
    doc_path <- file.path(CORPUS_DIR, paste0(did, ".json"))

    # Resolve date from best available source
    raw_map <- if (!is.null(date_map[[url]])) date_map[[url]] else ""
    date_str <- resolve_date(art$date, raw_map, body_text)

    # Use CSV title if article title is empty
    title <- art$title
    if ((is.null(title) || title == "") && !is.null(csv_titles[[url]])) {
      title <- csv_titles[[url]]
    }

    # All URLs from the speeches listing page are speeches
    # (the URL path is /news/<slug>, not /news/speeches/<slug>)
    content_type <- "speech"

    doc <- list(
      id           = did,
      url          = url,
      title        = if (is.null(title)) "" else title,
      date         = date_str,
      content_type = content_type,
      body_text    = body_text,
      word_count   = length(strsplit(body_text, "\\s+")[[1]]),
      scraped_at   = format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
    )

    write_json(doc, doc_path, auto_unbox = TRUE, pretty = TRUE)
    saved <- saved + 1
  }

  cat(sprintf("\n  Saved: %d documents to %s\n", saved, CORPUS_DIR))
  if (skipped > 0) cat(sprintf("  Skipped: %d (too short or missing URL)\n", skipped))

  # Save master index
  dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)
  index <- data.frame(
    id = character(), url = character(), title = character(),
    date = character(), content_type = character(),
    word_count = integer(), stringsAsFactors = FALSE
  )
  json_files <- list.files(CORPUS_DIR, pattern = "\\.json$", full.names = TRUE)
  for (f in json_files) {
    d <- tryCatch(fromJSON(f), error = function(e) NULL)
    if (!is.null(d)) {
      index <- rbind(index, data.frame(
        id = d$id, url = d$url, title = d$title,
        date = if (is.null(d$date) || is.na(d$date)) "" else d$date,
        content_type = d$content_type,
        word_count = d$word_count,
        stringsAsFactors = FALSE
      ))
    }
  }
  write_json(index, file.path(OUTPUT_DIR, "scrape_index.json"),
             auto_unbox = TRUE, pretty = TRUE)
  cat(sprintf("  Index saved: %s (%d documents)\n",
              file.path(OUTPUT_DIR, "scrape_index.json"), nrow(index)))

  cat(sprintf("\nReady for analysis. Run:\n  source('03_analyse.R')\n  results <- analyse_corpus()\n"))
  invisible(index)
}
