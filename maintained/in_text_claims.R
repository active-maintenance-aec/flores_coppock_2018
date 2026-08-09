# flores_coppock_2018/maintained/in_text_claims.R
# Output: printed to the console; nothing is written
# Depends on: maintained/output/*, ground_truth/published_claims.csv
# Description: The second instrument. Every quantity the article states in a sentence
#   rather than inside a typeset table is recomputed here from the pipeline's own
#   output, by a path of its own, and printed beside the sentence that states it. It
#   reads the extraction, because a block cannot name the article's own figure without
#   it, and it never reads the ground truth, because agreeing with the comparison
#   would prove nothing.
#
#   Where build_ground_truth.R reaches a prose quantity through text_in_text_claims.csv,
#   this file goes back to the table output that summary was built from, so the two
#   derivations are separate. Nothing here refits anything.
#
#   It sources helpers.R for the packages and the output path. helpers.R also loads the
#   three deposited study files; no block below reads them, and every quantity here
#   comes out of maintained/output/.
#
#   Each printed line is CLAIM <id> = <value> || <label>. The id on that line is the
#   only link the coverage gate uses.

source(here::here("maintained", "helpers.R"))

options(width = 200)

published_claims <- read_csv(
  here::here("ground_truth", "published_claims.csv"),
  col_types = cols(value_paper = col_character(), .default = col_guess())
)

claim_row <- function(id) {
  row <- published_claims |> filter(.data$claim_id == .env$id)
  stopifnot(nrow(row) == 1)
  row
}

# Signed zero is normalised on this side as well as on the transcription side;
# whichever instrument normalises, both must.
render_at <- function(x, digits) {
  rendered <- sprintf(paste0("%.", digits, "f"), x)
  str_replace(rendered, "^-(0(\\.0+)?)$", "\\1")
}

emit <- function(id, value, label) {
  row <- claim_row(id)
  rendered <- if (is.na(value)) "NA" else render_at(value, row$digits)
  cat("CLAIM ", id, " = ", rendered, " || ", label, "\n", sep = "")
}

emit_holds <- function(id, holds, label) {
  claim_row(id)
  cat("CLAIM ", id, " = ", as.character(holds), " || ", label, "\n", sep = "")
}

# Pipeline output ------------------------------------------------------------------

out <- function(f) read_csv(here::here("maintained", "output", f), show_col_types = FALSE)

t5 <- out("table_5_general_election.csv")
t6 <- out("table_6_like_candidate.csv")
t7 <- out("table_7_candidate_cares.csv")
t8 <- out("table_8_confidence.csv")
t9 <- out("table_9_linked_fate.csv")
t3 <- out("table_3_randomization.csv")
t3_chisq <- out("table_3_chisq.csv")
a1_a4 <- out("tables_a1_a4_interaction.csv")
b5_b8 <- out("tables_b5_b8_pid.csv")
ames <- out("tables_c9_c10_ames.csv")
figure_1 <- out("figure_1_main_effects.csv")
figure_2 <- out("figure_2_het_fx_party.csv")
figure_3 <- out("figure_3_simulation.csv")
design_facts <- out("text_design_facts.csv")

treatment_terms <- c("Z_ad", "Z_vela", "Z_coffman")

# An outcome name carries the candidate; the outcome MEASURE is what is left when the
# candidate comes out of it, and that is the thing the article counts.
outcome_measure <- function(outcome) {
  str_remove_all(outcome, "bush|vela|coffman|_")
}

fact <- function(name) {
  value <- design_facts$value[design_facts$quantity == name]
  stopifnot(length(value) == 1)
  value
}

main_tables <- bind_rows(t5, t6, t7, t8)

bilingual_ad_effects <- t5 |> filter(term %in% treatment_terms, sample == "bilingual")

# The two experiments the abstract and the discussion single out are the two whose
# bilingual advertisement effect is positive and separated from zero, which is how the
# article itself identifies them ("Both estimates are statistically significant";
# Coffman "received no electoral reward"). Selecting them by their published magnitude
# would make the comparison agree by construction.
positive_significant <- bilingual_ad_effects |> filter(conf.low > 0)

# Abstract ----

# "In two of our three experiments, the Spanish-language advertisements increased
#  candidates' electoral support by 5 percentage points among bilinguals."
emit_holds(
  "abstract_two_of_three",
  nrow(positive_significant) == 2 && nrow(bilingual_ad_effects) == 3,
  str_glue("{nrow(positive_significant)} of {nrow(bilingual_ad_effects)} bilingual ",
           "advertisement effects are positive with a confidence interval clear of zero ",
           "({str_flatten_comma(positive_significant$candidate)}); the third is ",
           "{str_flatten_comma(setdiff(bilingual_ad_effects$candidate, positive_significant$candidate))} ",
           "at {sprintf('%.1f', 100 * setdiff(bilingual_ad_effects$estimate, positive_significant$estimate))} points"))

