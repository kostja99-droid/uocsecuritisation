# ──────────────────────────────────────────────────────────
# 02_scrape_browser.R — Stealth browser-based scraper (Chromote)
#
# Use this instead of 02_scrape.R if president.gov.ua blocks
# regular HTTP requests. Uses anti-detection measures to avoid
# Akamai bot fingerprinting.
#
# REQUIRES: Google Chrome or Chromium installed on your system.
#   install.packages("chromote")
#
# Usage:
#   source("01_config.R")
#   source("02_scrape_browser.R")
#   docs <- scrape_all(DATE_START, DATE_END)
# ──────────────────────────────────────────────────────────

library(chromote)
library(rvest)
library(jsonlite)
library(stringr)
library(dplyr)

# ── Browser session management (stealth mode) ────────────
.chrome_process <- NULL
.browser_session <- NULL

start_browser <- function() {
  if (is.null(.browser_session)) {
    cat("Starting stealth browser...\n")
    chrome <- Chrome$new(args = c(
      "--disable-blink-features=AutomationControlled",
      "--no-first-run",
      "--no-default-browser-check",
      "--disable-extensions",
      "--window-size=1920,1080",
      "--start-maximized",
      "--lang=uk-UA"
    ))
    .chrome_process <<- chrome
    b <- ChromoteSession$new(parent = chrome)

    # Remove webdriver flag that Akamai detects
    b$Runtime$evaluate(
      "Object.defineProperty(navigator, 'webdriver', {get: () => undefined})"
    )
    # Override plugins to look like a real browser
    b$Runtime$evaluate(paste0(
      "Object.defineProperty(navigator, 'plugins', {",
      "get: () => [1,2,3,4,5]",
      "})"
    ))
    # Override languages
    b$Runtime$evaluate(paste0(
      "Object.defineProperty(navigator, 'languages', {",
      "get: () => ['uk-UA', 'uk', 'en-US', 'en']",
      "})"
    ))

    # Set a real user-agent via CDP
    b$Network$setUserAgentOverride(
      userAgent = USER_AGENT,
      acceptLanguage = "uk-UA,uk;q=0.9,en-US;q=0.8,en;q=0.7",
      platform = "Win32"
    )

    .browser_session <<- b
    Sys.sleep(2)
    cat("Stealth browser ready.\n")
  }
  invisible(.browser_session)
}

stop_browser <- function() {
  if (!is.null(.browser_session)) {
    tryCatch(.browser_session$close(), error = function(e) NULL)
    .browser_session <<- NULL
  }
  if (!is.null(.chrome_process)) {
    tryCatch(.chrome_process$close(), error = function(e) NULL)
    .chrome_process <<- NULL
  }
  cat("Browser closed.\n")
}

# ── Fetch a page using stealth Chrome ────────────────────
fetch_page <- function(url, retries = MAX_RETRIES) {
  for (attempt in seq_len(retries)) {
    b <- start_browser()
    Sys.sleep(runif(1, REQUEST_DELAY[1], REQUEST_DELAY[2]))
    tryCatch({
      b$Page$navigate(url)
      Sys.sleep(4)

      # Check if we got an Access Denied page
      title_result <- b$Runtime$evaluate("document.title")
      page_title <- title_result$result$value
      if (!is.null(page_title) && grepl("Access Denied", page_title, ignore.case = TRUE)) {
        message(sprintf("  [attempt %d/%d] Access Denied for %s", attempt, retries, url))
        # Restart browser with fresh session
        stop_browser()
        if (attempt < retries) Sys.sleep(2^attempt + runif(1, 1, 3))
        next
      }

      result <- b$Runtime$evaluate("document.documentElement.outerHTML")
      html <- result$result$value
      if (is.null(html) || nchar(html) < 500) {
        message(sprintf("  [attempt %d/%d] Page too small (%d chars) for %s",
                        attempt, retries,
                        if (is.null(html)) 0 else nchar(html), url))
        stop_browser()
        if (attempt < retries) Sys.sleep(2^attempt)
        next
      }
      return(html)
    }, error = function(e) {
      message(sprintf("  [attempt %d/%d] Error: %s", attempt, retries, e$message))
      tryCatch(stop_browser(), error = function(e2) NULL)
      if (attempt < retries) Sys.sleep(2^attempt)
    })
  }
  return(NULL)
}

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

