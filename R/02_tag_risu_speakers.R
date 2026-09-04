# ──────────────────────────────────────────────────────────
# 02_tag_risu_speakers.R — Tag RISU articles by speaker attribution
#
# Scans RISU corpus files and tags each with a speaker_attribution
# field: "poroshenko" if the article contains direct speech or
# statements attributable to Poroshenko, "none" otherwise.
# Articles tagged "none" remain useful as evidence of government
# measures/practices but are not attributed to a securitising actor.
#
# Usage:
#   source("01_config.R")
#   source("02_tag_risu_speakers.R")
#   tag_risu_speakers()
# ──────────────────────────────────────────────────────────

library(jsonlite)
library(stringr)

if (!exists("CORPUS_DIR")) source(file.path("R", "01_config.R"))

# Ukrainian speech verbs and attribution patterns near "Порошенко" / "Poroshenko"
POROSHENKO_PATTERNS <- c(
  # Name variants (Ukrainian)
  "Порошенко",
  "Петро Порошенко",
  "П\\.\\s*Порошенко",
  "президент Порошенко",
  "Президент Порошенко",
  "п'ятий президент",
  "п'ятого президента",
  # Name variants (transliterated in URL slugs)
  "poroshenko"
)

# Patterns that indicate direct speech / attribution
SPEECH_PATTERNS_UK <- c(
  "Порошенко\\s+(заявив|сказав|наголосив|зазначив|підкреслив|повідомив|додав|написав|звернувся|закликав|вважає|переконаний|пояснив|констатував|попередив|відзначив|привітав|подякував|запропонував|нагадав|розповів|зауважив|стверджує|вимагає|просить|каже|вказав|висловив|оголосив|анонсував|заявляє|вітає)",
  "Порошенко[^.]{0,30}(сказав|заявив|написав|наголосив|зазначив|підкреслив)",
  "—\\s*Порошенко",
  "Порошенко\\s*:",
  "за\\s+словами\\s+Порошенк",
  "як\\s+заявив\\s+Порошенко",
  "як\\s+сказав\\s+Порошенко",
  "як\\s+зазначив\\s+Порошенко",
  "на\\s+думку\\s+Порошенк",
  "Порошенко\\s+у\\s+(зверненні|виступі|промові|заяві|інтерв)",
  "цитат[аує].*Порошенк"
)

# Russian equivalents
SPEECH_PATTERNS_RU <- c(
  "Порошенко\\s+(заявил|сказал|подчеркнул|отметил|сообщил|добавил|написал|обратился|призвал|считает|убежден|объяснил|предупредил|поздравил|предложил|напомнил|рассказал|утверждает|требует|просит|говорит|указал|высказал|объявил|заявляет)",
  "—\\s*Порошенко",
  "Порошенко\\s*:",
  "по\\s+словам\\s+Порошенк",
  "как\\s+заявил\\s+Порошенко",
  "как\\s+сказал\\s+Порошенко"
)

detect_poroshenko_speech <- function(url, title, body) {
  url   <- if (is.null(url))   "" else as.character(url)
  title <- if (is.null(title)) "" else as.character(title)
  body  <- if (is.null(body))  "" else as.character(body)

  full_text <- paste(title, body)

  # Check 1: URL slug starts with "poroshenko"
  slug <- sub("^https?://risu\\.ua/", "", url)
  if (grepl("^poroshenko", slug, ignore.case = TRUE)) return(TRUE)

  # Check 2: Title contains Poroshenko prominently
  if (grepl("Порошенко|Poroshenko", title, ignore.case = TRUE)) {
    # Title mentions him — likely about him, but check for speech attribution
    for (pat in c(SPEECH_PATTERNS_UK, SPEECH_PATTERNS_RU)) {
      if (grepl(pat, full_text, ignore.case = FALSE, perl = TRUE)) return(TRUE)
    }
    # Title has his name + body mentions him multiple times = likely his statements
    poroshenko_count <- str_count(full_text, regex("Порошенко", ignore_case = FALSE))
    if (poroshenko_count >= 3) return(TRUE)
  }

  # Check 3: Body has clear speech attribution patterns
  for (pat in c(SPEECH_PATTERNS_UK, SPEECH_PATTERNS_RU)) {
    if (grepl(pat, full_text, ignore.case = FALSE, perl = TRUE)) return(TRUE)
  }

  # Check 4: Poroshenko appears many times (5+) = article substantially about him
  poroshenko_count <- str_count(full_text, regex("Порошенко", ignore_case = FALSE))
  if (poroshenko_count >= 5) return(TRUE)

  return(FALSE)
}

