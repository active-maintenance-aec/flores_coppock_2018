# flores_coppock_2018/ground_truth/build_ground_truth.R
# Output: ground_truth/flores_coppock_2018_ground_truth.csv,
#   ground_truth/float_coverage.csv
# Depends on: ground_truth/published_claims.csv, ground_truth/published_values.csv,
#   ground_truth/archive_values.csv, ground_truth/archive_figure_estimates.csv,
#   maintained/output/ (run run_all.R first), maintained/in_text_claims.R
# Description: Assemble the comparison table, then run the coverage gate over the second
#   instrument. One row per published quantity, carrying the value the article prints,
#   the value the deposited scripts produce, and the value the maintained rewrite
#   computes.
#
#   Nothing here is typed except value_paper, which may only come from reading the
#   article. The typeset table cells arrive already transcribed in published_values.csv,
#   parsed from the two PDFs by extract_published_values.R; the quantities the article
#   states in sentences are transcribed below from rendered pages. value_script comes
#   from archive_values.csv, parsed from the deposited scripts' own output by
#   extract_archive_values.R. value_rewrite is read out of maintained/output/, so the
#   table cannot drift from the pipeline. No published value is an input to any
#   computation here or anywhere in maintained/.
#
#   value_paper is carried as the STRING the page prints, and a value agrees when the
#   pipeline's number, printed to that page's own precision, gives the same digits. A
#   double cannot do this job: it does not record that Table 5 prints a standard error
#   as 0.020 rather than 0.02.

library(here)
library(tidyverse)

here::i_am("ground_truth/build_ground_truth.R")

options(width = 200)

paper_id <- "flores_coppock_2018"

out <- function(f) read_csv(here::here("maintained", "output", f), show_col_types = FALSE)

# The extraction -----------------------------------------------------------------------
# published_claims.csv is the numeric-token extraction from the article and the
# appendix. It governs coverage for both instruments and is the single home of the
# per-claim precision, so neither file can name a different one.

published_claims <- read_csv(
  here::here("ground_truth", "published_claims.csv"),
  col_types = cols(value_paper = col_character(), .default = col_guess())
)

# Rendering and comparison --------------------------------------------------------------

# "The string the article prints" means its digits, not its typography: the Unicode
# minus, thousands separators and a missing leading zero are normalised away, and the
# number of decimals, which is the one typographic fact the comparison needs, survives.
normalise_printed <- function(x) {
  x |>
    str_replace_all("[−–—]", "-") |>
    str_remove_all(",") |>
    str_replace("^(-?)\\.", "\\10")
}

# Signed zero is normalised on this side as well as in the claims file; whichever
# instrument normalises, both must.
render_at <- function(x, digits) {
  rendered <- sprintf(paste0("%.", digits, "f"), x)
  str_replace(rendered, "^-(0(\\.0+)?)$", "\\1")
}

printed_decimals <- function(x) {
  if_else(str_detect(x, "\\."), nchar(str_remove(x, "^.*\\.")), 0L)
}

# A value agrees when the pipeline's number, printed to the page's own precision, gives
# the same digits. The epsilon keeps a value sitting a hair from the rounding boundary
# from being rejected by floating point.
agrees <- function(value, value_paper, digits) {
  target <- suppressWarnings(as.numeric(normalise_printed(value_paper)))
  d <- if_else(is.na(digits), 0L, as.integer(digits))
  case_when(
    is.na(value) | is.na(target) | is.na(digits) ~ NA_real_,
    render_at(value, d) == normalise_printed(value_paper) ~ 1,
    abs(round(value, d) - target) < 1e-9 * pmax(1, abs(target)) ~ 1,
    .default = 0
  )
}

# Checks that depend only on the extraction ---------------------------------------------
# These run before anything consumes it, so a wrong precision trips its own check rather
# than the value comparison downstream.

stopifnot(
  !any(duplicated(published_claims$claim_id)),
  all(nzchar(published_claims$claim_id)),
  all(published_claims$claim_type %in%
        c("pipeline", "descriptive", "definitional", "structural", "transcribed")),
  all(published_claims$needs_block %in% c(TRUE, FALSE)),
  all(is.na(published_claims$comparison) |
        published_claims$comparison %in% c("==", "<", ">", "<=", ">=", "approx")),
  all(published_claims$needs_block[
    published_claims$claim_type %in% c("pipeline", "descriptive")])
)

# A stored value_paper that does not survive a round trip through its own recorded
# precision means digits is wrong about the precision even where it is right about the
# value, which numeric equality would pass.
round_trips <- function(value_paper, digits, where) {
  numeric_rows <- !is.na(value_paper) & !is.na(digits) &
    str_detect(value_paper, "^-?\\d+(\\.\\d+)?$")
  bad <- numeric_rows &
    (value_paper != normalise_printed(value_paper) |
       render_at(as.numeric(value_paper), digits) != value_paper)
  if (any(bad)) {
    print(tibble(value_paper = value_paper[bad], digits = digits[bad]), n = Inf)
    stop("A stored published value does not round trip through its own precision in ",
         where, ".")
  }
  invisible(NULL)
}

round_trips(published_claims$value_paper, published_claims$digits, "published_claims.csv")

# The precision of a prose claim comes from the extraction and from nowhere else.
prose_digits <- function(id) {
  d <- published_claims$digits[match(id, published_claims$claim_id)]
  stopifnot(!any(is.na(d)))
  d
}

# The three sides ------------------------------------------------------------------------

published <- read_csv(here::here("ground_truth", "published_values.csv"),
                      col_types = cols(value_paper = col_character(),
                                       .default = col_character()))
archive <- read_csv(here::here("ground_truth", "archive_values.csv"),
                    show_col_types = FALSE)

round_trips(published$value_paper, printed_decimals(published$value_paper),
            "published_values.csv")

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
  long_coefs(c9_c10),
  # Table 2, which the deposit has no script for.
  out("table_2_sample_comparison.csv") |>
    pivot_longer(c(mean, se), names_to = "which", values_to = "value_rewrite") |>
    filter(!is.na(value_rewrite)) |>
    transmute(table_figure = "table_2", column,
              stat = if_else(which == "se", paste0(quantity, "_se"), quantity),
              value_rewrite),
  # Table 3's cell counts.
  out("table_3_randomization.csv") |>
    pivot_longer(c(english_ad, spanish_ad), names_to = "stat", values_to = "value_rewrite") |>
    transmute(table_figure = "table_3", column = paste(block, survey_language, sep = "_"),
              stat, value_rewrite)
)

