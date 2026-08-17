# ──────────────────────────────────────────────────────────
# 03_analyse.R — Corpus analysis with udpipe lemmatisation
#
# This is the core analysis module. It:
#   1. Loads all scraped documents.
#   2. Annotates each with udpipe (tokenisation + lemmatisation).
#   3. Matches seed-term lemmas against the lemmatised text.
#   4. Extracts claims (sentences containing matches).
#   5. Computes summary statistics by year and juncture.
#
# Usage:
#   source("R/01_config.R")
#   source("R/03_analyse.R")
#   results <- analyse_corpus()
# ──────────────────────────────────────────────────────────

library(udpipe)
library(dplyr)
library(tidyr)
library(stringr)
library(jsonlite)
library(purrr)

# ── Load the udpipe model ────────────────────────────────
load_udpipe_model <- function() {
  model_files <- list.files("models", pattern = "\\.udpipe$", full.names = TRUE)
  if (length(model_files) == 0) {
    stop("No udpipe model found. Run 00_setup.R first.")
  }
  udpipe_load_model(model_files[1])
}

# ── Load corpus from disk ────────────────────────────────
load_corpus <- function(corpus_dir = CORPUS_DIR) {
  if (!dir.exists(corpus_dir)) {
    stop(sprintf("Corpus directory not found: %s\nRun the scraper first.", corpus_dir))
  }
  files <- list.files(corpus_dir, pattern = "\\.json$", full.names = TRUE)
  if (length(files) == 0) stop("No documents in corpus directory.")

  docs <- lapply(files, function(f) {
    tryCatch(fromJSON(f), error = function(e) NULL)
  })
  docs <- Filter(Negate(is.null), docs)
  docs <- Filter(function(d) !is.null(d$body_text) && nchar(d$body_text) > 0, docs)

  cat(sprintf("Loaded %d documents from %s\n", length(docs), corpus_dir))
  docs
}

# ── Annotate a document with udpipe ──────────────────────
annotate_document <- function(text, model, doc_id = "doc") {
  if (is.na(text) || nchar(trimws(text)) == 0) return(NULL)

  annotation <- udpipe_annotate(
    model,
    x          = text,
    doc_id     = doc_id,
    tokenizer  = "tokenizer",
    tagger     = "default",
    parser     = "none"     # skip dependency parsing for speed
  )
  as.data.frame(annotation, detailed = TRUE)
}

# ── Build a flat lookup of all seed term lemmas ──────────
build_term_lookup <- function() {
  lookup <- list()
  for (cat_name in names(SEED_TERMS)) {
    cat_data <- SEED_TERMS[[cat_name]]

    # Single-word terms
    for (lang in c("uk", "ru")) {
      key <- paste0("terms_", lang)
      if (!is.null(cat_data[[key]])) {
        for (term in cat_data[[key]]) {
          lookup[[length(lookup) + 1]] <- list(
            category = cat_name,
            lemma    = tolower(term),
            lang     = lang,
            type     = "single"
          )
        }
      }
    }

    # Multi-word terms
    for (lang in c("uk", "ru")) {
      key <- paste0("multiword_", lang)
      if (!is.null(cat_data[[key]])) {
        for (term in cat_data[[key]]) {
          words <- tolower(strsplit(term, "\\s+")[[1]])
          lookup[[length(lookup) + 1]] <- list(
            category = cat_name,
            lemma    = words,
            lang     = lang,
            type     = "multi",
            n_words  = length(words)
          )
        }
      }
    }
  }
  lookup
}