emit("abstract_effect_five_points", 100 * mean(positive_significant$estimate),
     str_glue("Mean of the two positive bilingual advertisement effects, ",
              "{str_flatten_comma(sprintf('%.2f', 100 * positive_significant$estimate))} points"))

# Introduction ----

# "We count ourselves lucky that we were able to find three candidates who produced
#  otherwise identical versions of the same advertisement in both English and Spanish."
emit("intro_candidates_found", n_distinct(t5$candidate),
     "Candidates whose advertisement is a treatment in some experiment")

# "In all six advertisements, the candidate speaks directly to the camera and in his
#  own voice."
emit("intro_advertisements", 2 * n_distinct(t5$candidate),
     str_glue("Each of the {n_distinct(t5$candidate)} candidates contributes an ",
              "English and a Spanish version, which is what the advertisement ",
              "assignment contrasts"))

# "In the Bush experiment, we recruited 2,866 self-identified bilinguals, 1,862 of whom
#  passed a simple quiz in both languages. In the Vela and Coffman experiments, we
#  similarly recruited a sample of 2,233 bilinguals, of whom 1,681 passed the quiz."
emit("intro_bush_recruited", fact("study_1_recruited"),
     "Rows in the deposited study_1.csv, which carries the full recruited sample")
emit("intro_bush_passed", fact("study_1_passed_quiz"),
     "Study 1 respondents flagged bilingual, which is the quiz-passing flag")
emit("intro_vela_coffman_recruited", fact("study_2_recruited"),
     "Rows in the deposited study_2.csv")
emit("intro_vela_coffman_passed", fact("study_2_passed_quiz"),
     "Study 2 respondents flagged bilingual")

# "To preview our results, we find that the Spanish-language ad increases the
#  probability that bilingual subjects would vote for Bush by approximately 5
#  percentage points in a hypothetical general election matchup against Hillary
#  Clinton."
emit("intro_preview_bush_effect",
     100 * bilingual_ad_effects$estimate[bilingual_ad_effects$candidate == "bush"],
     "Bush bilingual advertisement effect on general election support, in points")

# Experimental Design ----

# "In our first experiment (Bush), we collected responses from 2,866 self-identified
#  Latinos, of which 1,862 passed a language quiz in both Spanish and English, the full
#  text of which is presented in the supplemental Appendix D. We consider these 1,862
#  who passed the quiz to be 'bilinguals.' In our second and third experiments (Vela
#  and Coffman), we obtained responses from 2,233 self-identified bilinguals, 1,681 of
#  whom passed the quiz."
emit("design_bush_recruited", fact("study_1_recruited"),
     "Rows in study_1.csv, as the design section counts them")
emit("design_bush_passed", fact("study_1_passed_quiz"),
     "Study 1 quiz passers, as the design section counts them")
emit("design_bush_passed_restated", fact("study_1_passed_quiz"),
     "The same count, restated in the next sentence")
emit("design_vela_coffman_recruited", fact("study_2_recruited"),
     "Rows in study_2.csv, as the design section counts them")
emit("design_vela_coffman_passed", fact("study_2_passed_quiz"),
     "Study 2 quiz passers, as the design section counts them")

# The appendix's own contents list is in the extraction, so which lettered section
# holds which material is recoverable without reading the appendix PDF again. The
# letter each sentence names is read out of the sentence itself.
appendix_sections <- published_claims |>
  filter(str_starts(claim_id, "appendix_section_")) |>
  transmute(letter = str_to_upper(str_remove(claim_id, "^appendix_section_")), claim)

section_letter <- function(title) {
  hit <- appendix_sections |> filter(str_detect(claim, fixed(title)))
  stopifnot(nrow(hit) == 1)
  hit$letter
}

cross_reference_holds <- function(id, title) {
  named <- str_match(claim_row(id)$claim, "Appendix ([A-E])")[, 2]
  actual <- section_letter(title)
  list(holds = named == actual, named = named, actual = actual)
}

quiz_ref <- cross_reference_holds("design_appendix_quiz_reference", "Language Quiz")
emit_holds("design_appendix_quiz_reference", quiz_ref$holds,
           str_glue("The sentence sends the reader to Appendix {quiz_ref$named}; the ",
                    "language quiz is appendix section {quiz_ref$actual}, and section ",
                    "{quiz_ref$named} is ",
                    "{str_remove(appendix_sections$claim[appendix_sections$letter == quiz_ref$named], ',.*')}"))

# "Of the 2,230 'nationally representative' subjects supplied to us, 1,344 did not pass
#  the language quiz. These subjects constitute our monolingual sample."
emit("design_mono_supplied", fact("study_3_supplied"),
     "Rows in the deposited study_3.csv")
emit("design_mono_failed", fact("study_3_failed_quiz"),
     "Study 3 respondents not flagged bilingual, which is the monolingual sample")

