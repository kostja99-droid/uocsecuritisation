# ──────────────────────────────────────────────────────────
# 06_figures.R — Recreate methodology figures from coded data
#
# Reads llm_coded_full.csv and llm_coded_securitising.csv,
# produces pipeline funnel, source breakdown, securitisation
# type, and temporal distribution figures.
#
# Usage:
#   source("R/06_figures.R")
#   generate_figures()     # saves PNGs to output/figures/
# ──────────────────────────────────────────────────────────

library(dplyr)
library(ggplot2)
library(tidyr)
library(scales)

PIPELINE_NUMBERS <- list(
  scraped = c(
    "President"  = 1780,
    "Rada"       = 2300,
    "SBU"        = 142,
    "RISU"       = 268
  ),
  relevant = c(
    "President"  = 56,
    "Rada"       = 611,
    "SBU"        = 142,
    "RISU"       = 262
  )
)

SOURCE_COLORS <- c(
  "President"  = "#2d5a7b",
  "Rada"       = "#7b5a2d",
  "SBU"        = "#6b3a8a",
  "RISU"       = "#2d7b5a"
)

SOURCE_MAP <- c(
  "president.gov.ua" = "President",
  "rada.gov.ua"      = "Rada",
  "ssu.gov.ua"       = "SBU",
  "sbu.gov.ua"       = "SBU",
  "risu.ua"          = "RISU"
)

theme_thesis <- function() {
  theme_minimal(base_size = 12, base_family = "sans") +
    theme(
      plot.title = element_text(face = "bold", size = 13, margin = margin(b = 8)),
      plot.subtitle = element_text(color = "grey40", size = 10, margin = margin(b = 12)),
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      axis.title = element_text(size = 10),
      legend.position = "bottom",
      legend.title = element_blank(),
      plot.margin = margin(15, 15, 15, 15)
    )
}

