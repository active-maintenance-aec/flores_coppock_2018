# flores_coppock_2018/maintained/tables_b5_b8_pid.R
# Output: output/tables_b5_b8_pid.csv
# Depends on: helpers.R
# Description: Appendix Tables B.5 through B.8, the effect of the Spanish-language
#   advertisement within partisan subgroups, for Vela and Coffman in both samples.
#   Thirty-two models: four outcomes by two candidates by two samples by two parties.
#   The in-text partisan effects on page 16 of the article come from this file.

source(here::here("maintained", "helpers.R"))

pid_subsets <- list(
  list(data = filter(s2_bil, democrat == 1), sample = "bilingual", party = "democrat"),
  list(data = filter(s2_bil, republican == 1), sample = "bilingual", party = "republican"),
  list(data = filter(s3_mono, democrat == 1), sample = "monolingual", party = "democrat"),
  list(data = filter(s3_mono, republican == 1), sample = "monolingual", party = "republican")
)

dvs <- list(
  list(vela_formula = vela_general ~ Z_vela, coffman_formula = coffman_general ~ Z_coffman, table = "b5"),
  list(vela_formula = like_vela ~ Z_vela, coffman_formula = like_coffman ~ Z_coffman, table = "b6"),
  list(vela_formula = vela_cares ~ Z_vela, coffman_formula = coffman_cares ~ Z_coffman, table = "b7"),
  list(vela_formula = conf_in_vela ~ Z_vela, coffman_formula = conf_in_coffman ~ Z_coffman, table = "b8")
)

out <- dvs |>
  map(\(dv) {
    pid_subsets |>
      map(\(sub) {
        fits <- list(
          vela = lm_robust(dv$vela_formula, data = sub$data, se_type = "HC2"),
          coffman = lm_robust(dv$coffman_formula, data = sub$data, se_type = "HC2")
        )
        fits |>
          imap(\(fit, nm) {
            tidy(fit) |>
              mutate(candidate = nm, sample = sub$sample, party = sub$party,
                     n = fit$nobs, table = dv$table)
          }) |>
          list_rbind()
      }) |>
      list_rbind()
  }) |>
  list_rbind() |>
  select(table, candidate, sample, party, outcome, term, estimate, std.error, conf.low, conf.high, n)

write_csv(out, here::here("maintained", "output", "tables_b5_b8_pid.csv"))