# Every join between a transcription and a pipeline output goes through one place, and
# it asserts that neither side is duplicated and that nothing falls through. A published
# value with no rewrite counterpart is a mistyped label, not an unverifiable quantity.
join_sides <- function(published, archive, rewrite) {
  key <- c("table_figure", "column", "stat")
  stopifnot(
    !any(duplicated(published[key])),
    !any(duplicated(archive[key])),
    !any(duplicated(rewrite[key]))
  )
  joined <- published |>
    left_join(archive, by = key) |>
    left_join(rewrite, by = key)
  stopifnot(nrow(joined) == nrow(published), !any(is.na(joined$value_rewrite)))
  unmatched <- anti_join(rewrite, published, by = key)
  stopifnot(nrow(unmatched) == 0)
  joined
}

table_rows <- join_sides(published, archive, rewrite) |>
  transmute(
    claim_id = paste(table_figure, column, stat, sep = "_"),
    table_figure,
    claim = paste0(column, ", ", stat),
    value_script, value_paper,
    digits = printed_decimals(value_paper),
    value_rewrite,
    holds = NA,
    defect_locus = NA_character_,
    notes = if_else(table_figure == "table_2",
                    "No deposited script computes any part of Table 2; the rewrite is the only code that produces it. Its Lucid column comes from the deposited study_1.csv, and its LNS and Pew columns from the Latino National Survey (ICPSR 20862) and Pew's 2012 National Survey of Latinos, which are licensed and are not redistributed with this repository",
                    NA_character_)
  )

# Quantities the article states in sentences ---------------------------------------------
# value_paper is transcribed here from the rendered pages, independently of the
# extraction, and the gate below compares the two transcriptions. value_rewrite goes
# through text_in_text_claims.csv and text_design_facts.csv wherever they carry the
# quantity, which is a different path from the one in_text_claims.R takes.

claims_out <- out("text_in_text_claims.csv")
facts <- out("text_design_facts.csv")
t5 <- out("table_5_general_election.csv")
t6 <- out("table_6_like_candidate.csv")
t7 <- out("table_7_candidate_cares.csv")
t9 <- out("table_9_linked_fate.csv")
t3_chisq <- out("table_3_chisq.csv")
interactions_rewrite <- out("tables_a1_a4_interaction.csv") |> filter(str_detect(term, ":"))
b5_b8_rewrite <- out("tables_b5_b8_pid.csv")
ames_rewrite <- out("tables_c9_c10_ames.csv")
figure_1_rewrite <- out("figure_1_main_effects.csv")
figure_2_rewrite <- out("figure_2_het_fx_party.csv")
figure_3_rewrite <- out("figure_3_simulation.csv")

tic <- function(claim_name, which) {
  value <- claims_out[[which]][claims_out$claim == claim_name]
  stopifnot(length(value) == 1, !is.na(value))
  value
}

fact <- function(name) {
  value <- facts$value[facts$quantity == name]
  stopifnot(length(value) == 1)
  value
}

arc <- function(tab, col, stat) {
  value <- archive$value_script[archive$table_figure == tab & archive$column == col &
                                  archive$stat == stat]
  stopifnot(length(value) == 1)
  value
}

outcome_measure <- function(outcome) str_remove_all(outcome, "bush|vela|coffman|_")

bilingual_ad <- t5 |>
  filter(term %in% c("Z_ad", "Z_vela", "Z_coffman"), sample == "bilingual")
positive_significant <- bilingual_ad |> filter(conf.low > 0)
five_points <- mean(c(tic("p13_general_bush_bilingual", "estimate_pp"),
                      tic("p13_general_vela_bilingual", "estimate_pp")))

bush_like <- t6 |> filter(candidate == "bush", sample == "bilingual", term == "Z_ad")
vela_mono <- t5 |> filter(candidate == "vela", sample == "monolingual", term == "Z_vela")
coffman_mono_control <- t5 |>
  filter(candidate == "coffman", sample == "monolingual", term == "(Intercept)")
linked_fate <- t9 |> filter(term == "Z_survey")

# The sample analysed for each outcome, read back out of the long rewrite frame rather
# than out of the table files, so this derivation and the claims file's are separate.
sample_spread <- rewrite |>
  filter(stat == "N", table_figure %in% paste0("table_", 5:9)) |>
  summarize(low = min(value_rewrite), high = max(value_rewrite), .by = column) |>
  mutate(spread = (high - low) / high)

# The appendix's contents page, transcribed here a second time. The letters the three
# sentences name are part of the sentences themselves.
appendix_contents <- tribble(
  ~letter, ~title,
  "A", "Interaction Regression Specifications",
  "B", "Heterogeneous Effects by Partisanship",
  "C", "Binary Choice Models",
  "D", "Spanish-Language Survey",
  "E", "Language Quiz"
)
section_of <- function(title) appendix_contents$letter[appendix_contents$title == title]

experiments_rewrite <- n_distinct(t5$candidate)

survey_language_share <- out("table_3_randomization.csv") |>
  filter(str_starts(block, "experiment_1")) |>
  mutate(subjects = english_ad + spanish_ad) |>
  mutate(share = subjects / sum(subjects))

party_contrast <- figure_2_rewrite |>
  select(sample, party, outcome, estimate, std.error) |>
  pivot_wider(names_from = party, values_from = c(estimate, std.error)) |>
  rename(estimate_dem = `estimate_Democratic Respondents`,
         estimate_rep = `estimate_Republican Respondents`,
         se_dem = `std.error_Democratic Respondents`,
         se_rep = `std.error_Republican Respondents`) |>
  mutate(gap_p = 2 * pnorm(-abs((estimate_dem - estimate_rep) /
                                  sqrt(se_dem^2 + se_rep^2))))
monolingual_contrast <- party_contrast |> filter(sample == "Monolingual Sample")
bilingual_contrast <- party_contrast |>
  filter(sample == "Bilingual Sample") |>
  mutate(candidate = if_else(str_detect(outcome, "vela"), "vela", "coffman")) |>
  summarize(dem_positive = sum(estimate_dem > 0),
            rep_negative = sum(estimate_rep < 0),
            outcomes = n(), .by = candidate)

