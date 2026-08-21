# ──────────────────────────────────────────────────────────
# 04_sample.R — Claim sampling and manual verification tools
#
# Usage:
#   source("01_config.R")
#   source("04_sample.R")
#
#   # Browse claims interactively
#   sample_claims(category = "ontological_security", n = 10, random = TRUE)
#   sample_claims(term = "духовний", n = 5)
#   sample_claims(doc_id = "abc123def456")
#
#   # View full document text
#   verify_document("abc123def456")
#
#   # Export stratified sample for manual coding
#   export_coding_sample(n_per_category = 15, seed = 42)
#
#   # After manual coding, compute inter-rater agreement
#   check_coding_agreement("output/coding_sample_coded.csv")
# ──────────────────────────────────────────────────────────

library(jsonlite)
library(dplyr)

# ── Load claims from disk ────────────────────────────────
load_claims <- function(claims_file = file.path(OUTPUT_DIR, "claims.json")) {
  if (!file.exists(claims_file)) {
    stop(sprintf("Claims file not found: %s\nRun the analysis first.", claims_file))
  }
  fromJSON(claims_file, simplifyDataFrame = FALSE)
}

# ── Sample and display claims ────────────────────────────
sample_claims <- function(category = NULL, term = NULL, doc_id = NULL,
                          juncture = NULL, n = 5, random = FALSE,
                          claims_file = file.path(OUTPUT_DIR, "claims.json")) {
  claims <- load_claims(claims_file)
  cat(sprintf("Loaded %d claims total\n\n", length(claims)))

  if (!is.null(category)) {
    claims <- Filter(function(c) c$category == category, claims)
    cat(sprintf("Filtered to category '%s': %d claims\n", category, length(claims)))
  }

  if (!is.null(term)) {
    term_lower <- tolower(term)
    claims <- Filter(function(c) {
      grepl(term_lower, tolower(c$matched_term_lemma), fixed = TRUE) ||
      grepl(term_lower, tolower(c$matched_surface_form), fixed = TRUE)
    }, claims)
    cat(sprintf("Filtered to term containing '%s': %d claims\n", term, length(claims)))
  }

  if (!is.null(doc_id)) {
    claims <- Filter(function(c) c$doc_id == doc_id, claims)
    cat(sprintf("Filtered to document '%s': %d claims\n", doc_id, length(claims)))
  }

  if (!is.null(juncture)) {
    if (!juncture %in% names(JUNCTURES)) {
      cat(sprintf("Unknown juncture '%s'. Available:\n", juncture))
      for (j in names(JUNCTURES)) cat(sprintf("  %s: %s to %s\n", j, JUNCTURES[[j]][1], JUNCTURES[[j]][2]))
      return(invisible(NULL))
    }
    jrange <- JUNCTURES[[juncture]]
    claims <- Filter(function(c) {
      d <- c$doc_date
      !is.null(d) && !is.na(d) && d >= jrange[1] && d <= jrange[2]
    }, claims)
    cat(sprintf("Filtered to juncture '%s': %d claims\n", juncture, length(claims)))
  }

  if (length(claims) == 0) {
    cat("\nNo claims match the filter criteria.\n")
    all_claims <- load_claims(claims_file)
    cats <- table(sapply(all_claims, function(c) c$category))
    cat("\nAvailable categories:\n")
    for (i in seq_along(cats)) {
      cat(sprintf("  %s: %d claims\n", names(cats)[i], cats[i]))
    }
    return(invisible(NULL))
  }

  if (random) {
    idx <- sample(seq_along(claims), min(n, length(claims)))
    sample_claims_list <- claims[idx]
  } else {
    sample_claims_list <- claims[seq_len(min(n, length(claims)))]
  }

  cat(sprintf("\nShowing %d of %d matching claims:\n", length(sample_claims_list), length(claims)))
  cat(strrep("=", 70), "\n")

  for (claim in sample_claims_list) {
    cat(sprintf("\n--- Claim #%s ---\n", claim$claim_id))
    cat(sprintf("Document:  %s\n", claim$doc_title))
    cat(sprintf("Date:      %s\n", claim$doc_date))
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

# ── List categories ──────────────────────────────────────
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

# ── Export stratified sample for manual coding ───────────
# Draws n_per_category random claims from each category,
# plus n_per_juncture from each juncture (if specified),
# and exports a CSV with columns for manual annotation.
export_coding_sample <- function(n_per_category = 15,
                                  n_per_juncture = NULL,
                                  seed = 42,
                                  output_file = file.path(OUTPUT_DIR, "coding_sample.csv"),
                                  claims_file = file.path(OUTPUT_DIR, "claims.json")) {
  set.seed(seed)
  claims <- load_claims(claims_file)
  cat(sprintf("Total claims: %d\n", length(claims)))

  # Convert to data frame for easier manipulation
  claims_df <- bind_rows(lapply(claims, function(c) {
    tibble(
      claim_id     = c$claim_id,
      doc_id       = c$doc_id,
      doc_title    = c$doc_title,
      doc_date     = if (is.null(c$doc_date) || is.na(c$doc_date)) NA_character_ else c$doc_date,
      doc_url      = c$doc_url,
      category     = c$category,
      matched_term = c$matched_term_lemma,
      surface_form = c$matched_surface_form,
      sentence     = c$sentence,
      context_before = if (is.null(c$context_before)) "" else c$context_before,
      context_after  = if (is.null(c$context_after)) "" else c$context_after
    )
  }))

  # Stratified sample by category
  sampled <- claims_df %>%
    group_by(category) %>%
    slice_sample(n = min(n_per_category, n())) %>%
    ungroup()

  # Add juncture samples if requested
  if (!is.null(n_per_juncture) && n_per_juncture > 0) {
    for (jname in names(JUNCTURES)) {
      jrange <- JUNCTURES[[jname]]
      j_claims <- claims_df %>%
        filter(!is.na(doc_date), doc_date >= jrange[1], doc_date <= jrange[2]) %>%
        filter(!(claim_id %in% sampled$claim_id))
      if (nrow(j_claims) > 0) {
        j_sample <- j_claims %>% slice_sample(n = min(n_per_juncture, nrow(j_claims)))
        sampled <- bind_rows(sampled, j_sample)
      }
    }
    sampled <- distinct(sampled, claim_id, .keep_all = TRUE)
  }

  # Add manual coding columns (empty, to be filled by the coder)
  sampled <- sampled %>%
    mutate(
      # Is the automated category assignment correct? (TRUE/FALSE)
      category_correct   = NA,
      # Does this sentence genuinely constitute a securitising move? (TRUE/FALSE)
      is_securitising     = NA,
      # What type of securitisation? (material / ontological / both / neither)
      securitisation_type = NA_character_,
      # Who is the referent object? (state / nation / identity / faith / other)
      referent_object     = NA_character_,
      # Who is the threat actor? (UOC-MP / Russia / internal / other / none)
      threat_actor        = NA_character_,
      # What extraordinary measure is proposed/implied? (ban / sanction / dissolution / none / other)
      extraordinary_measure = NA_character_,
      # Coder confidence (1=low, 2=medium, 3=high)
      confidence          = NA_integer_,
      # Free-text notes
      coder_notes         = NA_character_
    )

  write.csv(sampled, output_file, row.names = FALSE, fileEncoding = "UTF-8")
  cat(sprintf("\nExported %d claims to: %s\n", nrow(sampled), output_file))
  cat(sprintf("  By category:\n"))
  for (cat_name in sort(unique(sampled$category))) {
    cat(sprintf("    %-25s %d\n", cat_name, sum(sampled$category == cat_name)))
  }
  cat(sprintf("\nInstructions:\n"))
  cat("  1. Open the CSV in Excel or Google Sheets\n")
  cat("  2. Fill in the coding columns (category_correct through coder_notes)\n")
  cat("  3. Save as coding_sample_coded.csv\n")
  cat("  4. Run: check_coding_agreement('output/coding_sample_coded.csv')\n")

  invisible(sampled)
}

# ── Check inter-rater / self-consistency ─────────────────
check_coding_agreement <- function(coded_file) {
  if (!file.exists(coded_file)) {
    stop(sprintf("File not found: %s", coded_file))
  }

  coded <- read.csv(coded_file, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  total <- nrow(coded)
  coded_rows <- coded %>% filter(!is.na(category_correct))

  cat(strrep("=", 60), "\n")
  cat("CODING VERIFICATION REPORT\n")
  cat(strrep("=", 60), "\n\n")

  cat(sprintf("Total claims in sample: %d\n", total))
  cat(sprintf("Claims coded:           %d\n", nrow(coded_rows)))

  if (nrow(coded_rows) == 0) {
    cat("\nNo coded claims found. Fill in the coding columns first.\n")
    return(invisible(NULL))
  }

  # Category accuracy
  correct <- sum(coded_rows$category_correct == TRUE, na.rm = TRUE)
  cat(sprintf("\nCategory accuracy: %d/%d (%.1f%%)\n",
              correct, nrow(coded_rows), 100 * correct / nrow(coded_rows)))

  # Securitisation rate
  securitising <- sum(coded_rows$is_securitising == TRUE, na.rm = TRUE)
  cat(sprintf("Genuine securitising moves: %d/%d (%.1f%%)\n",
              securitising, nrow(coded_rows), 100 * securitising / nrow(coded_rows)))

  # Breakdown by category
  cat("\nPer-category accuracy:\n")
  by_cat <- coded_rows %>%
    group_by(category) %>%
    summarise(
      n = n(),
      correct = sum(category_correct == TRUE, na.rm = TRUE),
      securitising = sum(is_securitising == TRUE, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      accuracy = sprintf("%.0f%%", 100 * correct / n),
      sec_rate = sprintf("%.0f%%", 100 * securitising / n)
    )
  for (i in seq_len(nrow(by_cat))) {
    r <- by_cat[i, ]
    cat(sprintf("  %-25s n=%d  accuracy=%s  securitising=%s\n",
                r$category, r$n, r$accuracy, r$sec_rate))
  }

  # Confidence distribution
  if (any(!is.na(coded_rows$confidence))) {
    cat("\nCoder confidence distribution:\n")
    conf <- table(coded_rows$confidence, useNA = "ifany")
    for (i in seq_along(conf)) {
      cat(sprintf("  Level %s: %d\n", names(conf)[i], conf[i]))
    }
  }

  # False positive analysis
  false_pos <- coded_rows %>% filter(category_correct == FALSE | is_securitising == FALSE)
  if (nrow(false_pos) > 0) {
    cat(sprintf("\nFalse positives / misclassifications: %d\n", nrow(false_pos)))
    fp_terms <- table(false_pos$matched_term)
    fp_terms <- sort(fp_terms, decreasing = TRUE)
    cat("  Most common false-positive terms:\n")
    for (i in seq_len(min(10, length(fp_terms)))) {
      cat(sprintf("    %-30s %d\n", names(fp_terms)[i], fp_terms[i]))
    }
  }

  cat("\n", strrep("=", 60), "\n")
  invisible(coded_rows)
}
