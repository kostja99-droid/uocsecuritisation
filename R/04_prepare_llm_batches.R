# ──────────────────────────────────────────────────────────
# 04_prepare_llm_batches.R — Prepare corpus for LLM coding
#
# Loads corpus JSONs, cleans boilerplate, filters for UOC
# relevance, and outputs batch files sized for Claude.ai.
# Also writes the codebook system prompt.
#
# Usage:
#   source("01_config.R")
#   source("04_prepare_llm_batches.R")
#   prepare_llm_batches()
# ──────────────────────────────────────────────────────────

library(jsonlite)
library(stringr)
library(dplyr)

if (!exists("CORPUS_DIR")) source("01_config.R")

# ── Relevance terms (topic filter, NOT analysis keywords) ─
# These just check whether a document is about the UOC topic
# at all. Not used for securitisation coding.
RELEVANCE_TERMS <- c(
  "УПЦ", "упц", "ПЦУ", "пцу", "МП",
  "церкв", "Церкв",
  "томос", "Томос",
  "автокефал", "Автокефал",
  "православн", "Православн",
  "патріарх", "Патріарх",
  "митрополит", "Митрополит",
  "єпарх", "Єпарх",
  "лавр", "Лавр",
  "Онуфрій", "Епіфаній",
  "релігій", "Релігій",
  "монастир", "Монастир",
  "священн", "Священн",
  "парафі", "Парафі",
  "конфесі", "Конфесі",
  "храм", "Храм",
  # Russian equivalents
  "церков", "Церков",
  "патриарх", "Патриарх",
  "митрополит", "Митрополит",
  "монастыр", "Монастыр",
  "православн", "Православн"
)

# ── Clean body text ──────────────────────────────────────
clean_body <- function(text) {
  if (is.null(text) || is.na(text) || nchar(text) == 0) return("")

  # Remove common navigation / boilerplate patterns
  lines <- strsplit(text, "\n")[[1]]

  # Drop lines that are clearly navigation
  nav_patterns <- c(
    "^\\s*$",
    "^(Головна|Новини|Контакти|Про нас|Зв'язатися|Пошук)\\s*$",
    "^(Home|News|Contact|About|Search)\\s*$",
    "^GOV\\.UA",
    "^Офіційний вебпортал",
    "^Електронний кабінет",
    "^(Вхід|Реєстрація|Увійти)",
    "^Календар подій",
    "^\\d{2}\\.\\d{2}\\.\\d{4}$",
    "^(Пн|Вт|Ср|Чт|Пт|Сб|Нд)\\s",
    "^(Copyright|©|Всі права)",
    "^\\s*(Facebook|Twitter|Telegram|YouTube|Instagram)\\s*$",
    "^Поділитися",
    "^Версія для друку"
  )

  for (pat in nav_patterns) {
    lines <- lines[!grepl(pat, lines)]
  }

  text <- paste(lines, collapse = "\n")

  # Collapse multiple whitespace
  text <- str_replace_all(text, "\\n{3,}", "\n\n")
  text <- str_replace_all(text, " {2,}", " ")
  text <- trimws(text)

  text
}

# ── Check UOC relevance (density threshold) ──────────────
# Requires 2+ distinct terms OR 3+ total mentions to qualify
# as substantively about UOC (filters incidental mentions).
is_uoc_relevant <- function(text, title = "", min_distinct = 2, min_total = 3) {
  combined <- paste(title, text)
  hits <- vapply(RELEVANCE_TERMS, function(term) {
    length(str_locate_all(combined, fixed(term))[[1]]) / 2
  }, numeric(1))
  n_distinct <- sum(hits > 0)
  n_total <- sum(hits)
  n_distinct >= min_distinct || n_total >= min_total
}

# ── Estimate token count (rough: 1 Ukrainian word ~ 3.5 tokens)
estimate_tokens <- function(text) {
  n_words <- length(strsplit(text, "\\s+")[[1]])
  as.integer(n_words * 3.5)
}

