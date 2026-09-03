# ──────────────────────────────────────────────────────────
# 02_scrape_rada.R — Auto-scrape all Rada stenograms by ID
#
# Stenograms live at rada.gov.ua/meeting/stenogr/show/XXXX.html
# with sequential numeric IDs. This script probes a range of IDs,
# downloads every valid stenogram, and saves to the corpus.
#
# Usage:
#   source("01_config.R")
#   source("02_scrape_rada.R")
#   rada_docs <- scrape_rada_stenograms()
# ──────────────────────────────────────────────────────────

library(rvest)
library(httr)
library(jsonlite)
library(stringr)
library(dplyr)

if (!exists("CORPUS_DIR")) source(file.path("R", "01_config.R"))

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
    # "dd. mm. yyyy" (Rada uses spaces around dots)
    if (grepl("\\d{2}\\.\\s*\\d{2}\\.\\s*\\d{4}", text)) {
      clean <- gsub("\\s", "", text)
      parts <- strsplit(clean, "\\.")[[1]]
      if (length(parts) >= 3) {
        return(sprintf("%s-%s-%s", parts[3], parts[2], parts[1]))
      }
    }
    text <- str_replace(text, "\\s*(року|р\\.?)\\s*$", "")
    m <- str_match(text, "(\\d{1,2})\\s+(\\S+)\\s+(\\d{4})")
    if (!is.na(m[1, 1])) {
      day   <- sprintf("%02d", as.integer(m[1, 2]))
      month <- uk_months[tolower(m[1, 3])]
      year  <- m[1, 4]
      if (!is.na(month)) return(sprintf("%s-%s-%s", year, month, day))
    }
    return(NA_character_)
  }
}

if (!exists("doc_id")) {
  doc_id <- function(url) {
    if (!requireNamespace("digest", quietly = TRUE)) install.packages("digest")
    substr(digest::digest(url, algo = "md5"), 1, 12)
  }
}

# ── Fetch from rada.gov.ua ───────────────────────────────

RADA_BASE <- "https://rada.gov.ua"

fetch_rada <- function(url) {
  Sys.sleep(runif(1, REQUEST_DELAY[1], REQUEST_DELAY[2]))
  for (attempt in seq_len(MAX_RETRIES)) {
    tryCatch({
      resp <- GET(url,
                  user_agent(USER_AGENT),
                  add_headers(
                    Accept          = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                    `Accept-Language`= "uk-UA,uk;q=0.9,en-US;q=0.8,en;q=0.7"
                  ),
                  timeout(REQUEST_TIMEOUT))
      cat(sprintf("  [ID %s] HTTP %d (%d chars)\n",
                  sub(".*/(\\d+)\\.html$", "\\1", url),
                  status_code(resp),
                  nchar(content(resp, as = "text", encoding = "UTF-8"))))
      if (status_code(resp) == 404) return("404")
      if (status_code(resp) >= 300 && status_code(resp) < 400) {
        cat(sprintf("    Redirect: %s\n", headers(resp)$location))
        return("404")
      }
      if (!http_error(resp)) {
        return(content(resp, as = "text", encoding = "UTF-8"))
      }
      message(sprintf("  [attempt %d/%d] HTTP %d for %s",
                      attempt, MAX_RETRIES, status_code(resp), url))
    }, error = function(e) {
      message(sprintf("  [attempt %d/%d] Error: %s",
                      attempt, MAX_RETRIES, e$message))
    })
    if (attempt < MAX_RETRIES) Sys.sleep(2^attempt)
  }
  return(NULL)
}

# ── Parse a stenogram page ───────────────────────────────