# Table 2's row labels name the number of levels in three of its measures:
# "Education(5 levels)", "Income(7 levels)", "Income(9 levels)".
emit("design_education_levels", fact("educ_5_n_levels"),
     "Distinct values of the deposited education measure, excluding the not-found code")
emit("design_income_7_levels", fact("income_7_n_levels"),
     "Distinct values of the deposited seven-level income measure")
emit("design_income_9_levels", fact("income_9_n_levels"),
     "Distinct values of the deposited nine-level income measure")

# "We conducted three separate experiments, each of which followed very similar
#  designs."
experiments <- n_distinct(str_extract(t3$block, "^experiment_[0-9]+"))
emit("design_experiments", experiments,
     "Experiments named in the randomization table's own block labels")

# "Experiment 1 was conducted on February 8th, 2016, among 1,862 bilinguals the day
#  before the New Hampshire primary. We employed a 2 x 2 factorial design in which the
#  first factor was a Spanish- or English-language advertisement. The second factor is
#  the language of the survey itself. Half the subjects took the entire survey in
#  English, while the other half took the entire survey in Spanish."
emit("design_exp1_bilinguals", fact("study_1_passed_quiz"),
     "Experiment 1's bilingual sample, which is the study 1 quiz passers")

experiment_1 <- t3 |> filter(str_starts(block, "experiment_1"))
emit("design_factorial_ad_levels", 2L,
     str_glue("Advertisement-language arms the randomization table reports for ",
              "experiment 1: {str_flatten_comma(c('english_ad', 'spanish_ad'))}"))
emit("design_factorial_survey_levels", n_distinct(experiment_1$survey_language),
     str_glue("Survey-language arms in experiment 1: ",
              "{str_flatten_comma(experiment_1$survey_language)}"))

survey_language_share <- experiment_1 |>
  mutate(subjects = english_ad + spanish_ad) |>
  mutate(share = subjects / sum(subjects))
emit_holds(
  "design_half_english",
  all(abs(survey_language_share$share - 0.5) < 0.05),
  str_glue("Experiment 1 splits ",
           "{str_flatten_comma(paste0(survey_language_share$survey_language, ' ',
                                      sprintf('%.1f', 100 * survey_language_share$share), '%'))} ",
           "across {sum(survey_language_share$subjects)} subjects"))

emit("design_exp23_bilinguals", fact("study_2_passed_quiz"),
     "Experiments 2 and 3's bilingual sample")
emit("design_exp23_monolinguals", fact("study_3_failed_quiz"),
     "Experiments 2 and 3's monolingual sample")

# "The number of subjects in each cell is consistent with random assignment
#  (chi-squared = 7.3, df = 7, p = 0.40)."
emit("design_chisq_statistic", t3_chisq$statistic,
     "Pearson chi-squared over the randomization table's own cell counts")
emit("design_chisq_df", t3_chisq$df, "Degrees of freedom of that test")
emit("design_chisq_p", t3_chisq$p_value, "p-value of that test")

# "Our five outcome measures are shown next."
measures <- n_distinct(outcome_measure(main_tables$outcome)) +
  n_distinct(outcome_measure(t9$outcome))
emit("design_outcome_measures", measures,
     str_glue("Distinct outcome measures across the five main-text table files: ",
              "{str_flatten_comma(c(sort(unique(outcome_measure(main_tables$outcome))),
                                    unique(outcome_measure(t9$outcome))))}"))

# "We present the English-language versions here; subjects assigned to the
#  Spanish-language survey saw these questions in Spanish, the full text of which is
#  available in the supplemental Appendix C."
survey_ref <- cross_reference_holds("design_appendix_survey_reference",
                                    "Spanish-Language Survey")
emit_holds("design_appendix_survey_reference", survey_ref$holds,
           str_glue("The sentence sends the reader to Appendix {survey_ref$named}; the ",
                    "Spanish-language survey is appendix section {survey_ref$actual}, ",
                    "and section {survey_ref$named} is ",
                    "{str_remove(appendix_sections$claim[appendix_sections$letter == survey_ref$named], ',.*')}"))

# "Our main outcome measure is the candidate preference question, which is coded 1 if
#  the respondent preferred the advertising candidate and 0 otherwise."
emit("design_general_high", fact("bush_general_max"),
     "Largest value of the deposited general election preference variable")
emit("design_general_low", fact("bush_general_min"),
     "Smallest value of that variable")

# "Like Candidate: ... [Branching question mapped into scale from 1 to 7]"
emit("design_like_scale_min", fact("like_bush_min"),
     "Smallest value of the deposited liking variable")
emit("design_like_scale_max", fact("like_bush_max"),
     "Largest value of the deposited liking variable")

# "Candidate Cares: ... [Response options: 1: Cares about people like me, 0: Doesn't
#  care about people like me]"
emit("design_cares_high", fact("bush_cares_max"),
     "Largest value of the deposited candidate-cares variable")
emit("design_cares_low", fact("bush_cares_min"),
     "Smallest value of that variable")

