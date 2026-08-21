# ──────────────────────────────────────────────────────────
# 05_coding_analysis.R — Securitisation coding analysis
#
# Implements the coding scheme from the codebook: scores each
# claim for securitisation intensity, aggregates by juncture,
# category, and co-occurrence, and exports thesis-ready tables.
#
# Usage:
#   source("01_config.R")
#   source("05_coding_analysis.R")
#
#   # Run full analysis (requires claims.json from 03_analyse.R)
#   coding <- run_coding_analysis()
#
#   # Or step by step:
#   claims   <- load_and_prepare_claims()
#   scored   <- score_securitisation(claims)
#   tables   <- build_thesis_tables(scored)
#   export_all(scored, tables)
# ──────────────────────────────────────────────────────────

library(jsonlite)
library(dplyr)
library(tidyr)
library(stringr)

# ── Load and flatten claims into a data frame ────────────
load_and_prepare_claims <- function(claims_file = file.path(OUTPUT_DIR, "claims.json")) {
  if (!file.exists(claims_file)) {
    stop(sprintf("Claims file not found: %s\nRun 03_analyse.R first.", claims_file))
  }
  raw <- fromJSON(claims_file, simplifyDataFrame = FALSE)
  cat(sprintf("Loaded %d raw claims\n", length(raw)))

  df <- bind_rows(lapply(raw, function(c) {
    tibble(
      claim_id       = as.integer(c$claim_id),
      doc_id         = c$doc_id,
      doc_title      = if (is.null(c$doc_title)) NA_character_ else c$doc_title,
      doc_date       = if (is.null(c$doc_date) || is.na(c$doc_date)) NA_character_ else c$doc_date,
      doc_url        = c$doc_url,
      category       = c$category,
      matched_term   = c$matched_term_lemma,
      term_lang      = c$matched_term_lang,
      surface_form   = c$matched_surface_form,
      sentence       = c$sentence,
      sentence_index = as.integer(c$sentence_index),
      context_before = if (is.null(c$context_before)) "" else c$context_before,
      context_after  = if (is.null(c$context_after)) "" else c$context_after
    )
  }))

  # Assign juncture
  df$juncture <- NA_character_
  for (jname in names(JUNCTURES)) {
    jrange <- JUNCTURES[[jname]]
    mask <- !is.na(df$doc_date) & df$doc_date >= jrange[1] & df$doc_date <= jrange[2]
    df$juncture[mask] <- jname
  }

  # Year column
  df$year <- ifelse(!is.na(df$doc_date) & nchar(df$doc_date) >= 4,
                    substr(df$doc_date, 1, 4), NA_character_)

  cat(sprintf("Prepared %d claims across %d documents\n",
              nrow(df), n_distinct(df$doc_id)))
  df
}

# ── Score each document for securitisation intensity ─────
# The score reflects how many coding dimensions co-occur in
# a single document, weighted by the codebook's logic:
#   - church_actors alone = 0 (necessary but not sufficient)
#   - +1 per additional category present (material, ontological,
#     decolonisation, urgency)
#   - Bonus +1 if both material AND ontological are present
#   - Score range: 0 (church only) to 5 (all dimensions)
score_securitisation <- function(claims_df) {
  doc_cats <- claims_df %>%
    group_by(doc_id) %>%
    summarise(
      categories = list(unique(category)),
      n_categories = n_distinct(category),
      n_claims = n(),
      .groups = "drop"
    )

  doc_cats <- doc_cats %>%
    rowwise() %>%
    mutate(
      has_church       = "church_actors" %in% categories,
      has_material     = "material_security" %in% categories,
      has_ontological  = "ontological_security" %in% categories,
      has_decolonise   = "decolonisation" %in% categories,
      has_urgency      = "urgency" %in% categories,
      sec_score = {
        if (!has_church) 0L
        else {
          base <- sum(c(has_material, has_ontological, has_decolonise, has_urgency))
          bonus <- if (has_material && has_ontological) 1L else 0L
          base + bonus
        }
      },
      is_securitising = has_church & (has_material | has_ontological |
                                       has_decolonise | has_urgency)
    ) %>%
    ungroup() %>%
    select(-categories)

  # Merge scores back onto claims
  claims_scored <- claims_df %>%
    left_join(doc_cats, by = "doc_id")

  cat(sprintf("Scored %d documents: %d securitising (score >= 1)\n",
              nrow(doc_cats), sum(doc_cats$is_securitising)))
  claims_scored
}