parse_stenogram <- function(html_text) {
  page <- read_html(html_text)
  page_text <- html_text2(page)

  # Body text — the stenogram content
  # Try specific stenogram selectors first, then generic content areas
  body <- ""
  for (sel in c(".stenograma", ".steno-text", ".session_text",
                "#stenograma", ".main-content", ".content-main",
                ".article_content", "article", "#content", "main")) {
    el <- html_element(page, sel)
    if (!is.na(el)) {
      t <- html_text2(el)
      if (nchar(t) > 500) { body <- t; break }
    }
  }
  if (body == "") body <- page_text

  # Title — look for session-specific headings, skip generic navigation
  title <- ""
  for (sel in c(".stenograma h2", ".stenograma h1", ".main_title",
                ".session_text h2", "article h1", "article h2",
                "#content h1", "#content h2", "main h1")) {
    el <- html_element(page, sel)
    if (!is.na(el)) {
      t <- html_text2(el)
      if (nchar(t) > 3 && nchar(t) < 200 &&
          !grepl("Календар|календар|Головна|головна", t)) {
        title <- t; break
      }
    }
  }
  # If no title from selectors, try to find "Засідання" in body text
  if (title == "") {
    m <- str_match(body, "(Засідання[^\\n]{0,100})")
    if (!is.na(m[1, 1])) title <- trimws(m[1, 1])
  }

  # Date — extract from the body text, not the page navigation/calendar
  # Look for Ukrainian date patterns: "6 лютого 2018 року" etc.
  date_str <- NA_character_
  # First 2000 chars of body should contain the session date
  body_head <- substr(body, 1, 2000)

  # Try "dd місяця yyyy року" pattern in body
  m <- str_match(body_head,
    "(\\d{1,2})\\s+(січня|лютого|березня|квітня|травня|червня|липня|серпня|вересня|жовтня|листопада|грудня)\\s+(\\d{4})")
  if (!is.na(m[1, 1])) {
    date_str <- parse_uk_date(m[1, 1])
  }

  # Try "Опубліковано dd.mm.yyyy" specifically (not generic dd.mm.yyyy)
  if (is.na(date_str)) {
    m <- str_match(page_text,
      "Опубліковано\\s+(\\d{2}\\.\\s*\\d{2}\\.\\s*\\d{4})")
    if (!is.na(m[1, 1])) {
      date_str <- parse_uk_date(m[1, 2])
    }
  }

  # Try dd.mm.yyyy only in body text (not full page — avoids calendar widget)
  if (is.na(date_str)) {
    m <- str_match(body_head, "(\\d{2}\\.\\s*\\d{2}\\.\\s*\\d{4})")
    if (!is.na(m[1, 1])) {
      d <- parse_uk_date(m[1, 1])
      # Only accept if it's a plausible stenogram date (2000-2025)
      if (!is.na(d) && grepl("^20[0-2]", d)) date_str <- d
    }
  }

  list(title = title, date = date_str, body_text = body)
}

# ── Main scraper ─────────────────────────────────────────

