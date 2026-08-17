# ──────────────────────────────────────────────────────────
# 02_scrape_wayback.R — Scrape via the Wayback Machine
#
# Fallback when president.gov.ua blocks both HTTP and headless
# browser requests. Uses web.archive.org's CDX API to find
# archived snapshots, then fetches the cached HTML.
#
# No special dependencies beyond httr + rvest.
#
# Usage:
#   source("01_config.R")
#   source("02_scrape_wayback.R")
#   docs <- scrape_all(DATE_START, DATE_END)
# ──────────────────────────────────────────────────────────

library(httr)
library(rvest)
library(jsonlite)
library(stringr)
library(dplyr)

# ── Ukrainian month names → numeric ──────────────────────
uk_months <- c(
  "січня"    = "01", "лютого"   = "02", "березня"  = "03",
  "квітня"   = "04", "травня"   = "05", "червня"   = "06",
  "липня"    = "07", "серпня"   = "08", "вересня"  = "09",
  "жовтня"   = "10", "листопада" = "11", "грудня"   = "12"
)

parse_uk_date <- function(text) {
  if (is.na(text) || text == "") return(NA_character_)
  text <- trimws(text)
  if (grepl("^\\d{4}-\\d{2}-\\d{2}", text)) return(substr(text, 1, 10))
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

# ── Simple fetch (for Wayback Machine, no anti-bot needed) ──
fetch_url <- function(url, retries = 3) {
  for (attempt in seq_len(retries)) {
    Sys.sleep(runif(1, 1.0, 2.0))
    tryCatch({
      resp <- GET(url,
        user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"),
        timeout(60)
      )
      if (http_error(resp)) {
        message(sprintf("  [attempt %d/%d] HTTP %d for %s",
                        attempt, retries, status_code(resp), substr(url, 1, 100)))
        if (attempt < retries) Sys.sleep(2^attempt)
        next
      }
      return(content(resp, as = "text", encoding = "UTF-8"))
    }, error = function(e) {
      message(sprintf("  [attempt %d/%d] Error: %s", attempt, retries, e$message))
      if (attempt < retries) Sys.sleep(2^attempt)
    })
  }
  return(NULL)
}

# ── Query Wayback Machine CDX API for listing page snapshots ──
find_wayback_snapshots <- function(url_pattern, from_date, to_date) {
  from_ts <- gsub("-", "", from_date)
  to_ts   <- gsub("-", "", to_date)
  cdx_url <- sprintf(
    "https://web.archive.org/cdx/search/cdx?url=%s&matchType=prefix&output=json&fl=timestamp,original,statuscode&filter=statuscode:200&from=%s&to=%s&collapse=urlkey&limit=10000",
    URLencode(url_pattern, reserved = TRUE),
    from_ts, to_ts
  )
  cat(sprintf("  Querying Wayback Machine CDX API...\n"))
  json_text <- fetch_url(cdx_url)
  if (is.null(json_text)) return(data.frame())
  result <- tryCatch(fromJSON(json_text), error = function(e) NULL)
  if (is.null(result) || length(result) < 2) return(data.frame())
  header <- result[[1]]
  rows <- result[-1]
  df <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
  names(df) <- header
  cat(sprintf("  Found %d archived URLs\n", nrow(df)))
  df
}

# ── Find snapshots for listing pages specifically ────────
find_listing_snapshots <- function(base_path, from_date, to_date) {
  url_pattern <- paste0("www.president.gov.ua", base_path)
  snapshots <- find_wayback_snapshots(url_pattern, from_date, to_date)
  if (nrow(snapshots) == 0) return(character())

  # Keep only listing pages (not individual articles)
  listing_urls <- snapshots$original[
    grepl(paste0(base_path, "$"), snapshots$original) |
    grepl(paste0(base_path, "/page/\\d+$"), snapshots$original) |
    grepl(paste0(base_path, "\\?page=\\d+$"), snapshots$original)
  ]
  listing_urls <- unique(listing_urls)

  # Build Wayback URLs using the most recent snapshot for each
  wayback_urls <- character()
  for (url in listing_urls) {
    ts_rows <- snapshots[snapshots$original == url, ]
    latest_ts <- max(ts_rows$timestamp)
    wb_url <- sprintf("https://web.archive.org/web/%s/%s", latest_ts, url)
    wayback_urls <- c(wayback_urls, wb_url)
  }
  wayback_urls
}

# ── Find article URLs from Wayback CDX ───────────────────
find_article_snapshots <- function(from_date, to_date) {
  url_pattern <- "www.president.gov.ua/news/"
  snapshots <- find_wayback_snapshots(url_pattern, from_date, to_date)
  if (nrow(snapshots) == 0) return(data.frame())

  # Filter out listing pages, keep individual articles
  article_mask <- !grepl("/(speeches|all|decrees|statements)(/page/\\d+)?$",
                         snapshots$original) &
                  !grepl("\\?page=", snapshots$original) &
                  nchar(snapshots$original) > nchar("https://www.president.gov.ua/news/x")
  articles <- snapshots[article_mask, ]

  # Deduplicate: keep latest snapshot per original URL
  articles <- articles[order(articles$timestamp, decreasing = TRUE), ]
  articles <- articles[!duplicated(articles$original), ]
  cat(sprintf("  Found %d unique article URLs\n", nrow(articles)))
  articles
}

# ── Parse an article page (same selectors as other scrapers) ──
parse_article_page <- function(html_text) {
  page <- read_html(html_text)

  # Remove Wayback Machine toolbar if present
  wb_toolbar <- html_elements(page, "#wm-ipp-base, #wm-ipp, #donato, .wb-autocomplete-suggestions")
  # (rvest doesn't support node removal, but we parse around it)

  title <- ""
  for (sel in c("h1", "h2.entry-title", ".article_header h2", ".headline")) {
    el <- html_element(page, sel)
    if (!is.na(el)) {
      txt <- html_text2(el)
      if (!grepl("Wayback Machine", txt)) { title <- txt; break }
    }
  }
  date_text <- ""
  for (sel in c("time", ".date", ".article_date", ".news_date", ".created")) {
    el <- html_element(page, sel)
    if (!is.na(el)) {
      date_text <- html_attr(el, "datetime")
      if (is.na(date_text)) date_text <- html_text2(el)
      break
    }
  }
  body_text <- ""
  for (sel in c(".article_content", ".field-name-body", ".text",
                ".news_content", ".entry-content", "article .content",
                "#content .field-item")) {
    el <- html_element(page, sel)
    if (!is.na(el)) { body_text <- html_text2(el); break }
  }
  if (body_text == "") {
    main_el <- html_element(page, "main")
    if (is.na(main_el)) main_el <- html_element(page, "article")
    if (is.na(main_el)) main_el <- html_element(page, "#content")
    if (!is.na(main_el)) body_text <- html_text2(main_el)
  }
  list(title = title, date = parse_uk_date(date_text), body_text = body_text)
}

doc_id <- function(url) {
  clean_url <- sub("^https?://web\\.archive\\.org/web/\\d+/", "", url)
  substr(digest::digest(clean_url, algo = "md5"), 1, 12)
}

# ── Determine content type from URL ──────────────────────
guess_content_type <- function(url) {
  if (grepl("/speeches", url)) return("speech")
  return("press_release")
}

# ── Main scrape function via Wayback Machine ─────────────
scrape_all <- function(start_date = DATE_START, end_date = DATE_END, resume = FALSE) {
  if (!requireNamespace("digest", quietly = TRUE)) install.packages("digest")
  dir.create(CORPUS_DIR, recursive = TRUE, showWarnings = FALSE)
  start_dt <- as.Date(start_date)
  end_dt   <- as.Date(end_date)

  cat(sprintf("\n%s\nScraping via Wayback Machine\n", strrep("=", 60)))
  cat(sprintf("Date range: %s to %s\n%s\n\n", start_date, end_date, strrep("=", 60)))

  # Step 1: Find all article URLs archived by the Wayback Machine
  cat("Step 1: Finding archived article URLs...\n")
  articles <- find_article_snapshots(start_date, end_date)

  if (nrow(articles) == 0) {
    cat("No archived articles found. Try checking web.archive.org manually.\n")
    return(data.frame())
  }

  # Step 2: Fetch each article
  cat(sprintf("\nStep 2: Fetching %d articles...\n", nrow(articles)))
  all_docs <- list()
  for (i in seq_len(nrow(articles))) {
    row <- articles[i, ]
    original_url <- row$original
    if (!startsWith(original_url, "http")) {
      original_url <- paste0("https://", original_url)
    }
    did <- doc_id(original_url)
    doc_path <- file.path(CORPUS_DIR, paste0(did, ".json"))

    if (resume && file.exists(doc_path)) {
      existing <- fromJSON(doc_path)
      all_docs[[length(all_docs) + 1]] <- existing
      cat(sprintf("  [%d/%d] [skip] %s\n", i, nrow(articles), substr(original_url, 1, 80)))
      next
    }

    wb_url <- sprintf("https://web.archive.org/web/%s/%s", row$timestamp, original_url)
    cat(sprintf("  [%d/%d] Fetching: %s\n", i, nrow(articles), substr(original_url, 1, 80)))

    html <- fetch_url(wb_url)
    if (is.null(html)) {
      cat("    Failed to fetch.\n")
      next
    }

    article <- parse_article_page(html)

    # Skip if body is too short (navigation-only pages, redirects)
    if (nchar(article$body_text) < 100) {
      cat("    Too short, skipping.\n")
      next
    }

    date_str <- article$date

    # Date range check
    if (!is.na(date_str)) {
      doc_dt <- tryCatch(as.Date(date_str), error = function(e) NA)
      if (!is.na(doc_dt) && (doc_dt < start_dt || doc_dt > end_dt)) {
        cat(sprintf("    Date %s out of range, skipping.\n", date_str))
        next
      }
    }

    doc <- list(
      id           = did,
      url          = original_url,
      title        = article$title,
      date         = date_str,
      content_type = guess_content_type(original_url),
      body_text    = article$body_text,
      word_count   = length(strsplit(article$body_text, "\\s+")[[1]]),
      scraped_at   = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
      wayback_url  = wb_url
    )

    write_json(doc, doc_path, auto_unbox = TRUE, pretty = TRUE)
    all_docs[[length(all_docs) + 1]] <- doc
    cat(sprintf("    Saved: %s.json (%d words)\n", did, doc$word_count))
  }

  # Save master index
  if (length(all_docs) > 0) {
    result <- bind_rows(lapply(all_docs, as_tibble))
  } else {
    result <- data.frame()
  }
  dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)
  write_json(result, file.path(OUTPUT_DIR, "scrape_index.json"),
             auto_unbox = TRUE, pretty = TRUE)

  cat(sprintf("\n%s\n", strrep("=", 60)))
  cat(sprintf("Total documents scraped: %d\n", length(all_docs)))
  n_speeches <- sum(sapply(all_docs, function(d) d$content_type == "speech"))
  n_press    <- sum(sapply(all_docs, function(d) d$content_type == "press_release"))
  cat(sprintf("  Speeches: %d\n  Press releases: %d\n", n_speeches, n_press))
  cat(sprintf("%s\n", strrep("=", 60)))

  result
}

# ── Scrape by category (compatibility with run_all.R) ────
scrape_category <- function(category_key, start_date, end_date, resume = FALSE) {
  scrape_all(start_date, end_date, resume)
}
