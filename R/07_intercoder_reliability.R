# ──────────────────────────────────────────────────────────
# 07_intercoder_reliability.R — Cohen's Kappa validation
#
# Draws a stratified sample from the LLM-coded data,
# exports a blind coding sheet for manual coding, then
# computes Cohen's Kappa for agreement between the LLM
# and the human coder.
#
# Usage:
#   source("R/07_intercoder_reliability.R")
#
#   # Step 1: Generate the blind coding sheet
#   draw_validation_sample()
#
#   # Step 2: Open output/validation_sample.csv, fill in
#   #         the manual_* columns, save as
#   #         output/validation_coded.csv
#
#   # Step 3: Compute agreement
#   compute_kappa()
# ──────────────────────────────────────────────────────────

library(dplyr)
library(tidyr)

if (!requireNamespace("irr", quietly = TRUE)) install.packages("irr")
library(irr)

# ── Step 1: Draw stratified validation sample ────────────

draw_validation_sample <- function(
    coded_path = file.path("output", "llm_coded_full.csv"),
    output_path = file.path("output", "validation_sample.csv"),
    n_per_stratum = 6,
    seed = 42
) {
  coded <- read.csv(coded_path, stringsAsFactors = FALSE)
  cat(sprintf("Loaded %d coded passages\n", nrow(coded)))

  # Assign source labels for stratification
  coded$source_label <- case_when(
    coded$doc_content_type == "speech"              ~ "Zelensky",
    coded$doc_content_type == "poroshenko_speech"    ~ "Poroshenko",
    coded$doc_content_type == "rada_stenogram"       ~ "Rada",
    coded$doc_content_type == "sbu_press_release"    ~ "SBU",
    coded$doc_content_type == "dess_statement"       ~ "DESS",
    TRUE                                            ~ "Other"
  )

  coded$sec_label <- ifelse(
    tolower(coded$is_securitising) == "true", "securitising", "not_securitising"
  )

  # Show strata sizes
  strata <- coded %>%
    count(source_label, sec_label) %>%
    arrange(source_label, sec_label)

  cat("\nStrata sizes:\n")
  print(as.data.frame(strata), row.names = FALSE)

  # Draw stratified sample
  set.seed(seed)
  sample_df <- coded %>%
    group_by(source_label, sec_label) %>%
    slice_sample(n = min(n_per_stratum, n())) %>%
    ungroup()

  cat(sprintf("\nSampled %d passages (%d per stratum where available)\n",
              nrow(sample_df), n_per_stratum))

  # Shuffle so the coder doesn't see them grouped by source/classification
  sample_df <- sample_df[sample(nrow(sample_df)), ]
  sample_df$sample_id <- seq_len(nrow(sample_df))

  # Build the coding sheet:
  # - Visible: sample_id, source, date, title, passage (+ context)
  # - Hidden (for later comparison): LLM codes stored separately
  # - Blank manual columns for the human coder to fill in
  coding_sheet <- sample_df %>%
    select(
      sample_id,
      doc_id,
      source_label,
      doc_date,
      doc_title,
      passage,
      # Blank columns for manual coding
    ) %>%
    mutate(
      manual_is_securitising     = NA_character_,
      manual_securitisation_type = NA_character_,
      manual_referent_object     = NA_character_,
      manual_threat_actor        = NA_character_,
      manual_extraordinary_measure = NA_character_,
      manual_confidence          = NA_integer_,
      manual_notes               = NA_character_
    )

  write.csv(coding_sheet, output_path, row.names = FALSE, fileEncoding = "UTF-8")
  cat(sprintf("Blind coding sheet saved to: %s\n", output_path))

  # Save the LLM codes separately (don't look at this until after coding!)
  llm_key <- sample_df %>%
    select(
      sample_id,
      doc_id,
      llm_is_securitising     = is_securitising,
      llm_securitisation_type = securitisation_type,
      llm_referent_object     = referent_object,
      llm_threat_actor        = threat_actor,
      llm_extraordinary_measure = extraordinary_measure,
      llm_confidence          = confidence,
      llm_coder_notes         = coder_notes
    )

  key_path <- file.path("output", "validation_llm_key.csv")
  write.csv(llm_key, key_path, row.names = FALSE, fileEncoding = "UTF-8")
  cat(sprintf("LLM answer key saved to: %s (do not open until manual coding is complete)\n", key_path))

  cat(sprintf("\n%s\nNEXT STEPS\n%s\n", strrep("=", 50), strrep("=", 50)))
  cat("1. Open output/validation_sample.csv\n")
  cat("2. For each row, read the passage and code:\n")
  cat("   - manual_is_securitising: TRUE or FALSE\n")
  cat("   - manual_securitisation_type: material / ontological / both / neither\n")
  cat("   - manual_referent_object: state / nation / identity / faith / other\n")
  cat("   - manual_threat_actor: UOC-MP / Russia / internal / other / none\n")
  cat("   - manual_extraordinary_measure: ban / sanction / dissolution / seizure / other / none\n")
  cat("   - manual_confidence: 1 (uncertain), 2 (fairly confident), 3 (clear)\n")
  cat("   - manual_notes: any observations\n")
  cat("3. Save the completed sheet as output/validation_coded.csv\n")
  cat("4. Run: compute_kappa()\n")
  cat(strrep("=", 50), "\n")

  invisible(sample_df)
}


