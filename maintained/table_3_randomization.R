# flores_coppock_2018/maintained/table_3_randomization.R
# Output: output/table_3_randomization.csv, output/table_3_chisq.csv
# Depends on: helpers.R
# Description: Table 3, the number of subjects in each experiment by condition, and the
#   chi-squared test the article reports beneath it as a check on random assignment.
#   Monolinguals took the survey in English only, so their two blocks are single rows.

source(here::here("maintained", "helpers.R"))

# Cell counts ----
cells <- rbind(
  with(s1_bil, table(Z_survey, Z_ad)),
  with(s2_bil, table(Z_survey, Z_vela)),
  with(s3_mono, table(Z_vela)),
  with(s2_bil, table(Z_survey, Z_coffman)),
  with(s3_mono, table(Z_coffman))
)

counts <- tibble(
  block = c(
    "experiment_1_bush_bilingual", "experiment_1_bush_bilingual",
    "experiment_2_vela_bilingual", "experiment_2_vela_bilingual",
    "experiment_2_vela_monolingual",
    "experiment_3_coffman_bilingual", "experiment_3_coffman_bilingual",
    "experiment_3_coffman_monolingual"
  ),
  survey_language = c(
    "english_survey", "spanish_survey",
    "english_survey", "spanish_survey",
    "english_survey",
    "english_survey", "spanish_survey",
    "english_survey"
  ),
  english_ad = cells[, 1],
  spanish_ad = cells[, 2]
)

write_csv(counts, here::here("maintained", "output", "table_3_randomization.csv"))

# Balance test ----
ct <- chisq.test(cells)

write_csv(
  tibble(statistic = unname(ct$statistic), df = unname(ct$parameter), p_value = ct$p.value),
  here::here("maintained", "output", "table_3_chisq.csv")
)