coffman_party <- b5_b8_rewrite |>
  filter(table == "b5", candidate == "coffman", sample == "monolingual",
         term == "Z_coffman")
stopifnot(nrow(coffman_party) == 2)
party_gap <- coffman_party$estimate[coffman_party$party == "republican"] -
  coffman_party$estimate[coffman_party$party == "democrat"]
party_gap_p <- 2 * pnorm(-abs(party_gap / sqrt(sum(coffman_party$std.error^2))))

ame_gap <- ames_rewrite |>
  filter(term %in% c("Z_ad", "Z_vela", "Z_coffman")) |>
  inner_join(
    bind_rows(t5 |> mutate(table = "c9"), t7 |> mutate(table = "c10")) |>
      filter(term %in% c("Z_ad", "Z_vela", "Z_coffman")) |>
      select(table, candidate, sample, ols = estimate),
    by = c("table", "candidate", "sample")
  ) |>
  mutate(gap = abs(estimate - ols))
stopifnot(nrow(ame_gap) == 10)

surface <- figure_3_rewrite |> filter(quantity == "net_effect")
majority_bilingual <- surface |> filter(prop_bilingual > 0.5)

prose_rows <- tribble(
  ~claim_id, ~table_figure, ~claim, ~value_script, ~value_paper, ~value_rewrite, ~holds, ~defect_locus, ~notes,

  # Abstract and introduction ----
  "abstract_two_of_three", "text", "Two of three experiments raise bilingual support by about five points",
    NA, NA_character_, NA, nrow(positive_significant) == 2 && nrow(bilingual_ad) == 3, NA_character_, NA_character_,
  "abstract_effect_five_points", "text", "Spanish ad raises bilingual support by five percentage points",
    100 * mean(c(arc("table_5", "bush_bilingual", "Z_ad"), arc("table_5", "vela_bilingual", "Z_ad"))),
    "5", five_points, NA, NA_character_, NA_character_,
  "intro_candidates_found", "text", "Three candidates produced matched advertisements",
    NA, "3", n_distinct(a1_a4$column), NA, NA_character_, NA_character_,
  "intro_advertisements", "text", "Six advertisements in all",
    NA, "6", 2 * n_distinct(a1_a4$column), NA, NA_character_, NA_character_,
  "intro_bush_recruited", "text", "Bush experiment: bilinguals recruited",
    NA, "2866", fact("study_1_recruited"), NA, NA_character_, NA_character_,
  "intro_bush_passed", "text", "Bush experiment: bilinguals who passed the quiz",
    NA, "1862", fact("study_1_passed_quiz"), NA, NA_character_, NA_character_,
  "intro_vela_coffman_recruited", "text", "Vela and Coffman experiments: bilinguals recruited",
    NA, "2233", fact("study_2_recruited"), NA, NA_character_, NA_character_,
  "intro_vela_coffman_passed", "text", "Vela and Coffman experiments: bilinguals who passed the quiz",
    NA, "1681", fact("study_2_passed_quiz"), NA, NA_character_, NA_character_,
  "intro_preview_bush_effect", "text", "Preview: Spanish ad raises Bush support by about five points",
    100 * arc("table_5", "bush_bilingual", "Z_ad"), "5",
    tic("p13_general_bush_bilingual", "estimate_pp"), NA, NA_character_, NA_character_,

  # Experimental design ----
  "design_bush_recruited", "text", "Sampling: Latinos who responded to the Bush survey",
    NA, "2866", fact("study_1_recruited"), NA, NA_character_, NA_character_,
  "design_bush_passed", "text", "Sampling: Bush respondents who passed the language quiz",
    NA, "1862", fact("study_1_passed_quiz"), NA, NA_character_, NA_character_,
  "design_bush_passed_restated", "text", "Sampling: the same count, restated",
    NA, "1862", fact("study_1_passed_quiz"), NA, NA_character_, NA_character_,
  "design_vela_coffman_recruited", "text", "Sampling: bilinguals who responded to the Vela and Coffman survey",
    NA, "2233", fact("study_2_recruited"), NA, NA_character_, NA_character_,
  "design_vela_coffman_passed", "text", "Sampling: those who passed the language quiz",
    NA, "1681", fact("study_2_passed_quiz"), NA, NA_character_, NA_character_,
  "design_appendix_quiz_reference", "text", "The language quiz is said to be in supplemental Appendix D",
    NA, NA_character_, NA, "D" == section_of("Language Quiz"), "paper_internal",
    "The language quiz is appendix section E; section D is the Spanish-language survey",
  "design_mono_supplied", "text", "Sampling: nationally representative subjects supplied",
    NA, "2230", fact("study_3_supplied"), NA, NA_character_, NA_character_,
  "design_mono_failed", "text", "Sampling: those who did not pass the language quiz",
    NA, "1344", fact("study_3_failed_quiz"), NA, NA_character_, NA_character_,
  "design_education_levels", "text", "Table 2 row label: Education(5 levels)",
    NA, "5", fact("educ_5_n_levels"), NA, NA_character_, NA_character_,
  "design_income_7_levels", "text", "Table 2 row label: Income(7 levels)",
    NA, "7", fact("income_7_n_levels"), NA, NA_character_, NA_character_,
  "design_income_9_levels", "text", "Table 2 row label: Income(9 levels)",
    NA, "9", fact("income_9_n_levels"), NA, NA_character_, NA_character_,
  "design_experiments", "text", "Three separate experiments were conducted",
    NA, "3", experiments_rewrite, NA, NA_character_, NA_character_,
  "design_exp1_bilinguals", "text", "Experiment 1's bilingual sample",
    NA, "1862", fact("study_1_passed_quiz"), NA, NA_character_, NA_character_,
  "design_factorial_ad_levels", "text", "A 2 x 2 design: advertisement-language arms",
    NA, "2", n_distinct(str_subset(names(out("table_3_randomization.csv")), "_ad$")), NA, NA_character_, NA_character_,
  "design_factorial_survey_levels", "text", "A 2 x 2 design: survey-language arms",
    NA, "2", n_distinct(survey_language_share$survey_language), NA, NA_character_, NA_character_,
  "design_half_english", "text", "Half the subjects took the survey in English",
    NA, NA_character_, NA, all(abs(survey_language_share$share - 0.5) < 0.05), NA_character_, NA_character_,
  "design_exp23_bilinguals", "text", "Experiments 2 and 3: bilingual sample",
    NA, "1681", fact("study_2_passed_quiz"), NA, NA_character_, NA_character_,
  "design_exp23_monolinguals", "text", "Experiments 2 and 3: monolingual sample",
    NA, "1344", fact("study_3_failed_quiz"), NA, NA_character_, NA_character_,
  "design_chisq_statistic", "text", "Balance test: chi-squared statistic",
    arc("table_3", "balance", "chi_sq"), "7.3", t3_chisq$statistic, NA, NA_character_, NA_character_,
  "design_chisq_df", "text", "Balance test: degrees of freedom",
    arc("table_3", "balance", "df"), "7", t3_chisq$df, NA, NA_character_, NA_character_,
  "design_chisq_p", "text", "Balance test: p-value",
    arc("table_3", "balance", "p_value"), "0.40", t3_chisq$p_value, NA, NA_character_, NA_character_,
  "design_outcome_measures", "text", "Five outcome measures",
    NA, "5", n_distinct(outcome_measure(c(figure_1_rewrite$outcome, t9$outcome))), NA, NA_character_, NA_character_,
  "design_appendix_survey_reference", "text", "The Spanish-language survey is said to be in supplemental Appendix C",
    NA, NA_character_, NA, "C" == section_of("Spanish-Language Survey"), "paper_internal",
    "The Spanish-language survey is appendix section D; section C is the binary choice models",
  "design_general_high", "text", "Candidate preference is coded 1 for the advertising candidate",
    NA, "1", fact("bush_general_max"), NA, NA_character_, NA_character_,
  "design_general_low", "text", "Candidate preference is coded 0 otherwise",
    NA, "0", fact("bush_general_min"), NA, NA_character_, NA_character_,
  "design_like_scale_min", "text", "Liking runs from 1",
    NA, "1", fact("like_bush_min"), NA, NA_character_, NA_character_,
  "design_like_scale_max", "text", "Liking runs to 7",
    NA, "7", fact("like_bush_max"), NA, NA_character_, NA_character_,
  "design_cares_high", "text", "Candidate cares is coded 1 for cares",
    NA, "1", fact("bush_cares_max"), NA, NA_character_, NA_character_,
  "design_cares_low", "text", "Candidate cares is coded 0 for does not care",
    NA, "0", fact("bush_cares_min"), NA, NA_character_, NA_character_,
  "design_confidence_min", "text", "Confidence is said to run from 1",
    NA, "1", fact("conf_in_bush_min"), NA, "paper_internal",
    "The deposited confidence variable runs 0 to 3, and Table 8's control means are on that scale",
  "design_confidence_max", "text", "Confidence is said to run to 4",
    NA, "4", fact("conf_in_bush_max"), NA, "paper_internal",
    "The deposited confidence variable runs 0 to 3, and Table 8's control means are on that scale",
  "design_confidence_top", "text", "4 is said to indicate greater confidence",
    NA, "4", fact("conf_in_bush_max"), NA, "paper_internal",
    "The top of the deposited confidence variable is 3",
  "design_linked_fate_min", "text", "Linked fate is said to run from 1",
    NA, "1", fact("linked_fate_min"), NA, "paper_internal",
    "The deposited linked fate variable runs 0 to 3, and Table 9's control means are on that scale",
  "design_linked_fate_max", "text", "Linked fate is said to run to 4",
    NA, "4", fact("linked_fate_max"), NA, "paper_internal",
    "The deposited linked fate variable runs 0 to 3, and Table 9's control means are on that scale",
  "design_linked_fate_top", "text", "4 is said to indicate a lot",
    NA, "4", fact("linked_fate_max"), NA, "paper_internal",
    "The top of the deposited linked fate variable is 3",
  "design_appendix_logit_reference", "text", "The logit tables are said to be in supplemental Appendix A",
    NA, NA_character_, NA, "A" == section_of("Binary Choice Models"), "paper_internal",
    "The logistic regression tables are appendix section C; section A is the interaction specifications",

  # Results ----
  "results_n_varies", "text", "Item non-response moves the analysed sample only slightly",
    NA, NA_character_, NA, max(sample_spread$spread) < 0.01, NA_character_, NA_character_,
  "results_nonresponse_tests", "text", "Formal tests of non-response against treatment assignment",
    NA, NA_character_, NA, NA, "archive",
    "No counterpart in the deposit: none of its eight scripts tests item non-response against assignment",
  "results_three_experiments", "text", "Table 5 covers all three experiments",
    NA, "3", experiments_rewrite, NA, NA_character_, NA_character_,
  "results_bush_ate", "text", "Bush bilingual advertisement effect",
    100 * arc("table_5", "bush_bilingual", "Z_ad"), "4.9",
    tic("p13_general_bush_bilingual", "estimate_pp"), NA, NA_character_, NA_character_,
  "results_bush_ate_se", "text", "Bush bilingual advertisement effect, standard error",
    100 * arc("table_5", "bush_bilingual", "Z_ad_se"), "2.3",
    tic("p13_general_bush_bilingual", "std_error_pp"), NA, NA_character_, NA_character_,
  "results_identical_point_estimate", "text", "The Vela point estimate is identical to the Bush one",
    NA, NA_character_, NA,
    sprintf("%.1f", tic("p13_general_bush_bilingual", "estimate_pp")) ==
      sprintf("%.1f", tic("p13_general_vela_bilingual", "estimate_pp")), NA_character_, NA_character_,
  "results_vela_ate", "text", "Vela bilingual advertisement effect",
    100 * arc("table_5", "vela_bilingual", "Z_ad"), "4.9",
    tic("p13_general_vela_bilingual", "estimate_pp"), NA, NA_character_, NA_character_,
  "results_vela_ate_se", "text", "Vela bilingual advertisement effect, standard error",
    100 * arc("table_5", "vela_bilingual", "Z_ad_se"), "2.4",
    tic("p13_general_vela_bilingual", "std_error_pp"), NA, NA_character_, NA_character_,
  "results_both_significant", "text", "Both bilingual advertisement effects are significant",
    NA, NA_character_, NA, all(bilingual_ad$conf.low[bilingual_ad$candidate != "coffman"] > 0),
    NA_character_, NA_character_,
  "results_vela_survey_ate", "text", "Effect of the Spanish survey on support for Vela",
    100 * arc("table_5", "vela_bilingual", "Z_survey"), "7.3",
    tic("p13_survey_language_vela_bilingual", "estimate_pp"), NA, NA_character_, NA_character_,
  "results_vela_survey_ate_se", "text", "Effect of the Spanish survey on support for Vela, standard error",
    100 * arc("table_5", "vela_bilingual", "Z_survey_se"), "2.4",
    tic("p13_survey_language_vela_bilingual", "std_error_pp"), NA, NA_character_, NA_character_,
  "results_vela_mono_ate", "text", "Vela monolingual advertisement effect",
    100 * arc("table_5", "vela_monolingual", "Z_ad"), "-2",
    tic("p13_general_vela_monolingual", "estimate_pp"), NA, NA_character_, NA_character_,
  "results_vela_mono_not_significant", "text", "The Vela monolingual effect cannot be distinguished from zero",
    NA, NA_character_, NA, vela_mono$conf.low < 0 && vela_mono$conf.high > 0, NA_character_, NA_character_,
  "results_coffman_mono_ate", "text", "Coffman monolingual advertisement effect",
    100 * arc("table_5", "coffman_monolingual", "Z_ad"), "-18.7",
    tic("p13_general_coffman_monolingual", "estimate_pp"), NA, NA_character_, NA_character_,
  "results_coffman_mono_ate_se", "text", "Coffman monolingual advertisement effect, standard error",
    100 * arc("table_5", "coffman_monolingual", "Z_ad_se"), "2.6",
    tic("p13_general_coffman_monolingual", "std_error_pp"), NA, NA_character_, NA_character_,
  "results_coffman_control_support", "text", "Coffman's support in the monolingual control group",
    100 * arc("table_5", "coffman_monolingual", "constant"), "51",
    100 * coffman_mono_control$estimate, NA, NA_character_, NA_character_,
  "results_bush_like_ate", "text", "Effect on liking Bush",
    arc("table_6", "bush_bilingual", "Z_ad"), "0.167", bush_like$estimate, NA, NA_character_, NA_character_,
  "results_bush_like_ate_se", "text", "Effect on liking Bush, standard error",
    arc("table_6", "bush_bilingual", "Z_ad_se"), "0.075", bush_like$std.error, NA, NA_character_, NA_character_,
  "results_seven_point_scale", "text", "Liking is measured on a seven-point scale",
    NA, "7", fact("like_bush_max"), NA, NA_character_, NA_character_,
  "results_bilingual_cares_magnitude", "text", "Bilingual effects on candidate caring are on the order of 2 to 3 points",
    NA, NA_character_, NA, NA, NA_character_,
    "An approximate claim: the three bilingual effects run 1.8 to 3.7 points, which the sentence hedges",
  "results_vela_mono_cares", "text", "Vela monolingual effect on candidate caring",
    100 * arc("table_7", "vela_monolingual", "Z_ad"), "-15.2",
    tic("p14_cares_vela_monolingual", "estimate_pp"), NA, NA_character_, NA_character_,
  "results_vela_mono_cares_se", "text", "Vela monolingual effect on candidate caring, standard error",
    100 * arc("table_7", "vela_monolingual", "Z_ad_se"), "2.5",
    tic("p14_cares_vela_monolingual", "std_error_pp"), NA, NA_character_, NA_character_,
  "results_coffman_mono_cares", "text", "Coffman monolingual effect on candidate caring",
    100 * arc("table_7", "coffman_monolingual", "Z_ad"), "-15.5",
    tic("p14_cares_coffman_monolingual", "estimate_pp"), NA, NA_character_, NA_character_,
  "results_coffman_mono_cares_se", "text", "Coffman monolingual effect on candidate caring, standard error",
    100 * arc("table_7", "coffman_monolingual", "Z_ad_se"), "2.4",
    tic("p14_cares_coffman_monolingual", "std_error_pp"), NA, NA_character_, NA_character_,
  "results_interaction_opportunities", "text", "Twelve interaction terms",
    NA, "12", nrow(interactions_rewrite), NA, NA_character_, NA_character_,
  "results_interaction_sig_05", "text", "Interactions significant at the 5 per cent level",
    NA, "0", sum(interactions_rewrite$p.value < 0.05), NA, NA_character_, NA_character_,
  "results_interaction_sig_10", "text", "Interactions significant at the 10 per cent level",
    NA, "2", sum(interactions_rewrite$p.value < 0.10), NA, NA_character_, NA_character_,
  "results_interaction_opportunities_restated", "text", "Twelve interaction terms, restated",
    NA, "12", nrow(interactions_rewrite), NA, NA_character_, NA_character_,
  "results_figure_1_outcomes", "figure_1", "Figure 1 covers four outcomes",
    NA, "4", n_distinct(outcome_measure(figure_1_rewrite$outcome)), NA, NA_character_, NA_character_,
  "results_coffman_rep_ate", "text", "Coffman monolingual Republican advertisement effect",
    100 * arc("table_b5", "coffman_monolingual_republican", "Z_ad"), "-16.8",
    tic("p16_coffman_monolingual_republican", "estimate_pp"), NA, NA_character_, NA_character_,
  "results_coffman_rep_ate_se", "text", "Coffman monolingual Republican effect, standard error",
    100 * arc("table_b5", "coffman_monolingual_republican", "Z_ad_se"), "4.0",
    tic("p16_coffman_monolingual_republican", "std_error_pp"), NA, NA_character_, NA_character_,
  "results_coffman_dem_ate", "text", "Coffman monolingual Democrat advertisement effect",
    100 * arc("table_b5", "coffman_monolingual_democrat", "Z_ad"), "-14.1",
    tic("p16_coffman_monolingual_democrat", "estimate_pp"), NA, NA_character_, NA_character_,
  "results_coffman_dem_ate_se", "text", "Coffman monolingual Democrat effect, standard error",
    100 * arc("table_b5", "coffman_monolingual_democrat", "Z_ad_se"), "3.3",
    tic("p16_coffman_monolingual_democrat", "std_error_pp"), NA, NA_character_, NA_character_,
  "results_party_difference_ns", "text", "The Republican and Democrat effects do not differ significantly",
    NA, NA_character_, NA, party_gap_p > 0.05, NA_character_, NA_character_,
  "results_figure_2_dvs", "figure_2", "Figure 2 covers four dependent variables",
    NA, "4", n_distinct(outcome_measure(figure_2_rewrite$outcome)), NA, NA_character_, NA_character_,
  "results_mono_no_party_difference", "text", "Among monolinguals the pattern does not differ by party",
    NA, NA_character_, NA,
    all(c(monolingual_contrast$estimate_dem, monolingual_contrast$estimate_rep) < 0),
    NA_character_,
    "Read as the following sentence glosses it, that Republicans and Democrats alike respond negatively: all 16 monolingual estimates are negative. On the stricter reading, two of the eight Democrat-Republican differences separate from zero at 0.05",
  "results_bilingual_party_direction", "text", "Bilingual Democrats respond positively and bilingual Republicans negatively",
    NA, NA_character_, NA,
    all(bilingual_contrast$dem_positive > bilingual_contrast$outcomes / 2) &&
      all(bilingual_contrast$rep_negative > bilingual_contrast$outcomes / 2),
    NA_character_,
    "Taken per candidate over the four outcomes Figure 2 plots. The exception on both sides is the Coffman general election cell, which is not separable from zero",
  "results_figure_2_caption_outcomes", "figure_2", "Figure 2's caption names four outcomes",
    NA, "4", n_distinct(outcome_measure(figure_2_rewrite$outcome)), NA, NA_character_, NA_character_,
  "results_linked_fate_bush", "text", "Effect of the Spanish survey on linked fate, Bush experiment",
    arc("table_9", "bush_bilingual", "Z_survey"), "0.24",
    tic("p17_linked_fate_bush_bilingual", "estimate_pp"), NA, NA_character_, NA_character_,
  "results_linked_fate_bush_se", "text", "Effect on linked fate, Bush experiment, standard error",
    arc("table_9", "bush_bilingual", "Z_survey_se"), "0.04",
    tic("p17_linked_fate_bush_bilingual", "std_error_pp"), NA, NA_character_, NA_character_,
  "results_linked_fate_vela_coffman", "text", "Effect on linked fate, Vela and Coffman experiments",
    arc("table_9", "vela_coffman_bilingual", "Z_survey"), "0.13",
    tic("p17_linked_fate_vela_coffman_bilingual", "estimate_pp"), NA, NA_character_, NA_character_,
  "results_linked_fate_vela_coffman_se", "text", "Effect on linked fate, Vela and Coffman, standard error",
    arc("table_9", "vela_coffman_bilingual", "Z_survey_se"), "0.04",
    tic("p17_linked_fate_vela_coffman_bilingual", "std_error_pp"), NA, NA_character_, NA_character_,
  "results_linked_fate_both_significant", "text", "Both linked fate estimates are significant",
    NA, NA_character_, NA, all(linked_fate$conf.low > 0), NA_character_, NA_character_,

  # Discussion ----
  "discussion_three_experiments", "text", "Three randomized survey experiments",
    NA, "3", experiments_rewrite, NA, NA_character_, NA_character_,
  "discussion_effect_five_points", "text", "Bush and Vela bilinguals were about five points more likely to support",
    100 * mean(c(arc("table_5", "bush_bilingual", "Z_ad"), arc("table_5", "vela_bilingual", "Z_ad"))),
    "5", five_points, NA, NA_character_, NA_character_,
  "discussion_assumed_bilingual_effect", "text", "The calibration supposes a five-point bilingual effect",
    NA, "5", 100 * unique(surface$value[surface$prop_bilingual == max(surface$prop_bilingual)]),
    NA, NA_character_, NA_character_,
  "discussion_assumed_monolingual_effect", "text", "The calibration supposes a negative fifteen-point monolingual effect",
    NA, "-15",
    100 * surface$value[surface$prop_bilingual == min(surface$prop_bilingual) &
                          surface$prop_mistargeted == max(surface$prop_mistargeted)],
    NA, NA_character_, NA_character_,
  "discussion_electorate_zero", "text", "The simulated electorate runs from 0 per cent bilingual",
    NA, "0", 100 * min(surface$prop_bilingual), NA, NA_character_, NA_character_,
  "discussion_electorate_hundred", "text", "The simulated electorate runs to 100 per cent bilingual",
    NA, "100", 100 * max(surface$prop_bilingual), NA, NA_character_, NA_character_,
  "discussion_majority_bilingual", "text", "A Spanish strategy can lose ground above a half-bilingual electorate",
    NA, NA_character_, NA, any(majority_bilingual$value < 0), NA_character_, NA_character_,

  # Appendix ----
  "appendix_a_dependent_variables", "text", "Appendix A covers all four dependent variables",
    NA, "4", n_distinct(outcome_measure(out("tables_a1_a4_interaction.csv")$outcome)),
    NA, NA_character_, NA_character_,
  "appendix_a_interactions_insignificant", "text", "The interaction coefficients are small and insignificant",
    NA, NA_character_, NA, all(interactions_rewrite$p.value >= 0.05), NA_character_, NA_character_,
  "appendix_c_binary_outcomes", "text", "Two dependent variables are binary",
    NA, "2",
    sum(facts$value[str_ends(facts$quantity, "_n_values") &
                      !str_starts(facts$quantity, "educ|income")] == 2),
    NA, NA_character_, NA_character_,
  "appendix_c_ame_matches_ols", "text", "Average marginal effects match OLS to the second decimal place",
    NA, NA_character_, NA, max(ame_gap$gap) < 0.005, NA_character_,
    NA_character_,

  # Floats that print no numbers ----
  "float_figure_1", "figure_1", "Estimates Figure 1 plots",
    NA, "20", nrow(figure_1_rewrite), NA, NA_character_,
    "The published figure prints no estimate on its face, so the countable claim is how many it plots. The deposited script that draws it saves a PDF and writes no estimate, so the archive side was recovered by refitting the models it specifies.",
  "float_figure_2", "figure_2", "Estimates Figure 2 plots",
    NA, "32", nrow(figure_2_rewrite), NA, NA_character_,
    "As Figure 1.",
  "float_figure_3", "figure_3", "Points of the simulated surface the rewrite commits",
    NA, NA_character_, nrow(surface), NA, NA_character_,
    "Figure 3 is a continuous raster and its cells cannot be counted from the page, so no published count can be laid against this one. The deposited script draws the figure to the screen and never saves it."
) |>
  mutate(digits = prose_digits(claim_id))