# ── Match terms against an annotated document ────────────
match_terms_in_annotation <- function(ann_df, term_lookup) {
  if (is.null(ann_df) || nrow(ann_df) == 0) return(list())

  ann_df$lemma_lower <- tolower(ann_df$lemma)
  matches <- list()

  # Single-word matches
  single_terms <- Filter(function(t) t$type == "single", term_lookup)
  single_lemmas <- sapply(single_terms, function(t) t$lemma)
  single_cats   <- sapply(single_terms, function(t) t$category)
  single_langs  <- sapply(single_terms, function(t) t$lang)

  hit_rows <- which(ann_df$lemma_lower %in% single_lemmas)
  for (row_idx in hit_rows) {
    lemma_val <- ann_df$lemma_lower[row_idx]
    which_terms <- which(single_lemmas == lemma_val)
    for (ti in which_terms) {
      matches[[length(matches) + 1]] <- list(
        category       = single_cats[ti],
        matched_lemma  = single_lemmas[ti],
        lang           = single_langs[ti],
        surface_form   = ann_df$token[row_idx],
        sentence_id    = ann_df$sentence_id[row_idx],
        token_id       = ann_df$token_id[row_idx]
      )
    }
  }

  # Multi-word matches (consecutive lemma sequences)
  multi_terms <- Filter(function(t) t$type == "multi", term_lookup)
  for (mt in multi_terms) {
    n <- mt$n_words
    for (i in seq_len(nrow(ann_df) - n + 1)) {
      window <- ann_df$lemma_lower[i:(i + n - 1)]
      # Only match within the same sentence
      sids <- ann_df$sentence_id[i:(i + n - 1)]
      if (length(unique(sids)) > 1) next
      if (all(window == mt$lemma)) {
        surface <- paste(ann_df$token[i:(i + n - 1)], collapse = " ")
        matches[[length(matches) + 1]] <- list(
          category       = mt$category,
          matched_lemma  = paste(mt$lemma, collapse = " "),
          lang           = mt$lang,
          surface_form   = surface,
          sentence_id    = sids[1],
          token_id       = ann_df$token_id[i]
        )
      }
    }
  }

  matches
}

# ── Reconstruct original sentences from annotation ──────
reconstruct_sentences <- function(ann_df) {
  if (is.null(ann_df) || nrow(ann_df) == 0) return(character())

  ann_df %>%
    group_by(sentence_id) %>%
    summarise(
      sentence = paste(token, collapse = " "),
      .groups = "drop"
    ) %>%
    arrange(as.integer(sentence_id)) %>%
    pull(sentence)
}

# ── Analyse a single document ────────────────────────────
analyse_one_document <- function(doc, model, term_lookup) {
  ann_df <- annotate_document(doc$body_text, model, doc$id)
  if (is.null(ann_df)) {
    return(list(
      id = doc$id, url = doc$url, title = doc$title,
      date = doc$date, content_type = doc$content_type,
      word_count = doc$word_count,
      matched_categories = character(),
      matched_terms = list(),
      match_count = 0L,
      claims = list(),
      is_relevant = FALSE,
      sentence_count = 0L
    ))
  }

  matches <- match_terms_in_annotation(ann_df, term_lookup)
  sentences <- reconstruct_sentences(ann_df)

  # Build claims with context
  claims <- list()
  matched_categories <- unique(sapply(matches, function(m) m$category))
  matched_terms_by_cat <- list()

  # Deduplicate matches by (category, sentence_id, surface_form)
  seen <- character()
  for (m in matches) {
    dedup_key <- paste(m$category, m$sentence_id, m$surface_form, sep = "|")
    if (dedup_key %in% seen) next
    seen <- c(seen, dedup_key)

    sid <- as.integer(m$sentence_id)
    sentence_text <- if (sid <= length(sentences)) sentences[sid] else ""
    context_before <- if (sid > 1) sentences[sid - 1] else ""
    context_after  <- if (sid < length(sentences)) sentences[sid + 1] else ""

    # Track terms per category
    cat_name <- m$category
    if (is.null(matched_terms_by_cat[[cat_name]])) {
      matched_terms_by_cat[[cat_name]] <- character()
    }
    if (!(m$matched_lemma %in% matched_terms_by_cat[[cat_name]])) {
      matched_terms_by_cat[[cat_name]] <- c(matched_terms_by_cat[[cat_name]], m$matched_lemma)
    }

    claims[[length(claims) + 1]] <- list(
      doc_id            = doc$id,
      doc_title         = doc$title,
      doc_date          = doc$date,
      doc_url           = doc$url,
      content_type      = doc$content_type,
      category          = m$category,
      matched_term_lemma = m$matched_lemma,
      matched_term_lang = m$lang,
      matched_surface_form = m$surface_form,
      sentence          = sentence_text,
      sentence_index    = sid,
      context_before    = context_before,
      context_after     = context_after
    )
  }

  # Relevant = has church term + at least one other category
  has_church <- "church_actors" %in% matched_categories
  has_other  <- length(setdiff(matched_categories, "church_actors")) > 0
  is_relevant <- has_church && has_other

  list(
    id                 = doc$id,
    url                = doc$url,
    title              = doc$title,
    date               = doc$date,
    content_type       = doc$content_type,
    word_count         = doc$word_count,
    matched_categories = matched_categories,
    matched_terms      = matched_terms_by_cat,
    match_count        = length(claims),
    claims             = claims,
    is_relevant        = is_relevant,
    sentence_count     = length(sentences)
  )
}

