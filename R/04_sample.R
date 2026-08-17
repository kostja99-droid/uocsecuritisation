# ──────────────────────────────────────────────────────────
# 04_sample.R — Claim sampling and document verification
#
# Usage:
#   source("R/01_config.R")
#   source("R/04_sample.R")
#
#   # Sample 10 random ontological security claims
#   sample_claims(category = "ontological_security", n = 10, random = TRUE)
#
#   # Sample claims matching a specific term
#   sample_claims(term = "духовний", n = 5)
#
#   # Show all claims from a specific document
#   sample_claims(doc_id = "abc123def456")
#
#   # View full text of a document
#   verify_document("abc123def456")
# ──────────────────────────────────────────────────────────

library(jsonlite)

# ── Load claims from disk ────────────────────────────────
load_claims <- function(claims_file = file.path(OUTPUT_DIR, "claims.json")) {
  if (!file.exists(claims_file)) {
    stop(sprintf("Claims file not found: %s\nRun the analysis first.", claims_file))
  }
  fromJSON(claims_file, simplifyDataFrame = FALSE)
}

# ── Sample and display claims ────────────────────────────
sample_claims <- function(category = NULL, term = NULL, doc_id = NULL,
                          n = 5, random = FALSE,
                          claims_file = file.path(OUTPUT_DIR, "claims.json")) {
  claims <- load_claims(claims_file)
  cat(sprintf("Loaded %d claims total\n\n", length(claims)))

  # Filter by category
  if (!is.null(category)) {
    claims <- Filter(function(c) c$category == category, claims)
    cat(sprintf("Filtered to category '%s': %d claims\n", category, length(claims)))
  }

  # Filter by term (substring match on lemma or surface form)
  if (!is.null(term)) {
    term_lower <- tolower(term)
    claims <- Filter(function(c) {
      grepl(term_lower, tolower(c$matched_term_lemma), fixed = TRUE) ||
      grepl(term_lower, tolower(c$matched_surface_form), fixed = TRUE)
    }, claims)
    cat(sprintf("Filtered to term containing '%s': %d claims\n", term, length(claims)))
  }

  # Filter by document
  if (!is.null(doc_id)) {
    claims <- Filter(function(c) c$doc_id == doc_id, claims)
    cat(sprintf("Filtered to document '%s': %d claims\n", doc_id, length(claims)))
  }

  if (length(claims) == 0) {
    cat("\nNo claims match the filter criteria.\n")
    # Show available categories
    all_claims <- load_claims(claims_file)
    cats <- table(sapply(all_claims, function(c) c$category))
    cat("\nAvailable categories:\n")
    for (i in seq_along(cats)) {
      cat(sprintf("  %s: %d claims\n", names(cats)[i], cats[i]))
    }
    return(invisible(NULL))
  }

  # Sample
  if (random) {
    idx <- sample(seq_along(claims), min(n, length(claims)))
    sample_claims_list <- claims[idx]
  } else {
    sample_claims_list <- claims[seq_len(min(n, length(claims)))]
  }

  # Display
  cat(sprintf("\nShowing %d of %d matching claims:\n",
              length(sample_claims_list), length(claims)))
  cat(strrep("=", 70), "\n")

  for (claim in sample_claims_list) {
    cat(sprintf("\n--- Claim #%s ---\n", claim$claim_id))
    cat(sprintf("Document:  %s\n", claim$doc_title))
    cat(sprintf("Date:      %s\n", claim$doc_date))
    cat(sprintf("Type:      %s\n", claim$content_type))
    cat(sprintf("URL:       %s\n", claim$doc_url))
    cat(sprintf("Category:  %s\n", claim$category))
    cat(sprintf("Term:      %s (%s)\n", claim$matched_term_lemma, claim$matched_term_lang))
    cat(sprintf("Surface:   \"%s\"\n\n", claim$matched_surface_form))

    if (!is.null(claim$context_before) && nchar(claim$context_before) > 0) {
      cat(sprintf("  [prev] %s\n", substr(claim$context_before, 1, 200)))
    }
    cat(sprintf("  >>> %s\n", claim$sentence))
    if (!is.null(claim$context_after) && nchar(claim$context_after) > 0) {
      cat(sprintf("  [next] %s\n", substr(claim$context_after, 1, 200)))
    }
    cat("\n")
  }

  cat(strrep("=", 70), "\n")
  if (length(sample_claims_list) > 0) {
    cat(sprintf("\nTo view full document text, run:\n  verify_document(\"%s\")\n",
                sample_claims_list[[1]]$doc_id))
  }

  invisible(sample_claims_list)
}

# ── View full document text ──────────────────────────────
verify_document <- function(doc_id, corpus_dir = CORPUS_DIR) {
  doc_path <- file.path(corpus_dir, paste0(doc_id, ".json"))

  if (!file.exists(doc_path)) {
    cat(sprintf("Document not found: %s\n", doc_path))
    cat("\nAvailable documents:\n")
    files <- list.files(corpus_dir, pattern = "\\.json$", full.names = TRUE)
    for (f in head(files, 20)) {
      d <- tryCatch(fromJSON(f), error = function(e) NULL)
      if (!is.null(d)) {
        cat(sprintf("  %-14s %-12s %s\n",
                    tools::file_path_sans_ext(basename(f)),
                    if (is.null(d$date)) "?" else d$date,
                    substr(if (is.null(d$title)) "?" else d$title, 1, 55)))
      }
    }
    return(invisible(NULL))
  }

  doc <- fromJSON(doc_path)

  cat(strrep("=", 70), "\n")
  cat(sprintf("DOCUMENT: %s\n", doc$title))
  cat(sprintf("Date:     %s\n", doc$date))
  cat(sprintf("Type:     %s\n", doc$content_type))
  cat(sprintf("URL:      %s\n", doc$url))
  cat(sprintf("Words:    %s\n", doc$word_count))
  cat(sprintf("Doc ID:   %s\n", doc$id))
  cat(strrep("=", 70), "\n\n")
  cat(doc$body_text)
  cat("\n\n")
  cat(strrep("=", 70), "\n")

  invisible(doc)
}

# ── List all available categories and term counts ────────
list_categories <- function(claims_file = file.path(OUTPUT_DIR, "claims.json")) {
  claims <- load_claims(claims_file)
  cats <- table(sapply(claims, function(c) c$category))
  cat("Available categories:\n")
  for (i in seq_along(cats)) {
    desc <- SEED_TERMS[[names(cats)[i]]]$description
    if (is.null(desc)) desc <- names(cats)[i]
    cat(sprintf("  %-20s (%s): %d claims\n", names(cats)[i], desc, cats[i]))
  }
  invisible(cats)
}
