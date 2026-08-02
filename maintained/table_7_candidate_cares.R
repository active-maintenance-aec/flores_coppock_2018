# flores_coppock_2018/maintained/table_7_candidate_cares.R
# Output: output/table_7_candidate_cares.csv
# Depends on: helpers.R
# Description: Table 7, the effect of the Spanish-language advertisement on
#   perceptions that the candidate cares about people like the respondent.
#   The archive fits these with lm() and takes HC2 standard errors from
#   estimatr::starprep(); lm_robust(se_type = "HC2") is the same estimator in one call.

source(here::here("maintained", "helpers.R"))

specs <- list(
  list(formula = bush_cares    ~ Z_ad      + Z_survey, data = s1_bil, candidate = "bush", sample = "bilingual"),
  list(formula = vela_cares    ~ Z_vela    + Z_survey, data = s2_bil, candidate = "vela", sample = "bilingual"),
  list(formula = vela_cares    ~ Z_vela, data = s3_mono, candidate = "vela", sample = "monolingual"),
  list(formula = coffman_cares ~ Z_coffman + Z_survey, data = s2_bil, candidate = "coffman", sample = "bilingual"),
  list(formula = coffman_cares ~ Z_coffman, data = s3_mono, candidate = "coffman", sample = "monolingual")
)

out <- specs |>
  map(\(s) {
    fit <- lm_robust(s$formula, data = s$data, se_type = "HC2")
    tidy(fit) |> mutate(candidate = s$candidate, sample = s$sample, n = fit$nobs)
  }) |>
  list_rbind() |>
  select(candidate, sample, outcome, term, estimate, std.error, conf.low, conf.high, n)

write_csv(out, here::here("maintained", "output", "table_7_candidate_cares.csv"))
