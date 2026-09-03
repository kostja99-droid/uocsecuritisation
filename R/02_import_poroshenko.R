# ──────────────────────────────────────────────────────────
# 02_import_poroshenko.R — Fetch & import Poroshenko speeches
#
# Takes a CSV of URLs (extracted via browser dev tools) and
# fetches each article's full text, saving to the same corpus
# format used by the rest of the pipeline.
#
# Usage:
#   source("R/01_config.R")
#   source("R/02_import_poroshenko.R")
#
#   # From RISU:
#   docs <- fetch_poroshenko_articles("data/poroshenko_risu_links.csv",
#                                     source = "risu.ua")
#
#   # From ppu.gov.ua:
#   docs <- fetch_poroshenko_articles("data/poroshenko_ppu_links.csv",
#                                     source = "ppu.gov.ua")
#
#   # Or combine multiple CSVs:
#   docs <- fetch_poroshenko_all()
# ──────────────────────────────────────────────────────────

library(rvest)
library(httr)
library(jsonlite)
library(stringr)
library(dplyr)

if (!exists("CORPUS_DIR")) source(file.path("R", "01_config.R"))

# Reuse helpers if already loaded from 02_scrape.R
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

# ── Site-specific article parsers ────────────────────────

parse_risu_article <- function(html_text) {
  page <- read_html(html_text)

  title <- ""
  for (sel in c("h1", "h1.entry-title", ".article-title",
                ".news-detail h1", "h2.title")) {
    el <- html_element(page, sel)
    if (!is.na(el)) { title <- html_text2(el); break }
  }

  date_text <- ""
  for (sel in c("time", ".date", ".article-date", ".news-date",
                ".entry-date", ".created", "[class*='date']",
                "span.date", "div.date")) {
    el <- html_element(page, sel)
    if (!is.na(el)) {
      date_text <- html_attr(el, "datetime")
      if (is.na(date_text)) date_text <- html_text2(el)
      break
    }
  }

  body <- ""
  for (sel in c(".article-body", ".entry-content", ".news-text",
                ".article-content", ".field-name-body", ".text",
                ".news-detail-text", "article .content",
                "#content .field-item", ".post-content")) {
    el <- html_element(page, sel)
    if (!is.na(el)) { body <- html_text2(el); break }
  }
  if (body == "") {
    for (sel in c("article", "main", "#content")) {
      el <- html_element(page, sel)
      if (!is.na(el)) { body <- html_text2(el); break }
    }
  }

  list(title = title, date = parse_uk_date(date_text), body_text = body)
}

parse_ppu_article <- function(html_text) {
  page <- read_html(html_text)

  title <- ""
  for (sel in c("h1", ".entry-title", "h2.title")) {
    el <- html_element(page, sel)
    if (!is.na(el)) { title <- html_text2(el); break }
  }

  date_text <- ""
  for (sel in c("time", ".date", ".entry-date", "[class*='date']")) {
    el <- html_element(page, sel)
    if (!is.na(el)) {
      date_text <- html_attr(el, "datetime")
      if (is.na(date_text)) date_text <- html_text2(el)
      break
    }
  }

  body <- ""
  for (sel in c(".entry-content", ".article-body", ".text",
                "article .content", "#content")) {
    el <- html_element(page, sel)
    if (!is.na(el)) { body <- html_text2(el); break }
  }
  if (body == "") {
    el <- html_element(page, "main")
    if (!is.na(el)) body <- html_text2(el)
  }

  list(title = title, date = parse_uk_date(date_text), body_text = body)
}

parse_generic_article <- function(html_text) {
  page <- read_html(html_text)

  title <- ""
  for (sel in c("h1", "h2.entry-title", ".article_header h2")) {
    el <- html_element(page, sel)
    if (!is.na(el)) { title <- html_text2(el); break }
  }

  date_text <- ""
  for (sel in c("time", ".date", "[class*='date']")) {
    el <- html_element(page, sel)
    if (!is.na(el)) {
      date_text <- html_attr(el, "datetime")
      if (is.na(date_text)) date_text <- html_text2(el)
      break
    }
  }

  body <- ""
  for (sel in c(".article-body", ".entry-content", ".article_content",
                ".field-name-body", ".text", ".news_content",
                "article .content")) {
    el <- html_element(page, sel)
    if (!is.na(el)) { body <- html_text2(el); break }
  }
  if (body == "") {
    for (sel in c("article", "main", "#content")) {
      el <- html_element(page, sel)
      if (!is.na(el)) { body <- html_text2(el); break }
    }
  }

  list(title = title, date = parse_uk_date(date_text), body_text = body)
}

# ── Fetch with polite delay ──────────────────────────────

.poroshenko_handles <- list()

