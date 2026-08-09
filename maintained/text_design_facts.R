# flores_coppock_2018/maintained/text_design_facts.R
# Output: output/text_design_facts.csv
# Depends on: helpers.R
# Description: The design quantities the article states in prose rather than in a table:
#   how many subjects were recruited into each experiment and how many passed the
#   language quiz, the range of each outcome scale, and the number of levels in the two
#   income measures and the education measure that Table 2 names in its row labels.
#   Every one of them is in the deposited data and none of them was in output/, so the
#   sampling paragraph and the outcome-measure list had nothing to be checked against.

source(here::here("maintained", "helpers.R"))

# Recruitment and the language quiz ----
# The deposit ships the full recruited sample for each experiment, not only the subjects
# who passed the quiz, so both counts are recoverable. Study 3's monolinguals are the
# subjects who FAILED the quiz, which is why its two counts read the other way round.
recruitment <- tibble(
  quantity = c("study_1_recruited", "study_1_passed_quiz",
               "study_2_recruited", "study_2_passed_quiz",
               "study_3_supplied", "study_3_failed_quiz"),
  value = c(nrow(study_1), sum(study_1$bilingual == 1),
            nrow(study_2), sum(study_2$bilingual == 1),
            nrow(study_3), sum(study_3$bilingual == 0))
)

# Outcome scales ----
# One row per endpoint of each outcome the article describes, taken from the Bush
# experiment, where all five outcomes are measured.
outcome_range <- function(x) {
  values <- x[!is.na(x)]
  tibble(min = min(values), max = max(values), n_values = n_distinct(values))
}

scales <- s1_bil |>
  select(bush_general, like_bush, bush_cares, conf_in_bush, linked_fate) |>
  pivot_longer(everything(), names_to = "outcome", values_to = "value") |>
  filter(!is.na(value)) |>
  summarize(min = min(value), max = max(value), n_values = n_distinct(value),
            .by = outcome) |>
  pivot_longer(c(min, max, n_values), names_to = "stat", values_to = "value") |>
  transmute(quantity = paste(outcome, stat, sep = "_"), value)

# Levels of the Table 2 row labels that name a number of levels ----
# educ_5 codes "Not Found" as 99; those cases are missing, not a sixth level.
levels_named <- tibble(
  quantity = c("educ_5_n_levels", "income_7_n_levels", "income_9_n_levels"),
  value = c(n_distinct(s1_bil$educ_5[s1_bil$educ_5 != 99 & !is.na(s1_bil$educ_5)]),
            n_distinct(s1_bil$income_7[!is.na(s1_bil$income_7)]),
            n_distinct(s1_bil$income_9[!is.na(s1_bil$income_9)]))
)

out <- bind_rows(recruitment, scales, levels_named)

write_csv(out, here::here("maintained", "output", "text_design_facts.csv"))