# ── Compute summary statistics ───────────────────────────
compute_summary <- function(results) {
  n_total    <- length(results)
  speeches   <- Filter(function(r) r$content_type == "speech", results)
  press      <- Filter(function(r) r$content_type == "press_release", results)
  relevant   <- Filter(function(r) r$is_relevant, results)
  rel_speech <- Filter(function(r) r$content_type == "speech", relevant)
  rel_press  <- Filter(function(r) r$content_type == "press_release", relevant)

  # All claims
  all_claims <- unlist(lapply(results, function(r) r$claims), recursive = FALSE)

  # Claims by category
  claim_cats <- table(sapply(all_claims, function(c) c$category))

  # Claims by term
  claim_terms <- table(sapply(all_claims, function(c) c$matched_term_lemma))
  claim_terms <- sort(claim_terms, decreasing = TRUE)

  # Yearly breakdown
  years <- sapply(results, function(r) {
    if (!is.na(r$date) && nchar(r$date) >= 4) substr(r$date, 1, 4) else "unknown"
  })
  yearly <- data.frame(year = years, stringsAsFactors = FALSE)
  yearly$type <- sapply(results, function(r) r$content_type)
  yearly$is_relevant <- sapply(results, function(r) r$is_relevant)
  yearly$n_claims <- sapply(results, function(r) length(r$claims))

  yearly_summary <- yearly %>%
    group_by(year) %>%
    summarise(
      total_docs = n(),
      speeches   = sum(type == "speech"),
      press_releases = sum(type == "press_release"),
      relevant_docs  = sum(is_relevant),
      total_claims   = sum(n_claims),
      .groups = "drop"
    ) %>%
    arrange(year)

  # Juncture breakdown
  juncture_summary <- lapply(names(JUNCTURES), function(jname) {
    jrange <- JUNCTURES[[jname]]
    j_results <- Filter(function(r) {
      !is.na(r$date) && r$date >= jrange[1] && r$date <= jrange[2]
    }, results)
    j_relevant <- Filter(function(r) r$is_relevant, j_results)
    j_claims   <- sum(sapply(j_results, function(r) length(r$claims)))
    data.frame(
      juncture      = jname,
      date_range    = paste(jrange, collapse = " to "),
      total_docs    = length(j_results),
      relevant_docs = length(j_relevant),
      total_claims  = j_claims,
      stringsAsFactors = FALSE
    )
  })
  juncture_df <- bind_rows(juncture_summary)

  list(
    overview = list(
      total_documents   = n_total,
      total_speeches    = length(speeches),
      total_press       = length(press),
      relevant_docs     = length(relevant),
      relevant_speeches = length(rel_speech),
      relevant_press    = length(rel_press),
      total_claims      = length(all_claims),
      unique_sentences  = length(unique(sapply(all_claims, function(c) c$sentence)))
    ),
    claims_by_category = as.data.frame(claim_cats),
    top_terms          = head(as.data.frame(claim_terms), 30),
    yearly_breakdown   = yearly_summary,
    juncture_breakdown = juncture_df,
    all_claims         = all_claims
  )
}