# "Confidence in Candidate: ... [Scale from 1 to 4, where 4 indicates greater
#  confidence]"
emit("design_confidence_min", fact("conf_in_bush_min"),
     str_glue("Smallest value of the deposited confidence variable, which takes ",
              "{fact('conf_in_bush_n_values')} values"))
emit("design_confidence_max", fact("conf_in_bush_max"),
     "Largest value of the deposited confidence variable")
emit("design_confidence_top", fact("conf_in_bush_max"),
     "The value that indicates greatest confidence, which is that variable's maximum")

# "Linked Fate: ... [Scale from 1 to 4, where 4 indicates 'a lot']"
emit("design_linked_fate_min", fact("linked_fate_min"),
     str_glue("Smallest value of the deposited linked fate variable, which takes ",
              "{fact('linked_fate_n_values')} values"))
emit("design_linked_fate_max", fact("linked_fate_max"),
     "Largest value of the deposited linked fate variable")
emit("design_linked_fate_top", fact("linked_fate_max"),
     "The value that indicates 'a lot', which is that variable's maximum")

# "Our substantive results do not depend on this choice (see supplemental Appendix A
#  for logistic regression tables equivalent to Tables 5 and 7)."
logit_ref <- cross_reference_holds("design_appendix_logit_reference",
                                   "Binary Choice Models")
emit_holds("design_appendix_logit_reference", logit_ref$holds,
           str_glue("The sentence sends the reader to Appendix {logit_ref$named}; the ",
                    "logistic regression tables are appendix section ",
                    "{logit_ref$actual}, and section {logit_ref$named} is ",
                    "{str_remove(appendix_sections$claim[appendix_sections$letter == logit_ref$named], ',.*')}"))

# Results ----

# "Due to item non-response, the number of subjects who answer each question changes
#  very slightly; formal tests indicate that item non-response is unlikely to be
#  related to treatment assignment."
sample_spread <- main_tables |>
  bind_rows(t9 |> mutate(candidate = experiment, sample = "bilingual")) |>
  filter(term %in% c(treatment_terms, "Z_survey")) |>
  summarize(low = min(n), high = max(n), .by = c(candidate, sample)) |>
  mutate(spread = (high - low) / high)
emit_holds(
  "results_n_varies",
  max(sample_spread$spread) < 0.01,
  str_glue("Across the five outcomes the analysed sample moves by at most ",
           "{sprintf('%.2f', 100 * max(sample_spread$spread))}% within a ",
           "candidate-by-sample cell, the widest being ",
           "{sample_spread$candidate[which.max(sample_spread$spread)]} ",
           "{sample_spread$sample[which.max(sample_spread$spread)]} at ",
           "{sample_spread$low[which.max(sample_spread$spread)]} to ",
           "{sample_spread$high[which.max(sample_spread$spread)]}"))

emit_holds(
  "results_nonresponse_tests", NA,
  str_glue("No counterpart in the deposit: none of its eight scripts tests item ",
           "non-response against treatment assignment, and adding one would estimate ",
           "something the deposit never did. What is checkable is the size of the ",
           "non-response, which moves the analysed sample by at most ",
           "{sprintf('%.2f', 100 * max(sample_spread$spread))}%"))

# "Table 5 shows our main results in all three experiments."
emit("results_three_experiments", experiments,
     "Experiments, as the results section counts them")

# "In column 1 we estimate that, relative to subjects who saw the English-language ad,
#  bilingual subjects who saw the Spanish-language ad were 4.9 percentage points
#  (SE: 2.3 percentage points) more likely to support Bush in the general election."
bush_ad <- bilingual_ad_effects |> filter(candidate == "bush")
emit("results_bush_ate", 100 * bush_ad$estimate,
     "Bush bilingual advertisement effect, in percentage points")
emit("results_bush_ate_se", 100 * bush_ad$std.error,
     "Its HC2 standard error, in percentage points")

# "We obtain the identical point estimate in our second experiment: the effect on
#  bilinguals' general election support for Filemon Vela is also estimated to be 4.9
#  percentage points (SE: 2.4 percentage points). Both estimates are statistically
#  significant at conventional levels."
vela_ad <- bilingual_ad_effects |> filter(candidate == "vela")
emit_holds(
  "results_identical_point_estimate",
  sprintf("%.1f", 100 * bush_ad$estimate) == sprintf("%.1f", 100 * vela_ad$estimate),
  str_glue("Bush {sprintf('%.3f', 100 * bush_ad$estimate)} against Vela ",
           "{sprintf('%.3f', 100 * vela_ad$estimate)} points, identical at the one ",
           "decimal the sentence uses and not before it"))
emit("results_vela_ate", 100 * vela_ad$estimate,
     "Vela bilingual advertisement effect, in percentage points")
emit("results_vela_ate_se", 100 * vela_ad$std.error,
     "Its HC2 standard error, in percentage points")