# ── Parsing functions ────────────────────────────────────

parse_listing_page <- function(html_text) {
  page <- read_html(html_text)
  items <- list()
  selectors <- c(
    "div.item_stat_headline", "div.news_item",
    "li.item_stat_headline_line", "div.col-md-8 div.item", "article"
  )
  articles <- NULL
  for (sel in selectors) {
    nodes <- html_elements(page, sel)
    if (length(nodes) > 0) { articles <- nodes; break }
  }
  if (is.null(articles) || length(articles) == 0) {
    links <- html_elements(page, "a[href*='/news/']")
    for (link in links) {
      href  <- html_attr(link, "href")
      title <- html_text2(link)
      if (is.na(href) || is.na(title)) next
      if (nchar(title) < 10 || grepl("page", href)) next
      full_url <- if (startsWith(href, "http")) href else paste0(BASE_URL, href)
      items[[length(items) + 1]] <- list(title = title, url = full_url, date_text = "")
    }
  } else {
    for (art in articles) {
      link <- html_element(art, "a")
      if (is.na(link)) next
      href  <- html_attr(link, "href")
      title <- html_text2(link)
      if (is.na(title) || nchar(title) < 5) next
      full_url <- if (startsWith(href, "http")) href else paste0(BASE_URL, href)
      date_el <- html_element(art, "time")
      date_text <- ""
      if (!is.na(date_el)) {
        date_text <- html_attr(date_el, "datetime")
        if (is.na(date_text)) date_text <- html_text2(date_el)
      } else {
        date_el2 <- html_element(art, "[class*='date']")
        if (!is.na(date_el2)) date_text <- html_text2(date_el2)
      }
      items[[length(items) + 1]] <- list(title = title, url = full_url, date_text = date_text)
    }
  }
  next_url <- NA_character_
  next_link <- html_element(page, "a.next, a.pager-next")
  if (!is.na(next_link)) {
    href <- html_attr(next_link, "href")
    if (!is.na(href)) next_url <- if (startsWith(href, "http")) href else paste0(BASE_URL, href)
  }
  if (is.na(next_url)) {
    pager <- html_element(page, "[class*='pag']")
    if (!is.na(pager)) {
      active <- html_element(pager, ".active, .current")
      if (!is.na(active)) {
        siblings <- html_elements(pager, "a")
        active_text <- html_text2(active)
        found_active <- FALSE
        for (s in siblings) {
          if (found_active) {
            href <- html_attr(s, "href")
            if (!is.na(href)) next_url <- if (startsWith(href, "http")) href else paste0(BASE_URL, href)
            break
          }
          if (html_text2(s) == active_text) found_active <- TRUE
        }
      }
    }
  }
  urls_seen <- character()
  unique_items <- list()
  for (item in items) {
    if (!(item$url %in% urls_seen)) {
      urls_seen <- c(urls_seen, item$url)
      unique_items[[length(unique_items) + 1]] <- item
    }
  }
  list(items = unique_items, next_url = next_url)
}

