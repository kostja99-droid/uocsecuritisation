# ──────────────────────────────────────────────────────────
# 02_diagnose_rada.R — Identify broken Rada corpus files
#
# Scans Rada stenogram files in the corpus and identifies
# those with boilerplate/navigation content instead of actual
# stenogram text. Generates the URL list for browser re-fetch.
#
# Usage:
#   source("R/01_config.R")
#   source("R/02_diagnose_rada.R")
#   diagnose_rada()              # prints report
#   generate_rada_urls()         # writes JS URL array to console
# ──────────────────────────────────────────────────────────

library(jsonlite)
library(stringr)

if (!exists("CORPUS_DIR")) source(file.path("R", "01_config.R"))

BOILERPLATE_MARKERS <- c(
  "Головна сторінка",
  "Календар пленарних",
  "Порядок денний",
  "Прес-служба",
  "Контакти",
  "Карта сайту",
  "Верховна Рада України\\s*\\n\\s*Головна",
  "Реєстр законопроект",
  "Пошук по сайту"
)

is_boilerplate <- function(body_text) {
  if (is.null(body_text) || is.na(body_text)) return(TRUE)
  body <- as.character(body_text)
  if (nchar(body) < 200) return(TRUE)

  marker_count <- 0
  for (pat in BOILERPLATE_MARKERS) {
    if (grepl(pat, body, ignore.case = TRUE)) marker_count <- marker_count + 1
  }
  if (marker_count >= 3) return(TRUE)

  stenogram_markers <- c(
    "ГОЛОВУЮЧИЙ", "головуючий",
    "ЗАСІДАННЯ", "засідання",
    "Шановні народні депутати",
    "Слово має", "Слово надається",
    "Хто за\\?", "Прошу голосувати",
    "Результат поіменного голосування",
    "Дякую", "дякую"
  )
  steno_count <- 0
  for (pat in stenogram_markers) {
    if (grepl(pat, body, fixed = TRUE)) steno_count <- steno_count + 1
  }
  if (steno_count == 0 && nchar(body) < 2000) return(TRUE)

  return(FALSE)
}

diagnose_rada <- function(corpus_dir = CORPUS_DIR) {
  files <- list.files(corpus_dir, pattern = "\\.json$", full.names = TRUE)

  rada_files <- c()
  for (f in files) {
    d <- tryCatch(fromJSON(f), error = function(e) NULL)
    if (!is.null(d) && !is.null(d$source) && d$source == "rada.gov.ua") {
      rada_files <- c(rada_files, f)
    }
  }

  cat(sprintf("Found %d Rada corpus files\n\n", length(rada_files)))

  good <- list()
  broken <- list()

  for (f in rada_files) {
    d <- fromJSON(f)
    body <- if (!is.null(d$body_text)) d$body_text else ""
    title <- if (!is.null(d$title)) d$title else ""
    url <- if (!is.null(d$url)) d$url else ""
    wc <- if (!is.null(d$word_count)) d$word_count else 0

    if (is_boilerplate(body)) {
      broken[[length(broken) + 1]] <- list(
        file = basename(f), url = url,
        title = substr(title, 1, 60),
        word_count = wc,
        body_preview = substr(body, 1, 100)
      )
    } else {
      good[[length(good) + 1]] <- list(
        file = basename(f), url = url,
        title = substr(title, 1, 60),
        word_count = wc
      )
    }
  }

  cat(sprintf("%s\nRADA CORPUS DIAGNOSIS\n%s\n", strrep("=", 50), strrep("=", 50)))
  cat(sprintf("Total Rada files:            %d\n", length(rada_files)))
  cat(sprintf("Good (actual stenogram):     %d\n", length(good)))
  cat(sprintf("Broken (boilerplate/empty):  %d\n", length(broken)))

  if (length(broken) > 0) {
    cat(sprintf("\n%s\nBROKEN FILES (need browser re-fetch)\n%s\n",
                strrep("-", 50), strrep("-", 50)))
    for (item in broken[1:min(10, length(broken))]) {
      cat(sprintf("  %s  (%d words)\n    %s\n    Preview: %s\n\n",
                  item$file, item$word_count, item$url,
                  gsub("\\s+", " ", item$body_preview)))
    }
    if (length(broken) > 10) {
      cat(sprintf("  ... and %d more broken files\n", length(broken) - 10))
    }
  }

  cat("\nNext steps:\n")
  cat("  1. Run generate_rada_urls() to get the URL list for browser re-fetch\n")
  cat("  2. Paste the output into data/rada_fetch_console.js\n")
  cat("  3. Open rada.gov.ua in Chrome, F12 -> Console, run the script\n")
  cat("  4. Import with: import_rada_articles('data/rada_articles.json')\n\n")

  invisible(list(good = good, broken = broken))
}

generate_rada_urls <- function(corpus_dir = CORPUS_DIR, only_broken = TRUE) {
  files <- list.files(corpus_dir, pattern = "\\.json$", full.names = TRUE)
  urls <- c()

  for (f in files) {
    d <- tryCatch(fromJSON(f), error = function(e) NULL)
    if (is.null(d) || is.null(d$source) || d$source != "rada.gov.ua") next
    if (is.null(d$url)) next

    if (only_broken) {
      body <- if (!is.null(d$body_text)) d$body_text else ""
      if (!is_boilerplate(body)) next
    }

    urls <- c(urls, d$url)
  }

  cat(sprintf("// %d Rada URLs to re-fetch%s\n",
              length(urls),
              if (only_broken) " (broken files only)" else " (all)"))
  cat("const urls = [\n")
  for (i in seq_along(urls)) {
    comma <- if (i < length(urls)) "," else ""
    cat(sprintf('  "%s"%s\n', urls[i], comma))
  }
  cat("];\n")

  invisible(urls)
}