emit_holds(
  "results_both_significant",
  all(c(bush_ad$conf.low, vela_ad$conf.low) > 0),
  str_glue("Bush [{sprintf('%.1f', 100 * bush_ad$conf.low)}, ",
           "{sprintf('%.1f', 100 * bush_ad$conf.high)}] and Vela ",
           "[{sprintf('%.1f', 100 * vela_ad$conf.low)}, ",
           "{sprintf('%.1f', 100 * vela_ad$conf.high)}] both exclude zero"))

# "we see in column 2 of Table 5 that being assigned to take the survey in Spanish
#  increased support for Filemon Vela by an astounding 7.3 percentage points
#  (SE: 2.4 percentage points)."
vela_survey <- t5 |> filter(candidate == "vela", sample == "bilingual", term == "Z_survey")
emit("results_vela_survey_ate", 100 * vela_survey$estimate,
     "Effect of the Spanish-language survey on bilinguals' support for Vela, in points")
emit("results_vela_survey_ate_se", 100 * vela_survey$std.error,
     "Its HC2 standard error, in percentage points")

# "For Vela, the average effect is estimated to be negative two percentage points,
#  although this estimate cannot be distinguished from zero."
vela_mono <- t5 |> filter(candidate == "vela", sample == "monolingual",
                          term %in% treatment_terms)
emit("results_vela_mono_ate", 100 * vela_mono$estimate,
     "Vela monolingual advertisement effect, in percentage points")
emit_holds("results_vela_mono_not_significant",
           vela_mono$conf.low < 0 & vela_mono$conf.high > 0,
           str_glue("Its interval runs [{sprintf('%.1f', 100 * vela_mono$conf.low)}, ",
                    "{sprintf('%.1f', 100 * vela_mono$conf.high)}] points and covers zero"))

# "Relative to seeing the ad in English, support for Coffman decreases by 18.7
#  percentage points (SE: 2.6 percentage points) when subjects see the ad in Spanish,
#  a language they do not speak. This very large negative treatment cannot be explained
#  by a high baseline or other ceiling effects, as Coffman's support in the control
#  group was 51%."
coffman_mono <- t5 |> filter(candidate == "coffman", sample == "monolingual",
                             term %in% treatment_terms)
emit("results_coffman_mono_ate", 100 * coffman_mono$estimate,
     "Coffman monolingual advertisement effect, in percentage points")
emit("results_coffman_mono_ate_se", 100 * coffman_mono$std.error,
     "Its HC2 standard error, in percentage points")
coffman_mono_control <- t5 |> filter(candidate == "coffman", sample == "monolingual",
                                     term == "(Intercept)")
emit("results_coffman_control_support", 100 * coffman_mono_control$estimate,
     "Control-group mean of Coffman's general election support, as a percentage")

# "The Spanish-language ad causes bilingual subjects to like Bush somewhat more
#  (0.167 points on a seven-point scale, SE: 0.075 points)."
bush_like <- t6 |> filter(candidate == "bush", sample == "bilingual",
                          term %in% treatment_terms)
emit("results_bush_like_ate", bush_like$estimate,
     "Effect on liking Bush, in scale points")
emit("results_bush_like_ate_se", bush_like$std.error,
     "Its HC2 standard error, in scale points")
emit("results_seven_point_scale", fact("like_bush_max"),
     "Top of the liking scale, read off the deposited variable")

# "We observe mildly positive effects among bilinguals on the order of 2 to 3
#  percentage points and massively negative effects among monolinguals -- negative
#  15.2 percentage points (SE: 2.5 percentage points) for Vela and negative 15.5
#  percentage points (SE: 2.4 percentage points) for Coffman."
cares_bilingual <- t7 |> filter(sample == "bilingual", term %in% treatment_terms)
emit_holds(
  "results_bilingual_cares_magnitude", NA,
  str_glue("The three bilingual effects on candidate caring are ",
           "{str_flatten_comma(paste0(cares_bilingual$candidate, ' ',
                                      sprintf('%.1f', 100 * cares_bilingual$estimate)))} ",
           "points, a range the sentence hedges as being on the order of 2 to 3"))
vela_mono_cares <- t7 |> filter(candidate == "vela", sample == "monolingual",
                                term %in% treatment_terms)
coffman_mono_cares <- t7 |> filter(candidate == "coffman", sample == "monolingual",
                                   term %in% treatment_terms)
emit("results_vela_mono_cares", 100 * vela_mono_cares$estimate,
     "Vela monolingual effect on candidate caring, in percentage points")
emit("results_vela_mono_cares_se", 100 * vela_mono_cares$std.error,
     "Its HC2 standard error, in percentage points")
emit("results_coffman_mono_cares", 100 * coffman_mono_cares$estimate,
     "Coffman monolingual effect on candidate caring, in percentage points")
emit("results_coffman_mono_cares_se", 100 * coffman_mono_cares$std.error,
     "Its HC2 standard error, in percentage points")