parse_article_page <- function(html_text) {
  page <- read_html(html_text)
  title <- ""
  for (sel in c("h1", "h2.entry-title", ".article_header h2", ".headline")) {
    el <- html_element(page, sel)
    if (!is.na(el)) { title <- html_text2(el); break }
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
  substr(digest::digest(url, algo = "md5"), 1, 12)
}

# ── Scrape one category ──────────────────────────────────
scrape_category <- function(category_key, start_date, end_date, resume = FALSE) {
  if (!requireNamespace("digest", quietly = TRUE)) install.packages("digest")
  cat_info <- CATEGORIES[[category_key]]
  dir.create(CORPUS_DIR, recursive = TRUE, showWarnings = FALSE)
  start_dt <- as.Date(start_date)
  end_dt   <- as.Date(end_date)
  all_docs <- list()
  page_url <- paste0(BASE_URL, cat_info$path)
  page_num <- 0
  consecutive_oor <- 0
  cat(sprintf("\n%s\nScraping: %s (%s)\nDate range: %s to %s\n%s\n",
              strrep("=", 60), cat_info$label, cat_info$path,
              start_date, end_date, strrep("=", 60)))
  while (!is.na(page_url) && consecutive_oor < 5) {
    page_num <- page_num + 1
    cat(sprintf("\n--- Listing page %d: %s\n", page_num, page_url))
    html <- fetch_page(page_url)
    if (is.null(html)) { cat("  Failed to fetch listing page, stopping.\n"); break }
    parsed <- parse_listing_page(html)
    cat(sprintf("  Found %d items on this page\n", length(parsed$items)))
    if (length(parsed$items) == 0) {
      cat("  No items found — end of listings or selector mismatch.\n")
      break
    }
    for (item in parsed$items) {
      did <- doc_id(item$url)
      doc_path <- file.path(CORPUS_DIR, paste0(did, ".json"))
      if (resume && file.exists(doc_path)) {
        existing <- fromJSON(doc_path)
        all_docs[[length(all_docs) + 1]] <- existing
        cat(sprintf("  [skip] %s...\n", substr(item$title, 1, 60)))
        next
      }
      cat(sprintf("  Fetching: %s...\n", substr(item$title, 1, 60)))
      article_html <- fetch_page(item$url)
      if (is.null(article_html)) { cat("    Failed to fetch article.\n"); next }
      article <- parse_article_page(article_html)
      date_str <- article$date
      if (is.na(date_str) && item$date_text != "") date_str <- parse_uk_date(item$date_text)
      if (!is.na(date_str)) {
        doc_dt <- tryCatch(as.Date(date_str), error = function(e) NA)
        if (!is.na(doc_dt)) {
          if (doc_dt < start_dt || doc_dt > end_dt) {
            consecutive_oor <- consecutive_oor + 1
            cat(sprintf("    Date %s out of range, skipping.\n", date_str))
            next
          }
          consecutive_oor <- 0
        }
      }
      doc <- list(
        id           = did,
        url          = item$url,
        title        = if (article$title != "") article$title else item$title,
        date         = date_str,
        content_type = cat_info$type,
        body_text    = article$body_text,
        word_count   = length(strsplit(article$body_text, "\\s+")[[1]]),
        scraped_at   = format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
      )
      write_json(doc, doc_path, auto_unbox = TRUE, pretty = TRUE)
      all_docs[[length(all_docs) + 1]] <- doc
      cat(sprintf("    Saved: %s.json (%d words)\n", did, doc$word_count))
    }
    page_url <- parsed$next_url
    if (is.na(page_url) && page_num < 500) {
      constructed <- sprintf("%s%s/page/%d", BASE_URL, cat_info$path, page_num + 1)
      test_html <- fetch_page(constructed)
      if (!is.null(test_html)) {
        test_parsed <- parse_listing_page(test_html)
        if (length(test_parsed$items) > 0) page_url <- constructed
      }
    }
  }
  cat(sprintf("\n%s\nTotal documents scraped for '%s': %d\n%s\n",
              strrep("=", 60), category_key, length(all_docs), strrep("=", 60)))
  stop_browser()
  bind_rows(lapply(all_docs, as_tibble))
}

# ── Scrape everything ────────────────────────────────────
scrape_all <- function(start_date = DATE_START, end_date = DATE_END, resume = FALSE) {
  all <- list()
  for (cat_key in names(CATEGORIES)) {
    docs <- scrape_category(cat_key, start_date, end_date, resume)
    all[[cat_key]] <- docs
  }
  result <- bind_rows(all)
  dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)
  write_json(result, file.path(OUTPUT_DIR, "scrape_index.json"),
             auto_unbox = TRUE, pretty = TRUE)
  cat(sprintf("\nMaster index saved (%d documents)\n", nrow(result)))
  stop_browser()
  result
}