# ── Smart truncation: keep only UOC-relevant sections ────
# Splits text into sentences, finds those containing UOC
# terms, and keeps a window of context around each hit.
# Short documents (< max_words) are returned as-is.
extract_relevant_sections <- function(text, max_words = 1200, context_sentences = 5) {
  words <- strsplit(text, "\\s+")[[1]]
  if (length(words) <= max_words) return(text)

  # Split into sentences (Ukrainian period/!/? followed by space + capital or newline)
  sentences <- strsplit(text, "(?<=[.!?\\n])\\s+(?=[А-ЯІЇЄҐA-Z\"])", perl = TRUE)[[1]]
  sentences <- trimws(sentences)
  sentences <- sentences[nchar(sentences) > 0]

  if (length(sentences) == 0) return(text)

  # Find which sentences contain UOC-relevant terms
  hit_indices <- which(sapply(sentences, function(s) {
    any(str_detect(s, fixed(RELEVANCE_TERMS)))
  }))

  if (length(hit_indices) == 0) {
    return(paste(words[1:min(max_words, length(words))], collapse = " "))
  }

  # Expand each hit to include context_sentences before and after
  keep <- integer()
  for (idx in hit_indices) {
    window_start <- max(1, idx - context_sentences)
    window_end <- min(length(sentences), idx + context_sentences)
    keep <- c(keep, window_start:window_end)
  }
  keep <- sort(unique(keep))

  # Build output with section breaks where gaps exist
  sections <- list()
  current_section <- keep[1]
  section_start <- keep[1]

  for (i in seq_along(keep)) {
    if (i > 1 && keep[i] > keep[i - 1] + 1) {
      sections[[length(sections) + 1]] <- list(
        start = section_start, end = keep[i - 1]
      )
      section_start <- keep[i]
    }
  }
  sections[[length(sections) + 1]] <- list(
    start = section_start, end = keep[length(keep)]
  )

  # Assemble with markers
  parts <- character()
  for (sec in sections) {
    chunk <- paste(sentences[sec$start:sec$end], collapse = " ")
    if (sec$start > 1) chunk <- paste0("[...] ", chunk)
    if (sec$end < length(sentences)) chunk <- paste0(chunk, " [...]")
    parts <- c(parts, chunk)
  }

  result <- paste(parts, collapse = "\n\n---\n\n")

  # Final safety: if still too long, hard-truncate
  result_words <- strsplit(result, "\\s+")[[1]]
  if (length(result_words) > max_words * 1.5) {
    result <- paste(result_words[1:as.integer(max_words * 1.5)], collapse = " ")
    result <- paste0(result, "\n[... TRUNCATED ...]")
  }

  result
}

# ── Load and prepare corpus ──────────────────────────────
load_and_filter_corpus <- function(corpus_dir = CORPUS_DIR) {
  if (!dir.exists(corpus_dir)) {
    stop(sprintf("Corpus directory not found: %s\nRun the scrapers first.", corpus_dir))
  }

  files <- list.files(corpus_dir, pattern = "\\.json$", full.names = TRUE)
  cat(sprintf("Found %d corpus files\n", length(files)))

  docs <- list()
  skipped_empty <- 0
  skipped_irrelevant <- 0

  for (f in files) {
    d <- tryCatch(fromJSON(f), error = function(e) NULL)
    if (is.null(d)) next
    if (is.null(d$body_text) || nchar(d$body_text) < 100) {
      skipped_empty <- skipped_empty + 1
      next
    }

    cleaned <- clean_body(d$body_text)
    if (nchar(cleaned) < 100) {
      skipped_empty <- skipped_empty + 1
      next
    }

    title <- if (!is.null(d$title)) d$title else ""
    source <- if (!is.null(d$source)) d$source else "unknown"

    # Pre-selected sources (hand-curated for UOC relevance) skip density filter
    curated_sources <- c("risu.ua", "ssu.gov.ua")
    if (!(source %in% curated_sources) && !is_uoc_relevant(cleaned, title)) {
      skipped_irrelevant <- skipped_irrelevant + 1
      next
    }

    truncated <- extract_relevant_sections(cleaned)

    docs[[length(docs) + 1]] <- list(
      id           = if (!is.null(d$id)) d$id else basename(f),
      title        = title,
      date         = if (!is.null(d$date) && !is.na(d$date)) d$date else "unknown",
      source       = source,
      content_type = if (!is.null(d$content_type)) d$content_type else "unknown",
      body         = truncated,
      tokens_est   = estimate_tokens(truncated),
      original_words = length(strsplit(cleaned, "\\s+")[[1]]),
      truncated_words = length(strsplit(truncated, "\\s+")[[1]])
    )
  }

  cat(sprintf("  UOC-relevant: %d\n", length(docs)))
  cat(sprintf("  Skipped (empty/short): %d\n", skipped_empty))
  cat(sprintf("  Skipped (not about UOC): %d\n", skipped_irrelevant))

  # Truncation summary
  orig_total <- sum(vapply(docs, function(d) as.numeric(d$original_words), numeric(1)))
  trunc_total <- sum(vapply(docs, function(d) as.numeric(d$truncated_words), numeric(1)))
  n_truncated <- sum(vapply(docs, function(d) d$original_words > d$truncated_words, logical(1)))
  cat(sprintf("\n  Smart truncation: %d docs trimmed\n", n_truncated))
  cat(sprintf("  Original total: %s words -> Truncated: %s words (%.0f%% reduction)\n",
              format(as.integer(orig_total), big.mark = ","),
              format(as.integer(trunc_total), big.mark = ","),
              100 * (1 - trunc_total / max(orig_total, 1))))

  # Sort by date
  dates <- sapply(docs, function(d) d$date)
  docs <- docs[order(dates)]

  docs
}

