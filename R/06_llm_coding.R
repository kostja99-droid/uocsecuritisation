# ──────────────────────────────────────────────────────────
# 06_llm_coding.R — LLM-assisted securitisation coding
#
# Uses the Anthropic API to read each claim in context and
# fill in the codebook decision fields. Every judgment
# includes a rationale for audit.
#
# Usage:
#   source("01_config.R")
#   source("06_llm_coding.R")
#
#   # Code all claims from relevant documents
#   coded <- run_llm_coding()
#
#   # Or step by step:
#   claims <- prepare_relevant_claims()
#   coded  <- code_claims_batch(claims)
#   export_coded(coded)
#
#   # Audit tools:
#   audit  <- prepare_audit_sample(coded, n = 50)
#   report <- compute_agreement(coded_file, human_file)
# ──────────────────────────────────────────────────────────

library(jsonlite)
library(dplyr)
library(httr2)

# ── Configuration ────────────────────────────────────────

LLM_CONFIG <- list(
  model        = "claude-sonnet-5",
  max_tokens   = 1024,
  temperature  = 0,
  batch_delay  = 0.5,
  save_every   = 25
)

# ── System prompt (the codebook, condensed for the LLM) ──

CODING_SYSTEM_PROMPT <- '
You are a trained coder for a securitisation discourse analysis of Ukrainian presidential speeches (2018-2025). Your task is to assess individual claims (sentences with matched terms) according to a theory-derived coding scheme based on the Copenhagen School of securitisation theory, extended with Mitzen\'s ontological security concept.

## Context
The study examines how the Ukrainian state has securitised the Ukrainian Orthodox Church (Moscow Patriarchate, UOC-MP). Claims have been pre-identified by keyword matching against five coding dimensions:
- **church_actors**: Terms identifying churches and religious actors (церква, УПЦ, ПЦУ, автокефалія, томос, православний, патріарх, лавра, etc.)
- **material_security**: Material threat to the physical state (загроза, колабораціонізм, шпигунство, агент, зрада, суверенітет, безпека, СБУ, etc.)
- **ontological_security**: Threat to the national self (духовний, ідентичність, самобутність, духовна незалежність, національна ідентичність, etc.)
- **decolonisation**: Identity-restorative language (деколонізація, дерусифікація, визволення, звільнення, кайдани, імперський, колоніальний, etc.)
- **urgency**: Existential intensity and exceptional measures (заборона, ліквідація, надзвичайний, негайний, заборонити, ліквідувати, etc.)

## Your coding task
For each claim, you receive the matched sentence, its category, the matched term, and the surrounding context (previous and next sentences). You must assess:

1. **category_correct** (true/false): Is the automated category assignment correct? FALSE if the term is used metaphorically, in a different domain (e.g. "безпека" in a healthcare context), or the sentence is about something entirely unrelated.

2. **is_securitising** (true/false): Does this sentence (in context) constitute a securitising move? TRUE requires ALL THREE: (a) identification of a threat, (b) framing as existential or extraordinary, (c) implied or explicit call for extraordinary action. A neutral policy mention of the church is NOT securitising.

3. **securitisation_type** (material/ontological/both/neither): Material = threat to the physical state (espionage, treason, territorial integrity). Ontological = threat to identity/selfhood (spiritual independence, national identity, civilisational choice). Both = explicitly links material and identity threats. Neither = not a securitising move.

4. **referent_object** (state/nation/identity/faith/other/none): What is being protected or threatened? The state apparatus, the Ukrainian nation/people, national identity/culture, the "true" Ukrainian faith, something else, or nothing identifiable.

5. **threat_actor** (UOC-MP/Russia/internal/other/none): Who is doing the threatening? The UOC-MP specifically, Russia broadly, internal enemies/collaborators, another actor, or no actor identified.

6. **extraordinary_measure** (ban/sanction/dissolution/seizure/none/other): What action beyond normal politics is proposed or implied?

7. **confidence** (1/2/3): 1 = uncertain, ambiguous case; 2 = fairly confident; 3 = clear case.

8. **rationale**: One sentence explaining your judgment. This is mandatory for audit purposes.