tag_risu_speakers <- function(corpus_dir = CORPUS_DIR) {
  files <- list.files(corpus_dir, pattern = "\\.json$", full.names = TRUE)

  risu_files <- c()
  for (f in files) {
    d <- tryCatch(fromJSON(f), error = function(e) NULL)
    if (!is.null(d) && !is.null(d$source) && d$source == "risu.ua") {
      risu_files <- c(risu_files, f)
    }
  }

  cat(sprintf("Found %d RISU corpus files\n", length(risu_files)))

  tagged_poroshenko <- 0
  tagged_none       <- 0
  poroshenko_list   <- list()
  none_list         <- list()

  for (f in risu_files) {
    d <- fromJSON(f)

    url   <- if (!is.null(d$url)) d$url else ""
    title <- if (!is.null(d$title)) d$title else ""
    body  <- if (!is.null(d$body_text)) d$body_text else ""

    is_poroshenko <- detect_poroshenko_speech(url, title, body)

    if (is_poroshenko) {
      d$speaker_attribution <- "poroshenko"
      tagged_poroshenko <- tagged_poroshenko + 1
      poroshenko_list[[length(poroshenko_list) + 1]] <- list(
        file = basename(f), title = substr(title, 1, 70)
      )
    } else {
      d$speaker_attribution <- "none"
      tagged_none <- tagged_none + 1
      none_list[[length(none_list) + 1]] <- list(
        file = basename(f), title = substr(title, 1, 70)
      )
    }

    write_json(d, f, auto_unbox = TRUE, pretty = TRUE)
  }

  cat(sprintf("\n%s\nRISU SPEAKER TAGGING SUMMARY\n%s\n", strrep("=", 50), strrep("=", 50)))
  cat(sprintf("Total RISU files:                  %d\n", length(risu_files)))
  cat(sprintf("Tagged as Poroshenko speech:        %d\n", tagged_poroshenko))
  cat(sprintf("Tagged as no direct attribution:    %d\n", tagged_none))

  if (tagged_poroshenko > 0) {
    cat(sprintf("\n%s\nPOROSHENKO-ATTRIBUTED ARTICLES (%d)\n%s\n",
                strrep("-", 50), tagged_poroshenko, strrep("-", 50)))
    for (item in poroshenko_list) {
      cat(sprintf("  %s  %s\n", item$file, item$title))
    }
  }

  if (tagged_none > 0) {
    cat(sprintf("\n%s\nNON-ATTRIBUTED ARTICLES (%d)\n%s\n",
                strrep("-", 50), tagged_none, strrep("-", 50)))
    for (item in none_list) {
      cat(sprintf("  %s  %s\n", item$file, item$title))
    }
  }

  cat("\nTo manually override a tag, run:\n")
  cat('  set_risu_speaker("FILENAME.json", "poroshenko")   # or "none"\n\n')

  invisible(list(poroshenko = poroshenko_list, none = none_list))
}

# Helper to manually override a speaker tag
set_risu_speaker <- function(filename, attribution, corpus_dir = CORPUS_DIR) {
  f <- file.path(corpus_dir, filename)
  if (!file.exists(f)) {
    cat(sprintf("File not found: %s\n", f))
    return(invisible(FALSE))
  }
  if (!(attribution %in% c("poroshenko", "none"))) {
    cat("Attribution must be 'poroshenko' or 'none'\n")
    return(invisible(FALSE))
  }
  d <- fromJSON(f)
  d$speaker_attribution <- attribution
  write_json(d, f, auto_unbox = TRUE, pretty = TRUE)
  cat(sprintf("Set speaker_attribution='%s' on %s (%s)\n",
              attribution, filename, d$title))
  invisible(TRUE)
}
