# flores_coppock_2018/ground_truth/build_ground_truth.R
# Output: ground_truth/flores_coppock_2018_ground_truth.csv
# Depends on: ground_truth/published_values.csv, ground_truth/archive_values.csv,
#   ground_truth/archive_figure_estimates.csv, maintained/output/ (run run_all.R first)
# Description: Assemble the ground truth table. One row per published quantity, carrying
#   the value the article prints, the value the deposited scripts produce, and the value
#   the maintained rewrite computes.
#
#   Nothing here is typed. value_paper comes from published_values.csv, which is parsed
#   from the article and appendix PDFs by extract_published_values.R. value_script comes
#   from archive_values.csv, parsed from the deposited scripts' own output by
#   extract_archive_values.R. value_rewrite is read back out of maintained/output/, so
#   the table cannot drift from the pipeline. No published value is an input to any
#   computation here or anywhere in maintained/.

library(here)
library(tidyverse)

here::i_am("ground_truth/build_ground_truth.R")

published <- read_csv(here::here("ground_truth", "published_values.csv"), show_col_types = FALSE)
archive <- read_csv(here::here("ground_truth", "archive_values.csv"), show_col_types = FALSE)

out <- function(f) read_csv(here::here("maintained", "output", f), show_col_types = FALSE)

# The rewrite's values, keyed the same way as the two sides above ----
# Every coefficient row contributes an estimate, a standard error and a sample size.
term_stat <- function(term) {
  case_when(
    str_detect(term, ":") ~ "interaction",
    term %in% c("Z_ad", "Z_vela", "Z_coffman") ~ "Z_ad",
    term == "Z_survey" ~ "Z_survey",
    term == "(Intercept)" ~ "constant"
  )
}

main_tables <- list(
  table_5 = "table_5_general_election.csv",
  table_6 = "table_6_like_candidate.csv",
  table_7 = "table_7_candidate_cares.csv",
  table_8 = "table_8_confidence.csv"
)

# The three appendix scripts each write four tables into one file, so their table label
# comes from a column rather than from the file name.
a1_a4 <- out("tables_a1_a4_interaction.csv") |>
  mutate(table_figure = paste0("table_", table), column = paste0(candidate, "_bilingual"),
         stat = term_stat(term)) |>
  select(table_figure, column, stat, estimate, std.error, n)
b5_b8 <- out("tables_b5_b8_pid.csv") |>
  mutate(table_figure = paste0("table_", table),
         column = paste(candidate, sample, party, sep = "_"), stat = term_stat(term)) |>
  select(table_figure, column, stat, estimate, std.error, n)
c9_c10 <- out("tables_c9_c10_logit.csv") |>
  mutate(table_figure = paste0("table_", table),
         column = paste(candidate, sample, sep = "_"), stat = term_stat(term)) |>
  select(table_figure, column, stat, estimate, std.error, n,
         log_likelihood, aic)

long_coefs <- function(dat) {
  dat |>
    pivot_longer(any_of(c("estimate", "std.error", "n", "log_likelihood", "aic")),
                 names_to = "which", values_to = "value_rewrite") |>
    mutate(stat = case_when(
      which == "estimate" ~ stat,
      which == "std.error" ~ paste0(stat, "_se"),
      which == "n" ~ "N",
      .default = which
    )) |>
    select(table_figure, column, stat, value_rewrite) |>
    distinct(table_figure, column, stat, .keep_all = TRUE)
}

rewrite <- bind_rows(
  imap(main_tables,
       \(f, tab) out(f) |>
         mutate(table_figure = tab, column = paste(candidate, sample, sep = "_"),
                stat = term_stat(term)) |>
         select(table_figure, column, stat, estimate, std.error, n) |>
         long_coefs()) |>
    list_rbind(),
  out("table_9_linked_fate.csv") |>
    mutate(table_figure = "table_9", column = experiment, stat = term_stat(term)) |>
    select(table_figure, column, stat, estimate, std.error, n) |>
    long_coefs(),
  long_coefs(a1_a4),
  long_coefs(b5_b8),
  long_coefs(c9_c10)
)

# Table 2, which the deposit has no script for ----
table_2 <- out("table_2_sample_comparison.csv") |>
  pivot_longer(c(mean, se), names_to = "which", values_to = "value_rewrite") |>
  filter(!is.na(value_rewrite)) |>
  transmute(table_figure = "table_2", column = "lucid",
            stat = if_else(which == "se", paste0(quantity, "_se"), quantity),
            value_rewrite)