## Key rule
When in doubt: Is the speaker framing something as SO threatening that normal political processes are insufficient? If yes, it is securitising. If the speaker merely mentions the church in a neutral policy context, it is not.

## Response format
Respond with ONLY a JSON object, no other text:
{
  "category_correct": true,
  "is_securitising": false,
  "securitisation_type": "neither",
  "referent_object": "none",
  "threat_actor": "none",
  "extraordinary_measure": "none",
  "confidence": 2,
  "rationale": "The term bezpeka is used in a general national defence context without reference to the church."
}
'

# ── Load only claims from relevant documents ─────────────

prepare_relevant_claims <- function(
    claims_file  = file.path(OUTPUT_DIR, "claims.json"),
    results_file = file.path(OUTPUT_DIR, "results.json")) {

  claims <- fromJSON(claims_file, simplifyDataFrame = FALSE)
  cat(sprintf("Total claims: %d\n", length(claims)))

  # Find relevant document IDs (church_actors + at least one other)
  results <- fromJSON(results_file, simplifyDataFrame = FALSE)
  relevant_ids <- character()
  for (r in results) {
    cats <- r$matched_categories
    if (is.null(cats)) next
    if ("church_actors" %in% cats && length(setdiff(cats, "church_actors")) > 0) {
      relevant_ids <- c(relevant_ids, r$id)
    }
  }
  cat(sprintf("Relevant documents: %d\n", length(relevant_ids)))

  # Filter claims to relevant documents only
  relevant_claims <- Filter(function(c) c$doc_id %in% relevant_ids, claims)
  cat(sprintf("Claims in relevant documents: %d\n", length(relevant_claims)))

  # Convert to data frame
  df <- bind_rows(lapply(relevant_claims, function(c) {
    tibble(
      claim_id       = as.integer(c$claim_id),
      doc_id         = c$doc_id,
      doc_title      = if (is.null(c$doc_title)) NA_character_ else c$doc_title,
      doc_date       = if (is.null(c$doc_date) || length(c$doc_date) == 0 || is.na(c$doc_date)) NA_character_ else c$doc_date,
      doc_url        = c$doc_url,
      category       = c$category,
      matched_term   = c$matched_term_lemma,
      term_lang      = c$matched_term_lang,
      surface_form   = c$matched_surface_form,
      sentence       = c$sentence,
      context_before = if (is.null(c$context_before)) "" else c$context_before,
      context_after  = if (is.null(c$context_after)) "" else c$context_after
    )
  }))

  cat(sprintf("Prepared %d claims for LLM coding\n", nrow(df)))
  df
}

# ── Call the Anthropic API for a single claim ────────────

code_single_claim <- function(claim_row, api_key) {
  user_prompt <- sprintf(
    'Code this claim:\n\nDocument: %s\nDate: %s\nCategory: %s\nMatched term: %s (surface form: "%s")\n\n[Previous sentence]: %s\n>>> [TARGET SENTENCE]: %s\n[Next sentence]: %s',
    claim_row$doc_title,
    if (is.na(claim_row$doc_date)) "unknown" else claim_row$doc_date,
    claim_row$category,
    claim_row$matched_term,
    claim_row$surface_form,
    if (is.na(claim_row$context_before) || claim_row$context_before == "") "(none)" else claim_row$context_before,
    claim_row$sentence,
    if (is.na(claim_row$context_after) || claim_row$context_after == "") "(none)" else claim_row$context_after
  )

  body <- list(
    model      = LLM_CONFIG$model,
    max_tokens = LLM_CONFIG$max_tokens,
    system     = CODING_SYSTEM_PROMPT,
    messages   = list(
      list(role = "user", content = user_prompt)
    )
  )

  resp <- tryCatch({
    req <- request("https://api.anthropic.com/v1/messages") |>
      req_headers(
        `x-api-key`         = api_key,
        `anthropic-version` = "2023-06-01",
        `content-type`      = "application/json"
      ) |>
      req_body_json(body) |>
      req_timeout(60) |>
      req_retry(max_tries = 3, backoff = ~ 2)

    result <- req_perform(req)
    resp_body <- resp_body_json(result)

    # Extract text from response
    text_block <- Filter(function(b) b$type == "text", resp_body$content)
    if (length(text_block) == 0) return(NULL)
    raw_text <- text_block[[1]]$text

    # Parse JSON from response
    parsed <- tryCatch(fromJSON(raw_text), error = function(e) {
      # Try to extract JSON from markdown code block
      json_match <- regmatches(raw_text, regexpr("\\{[^}]+\\}", raw_text))
      if (length(json_match) > 0) fromJSON(json_match[1]) else NULL
    })

    if (!is.null(parsed)) {
      parsed$input_tokens  <- resp_body$usage$input_tokens
      parsed$output_tokens <- resp_body$usage$output_tokens
      parsed$raw_response  <- raw_text
    }
    parsed

  }, error = function(e) {
    warning(sprintf("API error for claim %d: %s", claim_row$claim_id, e$message))
    NULL
  })

  resp
}