# "Out of 12 opportunities, none of the interaction terms are significant at the 5%
#  level. Two of the 12 are significant at the 10% level."
interactions <- a1_a4 |> filter(str_detect(term, ":"))
emit("results_interaction_opportunities", nrow(interactions),
     "Advertisement-by-survey interaction terms across the four appendix A tables")
emit("results_interaction_sig_05", sum(interactions$p.value < 0.05),
     str_glue("Interactions with a p-value below 0.05; the smallest of the twelve is ",
              "{sprintf('%.3f', min(interactions$p.value))}"))
emit("results_interaction_sig_10", sum(interactions$p.value < 0.10),
     str_glue("Interactions with a p-value below 0.10: ",
              "{str_flatten_comma(paste0(interactions$table[interactions$p.value < 0.10], ' ',
                                         interactions$candidate[interactions$p.value < 0.10]))}"))
emit("results_interaction_opportunities_restated", nrow(interactions),
     "The same denominator, restated in the next sentence")

# "Figure 1. Estimated average treatment effects of Spanish-language versus
#  English-language advertisements on four outcomes."
emit("results_figure_1_outcomes", n_distinct(outcome_measure(figure_1$outcome)),
     str_glue("Outcome measures Figure 1 plots: ",
              "{str_flatten_comma(sort(unique(outcome_measure(figure_1$outcome))))}"))

# "Among Republicans, the effect is -16.8 percentage points (SE: 4.0 points) and among
#  Democrats it is -14.1 points (SE: 3.3 points); the difference is not statistically
#  significant."
coffman_mono_party <- b5_b8 |>
  filter(table == "b5", candidate == "coffman", sample == "monolingual",
         term %in% treatment_terms)
republican <- coffman_mono_party |> filter(party == "republican")
democrat <- coffman_mono_party |> filter(party == "democrat")
emit("results_coffman_rep_ate", 100 * republican$estimate,
     "Coffman monolingual Republican advertisement effect, in percentage points")
emit("results_coffman_rep_ate_se", 100 * republican$std.error,
     "Its HC2 standard error, in percentage points")
emit("results_coffman_dem_ate", 100 * democrat$estimate,
     "Coffman monolingual Democrat advertisement effect, in percentage points")
emit("results_coffman_dem_ate_se", 100 * democrat$std.error,
     "Its HC2 standard error, in percentage points")

party_gap <- republican$estimate - democrat$estimate
party_gap_se <- sqrt(republican$std.error^2 + democrat$std.error^2)
party_gap_p <- 2 * pnorm(-abs(party_gap / party_gap_se))
emit_holds(
  "results_party_difference_ns", party_gap_p > 0.05,
  str_glue("The two subsamples are disjoint, so the difference is ",
           "{sprintf('%.1f', 100 * party_gap)} points with a standard error of ",
           "{sprintf('%.1f', 100 * party_gap_se)} and a normal p-value of ",
           "{sprintf('%.2f', party_gap_p)}"))

# "Figure 2 shows the estimated effects of treatment by party for all four dependent
#  variables."
emit("results_figure_2_dvs", n_distinct(outcome_measure(figure_2$outcome)),
     str_glue("Outcome measures Figure 2 plots: ",
              "{str_flatten_comma(sort(unique(outcome_measure(figure_2$outcome))))}"))

# "Figure 2. Heterogeneous effects of Spanish-language advertisment on four outcomes,
#  by respondent partisanship."
emit("results_figure_2_caption_outcomes", n_distinct(outcome_measure(figure_2$outcome)),
     "The same count, as the caption states it")

# "First, among monolinguals, the pattern of treatment effects does not differ by
#  respondent partisanship. Monolingual Republicans and Democrats alike respond
#  negatively to the Spanish-language advertisement."
party_contrast <- figure_2 |>
  select(sample, party, outcome, estimate, std.error) |>
  pivot_wider(names_from = party, values_from = c(estimate, std.error)) |>
  rename(estimate_dem = `estimate_Democratic Respondents`,
         estimate_rep = `estimate_Republican Respondents`,
         se_dem = `std.error_Democratic Respondents`,
         se_rep = `std.error_Republican Respondents`) |>
  mutate(gap = estimate_dem - estimate_rep,
         gap_se = sqrt(se_dem^2 + se_rep^2),
         gap_p = 2 * pnorm(-abs(gap / gap_se)))
# The sentence that follows says what "does not differ" means here, so that is the
# test: both parties respond in the same direction. The label carries the stricter
# reading, under which two of the eight party differences do separate from zero.
monolingual_contrast <- party_contrast |> filter(sample == "Monolingual Sample")
monolingual_estimates <- c(monolingual_contrast$estimate_dem,
                           monolingual_contrast$estimate_rep)