#' Scrape all Rada stenograms by probing sequential IDs
#'
#' @param start_id   First ID to probe (default 6700, ~early 2018)
#' @param end_id     Last ID to probe (default 9000, should cover through 2025)
#' @param start_date Only keep stenograms from this date onward
#' @param end_date   Only keep stenograms up to this date
#' @param resume     Skip already-downloaded stenograms
#' @param max_consecutive_404 Stop after this many 404s in a row
#' @return A tibble of scraped stenograms
scrape_rada_stenograms <- function(start_id = 6700, end_id = 9000,
                                    start_date = DATE_START,
                                    end_date = DATE_END,
                                    resume = TRUE,
                                    max_consecutive_404 = 50) {
  if (!requireNamespace("digest", quietly = TRUE)) install.packages("digest")
  dir.create(CORPUS_DIR, recursive = TRUE, showWarnings = FALSE)

  start_dt <- as.Date(start_date)
  end_dt   <- as.Date(end_date)

  cat(sprintf("\n%s\nScraping Rada stenograms (IDs %d to %d)\nDate range: %s to %s\n%s\n",
              strrep("=", 60), start_id, end_id, start_date, end_date,
              strrep("=", 60)))

  all_docs <- list()
  consecutive_404 <- 0
  fetched <- 0
  skipped <- 0

  for (id in start_id:end_id) {
    url <- sprintf("%s/meeting/stenogr/show/%d.html", RADA_BASE, id)
    did <- doc_id(url)
    doc_path <- file.path(CORPUS_DIR, paste0(did, ".json"))

    # Resume: skip existing
    if (resume && file.exists(doc_path)) {
      existing <- tryCatch(fromJSON(doc_path), error = function(e) NULL)
      if (!is.null(existing)) {
        for (nm in names(existing)) {
          if (is.null(existing[[nm]]) || length(existing[[nm]]) == 0)
            existing[[nm]] <- NA_character_
        }
        all_docs[[length(all_docs) + 1]] <- existing
        skipped <- skipped + 1
        if (skipped %% 50 == 0)
          cat(sprintf("  [skip] %d cached stenograms so far...\n", skipped))
        consecutive_404 <- 0
        next
      }
    }

    html <- fetch_rada(url)

    if (is.null(html)) {
      cat(sprintf("  [ID %d] Failed to fetch\n", id))
      next
    }

    if (identical(html, "404")) {
      consecutive_404 <- consecutive_404 + 1
      if (consecutive_404 >= max_consecutive_404) {
        cat(sprintf("  %d consecutive 404s — assuming end of stenograms at ID %d\n",
                    max_consecutive_404, id))
        break
      }
      next
    }

    consecutive_404 <- 0

    # Check if page has actual content (not an error page)
    if (nchar(html) < 1000) {
      cat(sprintf("  [ID %d] Skipped — too short (%d chars)\n", id, nchar(html)))
      next
    }
    # Accept any substantial page from a stenogram URL
    # (the URL path already guarantees it's a stenogram endpoint)
    if (nchar(html) < 5000 &&
        !grepl("стеногр|Засідання|засідання|stenogr", html, ignore.case = TRUE)) {
      cat(sprintf("  [ID %d] Skipped — small page without stenogram keywords (%d chars)\n", id, nchar(html)))
      next
    }

    # Show page title for diagnostics
    title_match <- regmatches(html, regexpr("<title>[^<]+</title>", html))
    if (length(title_match) > 0) {
      cat(sprintf("  [ID %d] Page <title>: %s\n", id,
                  substr(gsub("</?title>", "", title_match[1]), 1, 80)))
    }

    article <- parse_stenogram(html)
    date_str <- article$date
    cat(sprintf("  [ID %d] Parsed: title='%s', date='%s', body=%d chars\n",
                id,
                substr(if (is.null(article$title)) "" else article$title, 1, 50),
                if (is.na(date_str)) "NA" else date_str,
                nchar(article$body_text)))

    # Date range filter
    if (!is.na(date_str)) {
      doc_dt <- tryCatch(as.Date(date_str), error = function(e) NA)
      if (!is.na(doc_dt) && (doc_dt < start_dt || doc_dt > end_dt)) {
        cat(sprintf("  [ID %d] Skipped — date %s outside range %s to %s\n",
                    id, date_str, start_date, end_date))
        next
      }
    }

    body <- article$body_text
    wc <- length(strsplit(body, "\\s+")[[1]])

    doc <- list(
      id           = did,
      url          = url,
      rada_id      = id,
      title        = if (is.null(article$title) || article$title == "")
                       sprintf("Rada stenogram %d", id) else article$title,
      date         = if (is.null(date_str)) NA_character_ else date_str,
      content_type = "rada_stenogram",
      source       = "rada.gov.ua",
      body_text    = body,
      word_count   = wc,
      scraped_at   = format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
    )

    write_json(doc, doc_path, auto_unbox = TRUE, pretty = TRUE)
    all_docs[[length(all_docs) + 1]] <- doc
    fetched <- fetched + 1
    cat(sprintf("  [ID %d] %s — %s (%d words)\n",
                id, ifelse(is.na(date_str), "no date", date_str),
                substr(article$title, 1, 40), wc))
  }

  cat(sprintf("\n%s\nRada scraping complete\n  Fetched: %d\n  Cached:  %d\n  Total:   %d\n%s\n",
              strrep("=", 60), fetched, skipped,
              length(all_docs), strrep("=", 60)))

  if (length(all_docs) == 0) return(tibble())

  # Save index
  result <- bind_rows(lapply(all_docs, function(d) {
    for (nm in names(d)) {
      if (is.null(d[[nm]]) || length(d[[nm]]) == 0)
        d[[nm]] <- NA_character_
    }
    as_tibble(d)
  }))

  index_path <- file.path(OUTPUT_DIR, "rada_index.json")
  index_data <- result %>% select(-body_text)
  write_json(index_data, index_path, auto_unbox = TRUE, pretty = TRUE)
  cat(sprintf("Rada index saved: %s (%d documents)\n", index_path, nrow(result)))

  result
}