# ── Batch code all claims ────────────────────────────────

code_claims_batch <- function(claims_df,
                               api_key      = Sys.getenv("ANTHROPIC_API_KEY"),
                               progress_file = file.path(OUTPUT_DIR, "llm_coding_progress.csv"),
                               resume       = TRUE) {
  if (api_key == "") {
    stop("ANTHROPIC_API_KEY not set. Export it in your R session:\n  Sys.setenv(ANTHROPIC_API_KEY = 'sk-ant-...')")
  }

  # Resume from progress if available
  already_coded <- integer()
  if (resume && file.exists(progress_file)) {
    progress <- read.csv(progress_file, stringsAsFactors = FALSE)
    already_coded <- progress$claim_id
    cat(sprintf("Resuming: %d claims already coded\n", length(already_coded)))
  }

  remaining <- claims_df %>% filter(!(claim_id %in% already_coded))
  cat(sprintf("Claims to code: %d\n", nrow(remaining)))

  if (nrow(remaining) == 0) {
    cat("All claims already coded.\n")
    return(read.csv(progress_file, stringsAsFactors = FALSE))
  }

  results <- list()
  total_input  <- 0L
  total_output <- 0L
  t0 <- Sys.time()

  for (i in seq_len(nrow(remaining))) {
    row <- remaining[i, ]
    coding <- code_single_claim(row, api_key)

    if (is.null(coding)) {
      result_row <- tibble(
        claim_id            = row$claim_id,
        category_correct    = NA,
        is_securitising     = NA,
        securitisation_type = NA_character_,
        referent_object     = NA_character_,
        threat_actor        = NA_character_,
        extraordinary_measure = NA_character_,
        confidence          = NA_integer_,
        rationale           = "API_ERROR",
        input_tokens        = NA_integer_,
        output_tokens       = NA_integer_
      )
    } else {
      result_row <- tibble(
        claim_id            = row$claim_id,
        category_correct    = as.logical(coding$category_correct),
        is_securitising     = as.logical(coding$is_securitising),
        securitisation_type = as.character(coding$securitisation_type %||% NA),
        referent_object     = as.character(coding$referent_object %||% NA),
        threat_actor        = as.character(coding$threat_actor %||% NA),
        extraordinary_measure = as.character(coding$extraordinary_measure %||% NA),
        confidence          = as.integer(coding$confidence %||% NA),
        rationale           = as.character(coding$rationale %||% NA),
        input_tokens        = as.integer(coding$input_tokens %||% NA),
        output_tokens       = as.integer(coding$output_tokens %||% NA)
      )
      total_input  <- total_input + (coding$input_tokens %||% 0L)
      total_output <- total_output + (coding$output_tokens %||% 0L)
    }

    results[[length(results) + 1]] <- result_row

    # Progress reporting
    if (i %% 10 == 0 || i == nrow(remaining)) {
      elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
      rate <- i / elapsed
      eta <- (nrow(remaining) - i) / rate
      cost_est <- (total_input * 2 / 1e6) + (total_output * 10 / 1e6)
      cat(sprintf("  [%d/%d] %.0f%% | %.1f claims/s | ETA: %.0fs | ~$%.3f so far\n",
                  i, nrow(remaining), 100 * i / nrow(remaining),
                  rate, eta, cost_est))
    }

    # Save progress periodically
    if (i %% LLM_CONFIG$save_every == 0 || i == nrow(remaining)) {
      batch_df <- bind_rows(results)
      if (file.exists(progress_file)) {
        existing <- read.csv(progress_file, stringsAsFactors = FALSE)
        batch_df <- bind_rows(existing, batch_df)
      }
      write.csv(batch_df, progress_file, row.names = FALSE, fileEncoding = "UTF-8")
      results <- list()
    }

    Sys.sleep(LLM_CONFIG$batch_delay)
  }

  coded <- read.csv(progress_file, stringsAsFactors = FALSE)
  cat(sprintf("\nDone. %d claims coded. Progress saved to %s\n",
              nrow(coded), progress_file))
  cat(sprintf("Total tokens: %d input, %d output\n", total_input, total_output))
  cat(sprintf("Estimated cost: $%.3f\n",
              (total_input * 2 / 1e6) + (total_output * 10 / 1e6)))
  coded
}