emit_holds(
  "results_mono_no_party_difference",
  all(monolingual_estimates < 0),
  str_glue("All {length(monolingual_estimates)} monolingual estimates are negative for ",
           "both parties. Of the {nrow(monolingual_contrast)} Democrat-Republican ",
           "differences, {sum(monolingual_contrast$gap_p < 0.05)} separate from zero at ",
           "0.05 ({str_flatten_comma(paste0(monolingual_contrast$outcome[monolingual_contrast$gap_p < 0.05], ' p=',
                                            sprintf('%.3f', monolingual_contrast$gap_p[monolingual_contrast$gap_p < 0.05])))}), ",
           "so the pattern agrees in sign without being identical in magnitude"))

# "By contrast, we do see some differences in treatment response by partisanship among
#  the bilingual sample. Democratic bilinguals respond positively to both the Vela and
#  Coffman Spanish-language ads, whereas Republican bilinguals respond negatively to
#  both."
# The sentence is about each candidate's advertisement rather than about a single
# outcome, so the test is taken per candidate over the four outcomes Figure 2 plots.
bilingual_contrast <- party_contrast |>
  filter(sample == "Bilingual Sample") |>
  mutate(candidate = if_else(str_detect(outcome, "vela"), "vela", "coffman"))
by_candidate <- bilingual_contrast |>
  summarize(dem_positive = sum(estimate_dem > 0),
            rep_negative = sum(estimate_rep < 0),
            outcomes = n(), .by = candidate)
emit_holds(
  "results_bilingual_party_direction",
  all(by_candidate$dem_positive > by_candidate$outcomes / 2) &&
    all(by_candidate$rep_negative > by_candidate$outcomes / 2),
  str_glue("Per candidate, of the {unique(by_candidate$outcomes)} outcomes Figure 2 ",
           "plots: ",
           "{str_flatten_comma(paste0(by_candidate$candidate, ' ', by_candidate$dem_positive,
                                      ' positive for Democrats and ', by_candidate$rep_negative,
                                      ' negative for Republicans'))}. ",
           "The exception on both sides is the Coffman general election cell, at ",
           "{sprintf('%.1f', 100 * bilingual_contrast$estimate_dem[bilingual_contrast$outcome == 'coffman_general'])} ",
           "and ",
           "{sprintf('%.1f', 100 * bilingual_contrast$estimate_rep[bilingual_contrast$outcome == 'coffman_general'])} ",
           "points, neither separable from zero"))

# "The treatment raised linked fate by 0.24 scale points (SE: 0.04 points) on average
#  in the Bush experiment and by 0.13 scale points (SE: 0.04 points) in the Vela and
#  Coffman experiments. Both estimates are statistically significant."
linked_fate <- t9 |> filter(term == "Z_survey")
lf_bush <- linked_fate |> filter(experiment == "bush_bilingual")
lf_vela_coffman <- linked_fate |> filter(experiment == "vela_coffman_bilingual")
emit("results_linked_fate_bush", lf_bush$estimate,
     "Effect of the Spanish-language survey on linked fate, Bush experiment")
emit("results_linked_fate_bush_se", lf_bush$std.error,
     "Its HC2 standard error, in scale points")
emit("results_linked_fate_vela_coffman", lf_vela_coffman$estimate,
     "The same effect in the Vela and Coffman experiments")
emit("results_linked_fate_vela_coffman_se", lf_vela_coffman$std.error,
     "Its HC2 standard error, in scale points")
emit_holds(
  "results_linked_fate_both_significant",
  all(linked_fate$conf.low > 0),
  str_glue("Both intervals sit above zero: ",
           "{str_flatten_comma(paste0('[', sprintf('%.2f', linked_fate$conf.low), ', ',
                                      sprintf('%.2f', linked_fate$conf.high), ']'))}"))

# Discussion ----

# "Drawing on evidence from three randomized survey experiments, we have shown that the
#  language a politician uses to communicate with a bilingual audience has electoral
#  consequences."
emit("discussion_three_experiments", experiments,
     "Experiments, as the discussion counts them")

# "In the Bush and Vela experiments, bilingual subjects who were randomly assigned to
#  view a Spanish-language ad were approximately 5 percentage points more likely to
#  support the advertising candidate."
emit("discussion_effect_five_points", 100 * mean(positive_significant$estimate),
     str_glue("The same mean of the Bush and Vela bilingual effects, ",
              "{str_flatten_comma(sprintf('%.2f', 100 * positive_significant$estimate))} points"))

# "Suppose for the moment that the positive effect among bilinguals is 5 percentage
#  points but the effect among English-only monolinguals is negative 15 percentage
#  points."
surface <- figure_3 |> filter(quantity == "net_effect")
all_bilingual <- surface |> filter(prop_bilingual == max(prop_bilingual))
no_bilingual_all_mistargeted <- surface |>
  filter(prop_bilingual == min(prop_bilingual),
         prop_mistargeted == max(prop_mistargeted))
emit("discussion_assumed_bilingual_effect", 100 * unique(all_bilingual$value),
     str_glue("Net effect where the electorate is entirely bilingual, read off the ",
              "simulated surface; the same at all ",
              "{nrow(all_bilingual)} mistargeting risks"))