# ── Build batch files ────────────────────────────────────
build_batches <- function(docs, max_tokens_per_batch = 80000) {
  batches <- list()
  current_batch <- list()
  current_tokens <- 0

  for (d in docs) {
    doc_tokens <- d$tokens_est

    # If a single document exceeds the limit, truncate it
    if (doc_tokens > max_tokens_per_batch * 0.9) {
      max_words <- as.integer(max_tokens_per_batch * 0.9 / 3.5)
      words <- strsplit(d$body, "\\s+")[[1]]
      d$body <- paste(words[1:min(max_words, length(words))], collapse = " ")
      d$body <- paste0(d$body, "\n[... TRUNCATED ...]")
      doc_tokens <- max_tokens_per_batch * 0.9
    }

    if (current_tokens + doc_tokens > max_tokens_per_batch && length(current_batch) > 0) {
      batches[[length(batches) + 1]] <- current_batch
      current_batch <- list()
      current_tokens <- 0
    }

    current_batch[[length(current_batch) + 1]] <- d
    current_tokens <- current_tokens + doc_tokens
  }

  if (length(current_batch) > 0) {
    batches[[length(batches) + 1]] <- current_batch
  }

  batches
}

# ── Format a batch as text ───────────────────────────────
format_batch <- function(batch, batch_num) {
  header <- sprintf("BATCH %d — %d documents\n%s\n\n",
                     batch_num, length(batch), strrep("=", 60))

  doc_texts <- sapply(batch, function(d) {
    sprintf("=== DOC %s | %s | %s | %s ===\n%s",
            d$id, d$date, d$source, d$title, d$body)
  })

  paste0(header, paste(doc_texts, collapse = "\n\n"))
}

# ── Write the codebook prompt ────────────────────────────
write_codebook_prompt <- function(output_dir) {
  prompt <- '
You are a trained research coder analysing Ukrainian-language political texts for securitisation moves directed at or involving the Ukrainian Orthodox Church (UOC-MP / Moscow Patriarchate).

THEORETICAL FRAMEWORK:
- Copenhagen School securitisation theory: a securitising move identifies a threat, frames it as existential, and calls (explicitly or implicitly) for extraordinary measures beyond normal politics.
- Mitzen\'s ontological security: threats to collective identity, self-narrative, and sense of self — distinct from material/physical threats.

TASK:
For each document provided, identify ALL sentences or passages that constitute potential securitising moves related to the UOC-MP. For each identified passage, code the following fields:

DECISION FIELDS:
1. doc_id: The document ID (from the === DOC header)
2. passage: The exact sentence or short passage (quote it verbatim)
3. is_securitising: TRUE or FALSE — Does this passage constitute a securitising move? TRUE requires: (1) identification of a threat, (2) framing as existential, and (3) implied or explicit call for extraordinary action.
4. securitisation_type: "material" (threat to the physical state), "ontological" (threat to identity/self), "both" (explicitly links material and identity threats), or "neither" (not a securitising move)
5. referent_object: What is being threatened? "state" (the state apparatus), "nation" (the Ukrainian nation/people), "identity" (national identity/culture), "faith" (the "true" Ukrainian faith), or "other"
6. threat_actor: Who is doing the threatening? "UOC-MP" (the UOC-MP specifically), "Russia" (Russia broadly), "internal" (internal enemies/collaborators), "other" (another actor), or "none"
7. extraordinary_measure: What action beyond normal politics is proposed or implied? "ban" (direct ban), "sanction" (personal sanctions), "dissolution" (organisational dissolution), "seizure" (property seizure), "none", or "other"
8. confidence: 1 (uncertain), 2 (fairly confident), 3 (clear case)
9. coder_notes: Any observations, ambiguities, or context worth recording

OUTPUT FORMAT:
Return ONLY valid JSON — an array of objects, one per identified passage. If a document contains no securitising moves, include one entry with is_securitising: false and securitisation_type: "neither".

Example:
```json
[
  {
    "doc_id": "abc123",
    "passage": "[exact quote from text]",
    "is_securitising": true,
    "securitisation_type": "material",
    "referent_object": "state",
    "threat_actor": "UOC-MP",
    "extraordinary_measure": "sanction",
    "confidence": 3,
    "coder_notes": "Direct reference to SBU investigation"
  }
]
```

GUIDELINES:
- Read each document carefully in full before coding.
- A document may contain multiple securitising moves — code each one separately.
- Distinguish between: reporting on events (not securitising) vs. framing events as threats requiring action (securitising).
- SBU press releases often describe enforcement actions — code the framing language, not the factual reporting.
- Rada stenograms may contain speeches by multiple deputies — attribute the securitising move to the document, not the speaker (speaker attribution can be done later).
- Be conservative: when in doubt, code as is_securitising: false with confidence: 1.
- For very long documents, focus on the passages most relevant to UOC-MP securitisation.

Now analyse the following documents:
'

  writeLines(trimws(prompt), file.path(output_dir, "codebook_prompt.txt"))
  cat(sprintf("Codebook prompt saved to %s\n",
              file.path(output_dir, "codebook_prompt.txt")))
}

