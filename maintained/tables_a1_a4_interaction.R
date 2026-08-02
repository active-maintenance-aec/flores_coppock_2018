# flores_coppock_2018/maintained/tables_a1_a4_interaction.R
# Output: output/tables_a1_a4_interaction.csv
# Depends on: helpers.R
# Description: Appendix Tables A.1 through A.4, which add an advertisement-language by
#   survey-language interaction to the four bilingual-sample models. One script rather
#   than four because the twelve models differ only in the outcome and share a single
#   output file.

source(here::here("maintained", "helpers.R"))

specs <- list(
  # Table A.1, general election support
  list(formula = bush_general    ~ Z_ad * Z_survey,      data = s1_bil, table = "a1", candidate = "bush"),
  list(formula = vela_general    ~ Z_vela * Z_survey,    data = s2_bil, table = "a1", candidate = "vela"),
  list(formula = coffman_general ~ Z_coffman * Z_survey, data = s2_bil, table = "a1", candidate = "coffman"),
  # Table A.2, perceptions of candidate caring
  list(formula = bush_cares    ~ Z_ad * Z_survey,      data = s1_bil, table = "a2", candidate = "bush"),
  list(formula = vela_cares    ~ Z_vela * Z_survey,    data = s2_bil, table = "a2", candidate = "vela"),
  list(formula = coffman_cares ~ Z_coffman * Z_survey, data = s2_bil, table = "a2", candidate = "coffman"),
  # Table A.3, confidence on immigration
  list(formula = conf_in_bush    ~ Z_ad * Z_survey,      data = s1_bil, table = "a3", candidate = "bush"),
  list(formula = conf_in_vela    ~ Z_vela * Z_survey,    data = s2_bil, table = "a3", candidate = "vela"),
  list(formula = conf_in_coffman ~ Z_coffman * Z_survey, data = s2_bil, table = "a3", candidate = "coffman"),
  # Table A.4, liking the candidate
  list(formula = like_bush    ~ Z_ad * Z_survey,      data = s1_bil, table = "a4", candidate = "bush"),
  list(formula = like_vela    ~ Z_vela * Z_survey,    data = s2_bil, table = "a4", candidate = "vela"),
  list(formula = like_coffman ~ Z_coffman * Z_survey, data = s2_bil, table = "a4", candidate = "coffman")
)

out <- specs |>
  map(\(s) {
    fit <- lm_robust(s$formula, data = s$data, se_type = "HC2")
    tidy(fit) |> mutate(table = s$table, candidate = s$candidate, n = fit$nobs)
  }) |>
  list_rbind() |>
  select(table, candidate, outcome, term, estimate, std.error, conf.low, conf.high, n)

write_csv(out, here::here("maintained", "output", "tables_a1_a4_interaction.csv"))
