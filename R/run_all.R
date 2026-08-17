# ──────────────────────────────────────────────────────────
# run_all.R — One-command entry point: scrape + analyse
#
# Usage (from the project root):
#   Rscript R/run_all.R
#
# Or interactively in RStudio:
#   source("R/run_all.R")
#
# After running, use the sampling tools interactively:
#   source("R/01_config.R")
#   source("R/04_sample.R")
#   sample_claims(category = "ontological_security", n = 10, random = TRUE)
#   verify_document("abc123def456")
# ──────────────────────────────────────────────────────────

cat("========================================\n")
cat("Ukrainian Presidential Speech Scraper\n")
cat("& Securitisation Discourse Analyser\n")
cat("========================================\n\n")

# Set working directory to project root if run via Rscript
if (!interactive()) {
  script_dir <- dirname(sys.frame(1)$ofile)
  setwd(file.path(script_dir, ".."))
}

# Load configuration
source("R/01_config.R")
cat("Configuration loaded.\n")

# Step 1: Scrape
source("R/02_scrape.R")
cat("\n--- STEP 1: SCRAPING ---\n")
docs <- scrape_all(DATE_START, DATE_END)
cat(sprintf("Scraping complete: %d documents\n", nrow(docs)))

# Step 2: Analyse
source("R/03_analyse.R")
cat("\n--- STEP 2: ANALYSIS ---\n")
output <- analyse_corpus()

cat("\n\nDone! Output files are in the 'output/' directory.\n")
cat("\nNext steps (run interactively in R/RStudio):\n")
cat("  source('R/01_config.R')\n")
cat("  source('R/04_sample.R')\n")
cat("  sample_claims(category = 'ontological_security', n = 10, random = TRUE)\n")
cat("  sample_claims(term = 'духовний', n = 5)\n")
cat("  verify_document('<doc_id>')\n")
cat("  list_categories()\n")
