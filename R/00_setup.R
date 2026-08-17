# ──────────────────────────────────────────────────────────
# 00_setup.R — Install dependencies and download udpipe model
# Run this once before using the other scripts.
# ──────────────────────────────────────────────────────────

required_packages <- c(
  "rvest",       # web scraping
  "httr",        # HTTP requests
  "jsonlite",    # JSON I/O
  "udpipe",      # NLP: tokenisation, lemmatisation, POS tagging (Ukrainian)
  "stringr",     # string manipulation
  "stringi",     # Unicode-aware string ops
  "dplyr",       # data wrangling
  "tidyr",       # reshaping
  "purrr",       # functional programming
  "readr",       # file I/O
  "digest"       # hashing for document IDs
)

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
}

# Download Ukrainian udpipe model (≈50 MB, one-time download)
library(udpipe)
model_dir <- file.path("models")
dir.create(model_dir, showWarnings = FALSE, recursive = TRUE)
model_path <- file.path(model_dir, "ukrainian-iu-ud-2.5-191206.udpipe")

if (!file.exists(model_path)) {
  cat("Downloading Ukrainian udpipe model...\n")
  udpipe_download_model(
    language  = "ukrainian",
    model_dir = model_dir
  )
  cat("Model downloaded.\n")
} else {
  cat("Ukrainian udpipe model already present.\n")
}

# Optional: install chromote for browser-based scraping
# (needed only if president.gov.ua blocks regular HTTP requests)
if (!requireNamespace("chromote", quietly = TRUE)) {
  cat("\nNote: 'chromote' is not installed. If the regular scraper\n")
  cat("gets HTTP 403 errors, install it for browser-based scraping:\n")
  cat("  install.packages('chromote')\n")
  cat("Then use 02_scrape_browser.R instead of 02_scrape.R\n\n")
}

cat("\nSetup complete. You can now run the other scripts.\n")
