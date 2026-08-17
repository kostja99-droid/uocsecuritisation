# ──────────────────────────────────────────────────────────
# run_all.R — One-command entry point: scrape + analyse
#
# Usage:
#   In RStudio, just click "Source" on this file — it will
#   automatically set the working directory to its own folder.
#
#   Or from the command line:
#     Rscript path/to/run_all.R
#
# After running, use the sampling tools interactively:
#   source("04_sample.R")
#   sample_claims(category = "ontological_security", n = 10, random = TRUE)
#   verify_document("<doc_id>")
# ──────────────────────────────────────────────────────────

# Auto-detect script location and set working directory
this_dir <- tryCatch(
  dirname(rstudioapi::getSourceEditorContext()$path),
  error = function(e) {
    args <- commandArgs(trailingOnly = FALSE)
    file_arg <- grep("^--file=", args, value = TRUE)
    if (length(file_arg) > 0) {
      return(dirname(normalizePath(sub("^--file=", "", file_arg[1]))))
    }
    if (sys.nframe() > 0) {
      frame <- sys.frame(1)
      if (exists("ofile", envir = frame)) {
        return(dirname(normalizePath(get("ofile", envir = frame))))
      }
    }
    return(getwd())
  }
)
if (nzchar(this_dir) && dir.exists(this_dir)) {
  setwd(this_dir)
  cat(sprintf("Working directory set to: %s\n\n", this_dir))
}

cat("========================================\n")
cat("Ukrainian Presidential Speech Scraper\n")
cat("& Securitisation Discourse Analyser\n")
cat("========================================\n\n")

# Load configuration
source("01_config.R")
cat("Configuration loaded.\n")

# Step 1: Scrape
# If the regular scraper gets HTTP 403 errors, switch to browser mode:
#   source("02_scrape_browser.R")  # instead of 02_scrape.R
source("02_scrape.R")
cat("\n--- STEP 1: SCRAPING ---\n")
docs <- scrape_all(DATE_START, DATE_END)
cat(sprintf("Scraping complete: %d documents\n", nrow(docs)))

# Step 2: Analyse
source("03_analyse.R")
cat("\n--- STEP 2: ANALYSIS ---\n")
output <- analyse_corpus()

cat("\n\nDone! Output files are in the 'output/' directory.\n")
cat("\nNext steps (run interactively in R/RStudio):\n")
cat("  source('01_config.R')\n")
cat("  source('04_sample.R')\n")
cat("  sample_claims(category = 'ontological_security', n = 10, random = TRUE)\n")
cat("  sample_claims(term = 'духовний', n = 5)\n")
cat("  verify_document('<doc_id>')\n")
cat("  list_categories()\n")