# Floats with nothing in them to compare --------------------------------------------------
# Every numbered float in the article and appendix appears in this table, including the
# ones with nothing in them to compare, so that a float's absence from the ground truth
# can never be mistaken for a float that was checked and passed.

figures <- read_csv(here::here("ground_truth", "archive_figure_estimates.csv"),
                    show_col_types = FALSE)

figure_agreement <- function(fig, rewrite_file, join_by) {
  arc_fig <- figures |> filter(figure == fig)
  rw <- out(rewrite_file)
  joined <- inner_join(
    arc_fig |> select(all_of(join_by), a_est = estimate, a_se = std.error,
                      a_lo = conf.low, a_hi = conf.high),
    rw |> select(all_of(join_by), r_est = estimate, r_se = std.error,
                 r_lo = conf.low, r_hi = conf.high),
    by = join_by
  )
  stopifnot(nrow(joined) == nrow(arc_fig))
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

coverage_rows <- tribble(
  ~claim_id, ~table_figure, ~claim, ~notes,
  "table_1_notation", "table_1", "Potential outcomes of four subject types",
    "Notation rather than results. The table sets out the potential outcomes of bilingual, Spanish-only, English-only and neither-language subjects under the control, English-ad and Spanish-ad conditions. Its eight numeric cells are the two language indicators for each of its four rows; the potential outcomes themselves are symbols.",
  "table_4_advertisements", "table_4", "Advertisement treatments",
    "The advertisement titles, running times, YouTube links and full transcripts in English and Spanish for all three candidates. Its nine numbers are six running times and three election years, none of which the deposit records.",
  "figure_1_plotted_coordinates", "figure_1", "All plotted estimates, standard errors and confidence limits",
    str_glue("The published figure prints no numbers, so there is nothing in it to compare against the article. All {f1$n_estimates} plotted estimates agree with the deposit's own models on all four quantities, to within {signif(f1$worst, 2)}."),
  "figure_2_plotted_coordinates", "figure_2", "All plotted estimates, standard errors and confidence limits",
    str_glue("As Figure 1. All {f2$n_estimates} plotted estimates agree with the deposit's own models on all four quantities, to within {signif(f2$worst, 2)}."),
  "figure_3_surface", "figure_3", "Net effect surface",
    str_glue("A calibration exercise rather than an estimate: the net effect of a Spanish-language strategy over the share of bilinguals in the electorate and the risk of mistargeting, holding the two effects at the values the article supposes on page 18. The surface is deterministic given those two numbers, and the rewrite writes {nrow(figure_3_rewrite)} of its values to figure_3_simulation.csv.")
) |>
  mutate(value_script = NA_real_, value_paper = NA_character_, digits = NA_integer_,
         value_rewrite = NA_real_, holds = NA, defect_locus = NA_character_)

# Assemble -----------------------------------------------------------------------------

ground_truth <- bind_rows(table_rows, prose_rows, coverage_rows) |>
  mutate(
    paper_id = paper_id,
    match = agrees(value_script, value_paper, digits),
    match_rewrite = agrees(value_rewrite, value_paper, digits)
  )

table_order <- c("table_1", "table_2", "table_3", "table_4", "table_5", "table_6",
                 "table_7", "table_8", "table_9", "figure_1", "figure_2", "figure_3",
                 "table_a1", "table_a2", "table_a3", "table_a4",
                 "table_b5", "table_b6", "table_b7", "table_b8",
                 "table_c9", "table_c10", "text")

ground_truth <- ground_truth |>
  arrange(match(table_figure, table_order), claim) |>
  select(paper_id, claim_id, table_figure, claim, value_script, value_paper, digits,
         match, value_rewrite, match_rewrite, holds, defect_locus, notes)

stopifnot(!any(duplicated(ground_truth$claim_id)),
          all(table_order %in% ground_truth$table_figure))

# The locus rule, in three states --------------------------------------------------------
# An adverse row must carry a defect_locus, a clean match must not, and a row with no
# verdict may. A gate stated on match_rewrite alone can see neither an archive failure
# the rewrite survives nor a descriptive claim that does not hold.

adverse <- with(ground_truth,
                (!is.na(match) & match == 0) |
                  (!is.na(match_rewrite) & match_rewrite == 0) |
                  (!is.na(holds) & !holds))
clean <- with(ground_truth,
              !adverse & ((!is.na(match_rewrite) & match_rewrite == 1) |
                            (!is.na(holds) & holds)))

if (any(adverse & is.na(ground_truth$defect_locus))) {
  print(ground_truth |> filter(adverse & is.na(defect_locus)) |>
          select(claim_id, value_paper, value_rewrite, match, match_rewrite, holds),
        n = Inf)
  stop("An adverse row carries no defect_locus.")
}
if (any(clean & !is.na(ground_truth$defect_locus))) {
  print(ground_truth |> filter(clean & !is.na(defect_locus)) |>
          select(claim_id, value_paper, value_rewrite, match_rewrite, holds, defect_locus),
        n = Inf)
  stop("A clean match carries a defect_locus.")
}
stopifnot(all(is.na(ground_truth$defect_locus) |
                ground_truth$defect_locus %in%
                c("paper_internal", "archive", "environment", "rewrite", "unresolved")))

# The extraction against the ground truth --------------------------------------------------
# Two hand transcriptions of the same pages, and nothing else compares them.

reconcile <- published_claims |>
  filter(!is.na(value_paper)) |>
  select(claim_id, extraction = value_paper) |>
  inner_join(ground_truth |> select(claim_id, transcription = value_paper),
             by = "claim_id")

stopifnot(nrow(reconcile) == sum(!is.na(published_claims$value_paper) &
                                   published_claims$claim_id %in% ground_truth$claim_id))
if (!all(normalise_printed(reconcile$extraction) ==
           normalise_printed(reconcile$transcription))) {
  print(reconcile |> filter(normalise_printed(extraction) !=
                              normalise_printed(transcription)), n = Inf)
  stop("The extraction and the ground truth disagree about a published value.")
}

# Float coverage -----------------------------------------------------------------------------
# The extraction records how many numbers each published float carries; the ground truth
# records how many of them are covered and how many reproduce. For Figures 1 and 2 the
# count is what the float plots rather than what it prints, since they print nothing.

# A float's row reads that float's own cells, taken from the transcribed table bodies
# rather than from the whole ground truth, which also carries prose claims about a
# figure.
per_float <- ground_truth |>
  filter(claim_id %in% table_rows$claim_id) |>
  summarize(basis = "published cells",
            covered = n(),
            reproduced_by_rewrite = sum(match_rewrite == 1, na.rm = TRUE),
            reproduced_by_archive = sum(match == 1, na.rm = TRUE),
            .by = table_figure) |>
  rename(float = table_figure)

# Figures 1 and 2 print nothing, so their coverage is the plotted estimates, and what
# each is compared against is the deposit's own models rather than the page.
figure_floats <- tibble(
  float = c("figure_1", "figure_2"),
  basis = "plotted estimates, compared against the deposit",
  covered = c(f1$n_estimates, f2$n_estimates),
  reproduced_by_rewrite = c(f1$n_estimates, f2$n_estimates),
  reproduced_by_archive = c(f1$n_estimates, f2$n_estimates)
)

declared_floats <- published_claims |>
  filter(str_starts(claim_id, "float_")) |>
  transmute(float = str_remove(claim_id, "^float_"),
            published_numbers = if_else(is.na(value_paper), 0L, as.integer(value_paper)))

float_coverage <- declared_floats |>
  left_join(bind_rows(per_float, figure_floats), by = "float") |>
  mutate(basis = replace_na(basis, "no comparable number"),
         across(c(covered, reproduced_by_rewrite, reproduced_by_archive),
                \(x) replace_na(x, 0L))) |>
  arrange(match(float, table_order))

stopifnot(nrow(float_coverage) == nrow(declared_floats),
          all(float_coverage$covered <= float_coverage$published_numbers),
          setequal(float_coverage$float, setdiff(table_order, "text")))

# The coverage gate ---------------------------------------------------------------------------
# The second instrument is read as a program, not as text: it is run, its output is
# captured, and the printed claim lines are counted. A block that errors, or that prints
# nothing, satisfies a textual gate completely and fails this one. It runs in its own
# environment, because both files necessarily read the same outputs and name objects for
# what they hold.

claims_output <- capture.output(
  source(here::here("maintained", "in_text_claims.R"), local = new.env(), echo = FALSE)
)

printed <- claims_output |>
  str_subset("^CLAIM ") |>
  str_match("^CLAIM ([^ ]+) = (.*?) \\|\\| (.*)$")
printed_claims <- tibble(claim_id = printed[, 2], printed_value = printed[, 3],
                         label = printed[, 4])

required <- published_claims |> filter(needs_block)

missing_blocks <- setdiff(required$claim_id, printed_claims$claim_id)
unknown_blocks <- setdiff(printed_claims$claim_id, published_claims$claim_id)
if (length(missing_blocks) > 0 || length(unknown_blocks) > 0) {
  print(list(missing = missing_blocks, unknown = unknown_blocks))
  stop("in_text_claims.R does not print exactly the claims the extraction requires.")
}
if (nrow(printed_claims) != nrow(required)) {
  print(printed_claims |> count(claim_id) |> filter(n > 1))
  stop("in_text_claims.R printed ", nrow(printed_claims), " claims against ",
       nrow(required), " extraction rows requiring a block.")
}

# Cross-instrument comparison. The two files reach the same claimed number by separate
# paths from the same pipeline outputs; where they disagree, one of them is wrong.
cross <- printed_claims |>
  left_join(ground_truth |> select(claim_id, value_rewrite, holds), by = "claim_id") |>
  left_join(published_claims |> select(claim_id, digits, comparison, claim_type),
            by = "claim_id") |>
  mutate(
    expected = pmap_chr(
      list(claim_type, holds, value_rewrite, digits, comparison),
      function(type, holds_value, value, digits, comparison) {
        if (!is.na(comparison) && comparison == "approx") return(NA_character_)
        if (type == "descriptive") return(as.character(holds_value))
        if (is.na(value) || is.na(digits)) return(NA_character_)
        render_at(value, digits)
      }
    ),
    agrees = is.na(expected) | printed_value == expected
  )

if (!all(cross$agrees)) {
  print(cross |> filter(!agrees) |> select(claim_id, printed_value, expected), n = Inf)
  stop("The two instruments disagree about a claimed value.")
}

# Errata spine gate ----
# Every claim id an errata entry names has to exist here. A missing one is a typo or a
# claim that has since been renamed, and a published correction pointing at a row that is
# not in the table is a dangling reference the build should refuse to carry.
errata_path <- here::here("errata_entries.csv")
if (file.exists(errata_path)) {
  errata_spine <- read_csv(errata_path, show_col_types = FALSE)
  cited_claim_ids <- errata_spine$claim_ids |>
    str_split(";") |>
    unlist() |>
    str_trim()
  cited_claim_ids <- cited_claim_ids[!is.na(cited_claim_ids) & cited_claim_ids != ""]
  if (length(setdiff(cited_claim_ids, ground_truth$claim_id)) > 0) {
    print(setdiff(cited_claim_ids, ground_truth$claim_id))
  }
  stopifnot(length(setdiff(cited_claim_ids, ground_truth$claim_id)) == 0)
}

# Write -----------------------------------------------------------------------------------------

write_csv(float_coverage, here::here("ground_truth", "float_coverage.csv"))
write_csv(ground_truth,
          here::here("ground_truth", paste0(paper_id, "_ground_truth.csv")))

print(str_glue(
  "{nrow(ground_truth)} rows. ",
  "Archive: {sum(ground_truth$match == 1, na.rm = TRUE)} match, ",
  "{sum(ground_truth$match == 0, na.rm = TRUE)} fail, ",
  "{sum(is.na(ground_truth$match))} not comparable. ",
  "Rewrite: {sum(ground_truth$match_rewrite == 1, na.rm = TRUE)} match, ",
  "{sum(ground_truth$match_rewrite == 0, na.rm = TRUE)} fail, ",
  "{sum(is.na(ground_truth$match_rewrite))} not comparable."
))
print(ground_truth |> count(holds))
print(ground_truth |> filter(!is.na(defect_locus)) |> count(defect_locus))
print(ground_truth |> filter(adverse) |>
        select(table_figure, claim, value_paper, value_rewrite, holds, defect_locus),
      n = 100, width = 200)
print(str_glue(
  "{nrow(printed_claims)} claims printed by the second instrument against ",
  "{nrow(required)} extraction rows requiring a block; ",
  "{sum(float_coverage$covered)} of {sum(float_coverage$published_numbers)} ",
  "published float numbers covered."
))