# ── Merge LLM coding with original claims ────────────────

merge_coded_claims <- function(
    claims_df  = NULL,
    coded_file = file.path(OUTPUT_DIR, "llm_coding_progress.csv")) {

  if (is.null(claims_df)) {
    claims_df <- prepare_relevant_claims()
  }

  coded <- read.csv(coded_file, stringsAsFactors = FALSE)

  merged <- claims_df %>%
    left_join(coded %>% select(-any_of("raw_response")),
              by = "claim_id")

  cat(sprintf("Merged: %d claims, %d with LLM coding\n",
              nrow(merged), sum(!is.na(merged$is_securitising))))
  merged
}

# ── Export final coded dataset ───────────────────────────

export_coded <- function(merged_df,
                          output_dir = OUTPUT_DIR) {
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

  # Full coded claims
  out_path <- file.path(output_dir, "llm_coded_claims.csv")
  write.csv(merged_df, out_path, row.names = FALSE, fileEncoding = "UTF-8")
  cat(sprintf("Full coded claims: %s (%d rows)\n", out_path, nrow(merged_df)))

  # Securitising claims only
  sec_df <- merged_df %>% filter(is_securitising == TRUE)
  sec_path <- file.path(output_dir, "securitising_claims.csv")
  write.csv(sec_df, sec_path, row.names = FALSE, fileEncoding = "UTF-8")
  cat(sprintf("Securitising claims: %s (%d rows)\n", sec_path, nrow(sec_df)))

  # Summary by category and juncture
  if ("juncture" %in% names(merged_df)) {
    summary_path <- file.path(output_dir, "llm_coding_summary.csv")
    summary_df <- merged_df %>%
      filter(!is.na(is_securitising)) %>%
      group_by(category) %>%
      summarise(
        total         = n(),
        cat_correct   = sum(category_correct == TRUE, na.rm = TRUE),
        securitising  = sum(is_securitising == TRUE, na.rm = TRUE),
        pct_correct   = round(100 * cat_correct / total, 1),
        pct_securitising = round(100 * securitising / total, 1),
        .groups = "drop"
      )
    write.csv(summary_df, summary_path, row.names = FALSE)
    cat(sprintf("Summary: %s\n", summary_path))
  }

  # Audit log (model, timestamp, config)
  log_path <- file.path(output_dir, "llm_coding_log.json")
  log_data <- list(
    model       = LLM_CONFIG$model,
    coded_at    = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
    n_claims    = nrow(merged_df),
    n_coded     = sum(!is.na(merged_df$is_securitising)),
    n_securitising = sum(merged_df$is_securitising == TRUE, na.rm = TRUE),
    config      = LLM_CONFIG,
    system_prompt_hash = substr(digest::digest(CODING_SYSTEM_PROMPT, algo = "md5"), 1, 12)
  )
  write_json(log_data, log_path, auto_unbox = TRUE, pretty = TRUE)
  cat(sprintf("Audit log: %s\n", log_path))

  invisible(merged_df)
}

