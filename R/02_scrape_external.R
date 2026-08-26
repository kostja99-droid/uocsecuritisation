# ──────────────────────────────────────────────────────────
# 02_scrape_external.R — Scrape Rada stenograms & SBU press releases
#
# Companion to 02_scrape.R (president.gov.ua). This file handles
# rada.gov.ua and sbu.gov.ua using the same output format and
# conventions.
#
# Usage:
#   source("R/01_config.R")
#   source("R/02_scrape_external.R")
#
#   rada_docs  <- scrape_rada(DATE_START, DATE_END)
#   sbu_docs   <- scrape_sbu(DATE_START, DATE_END)
#   all_docs   <- scrape_external_all(DATE_START, DATE_END)
# ──────────────────────────────────────────────────────────

library(rvest)
library(httr)
library(jsonlite)
library(stringr)
library(dplyr)

# Source config if not already loaded
if (!exists("CORPUS_DIR")) {
  source(file.path("R", "01_config.R"))
}
# Reuse parse_uk_date and doc_id from 02_scrape.R if loaded,
# otherwise define them here
if (!exists("parse_uk_date")) {
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
    if (grepl("^\\d{4}-\\d{2}-\\d{2}", text))
      return(substr(text, 1, 10))
    if (grepl("^\\d{2}\\.\\d{2}\\.\\d{4}$", text)) {
      parts <- strsplit(text, "\\.")[[1]]
      return(sprintf("%s-%s-%s", parts[3], parts[2], parts[1]))
    }
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

# ── Generic fetch with per-site session handle ───────────

.ext_handles <- list()

init_ext_session <- function(base_url) {
  h <- handle(base_url)
  cat(sprintf("Initialising session for %s...\n", base_url))
  tryCatch({
    resp <- GET(
      base_url,
      handle = h,
      user_agent(USER_AGENT),
      add_headers(
        Accept            = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        `Accept-Language` = "uk-UA,uk;q=0.9,en-US;q=0.8,en;q=0.7",
        `Accept-Encoding` = "gzip, deflate, br",
        Connection        = "keep-alive"
      ),
      timeout(REQUEST_TIMEOUT)
    )
    cat(sprintf("  Response: HTTP %d\n", status_code(resp)))
    Sys.sleep(2)
  }, error = function(e) {
    cat(sprintf("  Warning: could not reach %s: %s\n", base_url, e$message))
  })
  .ext_handles[[base_url]] <<- h
  invisible(h)
}

fetch_ext <- function(url, base_url) {
  if (is.null(.ext_handles[[base_url]])) init_ext_session(base_url)
  h <- .ext_handles[[base_url]]

  for (attempt in seq_len(MAX_RETRIES)) {
    Sys.sleep(runif(1, REQUEST_DELAY[1], REQUEST_DELAY[2]))
    tryCatch({
      resp <- GET(
        url,
        handle = h,
        user_agent(USER_AGENT),
        add_headers(
          Accept            = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
          `Accept-Language` = "uk-UA,uk;q=0.9,en-US;q=0.8,en;q=0.7",
          `Accept-Encoding` = "gzip, deflate, br",
          Connection        = "keep-alive",
          Referer           = base_url
        ),
        timeout(REQUEST_TIMEOUT)
      )
      if (http_error(resp)) {
        message(sprintf("  [attempt %d/%d] HTTP %d for %s",
                        attempt, MAX_RETRIES, status_code(resp), url))
        if (attempt < MAX_RETRIES) Sys.sleep(2^attempt)
        next
      }
      return(content(resp, as = "text", encoding = "UTF-8"))
    }, error = function(e) {
      message(sprintf("  [attempt %d/%d] Error: %s", attempt, MAX_RETRIES, e$message))
      if (attempt < MAX_RETRIES) Sys.sleep(2^attempt)
    })
  }
  return(NULL)
}


# ══════════════════════════════════════════════════════════
# RADA STENOGRAMS
# ══════════════════════════════════════════════════════════

RADA_BASE <- "https://www.rada.gov.ua"

# Convocation info: which sessions overlap with thesis dates
# 8th convocation: 2014-11 to 2019-08 (covers J1 autocephaly)
# 9th convocation: 2019-08 to present (covers J2-J4)
RADA_CONVOCATIONS <- list(
  "8" = list(start = "2014-11-27", end = "2019-08-28",
             label = "8th convocation"),
  "9" = list(start = "2019-08-29", end = "2030-01-01",
             label = "9th convocation")
)

# Parse the Rada stenogram index page for session links
parse_rada_index <- function(html_text) {
  page <- read_html(html_text)
  links <- list()
  seen <- character()

  # Stenogram index pages list links to individual session records
  all_links <- html_elements(page, "a[href]")
  for (a in all_links) {
    href <- html_attr(a, "href")
    if (is.na(href)) next
    # Match stenogram URLs (various patterns rada.gov.ua uses)
    if (!grepl("stenogr|stenog|zasid", href, ignore.case = TRUE)) next
    if (href %in% seen) next
    seen <- c(seen, href)

    title <- html_text2(a)
    full_url <- if (startsWith(href, "http")) href else paste0(RADA_BASE, href)

    # Extract date from title or parent text
    parent_text <- tryCatch(
      html_text2(html_element(a, xpath = "..")),
      error = function(e) ""
    )
    combined <- paste(title, parent_text)
    date_str <- parse_uk_date(combined)
    if (is.na(date_str)) {
      m <- str_match(combined, "(\\d{2})\\.(\\d{2})\\.(\\d{4})")
      if (!is.na(m[1, 1])) {
        date_str <- sprintf("%s-%s-%s", m[1, 4], m[1, 3], m[1, 2])
      }
    }

    links[[length(links) + 1]] <- list(
      url   = full_url,
      title = title,
      date  = date_str
    )
  }

  links
}

# Parse the body text of a stenogram page
parse_rada_stenogram <- function(html_text) {
  page <- read_html(html_text)
  for (sel in c(".stenograma", ".steno-text", ".session_text",
                "#stenograma", ".main-content", ".content-main",
                "article", "#content", "main")) {
    el <- html_element(page, sel)
    if (!is.na(el)) return(html_text2(el))
  }
  html_text2(page)
}

#' Scrape Rada plenary stenograms
#'
#' @param start_date Start date (YYYY-MM-DD string)
#' @param end_date   End date (YYYY-MM-DD string)
#' @param resume     Skip already-scraped documents
#' @return A tibble of scraped stenograms
scrape_rada <- function(start_date = DATE_START, end_date = DATE_END,
                        resume = FALSE) {
  if (!requireNamespace("digest", quietly = TRUE)) install.packages("digest")
  dir.create(CORPUS_DIR, recursive = TRUE, showWarnings = FALSE)

  start_dt <- as.Date(start_date)
  end_dt   <- as.Date(end_date)
  all_docs <- list()

  cat(sprintf("\n%s\nScraping Rada stenograms (rada.gov.ua)\nDate range: %s to %s\n%s\n",
              strrep("=", 60), start_date, end_date, strrep("=", 60)))

  # First, try the stenogram index
  index_url <- paste0(RADA_BASE, "/meeting/stenogr/")
  html <- fetch_ext(index_url, RADA_BASE)

  if (!is.null(html)) {
    session_links <- parse_rada_index(html)
    cat(sprintf("  Found %d session links on index page\n", length(session_links)))

    # The index often has sub-pages per session; follow each
    for (link_info in session_links) {
      # Check if this is a sub-index or a stenogram
      sub_html <- fetch_ext(link_info$url, RADA_BASE)
      if (is.null(sub_html)) next

      sub_links <- parse_rada_index(sub_html)
      if (length(sub_links) > 0) {
        # This was a sub-index page — process its links
        cat(sprintf("  Sub-index: %s (%d stenograms)\n",
                    substr(link_info$title, 1, 40), length(sub_links)))
        for (sl in sub_links) {
          doc <- .scrape_one_rada(sl, start_dt, end_dt, resume)
          if (!is.null(doc)) all_docs[[length(all_docs) + 1]] <- doc
        }
      } else {
        # Direct stenogram page
        doc <- .scrape_one_rada(link_info, start_dt, end_dt, resume,
                                html_text = sub_html)
        if (!is.null(doc)) all_docs[[length(all_docs) + 1]] <- doc
      }
    }
  }

  # Also try paginated index for each session number
  for (session_num in 1:15) {
    session_url <- sprintf("%s/meeting/stenogr/%d", RADA_BASE, session_num)
    html <- fetch_ext(session_url, RADA_BASE)
    if (is.null(html)) next

    links <- parse_rada_index(html)
    if (length(links) == 0) next

    cat(sprintf("  Session %d: %d stenogram links\n", session_num, length(links)))
    for (link_info in links) {
      # Skip if already processed
      did <- doc_id(link_info$url)
      if (any(sapply(all_docs, function(d) d$id == did))) next

      doc <- .scrape_one_rada(link_info, start_dt, end_dt, resume)
      if (!is.null(doc)) all_docs[[length(all_docs) + 1]] <- doc
    }
  }

  cat(sprintf("\n%s\nTotal Rada stenograms: %d\n%s\n",
              strrep("=", 60), length(all_docs), strrep("=", 60)))

  if (length(all_docs) == 0) return(tibble())
  bind_rows(lapply(all_docs, as_tibble))
}

# Internal: scrape one Rada stenogram
.scrape_one_rada <- function(link_info, start_dt, end_dt, resume,
                             html_text = NULL) {
  date_str <- link_info$date
  if (!is.na(date_str)) {
    doc_dt <- tryCatch(as.Date(date_str), error = function(e) NA)
    if (!is.na(doc_dt) && (doc_dt < start_dt || doc_dt > end_dt)) return(NULL)
  }

  did <- doc_id(link_info$url)
  doc_path <- file.path(CORPUS_DIR, paste0(did, ".json"))
  if (resume && file.exists(doc_path)) {
    cat(sprintf("  [skip] %s\n", substr(link_info$title, 1, 60)))
    return(fromJSON(doc_path))
  }

  cat(sprintf("  Fetching: %s...\n", substr(link_info$title, 1, 60)))
  if (is.null(html_text)) {
    html_text <- fetch_ext(link_info$url, RADA_BASE)
    if (is.null(html_text)) return(NULL)
  }

  body <- parse_rada_stenogram(html_text)
  doc <- list(
    id           = did,
    url          = link_info$url,
    title        = link_info$title,
    date         = date_str,
    content_type = "rada_stenogram",
    source       = "rada.gov.ua",
    body_text    = body,
    word_count   = length(strsplit(body, "\\s+")[[1]]),
    scraped_at   = format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
  )

  write_json(doc, doc_path, auto_unbox = TRUE, pretty = TRUE)
  cat(sprintf("    Saved: %s.json (%d words)\n", did, doc$word_count))
  doc
}


# ══════════════════════════════════════════════════════════
# SBU PRESS RELEASES
# ══════════════════════════════════════════════════════════

SBU_BASE <- "https://sbu.gov.ua"

# Parse an SBU article page
parse_sbu_article <- function(html_text) {
  page <- read_html(html_text)

  title <- ""
  for (sel in c("h1", ".article-title", ".news-title", "h2.title")) {
    el <- html_element(page, sel)
    if (!is.na(el)) { title <- html_text2(el); break }
  }

  date_text <- ""
  for (sel in c("time", ".date", ".article-date", ".news-date", ".created")) {
    el <- html_element(page, sel)
    if (!is.na(el)) {
      date_text <- html_attr(el, "datetime")
      if (is.na(date_text)) date_text <- html_text2(el)
      break
    }
  }

  body <- ""
  for (sel in c(".article-body", ".article-content", ".news-body",
                ".news-content", ".field-name-body", ".text",
                "article .content", "#content .field-item")) {
    el <- html_element(page, sel)
    if (!is.na(el)) { body <- html_text2(el); break }
  }
  if (body == "") {
    for (sel in c("main", "article", "#content")) {
      el <- html_element(page, sel)
      if (!is.na(el)) { body <- html_text2(el); break }
    }
  }

  list(title = title, date = parse_uk_date(date_text), body_text = body)
}

# Parse an SBU listing page for news links
parse_sbu_listing <- function(html_text) {
  page <- read_html(html_text)
  items <- list()
  seen  <- character()

  all_links <- html_elements(page, "a[href]")
  for (a in all_links) {
    href <- html_attr(a, "href")
    if (is.na(href)) next
    if (!grepl("/news/\\d+|/press/|/article/", href)) next

    title <- html_text2(a)
    if (nchar(title) < 10) next

    full_url <- if (startsWith(href, "http")) href else paste0(SBU_BASE, href)
    if (full_url %in% seen) next
    seen <- c(seen, full_url)

    # Date from surrounding context
    date_text <- ""
    parent <- tryCatch(html_element(a, xpath = ".."), error = function(e) NA)
    if (!is.na(parent)) {
      time_el <- html_element(parent, "time")
      if (!is.na(time_el)) {
        date_text <- html_attr(time_el, "datetime")
        if (is.na(date_text)) date_text <- html_text2(time_el)
      } else {
        date_el <- html_element(parent, "[class*='date']")
        if (!is.na(date_el)) date_text <- html_text2(date_el)
      }
    }

    items[[length(items) + 1]] <- list(
      title = title, url = full_url, date_text = date_text
    )
  }

  # Next page link
  next_url <- NA_character_
  for (sel in c("a.next", "a.pager-next", "li.next a",
                ".pagination .next a")) {
    el <- html_element(page, sel)
    if (!is.na(el)) {
      href <- html_attr(el, "href")
      if (!is.na(href)) {
        next_url <- if (startsWith(href, "http")) href else paste0(SBU_BASE, href)
      }
      break
    }
  }

  list(items = items, next_url = next_url)
}

#' Scrape SBU press releases
#'
#' @param start_date Start date (YYYY-MM-DD string)
#' @param end_date   End date (YYYY-MM-DD string)
#' @param resume     Skip already-scraped documents
#' @return A tibble of scraped press releases
scrape_sbu <- function(start_date = DATE_START, end_date = DATE_END,
                       resume = FALSE) {
  if (!requireNamespace("digest", quietly = TRUE)) install.packages("digest")
  dir.create(CORPUS_DIR, recursive = TRUE, showWarnings = FALSE)

  start_dt <- as.Date(start_date)
  end_dt   <- as.Date(end_date)
  all_docs <- list()

  cat(sprintf("\n%s\nScraping SBU press releases (sbu.gov.ua)\nDate range: %s to %s\n%s\n",
              strrep("=", 60), start_date, end_date, strrep("=", 60)))

  # Try multiple URL patterns for the SBU news listing
  news_paths <- c("/news/archive", "/news", "/ua/news", "/en/news")
  listing_url <- NULL
  listing_html <- NULL

  for (path in news_paths) {
    url <- paste0(SBU_BASE, path)
    html <- fetch_ext(url, SBU_BASE)
    if (!is.null(html)) {
      cat(sprintf("  Found working path: %s\n", path))
      listing_url <- url
      listing_html <- html
      break
    }
  }

  if (is.null(listing_html)) {
    cat("  Could not find SBU news listing. Trying page enumeration...\n")
    for (p in 1:50) {
      url <- sprintf("%s/news/page/%d", SBU_BASE, p)
      html <- fetch_ext(url, SBU_BASE)
      if (is.null(html)) break

      page_docs <- .process_sbu_listing(html, start_dt, end_dt, resume)
      if (length(page_docs) == 0 && p > 1) break
      all_docs <- c(all_docs, page_docs)
    }
  } else {
    consecutive_empty <- 0
    current_url <- listing_url
    page_num <- 0

    while (!is.na(current_url) && consecutive_empty < 3) {
      page_num <- page_num + 1
      cat(sprintf("\n--- SBU listing page %d\n", page_num))

      if (page_num > 1) {
        listing_html <- fetch_ext(current_url, SBU_BASE)
        if (is.null(listing_html)) break
      }

      page_docs <- .process_sbu_listing(listing_html, start_dt, end_dt, resume)
      if (length(page_docs) == 0) {
        consecutive_empty <- consecutive_empty + 1
      } else {
        consecutive_empty <- 0
        all_docs <- c(all_docs, page_docs)
      }

      parsed <- parse_sbu_listing(listing_html)
      current_url <- parsed$next_url
    }
  }

  cat(sprintf("\n%s\nTotal SBU press releases: %d\n%s\n",
              strrep("=", 60), length(all_docs), strrep("=", 60)))

  if (length(all_docs) == 0) return(tibble())
  bind_rows(lapply(all_docs, as_tibble))
}

# Internal: process one SBU listing page
.process_sbu_listing <- function(html_text, start_dt, end_dt, resume) {
  parsed <- parse_sbu_listing(html_text)
  docs <- list()

  for (item in parsed$items) {
    did <- doc_id(item$url)
    doc_path <- file.path(CORPUS_DIR, paste0(did, ".json"))

    if (resume && file.exists(doc_path)) {
      cat(sprintf("  [skip] %s\n", substr(item$title, 1, 60)))
      docs[[length(docs) + 1]] <- fromJSON(doc_path)
      next
    }

    cat(sprintf("  Fetching: %s...\n", substr(item$title, 1, 60)))
    article_html <- fetch_ext(item$url, SBU_BASE)
    if (is.null(article_html)) next

    article <- parse_sbu_article(article_html)
    date_str <- article$date
    if (is.na(date_str) && item$date_text != "") {
      date_str <- parse_uk_date(item$date_text)
    }

    if (!is.na(date_str)) {
      doc_dt <- tryCatch(as.Date(date_str), error = function(e) NA)
      if (!is.na(doc_dt) && (doc_dt < start_dt || doc_dt > end_dt)) {
        cat(sprintf("    Date %s out of range, skipping.\n", date_str))
        next
      }
    }

    body <- article$body_text
    doc <- list(
      id           = did,
      url          = item$url,
      title        = if (article$title != "") article$title else item$title,
      date         = date_str,
      content_type = "sbu_press_release",
      source       = "sbu.gov.ua",
      body_text    = body,
      word_count   = length(strsplit(body, "\\s+")[[1]]),
      scraped_at   = format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
    )

    write_json(doc, doc_path, auto_unbox = TRUE, pretty = TRUE)
    docs[[length(docs) + 1]] <- doc
    cat(sprintf("    Saved: %s.json (%d words)\n", did, doc$word_count))
  }

  docs
}


# ══════════════════════════════════════════════════════════
# SCRAPE ALL EXTERNAL SOURCES
# ══════════════════════════════════════════════════════════

#' Scrape all external sources (Rada + SBU)
#'
#' Use this alongside scrape_all() from 02_scrape.R which handles
#' president.gov.ua (speeches and press releases, both Poroshenko
#' and Zelensky eras).
#'
#' @param start_date Start date (YYYY-MM-DD string)
#' @param end_date   End date (YYYY-MM-DD string)
#' @param resume     Skip already-scraped documents
#' @return A tibble of all scraped documents
scrape_external_all <- function(start_date = DATE_START,
                                end_date = DATE_END,
                                resume = FALSE) {
  rada <- scrape_rada(start_date, end_date, resume)
  sbu  <- scrape_sbu(start_date, end_date, resume)

  result <- bind_rows(rada, sbu)

  if (nrow(result) > 0) {
    dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)
    index_path <- file.path(OUTPUT_DIR, "scrape_external_index.json")
    index_data <- result %>% select(-body_text)
    write_json(index_data, index_path, auto_unbox = TRUE, pretty = TRUE)
    cat(sprintf("\nExternal index saved: %s (%d documents)\n",
                index_path, nrow(result)))
  }

  result
}