# ── Main function ────────────────────────────────────────
prepare_llm_batches <- function(corpus_dir = CORPUS_DIR,
                                 output_dir = file.path("data", "llm_batches"),
                                 max_tokens = 80000) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  cat(strrep("=", 60), "\n")
  cat("PREPARING LLM CODING BATCHES\n")
  cat(strrep("=", 60), "\n\n")

  # Load and filter
  docs <- load_and_filter_corpus(corpus_dir)
  if (length(docs) == 0) {
    cat("No relevant documents found. Check corpus directory.\n")
    return(invisible(NULL))
  }

  # Summary by source
  sources <- table(sapply(docs, function(d) d$source))
  cat("\nRelevant documents by source:\n")
  for (s in names(sources)) {
    cat(sprintf("  %-30s %d\n", s, sources[s]))
  }

  total_tokens <- sum(sapply(docs, function(d) d$tokens_est))
  cat(sprintf("\nTotal estimated tokens: %s (~$%.2f with Sonnet)\n",
              format(total_tokens, big.mark = ","),
              total_tokens * 6 / 1e6))  # rough Sonnet input cost

  # Build batches
  batches <- build_batches(docs, max_tokens)
  cat(sprintf("\nSplit into %d batches (max ~%dk tokens each)\n",
              length(batches), as.integer(max_tokens / 1000)))

  # Write batch files
  for (i in seq_along(batches)) {
    batch_text <- format_batch(batches[[i]], i)
    batch_file <- file.path(output_dir, sprintf("batch_%02d.txt", i))
    writeLines(batch_text, batch_file, useBytes = TRUE)

    n_docs <- length(batches[[i]])
    est_tokens <- sum(vapply(batches[[i]], function(d) as.numeric(d$tokens_est), numeric(1)))
    cat(sprintf("  batch_%02d.txt: %d docs, ~%dk tokens\n",
                i, n_docs, as.integer(est_tokens / 1000)))
  }

  # Write the codebook prompt
  write_codebook_prompt(output_dir)

  # Write a manifest
  manifest <- data.frame(
    batch = sprintf("batch_%02d.txt", seq_along(batches)),
    n_docs = vapply(batches, length, integer(1)),
    est_tokens = vapply(batches, function(b) {
      sum(vapply(b, function(d) as.numeric(d$tokens_est), numeric(1)))
    }, numeric(1)),
    doc_ids = vapply(batches, function(b) {
      paste(vapply(b, function(d) as.character(d$id), character(1)), collapse = ", ")
    }, character(1)),
    stringsAsFactors = FALSE
  )
  write.csv(manifest, file.path(output_dir, "manifest.csv"), row.names = FALSE)

  cat(sprintf("\nManifest saved to %s\n", file.path(output_dir, "manifest.csv")))
  cat(sprintf("\n%s\nDONE. Next steps:\n", strrep("=", 60)))
  cat("1. Open Claude.ai (Sonnet)\n")
  cat("2. Paste the contents of codebook_prompt.txt as your first message\n")
  cat("3. Upload batch_01.txt (or paste its contents)\n")
  cat("4. Copy Claude's JSON response -> save as data/llm_results/batch_01.json\n")
  cat("5. Repeat for each batch\n")
  cat("6. Run: source('05_import_llm_results.R'); merge_llm_results()\n")
  cat(strrep("=", 60), "\n")

  invisible(list(docs = docs, batches = batches, manifest = manifest))
}
