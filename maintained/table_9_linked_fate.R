# flores_coppock_2018/maintained/table_9_linked_fate.R
# Output: output/table_9_linked_fate.csv
# Depends on: helpers.R
# Description: Table 9, the effect of taking the survey in Spanish on linked fate (1-4),
#   among bilinguals in the Bush experiment and in the Vela and Coffman experiments.

source(here::here("maintained", "helpers.R"))

specs <- list(
  list(formula = linked_fate ~ Z_survey, data = s1_bil, experiment = "bush_bilingual"),
  list(formula = linked_fate ~ Z_survey, data = s2_bil, experiment = "vela_coffman_bilingual")
)

out <- specs |>
  map(\(s) {
    fit <- lm_robust(s$formula, data = s$data, se_type = "HC2")
    tidy(fit) |> mutate(experiment = s$experiment, n = fit$nobs)
  }) |>
  list_rbind() |>
  select(experiment, outcome, term, estimate, std.error, conf.low, conf.high, n)

write_csv(out, here::here("maintained", "output", "table_9_linked_fate.csv"))