# ── Print summary ────────────────────────────────────────
print_summary <- function(summary) {
  ov <- summary$overview
  cat("\n", strrep("=", 70), "\n")
  cat("CORPUS ANALYSIS SUMMARY\n")
  cat(strrep("=", 70), "\n")

  cat("\n1. TOTAL DOCUMENTS SCRAPED\n")
  cat(sprintf("   Speeches:        %6d\n", ov$total_speeches))
  cat(sprintf("   Press releases:  %6d\n", ov$total_press))
  cat(sprintf("   TOTAL:           %6d\n", ov$total_documents))

  cat("\n2. DOCUMENTS CONTAINING RELEVANT TERMS\n")
  cat("   (= contains church/religion term + at least one securitisation term)\n")
  cat(sprintf("   Speeches:        %6d\n", ov$relevant_speeches))
  cat(sprintf("   Press releases:  %6d\n", ov$relevant_press))
  cat(sprintf("   TOTAL:           %6d\n", ov$relevant_docs))

  cat("\n3. CLAIMS (sentences with matched terms)\n")
  cat(sprintf("   Total claims:         %6d\n", ov$total_claims))
  cat(sprintf("   Unique sentences:     %6d\n", ov$unique_sentences))

  cat("\n4. CLAIMS BY CODING DIMENSION\n")
  if (nrow(summary$claims_by_category) > 0) {
    for (i in seq_len(nrow(summary$claims_by_category))) {
      cat_name <- as.character(summary$claims_by_category$Var1[i])
      count    <- summary$claims_by_category$Freq[i]
      desc <- SEED_TERMS[[cat_name]]$description
      if (is.null(desc)) desc <- cat_name
      cat(sprintf("   %-50s %6d\n", desc, count))
    }
  }

  cat("\n5. TOP 15 MATCHED TERMS\n")
  top <- head(summary$top_terms, 15)
  if (nrow(top) > 0) {
    for (i in seq_len(nrow(top))) {
      cat(sprintf("   %-40s %6d\n", as.character(top$Var1[i]), top$Freq[i]))
    }
  }

  cat("\n6. YEARLY BREAKDOWN\n")
  cat(sprintf("   %-8s %6s %9s %6s %9s %7s\n",
              "Year", "Total", "Speeches", "Press", "Relevant", "Claims"))
  cat(sprintf("   %s\n", strrep("-", 50)))
  for (i in seq_len(nrow(summary$yearly_breakdown))) {
    r <- summary$yearly_breakdown[i, ]
    cat(sprintf("   %-8s %6d %9d %6d %9d %7d\n",
                r$year, r$total_docs, r$speeches,
                r$press_releases, r$relevant_docs, r$total_claims))
  }

  cat("\n7. JUNCTURE BREAKDOWN\n")
  for (i in seq_len(nrow(summary$juncture_breakdown))) {
    j <- summary$juncture_breakdown[i, ]
    cat(sprintf("   %s\n", j$juncture))
    cat(sprintf("     Period:    %s\n", j$date_range))
    cat(sprintf("     Documents: %d  Relevant: %d  Claims: %d\n",
                j$total_docs, j$relevant_docs, j$total_claims))
  }
  cat("\n", strrep("=", 70), "\n")
}

# ── Main analysis function ───────────────────────────────
analyse_corpus <- function(corpus_dir = CORPUS_DIR) {
  docs <- load_corpus(corpus_dir)

  cat("\nLoading Ukrainian udpipe model...\n")
  model <- load_udpipe_model()

  cat("Building term lookup...\n")
  term_lookup <- build_term_lookup()
  cat(sprintf("  %d term entries across %d categories\n",
              length(term_lookup), length(SEED_TERMS)))

  cat(sprintf("\nAnnotating and analysing %d documents...\n", length(docs)))
  results <- list()
  for (i in seq_along(docs)) {
    results[[i]] <- analyse_one_document(docs[[i]], model, term_lookup)
    if (i %% 25 == 0) cat(sprintf("  Processed %d/%d...\n", i, length(docs)))
  }
  cat(sprintf("  Done. Processed %d documents.\n", length(docs)))

  # Compute summary
  summary <- compute_summary(results)

  # Save outputs
  dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

  # Results (per-document, without full claims for compactness)
  results_slim <- lapply(results, function(r) {
    r$claims <- NULL
    r$claim_count <- r$match_count
    r
  })
  write_json(results_slim, file.path(OUTPUT_DIR, "results.json"),
             auto_unbox = TRUE, pretty = TRUE)
  cat(sprintf("\nPer-document results saved to %s\n",
              file.path(OUTPUT_DIR, "results.json")))

  # Claims
  all_claims <- summary$all_claims
  # Add claim IDs
  for (i in seq_along(all_claims)) all_claims[[i]]$claim_id <- i
  write_json(all_claims, file.path(OUTPUT_DIR, "claims.json"),
             auto_unbox = TRUE, pretty = TRUE)
  cat(sprintf("Claims saved to %s (%d claims)\n",
              file.path(OUTPUT_DIR, "claims.json"), length(all_claims)))

  # Summary (without the claims list)
  summary_out <- summary
  summary_out$all_claims <- NULL
  write_json(summary_out, file.path(OUTPUT_DIR, "summary.json"),
             auto_unbox = TRUE, pretty = TRUE)
  cat(sprintf("Summary saved to %s\n", file.path(OUTPUT_DIR, "summary.json")))

  # Print summary
  print_summary(summary)

  invisible(list(results = results, summary = summary))
}