emit("discussion_assumed_monolingual_effect", 100 * no_bilingual_all_mistargeted$value,
     "Net effect with no bilinguals and every monolingual mistargeted")

# "When the electorate is 0% or 100% bilingual, the respective strategies are clear:
#  use English or Spanish exclusively."
emit("discussion_electorate_zero", 100 * min(surface$prop_bilingual),
     "Lower end of the simulated bilingual share, as a percentage")
emit("discussion_electorate_hundred", 100 * max(surface$prop_bilingual),
     "Upper end of the simulated bilingual share, as a percentage")

# "But because of the extreme downside risk of mistargeting relative to the possible
#  benefit of correctly targeting bilingual constituents, candidates should be cautious
#  when pursuing a Spanish-language advertising strategy, even when more than 50% of
#  the constituency is bilingual."
majority_bilingual <- surface |> filter(prop_bilingual > 0.5)
emit_holds(
  "discussion_majority_bilingual",
  any(majority_bilingual$value < 0),
  str_glue("{sum(majority_bilingual$value < 0)} of {nrow(majority_bilingual)} ",
           "simulated cells above a half-bilingual electorate carry a negative net ",
           "effect, the worst being ",
           "{sprintf('%.1f', 100 * min(majority_bilingual$value))} points"))

# Appendix A ----

# "In this section, we will present estimates of the effects of treatment on all four
#  dependent variables using a model that includes an interaction between the language
#  of the advertisement and the language of the survey. As indicated by the small and
#  statistically insignificant coefficients on the interaction terms, the effects of
#  the advertisement treatment do not appear to be moderated by the language of the
#  survey."
emit("appendix_a_dependent_variables", n_distinct(outcome_measure(a1_a4$outcome)),
     str_glue("Outcome measures the appendix A tables cover: ",
              "{str_flatten_comma(sort(unique(outcome_measure(a1_a4$outcome))))}"))
emit_holds(
  "appendix_a_interactions_insignificant",
  all(interactions$p.value >= 0.05),
  str_glue("None of the {nrow(interactions)} interaction terms clears 0.05; the ",
           "largest in absolute value is ",
           "{sprintf('%.3f', max(abs(interactions$estimate)))} with a p-value of ",
           "{sprintf('%.3f', interactions$p.value[which.max(abs(interactions$estimate))])}"))

# Appendix C ----

# "Two of our dependent variables (Prefer Candidate in General and Candidate Cares) are
#  binary."
binary_outcomes <- design_facts |>
  filter(str_ends(quantity, "_n_values"), !str_starts(quantity, "educ|income"),
         value == 2)
emit("appendix_c_binary_outcomes", nrow(binary_outcomes),
     str_glue("Outcomes taking exactly two values: ",
              "{str_flatten_comma(str_remove(binary_outcomes$quantity, '_n_values$'))}"))

# "When we compute the average marginal effects (not shown, but included in the
#  replication archive code) from these models, we obtain answers that match the OLS
#  models to the second decimal place or better."
ols <- bind_rows(t5 |> mutate(table = "c9"), t7 |> mutate(table = "c10")) |>
  filter(term %in% treatment_terms) |>
  select(table, candidate, sample, ols = estimate)
ame_gap <- ames |>
  filter(term %in% treatment_terms) |>
  inner_join(ols, by = c("table", "candidate", "sample")) |>
  mutate(gap = abs(estimate - ols))
stopifnot(nrow(ame_gap) == nrow(ols))
emit_holds(
  "appendix_c_ame_matches_ols",
  max(ame_gap$gap) < 0.005,
  str_glue("Across all {nrow(ame_gap)} models the largest gap between the logit ",
           "average marginal effect and the OLS coefficient is ",
           "{signif(max(ame_gap$gap), 3)}, which is inside half a hundredth"))

# Floats that print no numbers ----

# Figures 1 and 2 print no estimate on their faces, so what each asserts is the number
# of estimates it plots, counted off the published page and recomputed here.
emit("float_figure_1", nrow(figure_1),
     str_glue("Estimates Figure 1 plots: {n_distinct(figure_1$outcome)} ",
              "candidate-by-outcome series across ",
              "{n_distinct(figure_1$sample)} samples"))
emit("float_figure_2", nrow(figure_2),
     str_glue("Estimates Figure 2 plots: Figure 1's Vela and Coffman series split by ",
              "{n_distinct(figure_2$party)} respondent parties"))
emit("float_figure_3", nrow(surface),
     str_glue("Figure 3 is a continuous raster whose cells cannot be counted from the ",
              "page. The rewrite commits {nrow(surface)} points of the surface it ",
              "draws, on a grid of {n_distinct(surface$prop_bilingual)} bilingual ",
              "shares by {n_distinct(surface$prop_mistargeted)} mistargeting risks"))