# ── Co-occurrence matrix ─────────────────────────────────
# How often do pairs of categories appear in the same document?
build_cooccurrence <- function(claims_df) {
  cat_names <- c("church_actors", "material_security",
                 "ontological_security", "decolonisation", "urgency")

  doc_cats <- claims_df %>%
    distinct(doc_id, category) %>%
    mutate(present = 1L) %>%
    pivot_wider(names_from = category, values_from = present, values_fill = 0L)

  # Ensure all columns exist
  for (cn in cat_names) {
    if (!cn %in% names(doc_cats)) doc_cats[[cn]] <- 0L
  }

  mat <- matrix(0L, nrow = length(cat_names), ncol = length(cat_names),
                dimnames = list(cat_names, cat_names))

  for (i in seq_along(cat_names)) {
    for (j in seq_along(cat_names)) {
      mat[i, j] <- sum(doc_cats[[cat_names[i]]] == 1L &
                        doc_cats[[cat_names[j]]] == 1L)
    }
  }
  as.data.frame(mat)
}

# ── Build thesis tables ──────────────────────────────────
build_thesis_tables <- function(scored_df) {
  tables <- list()

  # Table 1: Claims per category per juncture
  tables$claims_by_juncture <- scored_df %>%
    filter(!is.na(juncture)) %>%
    count(juncture, category, name = "n_claims") %>%
    pivot_wider(names_from = category, values_from = n_claims, values_fill = 0L) %>%
    arrange(factor(juncture, levels = names(JUNCTURES)))

  # Table 2: Securitisation intensity per juncture
  doc_level <- scored_df %>%
    distinct(doc_id, .keep_all = TRUE)

  tables$intensity_by_juncture <- doc_level %>%
    filter(!is.na(juncture)) %>%
    group_by(juncture) %>%
    summarise(
      n_documents       = n(),
      n_securitising    = sum(is_securitising, na.rm = TRUE),
      pct_securitising  = round(100 * n_securitising / n_documents, 1),
      mean_score        = round(mean(sec_score, na.rm = TRUE), 2),
      median_score      = median(sec_score, na.rm = TRUE),
      max_score         = max(sec_score, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(factor(juncture, levels = names(JUNCTURES)))

  # Table 3: Top terms per juncture
  tables$top_terms_by_juncture <- scored_df %>%
    filter(!is.na(juncture)) %>%
    count(juncture, matched_term, name = "freq") %>%
    group_by(juncture) %>%
    slice_max(freq, n = 10, with_ties = FALSE) %>%
    arrange(juncture, desc(freq)) %>%
    ungroup()

  # Table 4: Yearly trend
  tables$yearly_trend <- scored_df %>%
    filter(!is.na(year)) %>%
    group_by(year) %>%
    summarise(
      n_claims       = n(),
      n_documents    = n_distinct(doc_id),
      n_categories   = n_distinct(category),
      .groups = "drop"
    ) %>%
    arrange(year)

  # Table 5: Co-occurrence matrix
  tables$cooccurrence <- build_cooccurrence(scored_df)

  # Table 6: Category breakdown overall
  tables$category_summary <- scored_df %>%
    group_by(category) %>%
    summarise(
      n_claims     = n(),
      n_documents  = n_distinct(doc_id),
      n_unique_terms = n_distinct(matched_term),
      .groups = "drop"
    ) %>%
    arrange(desc(n_claims))

  # Table 7: Material vs ontological over time
  tables$material_vs_ontological <- scored_df %>%
    filter(category %in% c("material_security", "ontological_security"),
           !is.na(year)) %>%
    count(year, category, name = "n_claims") %>%
    pivot_wider(names_from = category, values_from = n_claims, values_fill = 0L) %>%
    arrange(year)

  cat(sprintf("Built %d thesis tables\n", length(tables)))
  tables
}

# ── Print analysis report ────────────────────────────────
print_coding_report <- function(scored_df, tables) {
  cat("\n", strrep("=", 70), "\n")
  cat("SECURITISATION CODING ANALYSIS REPORT\n")
  cat(strrep("=", 70), "\n")

  # Overview
  doc_level <- scored_df %>% distinct(doc_id, .keep_all = TRUE)
  cat(sprintf("\nTotal claims analysed:    %d\n", nrow(scored_df)))
  cat(sprintf("Total documents:          %d\n", nrow(doc_level)))
  cat(sprintf("Securitising documents:   %d (%.1f%%)\n",
              sum(doc_level$is_securitising, na.rm = TRUE),
              100 * mean(doc_level$is_securitising, na.rm = TRUE)))
  cat(sprintf("Mean intensity score:     %.2f (range 0-5)\n",
              mean(doc_level$sec_score, na.rm = TRUE)))

  # Category summary
  cat("\n--- Claims by Category ---\n")
  for (i in seq_len(nrow(tables$category_summary))) {
    r <- tables$category_summary[i, ]
    desc <- SEED_TERMS[[r$category]]$description
    if (is.null(desc)) desc <- r$category
    cat(sprintf("  %-45s %5d claims in %4d docs\n",
                desc, r$n_claims, r$n_documents))
  }

  # Juncture intensity
  cat("\n--- Securitisation Intensity by Juncture ---\n")
  cat(sprintf("  %-30s %5s %6s %6s %5s\n",
              "Juncture", "Docs", "Sec%", "Mean", "Max"))
  cat(sprintf("  %s\n", strrep("-", 55)))
  for (i in seq_len(nrow(tables$intensity_by_juncture))) {
    r <- tables$intensity_by_juncture[i, ]
    cat(sprintf("  %-30s %5d %5.1f%% %5.2f %5d\n",
                r$juncture, r$n_documents, r$pct_securitising,
                r$mean_score, r$max_score))
  }

  # Material vs ontological
  cat("\n--- Material vs Ontological Security (by year) ---\n")
  if (nrow(tables$material_vs_ontological) > 0) {
    cat(sprintf("  %-6s %10s %15s\n", "Year", "Material", "Ontological"))
    for (i in seq_len(nrow(tables$material_vs_ontological))) {
      r <- tables$material_vs_ontological[i, ]
      mat <- if ("material_security" %in% names(r)) r$material_security else 0
      ont <- if ("ontological_security" %in% names(r)) r$ontological_security else 0
      cat(sprintf("  %-6s %10d %15d\n", r$year, mat, ont))
    }
  }

  # Co-occurrence
  cat("\n--- Category Co-occurrence (document level) ---\n")
  short_names <- c("Church", "Material", "Ontological", "Decolonise", "Urgency")
  cat(sprintf("  %-12s %8s %8s %11s %10s %7s\n", "", short_names[1],
              short_names[2], short_names[3], short_names[4], short_names[5]))
  for (i in seq_len(nrow(tables$cooccurrence))) {
    cat(sprintf("  %-12s", short_names[i]))
    for (j in seq_len(ncol(tables$cooccurrence))) {
      cat(sprintf(" %8d", tables$cooccurrence[i, j]))
    }
    cat("\n")
  }

  cat("\n", strrep("=", 70), "\n")
}

# ── Export all results ───────────────────────────────────
export_all <- function(scored_df, tables,
                       output_dir = OUTPUT_DIR) {
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

  # Scored claims CSV
  export_df <- scored_df %>%
    select(claim_id, doc_id, doc_title, doc_date, doc_url,
           year, juncture, category, matched_term, term_lang,
           surface_form, sentence, context_before, context_after,
           sec_score, is_securitising,
           has_church, has_material, has_ontological,
           has_decolonise, has_urgency)
  write.csv(export_df, file.path(output_dir, "scored_claims.csv"),
            row.names = FALSE, fileEncoding = "UTF-8")
  cat(sprintf("  scored_claims.csv: %d rows\n", nrow(export_df)))

  # Each thesis table as a separate CSV
  for (tname in names(tables)) {
    tbl <- tables[[tname]]
    fname <- paste0("table_", tname, ".csv")
    write.csv(tbl, file.path(output_dir, fname),
              row.names = (tname == "cooccurrence"), fileEncoding = "UTF-8")
    cat(sprintf("  %s: %d rows\n", fname, nrow(tbl)))
  }

  # Document-level summary
  doc_summary <- scored_df %>%
    distinct(doc_id, .keep_all = TRUE) %>%
    select(doc_id, doc_title, doc_date, doc_url, year, juncture,
           n_claims, n_categories, sec_score, is_securitising,
           has_church, has_material, has_ontological,
           has_decolonise, has_urgency) %>%
    arrange(doc_date)
  write.csv(doc_summary, file.path(output_dir, "document_scores.csv"),
            row.names = FALSE, fileEncoding = "UTF-8")
  cat(sprintf("  document_scores.csv: %d rows\n", nrow(doc_summary)))

  cat(sprintf("\nAll outputs saved to %s/\n", output_dir))
}

# ── Main entry point ─────────────────────────────────────
run_coding_analysis <- function(claims_file = file.path(OUTPUT_DIR, "claims.json")) {
  cat("Loading and preparing claims...\n")
  claims <- load_and_prepare_claims(claims_file)

  cat("\nScoring securitisation intensity...\n")
  scored <- score_securitisation(claims)

  cat("\nBuilding thesis tables...\n")
  tables <- build_thesis_tables(scored)

  cat("\nExporting results...\n")
  export_all(scored, tables)

  cat("\n")
  print_coding_report(scored, tables)

  invisible(list(scored = scored, tables = tables))
}