# ── Audit tools ──────────────────────────────────────────

# Prepare a stratified sample for human verification
prepare_audit_sample <- function(coded_df, n = 50, seed = 42,
                                  output_file = file.path(OUTPUT_DIR, "audit_sample.csv")) {
  set.seed(seed)

  coded_only <- coded_df %>% filter(!is.na(is_securitising))

  # Stratify: half securitising, half not (or proportional if imbalanced)
  sec     <- coded_only %>% filter(is_securitising == TRUE)
  non_sec <- coded_only %>% filter(is_securitising == FALSE)

  n_sec <- min(ceiling(n / 2), nrow(sec))
  n_non <- min(n - n_sec, nrow(non_sec))

  sample_df <- bind_rows(
    sec %>% slice_sample(n = n_sec),
    non_sec %>% slice_sample(n = n_non)
  ) %>%
    arrange(claim_id)

  # Add human coding columns (empty, to be filled)
  sample_df <- sample_df %>%
    mutate(
      human_category_correct    = NA,
      human_is_securitising     = NA,
      human_securitisation_type = NA_character_,
      human_referent_object     = NA_character_,
      human_threat_actor        = NA_character_,
      human_extraordinary_measure = NA_character_,
      human_confidence          = NA_integer_,
      human_notes               = NA_character_
    )

  write.csv(sample_df, output_file, row.names = FALSE, fileEncoding = "UTF-8")
  cat(sprintf("Audit sample: %d claims exported to %s\n", nrow(sample_df), output_file))
  cat(sprintf("  Securitising: %d | Non-securitising: %d\n", n_sec, n_non))
  cat(sprintf("\nInstructions:\n"))
  cat("  1. Open the CSV in Excel or Google Sheets\n")
  cat("  2. For each row, fill in the human_* columns\n")
  cat("  3. Compare your judgment to the LLM columns (category_correct, is_securitising, etc.)\n")
  cat("  4. Save and run: compute_agreement('output/audit_sample.csv')\n")

  invisible(sample_df)
}