# Table 3, the cell counts and the balance test ----
table_3 <- bind_rows(
  out("table_3_randomization.csv") |>
    pivot_longer(c(english_ad, spanish_ad), names_to = "stat", values_to = "value_rewrite") |>
    transmute(table_figure = "table_3", column = paste(block, survey_language, sep = "_"),
              stat, value_rewrite),
  out("table_3_chisq.csv") |>
    transmute(chi_sq = statistic, df, p_value) |>
    pivot_longer(everything(), names_to = "stat", values_to = "value_rewrite") |>
    mutate(table_figure = "table_3", column = "balance")
)

# Numbers stated in prose ----
claims <- out("text_in_text_claims.csv")

text_rows <- claims |>
  filter(!str_starts(claim, "appendixC_ame_minus_ols")) |>
  pivot_longer(c(estimate_pp, std_error_pp), names_to = "which", values_to = "value_rewrite") |>
  transmute(table_figure = "text", column = claim,
            stat = if_else(which == "estimate_pp", "estimate", "std_error"),
            value_rewrite)

# The appendix says the logit average marginal effects "match the OLS models to the
# second decimal place or better", which is a claim about a gap rather than a value. It
# is recorded as the largest absolute gap across the ten models, which has to fall below
# half a hundredth for the sentence to hold.
worst_ame_gap <- claims |>
  filter(str_starts(claim, "appendixC_ame_minus_ols")) |>
  summarize(worst = max(abs(estimate_pp))) |>
  pull(worst)

text_rows <- bind_rows(
  text_rows,
  tibble(table_figure = "text", column = "appendixC_ame_vs_ols",
         stat = "max_abs_difference", value_rewrite = worst_ame_gap)
)

rewrite <- bind_rows(rewrite, table_2, table_3, text_rows)

# Join the three sides ----
gt <- published |>
  full_join(archive, by = c("table_figure", "column", "stat")) |>
  full_join(rewrite, by = c("table_figure", "column", "stat"))

# Agreement at the precision the article prints ----
printed_decimals <- function(x) {
  map_dbl(x, function(v) {
    if (is.na(v)) return(NA_real_)
    txt <- formatC(v, format = "fg", digits = 15, flag = "#")
    txt <- str_remove(txt, "0+$")
    if (str_detect(txt, "\\.")) nchar(str_remove(txt, "^.*\\.")) else 0
  })
}

agrees <- function(value, target) {
  case_when(
    is.na(value) | is.na(target) ~ NA_real_,
    abs(value - target) <= 0.5 * 10^(-printed_decimals(target)) ~ 1,
    .default = 0
  )
}

gt <- gt |>
  mutate(
    match = agrees(value_script, value_paper),
    match_rewrite = agrees(value_rewrite, value_paper)
  )

# The average marginal effect claim is an upper bound, not a value, so agreement to
# printed precision is the wrong test for it.
bound <- gt$column == "appendixC_ame_vs_ols"
gt$match_rewrite[bound] <- as.numeric(gt$value_rewrite[bound] < gt$value_paper[bound])

# Rows for the published floats that carry no comparable number ----
# Every numbered float in the article and appendix appears in this table, including the
# ones with nothing in them to compare, so that a float's absence from the ground truth
# can never be mistaken for a float that was checked and passed.
figures <- read_csv(here::here("ground_truth", "archive_figure_estimates.csv"),
                    show_col_types = FALSE)

figure_agreement <- function(fig, rewrite_file, join_by) {
  arc <- figures |> filter(figure == fig)
  rw <- out(rewrite_file)
  joined <- inner_join(
    arc |> select(all_of(join_by), a_est = estimate, a_se = std.error,
                  a_lo = conf.low, a_hi = conf.high),
    rw |> select(all_of(join_by), r_est = estimate, r_se = std.error,
                 r_lo = conf.low, r_hi = conf.high),
    by = join_by
  )
  stopifnot(nrow(joined) == nrow(arc))
  list(
    n_estimates = nrow(joined),
    worst = max(abs(c(joined$a_est - joined$r_est, joined$a_se - joined$r_se,
                      joined$a_lo - joined$r_lo, joined$a_hi - joined$r_hi)))
  )
}