generate_figures <- function(output_dir = file.path("output", "figures")) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  coded <- read.csv("output/llm_coded_full.csv", stringsAsFactors = FALSE)
  sec   <- read.csv("output/llm_coded_securitising.csv", stringsAsFactors = FALSE)

  coded$source_label <- SOURCE_MAP[coded$doc_source]
  sec$source_label   <- SOURCE_MAP[sec$doc_source]

  # ── Figure 1: Pipeline funnel by source ──────────────────

  claims_by_source <- coded %>%
    group_by(source_label) %>%
    summarise(claims = n(), .groups = "drop")

  sec_by_source <- sec %>%
    group_by(source_label) %>%
    summarise(sec_claims = n(), .groups = "drop")

  docs_by_source <- coded %>%
    distinct(doc_id, source_label) %>%
    group_by(source_label) %>%
    summarise(docs_coded = n(), .groups = "drop")

  sec_docs_by_source <- sec %>%
    distinct(doc_id, source_label) %>%
    group_by(source_label) %>%
    summarise(sec_docs = n(), .groups = "drop")

  pipeline <- data.frame(
    source = names(PIPELINE_NUMBERS$scraped),
    scraped = unname(PIPELINE_NUMBERS$scraped),
    relevant = unname(PIPELINE_NUMBERS$relevant),
    stringsAsFactors = FALSE
  ) %>%
    left_join(claims_by_source, by = c("source" = "source_label")) %>%
    left_join(sec_by_source, by = c("source" = "source_label")) %>%
    left_join(docs_by_source, by = c("source" = "source_label")) %>%
    left_join(sec_docs_by_source, by = c("source" = "source_label")) %>%
    replace_na(list(claims = 0, sec_claims = 0, docs_coded = 0, sec_docs = 0))

  pipeline_long <- pipeline %>%
    select(source, scraped, relevant, claims, sec_claims) %>%
    pivot_longer(-source, names_to = "stage", values_to = "count") %>%
    mutate(
      stage = factor(stage,
        levels = c("scraped", "relevant", "claims", "sec_claims"),
        labels = c("Scraped", "UOC-Relevant", "Claims Coded", "Securitising")),
      source = factor(source, levels = c("President", "Rada", "SBU", "RISU"))
    )

  p1 <- ggplot(pipeline_long, aes(x = stage, y = count, fill = source)) +
    geom_col(position = "dodge", width = 0.7) +
    geom_text(aes(label = ifelse(count > 0, comma(count), "")),
              position = position_dodge(width = 0.7),
              vjust = -0.4, size = 3) +
    scale_fill_manual(values = SOURCE_COLORS) +
    scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.15))) +
    labs(
      title = "Pipeline Funnel by Source",
      subtitle = "Document flow from scraping to securitisation coding",
      x = NULL, y = "Count"
    ) +
    theme_thesis()

  ggsave(file.path(output_dir, "fig1_pipeline_funnel.png"), p1,
         width = 10, height = 6, dpi = 300, bg = "white")
  cat("Saved fig1_pipeline_funnel.png\n")

  # ── Figure 2: Source breakdown of UOC-relevant corpus ────

  relevant_df <- data.frame(
    source = factor(names(PIPELINE_NUMBERS$relevant),
                    levels = rev(c("Rada", "RISU", "SBU", "President"))),
    docs = unname(PIPELINE_NUMBERS$relevant)
  ) %>%
    mutate(pct = round(100 * docs / sum(docs), 1))

  p2 <- ggplot(relevant_df, aes(x = source, y = docs, fill = source)) +
    geom_col(width = 0.6) +
    geom_text(aes(label = paste0(docs, " (", pct, "%)")),
              hjust = -0.1, size = 3.5) +
    scale_fill_manual(values = SOURCE_COLORS) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.2))) +
    coord_flip() +
    labs(
      title = "UOC-Relevant Documents by Source",
      subtitle = paste0("n = ", comma(sum(relevant_df$docs)), " documents after relevance filtering"),
      x = NULL, y = "Documents"
    ) +
    theme_thesis() +
    theme(legend.position = "none")

  ggsave(file.path(output_dir, "fig2_source_breakdown.png"), p2,
         width = 8, height = 4.5, dpi = 300, bg = "white")
  cat("Saved fig2_source_breakdown.png\n")

  # ── Figure 3: Securitisation type by source ──────────────

  type_source <- sec %>%
    mutate(
      sec_type = case_when(
        securitisation_type == "material" ~ "Material",
        securitisation_type == "ontological" ~ "Ontological",
        securitisation_type == "both" ~ "Both",
        TRUE ~ "Other"
      )
    ) %>%
    group_by(source_label, sec_type) %>%
    summarise(n = n(), .groups = "drop") %>%
    mutate(
      source_label = factor(source_label, levels = c("President", "Rada", "SBU", "RISU")),
      sec_type = factor(sec_type, levels = c("Material", "Ontological", "Both", "Other"))
    )

  type_colors <- c("Material" = "#d4803a", "Ontological" = "#2d5a7b",
                    "Both" = "#4a9e6d", "Other" = "#999999")

  p3 <- ggplot(type_source, aes(x = source_label, y = n, fill = sec_type)) +
    geom_col(position = "stack", width = 0.6) +
    geom_text(aes(label = n), position = position_stack(vjust = 0.5),
              size = 3, color = "white", fontface = "bold") +
    scale_fill_manual(values = type_colors) +
    labs(
      title = "Securitisation Type by Source",
      subtitle = paste0("n = ", nrow(sec), " securitising speech acts"),
      x = NULL, y = "Securitising claims"
    ) +
    theme_thesis()

  ggsave(file.path(output_dir, "fig3_sec_type_by_source.png"), p3,
         width = 8, height = 5.5, dpi = 300, bg = "white")
  cat("Saved fig3_sec_type_by_source.png\n")

  # ── Figure 4: Referent objects ───────────────────────────

  ref_obj <- sec %>%
    group_by(referent_object) %>%
    summarise(n = n(), .groups = "drop") %>%
    arrange(desc(n)) %>%
    mutate(
      referent_object = factor(referent_object, levels = rev(referent_object)),
      pct = round(100 * n / sum(n), 1)
    )

  p4 <- ggplot(ref_obj, aes(x = referent_object, y = n)) +
    geom_col(fill = "#2d5a7b", width = 0.6, alpha = 0.8) +
    geom_text(aes(label = paste0(n, " (", pct, "%)")),
              hjust = -0.1, size = 3.5) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.2))) +
    coord_flip() +
    labs(
      title = "Referent Objects",
      subtitle = "What is framed as needing protection",
      x = NULL, y = "Claims"
    ) +
    theme_thesis()

  ggsave(file.path(output_dir, "fig4_referent_objects.png"), p4,
         width = 8, height = 4, dpi = 300, bg = "white")
  cat("Saved fig4_referent_objects.png\n")

  # ── Figure 5: Threat actors ─────────────────────────────

  threat <- sec %>%
    group_by(threat_actor) %>%
    summarise(n = n(), .groups = "drop") %>%
    arrange(desc(n)) %>%
    mutate(
      threat_actor = factor(threat_actor, levels = rev(threat_actor)),
      pct = round(100 * n / sum(n), 1)
    )

  p5 <- ggplot(threat, aes(x = threat_actor, y = n)) +
    geom_col(fill = "#6b3a8a", width = 0.6, alpha = 0.8) +
    geom_text(aes(label = paste0(n, " (", pct, "%)")),
              hjust = -0.1, size = 3.5) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.2))) +
    coord_flip() +
    labs(
      title = "Threat Actors",
      subtitle = "Who/what is framed as the source of threat",
      x = NULL, y = "Claims"
    ) +
    theme_thesis()

  ggsave(file.path(output_dir, "fig5_threat_actors.png"), p5,
         width = 8, height = 4, dpi = 300, bg = "white")
  cat("Saved fig5_threat_actors.png\n")

  # ── Figure 6: Temporal distribution ─────────────────────

  sec_year <- sec %>%
    filter(!is.na(year) & year != "NA" & year != "") %>%
    mutate(year = as.integer(year)) %>%
    filter(year >= 2014 & year <= 2025) %>%
    group_by(year, source_label) %>%
    summarise(n = n(), .groups = "drop") %>%
    mutate(source_label = factor(source_label, levels = c("President", "Rada", "SBU", "RISU")))

  p6 <- ggplot(sec_year, aes(x = year, y = n, fill = source_label)) +
    geom_col(position = "stack", width = 0.7) +
    annotate("rect", xmin = 2017.5, xmax = 2019.5, ymin = -Inf, ymax = Inf,
             alpha = 0.08, fill = "#2d5a7b") +
    annotate("text", x = 2018.5, y = max(sec_year %>% group_by(year) %>%
             summarise(t = sum(n)) %>% pull(t)) * 0.95,
             label = "J1", size = 3, color = "#2d5a7b", fontface = "bold") +
    annotate("rect", xmin = 2021.7, xmax = 2024.1, ymin = -Inf, ymax = Inf,
             alpha = 0.08, fill = "#d4803a") +
    annotate("text", x = 2022.9, y = max(sec_year %>% group_by(year) %>%
             summarise(t = sum(n)) %>% pull(t)) * 0.95,
             label = "J2-J3", size = 3, color = "#d4803a", fontface = "bold") +
    scale_fill_manual(values = SOURCE_COLORS) +
    scale_x_continuous(breaks = 2014:2025) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.1))) +
    labs(
      title = "Securitising Speech Acts Over Time",
      subtitle = "By source and year (excludes undated SBU documents)",
      x = NULL, y = "Securitising claims"
    ) +
    theme_thesis() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

  ggsave(file.path(output_dir, "fig6_temporal.png"), p6,
         width = 10, height = 5.5, dpi = 300, bg = "white")
  cat("Saved fig6_temporal.png\n")

  # ── Figure 7: Extraordinary measures ────────────────────

  measures <- sec %>%
    group_by(extraordinary_measure) %>%
    summarise(n = n(), .groups = "drop") %>%
    arrange(desc(n)) %>%
    mutate(
      extraordinary_measure = factor(extraordinary_measure,
                                     levels = rev(extraordinary_measure)),
      pct = round(100 * n / sum(n), 1)
    )

  p7 <- ggplot(measures, aes(x = extraordinary_measure, y = n)) +
    geom_col(fill = "#d4803a", width = 0.6, alpha = 0.8) +
    geom_text(aes(label = paste0(n, " (", pct, "%)")),
              hjust = -0.1, size = 3.5) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.2))) +
    coord_flip() +
    labs(
      title = "Extraordinary Measures",
      subtitle = "Actions proposed or enacted in securitising speech acts",
      x = NULL, y = "Claims"
    ) +
    theme_thesis()

  ggsave(file.path(output_dir, "fig7_measures.png"), p7,
         width = 8, height = 4, dpi = 300, bg = "white")
  cat("Saved fig7_measures.png\n")

  # ── Summary table ───────────────────────────────────────

  cat(sprintf("\n%s\nSUMMARY\n%s\n", strrep("=", 50), strrep("=", 50)))
  cat(sprintf("Total claims coded: %d\n", nrow(coded)))
  cat(sprintf("Securitising claims: %d (%.1f%%)\n",
              nrow(sec), 100 * nrow(sec) / nrow(coded)))
  cat(sprintf("Documents with securitisation: %d / %d\n",
              n_distinct(sec$doc_id), n_distinct(coded$doc_id)))
  cat(sprintf("\nPipeline numbers:\n"))
  print(pipeline)
  cat(sprintf("\nAll figures saved to %s/\n", output_dir))

  invisible(pipeline)
}