# Compute inter-coder agreement (LLM vs human)
compute_agreement <- function(audit_file = file.path(OUTPUT_DIR, "audit_sample.csv")) {
  if (!file.exists(audit_file)) stop(sprintf("File not found: %s", audit_file))

  df <- read.csv(audit_file, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  coded <- df %>% filter(!is.na(human_is_securitising))

  if (nrow(coded) == 0) {
    cat("No human-coded rows found. Fill in the human_* columns first.\n")
    return(invisible(NULL))
  }

  cat(strrep("=", 65), "\n")
  cat("LLM vs HUMAN INTER-CODER AGREEMENT REPORT\n")
  cat(strrep("=", 65), "\n\n")

  cat(sprintf("Claims in audit sample: %d\n", nrow(df)))
  cat(sprintf("Claims coded by human:  %d\n", nrow(coded)))

  # Category correctness agreement
  cat_agree <- sum(coded$category_correct == coded$human_category_correct, na.rm = TRUE)
  cat(sprintf("\n--- category_correct ---\n"))
  cat(sprintf("Agreement: %d/%d (%.1f%%)\n", cat_agree, nrow(coded),
              100 * cat_agree / nrow(coded)))

  # Securitisation agreement
  sec_agree <- sum(coded$is_securitising == coded$human_is_securitising, na.rm = TRUE)
  cat(sprintf("\n--- is_securitising ---\n"))
  cat(sprintf("Agreement: %d/%d (%.1f%%)\n", sec_agree, nrow(coded),
              100 * sec_agree / nrow(coded)))

  # Confusion matrix for is_securitising
  llm_sec    <- coded$is_securitising == TRUE
  human_sec  <- coded$human_is_securitising == TRUE
  tp <- sum(llm_sec & human_sec, na.rm = TRUE)
  fp <- sum(llm_sec & !human_sec, na.rm = TRUE)
  fn <- sum(!llm_sec & human_sec, na.rm = TRUE)
  tn <- sum(!llm_sec & !human_sec, na.rm = TRUE)
  cat(sprintf("  True Positive:  %d  (both say securitising)\n", tp))
  cat(sprintf("  False Positive: %d  (LLM says yes, human says no)\n", fp))
  cat(sprintf("  False Negative: %d  (LLM says no, human says yes)\n", fn))
  cat(sprintf("  True Negative:  %d  (both say not securitising)\n", tn))

  precision <- if (tp + fp > 0) tp / (tp + fp) else NA
  recall    <- if (tp + fn > 0) tp / (tp + fn) else NA
  f1        <- if (!is.na(precision) && !is.na(recall) && (precision + recall) > 0) {
    2 * precision * recall / (precision + recall)
  } else NA
  cat(sprintf("  Precision: %.3f | Recall: %.3f | F1: %.3f\n",
              precision, recall, f1))

  # Cohen's kappa (simple binary)
  n <- nrow(coded)
  po <- (tp + tn) / n
  pe <- ((tp + fp) * (tp + fn) + (fn + tn) * (fp + tn)) / (n * n)
  kappa <- if (pe < 1) (po - pe) / (1 - pe) else 1
  cat(sprintf("  Cohen's kappa: %.3f\n", kappa))

  # Securitisation type agreement (among those both coded as securitising)
  both_sec <- coded %>%
    filter(is_securitising == TRUE, human_is_securitising == TRUE)
  if (nrow(both_sec) > 0) {
    type_agree <- sum(both_sec$securitisation_type == both_sec$human_securitisation_type,
                      na.rm = TRUE)
    cat(sprintf("\n--- securitisation_type (among agreed securitising) ---\n"))
    cat(sprintf("Agreement: %d/%d (%.1f%%)\n", type_agree, nrow(both_sec),
                100 * type_agree / nrow(both_sec)))
  }

  # Disagreement analysis
  disagreements <- coded %>%
    filter(is_securitising != human_is_securitising)
  if (nrow(disagreements) > 0) {
    cat(sprintf("\n--- Disagreements (%d) ---\n", nrow(disagreements)))
    for (i in seq_len(min(10, nrow(disagreements)))) {
      d <- disagreements[i, ]
      cat(sprintf("\n  Claim #%d [%s]: LLM=%s, Human=%s\n",
                  d$claim_id, d$category,
                  if (d$is_securitising) "SEC" else "NOT",
                  if (d$human_is_securitising) "SEC" else "NOT"))
      cat(sprintf("  Term: %s | Sentence: %.100s...\n",
                  d$matched_term, d$sentence))
      cat(sprintf("  LLM rationale: %s\n", d$rationale))
    }
  }

  # Confidence calibration
  if (any(!is.na(coded$confidence))) {
    cat(sprintf("\n--- LLM confidence vs accuracy ---\n"))
    for (conf in 1:3) {
      conf_rows <- coded %>% filter(confidence == conf)
      if (nrow(conf_rows) > 0) {
        agree <- sum(conf_rows$is_securitising == conf_rows$human_is_securitising,
                     na.rm = TRUE)
        cat(sprintf("  Confidence %d: %d claims, %.1f%% agreement\n",
                    conf, nrow(conf_rows), 100 * agree / nrow(conf_rows)))
      }
    }
  }

  cat("\n", strrep("=", 65), "\n")

  invisible(list(
    n = nrow(coded),
    agreement = sec_agree / nrow(coded),
    precision = precision,
    recall = recall,
    f1 = f1,
    kappa = kappa
  ))
}

# ── Print coding summary ─────────────────────────────────

print_coding_summary <- function(coded_df) {
  cat("\n", strrep("=", 65), "\n")
  cat("LLM SECURITISATION CODING SUMMARY\n")
  cat(strrep("=", 65), "\n")

  coded <- coded_df %>% filter(!is.na(is_securitising))
  cat(sprintf("\nTotal claims coded: %d\n", nrow(coded)))

  # Category correctness
  cat_correct <- sum(coded$category_correct == TRUE, na.rm = TRUE)
  cat(sprintf("Category correct:   %d/%d (%.1f%%)\n",
              cat_correct, nrow(coded), 100 * cat_correct / nrow(coded)))

  # Securitising
  sec <- sum(coded$is_securitising == TRUE, na.rm = TRUE)
  cat(sprintf("Securitising moves: %d/%d (%.1f%%)\n",
              sec, nrow(coded), 100 * sec / nrow(coded)))

  # By type
  cat("\n--- By securitisation type ---\n")
  type_tab <- coded %>%
    filter(is_securitising == TRUE) %>%
    count(securitisation_type, sort = TRUE)
  for (i in seq_len(nrow(type_tab))) {
    cat(sprintf("  %-15s %d\n", type_tab$securitisation_type[i], type_tab$n[i]))
  }

  # By referent object
  cat("\n--- By referent object ---\n")
  ref_tab <- coded %>%
    filter(is_securitising == TRUE) %>%
    count(referent_object, sort = TRUE)
  for (i in seq_len(nrow(ref_tab))) {
    cat(sprintf("  %-15s %d\n", ref_tab$referent_object[i], ref_tab$n[i]))
  }

  # By threat actor
  cat("\n--- By threat actor ---\n")
  actor_tab <- coded %>%
    filter(is_securitising == TRUE) %>%
    count(threat_actor, sort = TRUE)
  for (i in seq_len(nrow(actor_tab))) {
    cat(sprintf("  %-15s %d\n", actor_tab$threat_actor[i], actor_tab$n[i]))
  }

  # By category
  cat("\n--- Securitisation rate by keyword category ---\n")
  by_cat <- coded %>%
    group_by(category) %>%
    summarise(
      total = n(),
      correct = sum(category_correct == TRUE, na.rm = TRUE),
      securitising = sum(is_securitising == TRUE, na.rm = TRUE),
      .groups = "drop"
    )
  for (i in seq_len(nrow(by_cat))) {
    r <- by_cat[i, ]
    cat(sprintf("  %-25s n=%d  correct=%.0f%%  securitising=%.0f%%\n",
                r$category, r$total,
                100 * r$correct / r$total,
                100 * r$securitising / r$total))
  }

  # Confidence distribution
  cat("\n--- LLM confidence distribution ---\n")
  conf_tab <- table(coded$confidence, useNA = "ifany")
  for (i in seq_along(conf_tab)) {
    cat(sprintf("  Level %s: %d (%.0f%%)\n",
                names(conf_tab)[i], conf_tab[i],
                100 * conf_tab[i] / nrow(coded)))
  }

  cat("\n", strrep("=", 65), "\n")
}

# ── Main entry point ─────────────────────────────────────

run_llm_coding <- function(api_key = Sys.getenv("ANTHROPIC_API_KEY")) {
  cat("Preparing relevant claims...\n")
  claims <- prepare_relevant_claims()

  # Add juncture column
  claims$juncture <- NA_character_
  for (jname in names(JUNCTURES)) {
    jrange <- JUNCTURES[[jname]]
    mask <- !is.na(claims$doc_date) & claims$doc_date >= jrange[1] & claims$doc_date <= jrange[2]
    claims$juncture[mask] <- jname
  }

  cat("\nStarting LLM coding...\n")
  cat(sprintf("Model: %s\n", LLM_CONFIG$model))
  cat(sprintf("Estimated cost: ~$%.2f (at $2/$10 per MTok)\n\n",
              nrow(claims) * (1500 * 2 + 200 * 10) / 1e6))

  coded <- code_claims_batch(claims, api_key)

  cat("\nMerging results...\n")
  merged <- merge_coded_claims(claims)

  cat("\nExporting...\n")
  export_coded(merged)

  print_coding_summary(merged)

  cat("\nNext steps:\n")
  cat("  1. Review the summary above\n")
  cat("  2. Run: audit <- prepare_audit_sample(merged, n = 50)\n")
  cat("  3. Code the audit sample manually\n")
  cat("  4. Run: compute_agreement('output/audit_sample.csv')\n")
  cat("  5. Report the agreement statistics in your methodology chapter\n")

  invisible(merged)
}