# ── Step 2: Compute Cohen's Kappa ────────────────────────

compute_kappa <- function(
    coded_path = file.path("output", "validation_coded.csv"),
    key_path   = file.path("output", "validation_llm_key.csv"),
    report_path = file.path("output", "kappa_report.txt")
) {
  manual <- read.csv(coded_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  llm    <- read.csv(key_path,   stringsAsFactors = FALSE, fileEncoding = "UTF-8")

  # Merge on sample_id
  merged <- inner_join(manual, llm, by = "sample_id", suffix = c("", ".llm"))

  cat(sprintf("Matched %d passages for comparison\n", nrow(merged)))

  # Normalise boolean columns
  merged$manual_sec <- tolower(trimws(merged$manual_is_securitising)) == "true"
  merged$llm_sec    <- tolower(trimws(merged$llm_is_securitising)) == "true"

  # ── Open report file ──
  sink(report_path, split = TRUE)

  cat(strrep("=", 60), "\n")
  cat("INTER-CODER RELIABILITY REPORT\n")
  cat(sprintf("Date: %s\n", Sys.Date()))
  cat(sprintf("Sample size: %d passages\n", nrow(merged)))
  cat(strrep("=", 60), "\n\n")

  # ── 1. Binary: is_securitising ──
  cat(strrep("-", 60), "\n")
  cat("1. IS_SECURITISING (binary: TRUE / FALSE)\n")
  cat(strrep("-", 60), "\n\n")

  conf_matrix <- table(
    Human = merged$manual_sec,
    LLM   = merged$llm_sec
  )
  cat("Confusion matrix:\n")
  print(conf_matrix)
  cat("\n")

  k1 <- kappa2(data.frame(merged$manual_sec, merged$llm_sec))
  cat(sprintf("Cohen's Kappa:  %.3f\n", k1$value))
  cat(sprintf("z-statistic:    %.3f\n", k1$statistic))
  cat(sprintf("p-value:        %.4f\n", k1$p.value))

  # Raw agreement
  agree <- sum(merged$manual_sec == merged$llm_sec) / nrow(merged)
  cat(sprintf("Raw agreement:  %.1f%%\n", agree * 100))

  # Interpretation
  kval <- k1$value
  interp <- case_when(
    kval >= 0.81 ~ "almost perfect",
    kval >= 0.61 ~ "substantial",
    kval >= 0.41 ~ "moderate",
    kval >= 0.21 ~ "fair",
    TRUE         ~ "poor"
  )
  cat(sprintf("Interpretation: %s (Landis & Koch 1977)\n\n", interp))

  # Disagreement analysis
  disagree <- merged %>% filter(manual_sec != llm_sec)
  if (nrow(disagree) > 0) {
    cat(sprintf("Disagreements: %d passages\n", nrow(disagree)))

    fp <- sum(!disagree$manual_sec & disagree$llm_sec)
    fn <- sum(disagree$manual_sec & !disagree$llm_sec)
    cat(sprintf("  LLM false positives (LLM=TRUE, Human=FALSE): %d\n", fp))
    cat(sprintf("  LLM false negatives (LLM=FALSE, Human=TRUE): %d\n", fn))

    cat("\nDisagreed passages:\n")
    for (i in seq_len(nrow(disagree))) {
      row <- disagree[i, ]
      cat(sprintf("  #%d [%s] LLM=%s, Human=%s\n    %s\n\n",
                  row$sample_id, row$source_label,
                  row$llm_sec, row$manual_sec,
                  substr(row$passage, 1, 120)))
    }
  }

  # ── 2. Securitisation type (among agreed securitising) ──
  both_sec <- merged %>% filter(manual_sec & llm_sec)

  if (nrow(both_sec) >= 5) {
    cat(strrep("-", 60), "\n")
    cat("2. SECURITISATION_TYPE (among agreed securitising passages)\n")
    cat(strrep("-", 60), "\n\n")

    both_sec$manual_type <- tolower(trimws(both_sec$manual_securitisation_type))
    both_sec$llm_type    <- tolower(trimws(both_sec$llm_securitisation_type))

    cat("Cross-tabulation:\n")
    print(table(Human = both_sec$manual_type, LLM = both_sec$llm_type))
    cat("\n")

    # Only compute Kappa if there's variation
    if (length(unique(c(both_sec$manual_type, both_sec$llm_type))) > 1) {
      k2 <- kappa2(data.frame(both_sec$manual_type, both_sec$llm_type))
      cat(sprintf("Cohen's Kappa:  %.3f\n", k2$value))
      cat(sprintf("p-value:        %.4f\n", k2$p.value))
      agree2 <- sum(both_sec$manual_type == both_sec$llm_type) / nrow(both_sec)
      cat(sprintf("Raw agreement:  %.1f%%\n\n", agree2 * 100))
    } else {
      cat("Only one category present — Kappa undefined (perfect agreement trivially).\n\n")
    }
  } else {
    cat("\nToo few agreed-securitising passages for type Kappa (need >= 5).\n\n")
  }

  # ── 3. Referent object ──
  if (nrow(both_sec) >= 5) {
    cat(strrep("-", 60), "\n")
    cat("3. REFERENT_OBJECT (among agreed securitising passages)\n")
    cat(strrep("-", 60), "\n\n")

    both_sec$manual_ro <- tolower(trimws(both_sec$manual_referent_object))
    both_sec$llm_ro    <- tolower(trimws(both_sec$llm_referent_object))

    print(table(Human = both_sec$manual_ro, LLM = both_sec$llm_ro))
    cat("\n")

    if (length(unique(c(both_sec$manual_ro, both_sec$llm_ro))) > 1) {
      k3 <- kappa2(data.frame(both_sec$manual_ro, both_sec$llm_ro))
      cat(sprintf("Cohen's Kappa:  %.3f\n", k3$value))
      agree3 <- sum(both_sec$manual_ro == both_sec$llm_ro) / nrow(both_sec)
      cat(sprintf("Raw agreement:  %.1f%%\n\n", agree3 * 100))
    }
  }

  # ── 4. Threat actor ──
  if (nrow(both_sec) >= 5) {
    cat(strrep("-", 60), "\n")
    cat("4. THREAT_ACTOR (among agreed securitising passages)\n")
    cat(strrep("-", 60), "\n\n")

    both_sec$manual_ta <- tolower(trimws(both_sec$manual_threat_actor))
    both_sec$llm_ta    <- tolower(trimws(both_sec$llm_threat_actor))

    print(table(Human = both_sec$manual_ta, LLM = both_sec$llm_ta))
    cat("\n")

    if (length(unique(c(both_sec$manual_ta, both_sec$llm_ta))) > 1) {
      k4 <- kappa2(data.frame(both_sec$manual_ta, both_sec$llm_ta))
      cat(sprintf("Cohen's Kappa:  %.3f\n", k4$value))
      agree4 <- sum(both_sec$manual_ta == both_sec$llm_ta) / nrow(both_sec)
      cat(sprintf("Raw agreement:  %.1f%%\n\n", agree4 * 100))
    }
  }

  # ── Summary table ──
  cat(strrep("=", 60), "\n")
  cat("SUMMARY\n")
  cat(strrep("=", 60), "\n\n")
  cat(sprintf("%-30s  %-10s  %-10s  %s\n", "Variable", "Kappa", "Agreement", "Interpretation"))
  cat(strrep("-", 70), "\n")
  cat(sprintf("%-30s  %-10.3f  %-10.1f  %s\n",
              "is_securitising", k1$value, agree * 100, interp))

  if (nrow(both_sec) >= 5) {
    if (exists("k2") && !is.null(k2)) {
      interp2 <- case_when(k2$value >= 0.81 ~ "almost perfect", k2$value >= 0.61 ~ "substantial",
                           k2$value >= 0.41 ~ "moderate", k2$value >= 0.21 ~ "fair", TRUE ~ "poor")
      cat(sprintf("%-30s  %-10.3f  %-10.1f  %s\n",
                  "securitisation_type", k2$value, agree2 * 100, interp2))
    }
    if (exists("k3") && !is.null(k3)) {
      interp3 <- case_when(k3$value >= 0.81 ~ "almost perfect", k3$value >= 0.61 ~ "substantial",
                           k3$value >= 0.41 ~ "moderate", k3$value >= 0.21 ~ "fair", TRUE ~ "poor")
      cat(sprintf("%-30s  %-10.3f  %-10.1f  %s\n",
                  "referent_object", k3$value, agree3 * 100, interp3))
    }
    if (exists("k4") && !is.null(k4)) {
      interp4 <- case_when(k4$value >= 0.81 ~ "almost perfect", k4$value >= 0.61 ~ "substantial",
                           k4$value >= 0.41 ~ "moderate", k4$value >= 0.21 ~ "fair", TRUE ~ "poor")
      cat(sprintf("%-30s  %-10.3f  %-10.1f  %s\n",
                  "threat_actor", k4$value, agree4 * 100, interp4))
    }
  }

  cat("\n")
  cat("Benchmarks (Landis & Koch 1977):\n")
  cat("  < 0.20 poor | 0.21-0.40 fair | 0.41-0.60 moderate\n")
  cat("  0.61-0.80 substantial | 0.81+ almost perfect\n")

  sink()
  cat(sprintf("\nFull report saved to: %s\n", report_path))

  invisible(list(
    binary_kappa = k1,
    n_sample = nrow(merged),
    agreement = agree,
    n_disagreements = nrow(disagree)
  ))
}