fetch_article <- function(url) {
  domain <- str_extract(url, "https?://([^/]+)", group = 1)
  base_url <- paste0("https://", domain)

  if (is.null(.poroshenko_handles[[base_url]])) {
    .poroshenko_handles[[base_url]] <<- handle(base_url)
    tryCatch({
      GET(base_url,
          handle = .poroshenko_handles[[base_url]],
          user_agent(USER_AGENT),
          timeout(REQUEST_TIMEOUT))
      Sys.sleep(2)
    }, error = function(e) {
      cat(sprintf("  Warning: could not init session for %s: %s\n",
                  domain, e$message))
    })
  }

  Sys.sleep(runif(1, REQUEST_DELAY[1], REQUEST_DELAY[2]))
  for (attempt in seq_len(MAX_RETRIES)) {
    tryCatch({
      resp <- GET(
        url,
        handle = .poroshenko_handles[[base_url]],
        user_agent(USER_AGENT),
        add_headers(
          Accept          = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
          `Accept-Language`= "uk-UA,uk;q=0.9,en-US;q=0.8,en;q=0.7"
        ),
        timeout(REQUEST_TIMEOUT)
      )
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

# ── Main fetch function ─────────────────────────────────

#' Fetch full article texts from a CSV of URLs
#'
#' @param csv_path  Path to CSV with columns: url, title
#' @param source    Source label (e.g. "risu.ua", "ppu.gov.ua")
#' @param resume    Skip already-fetched documents
#' @return A tibble of fetched articles
fetch_poroshenko_articles <- function(csv_path, source = "risu.ua",
                                      resume = TRUE) {
  if (!requireNamespace("digest", quietly = TRUE)) install.packages("digest")
  dir.create(CORPUS_DIR, recursive = TRUE, showWarnings = FALSE)

  links <- read.csv(csv_path, stringsAsFactors = FALSE)
  cat(sprintf("\n%s\nFetching %d articles from %s\n%s\n",
              strrep("=", 60), nrow(links), source, strrep("=", 60)))

  parser <- switch(source,
    "risu.ua"    = parse_risu_article,
    "ppu.gov.ua" = parse_ppu_article,
    parse_generic_article
  )

  all_docs <- list()
  for (i in seq_len(nrow(links))) {
    url   <- links$url[i]
    title <- links$title[i]
    did   <- doc_id(url)
    doc_path <- file.path(CORPUS_DIR, paste0(did, ".json"))

    if (resume && file.exists(doc_path)) {
      cat(sprintf("  [%d/%d] [skip] %s\n", i, nrow(links),
                  substr(title, 1, 60)))
      all_docs[[length(all_docs) + 1]] <- fromJSON(doc_path)
      next
    }

    cat(sprintf("  [%d/%d] Fetching: %s...\n", i, nrow(links),
                substr(title, 1, 60)))
    html <- fetch_article(url)
    if (is.null(html)) {
      cat("    Failed to fetch.\n")
      next
    }

    article <- parser(html)
    body <- article$body_text

    doc <- list(
      id           = did,
      url          = url,
      title        = if (article$title != "") article$title else title,
      date         = article$date,
      content_type = "poroshenko_speech",
      source       = source,
      speaker      = "Poroshenko",
      body_text    = body,
      word_count   = length(strsplit(body, "\\s+")[[1]]),
      scraped_at   = format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
    )

    write_json(doc, doc_path, auto_unbox = TRUE, pretty = TRUE)
    all_docs[[length(all_docs) + 1]] <- doc
    cat(sprintf("    Saved: %s.json (%d words)\n", did, doc$word_count))
  }

  cat(sprintf("\n%s\nTotal articles fetched: %d\n%s\n",
              strrep("=", 60), length(all_docs), strrep("=", 60)))

  if (length(all_docs) == 0) return(tibble())
  bind_rows(lapply(all_docs, as_tibble))
}

#' Fetch from all available Poroshenko CSV files
#'
#' Looks for poroshenko_*.csv files in data/ and processes each.
#'
#' @param resume Skip already-fetched documents
#' @return A tibble of all fetched articles
fetch_poroshenko_all <- function(resume = TRUE) {
  csv_files <- list.files("data", pattern = "^poroshenko_.*\\.csv$",
                          full.names = TRUE)
  if (length(csv_files) == 0) {
    cat("No poroshenko_*.csv files found in data/\n")
    cat("See instructions in this file for how to create them.\n")
    return(tibble())
  }

  all_docs <- list()
  for (csv_path in csv_files) {
    source_name <- str_match(basename(csv_path),
                             "poroshenko_(.+)_links\\.csv")[1, 2]
    if (is.na(source_name)) source_name <- "unknown"
    source_domain <- paste0(source_name, if (!grepl("\\.", source_name)) ".ua")

    cat(sprintf("\nProcessing: %s (source: %s)\n", csv_path, source_domain))
    docs <- fetch_poroshenko_articles(csv_path, source = source_domain,
                                      resume = resume)
    all_docs[[length(all_docs) + 1]] <- docs
  }

  result <- bind_rows(all_docs)

  if (nrow(result) > 0) {
    index_path <- file.path(OUTPUT_DIR, "poroshenko_index.json")
    index_data <- result %>% select(-body_text)
    write_json(index_data, index_path, auto_unbox = TRUE, pretty = TRUE)
    cat(sprintf("\nPoroshenko index saved: %s (%d documents)\n",
                index_path, nrow(result)))
  }

  result
}