f1 <- figure_agreement("figure_1", "figure_1_main_effects.csv",
                       c("sample", "outcome", "term"))
f2 <- figure_agreement("figure_2", "figure_2_het_fx_party.csv",
                       c("sample", "party", "outcome", "term"))

f3 <- out("figure_3_simulation.csv")

coverage <- tribble(
  ~table_figure, ~column, ~stat, ~notes,
  "table_1", "potential outcomes of four subject types", "none",
    "Notation rather than results. The table sets out the potential outcomes of bilingual, Spanish-only, English-only and neither-language subjects under the control, English-ad and Spanish-ad conditions. Its only entries are two language indicators and six symbols; there is no estimated quantity in it.",
  "table_4", "advertisement treatments", "none",
    "The advertisement titles, running times, YouTube links and full transcripts in English and Spanish for all three candidates. No estimated quantity.",
  "figure_1", "all plotted estimates", "estimate, standard error and both confidence limits",
    str_glue("The published figure prints no numbers, so there is nothing in it to compare against the article. The deposited script that draws it saves a PDF but prints and writes no estimate, so its estimates were recovered by refitting the models it specifies. All {f1$n_estimates} plotted estimates agree with the rewrite on all four quantities, to within {signif(f1$worst, 2)}."),
  "figure_2", "all plotted estimates", "estimate, standard error and both confidence limits",
    str_glue("As Figure 1. All {f2$n_estimates} plotted estimates agree with the rewrite on all four quantities, to within {signif(f2$worst, 2)}."),
  "figure_3", "net effect surface", "none",
    str_glue("A calibration exercise rather than an estimate: the net effect of a Spanish-language strategy over the share of bilinguals in the electorate and the risk of mistargeting, holding the two effects at the values the article supposes on page 18. The surface is deterministic given those two numbers, and the rewrite writes {nrow(f3)} of its values to figure_3_simulation.csv. The deposited script draws the figure to the screen and never saves it, so the deposit contains no rendering of Figure 3 to compare against.")
) |>
  mutate(value_paper = NA_real_, value_script = NA_real_, value_rewrite = NA_real_,
         match = NA_real_, match_rewrite = NA_real_)

# Where a disagreement would live ----
# defect_locus is set on every row whose rewrite value disagrees with the article:
# paper_internal (the article is wrong or inconsistent), archive (the deposited code is
# wrong), environment (a change in R or a package moved the number), rewrite (this
# repository is wrong), unresolved.
gt <- bind_rows(gt, coverage) |>
  mutate(
    paper_id = "flores_coppock_2018",
    claim = if_else(stat == "none", column, paste0(column, ", ", stat)),
    defect_locus = case_when(
      is.na(match_rewrite) | match_rewrite == 1 ~ NA_character_,
      .default = "unresolved"
    ),
    notes = case_when(
      !is.na(notes) ~ notes,
      table_figure == "table_2" ~ "No deposited script computes any part of Table 2; the rewrite is the only code that produces it",
      .default = NA_character_
    )
  )

table_order <- c("table_1", "table_2", "table_3", "table_4", "table_5", "table_6",
                 "table_7", "table_8", "table_9", "figure_1", "figure_2", "figure_3",
                 "table_a1", "table_a2", "table_a3", "table_a4",
                 "table_b5", "table_b6", "table_b7", "table_b8",
                 "table_c9", "table_c10", "text")

gt <- gt |>
  arrange(match(table_figure, table_order), column, stat) |>
  select(paper_id, table_figure, claim, value_script, value_paper, match,
         value_rewrite, match_rewrite, defect_locus, notes)

write_csv(gt, here::here("ground_truth", "flores_coppock_2018_ground_truth.csv"))

print(str_glue(
  "{nrow(gt)} rows. ",
  "Archive: {sum(gt$match == 1, na.rm = TRUE)} match, {sum(gt$match == 0, na.rm = TRUE)} fail, ",
  "{sum(is.na(gt$match))} not comparable. ",
  "Rewrite: {sum(gt$match_rewrite == 1, na.rm = TRUE)} match, ",
  "{sum(gt$match_rewrite == 0, na.rm = TRUE)} fail, ",
  "{sum(is.na(gt$match_rewrite))} not comparable."
))

failures <- gt |> filter(match == 0 | match_rewrite == 0)
if (nrow(failures) > 0) print(failures, n = nrow(failures), width = 200)
