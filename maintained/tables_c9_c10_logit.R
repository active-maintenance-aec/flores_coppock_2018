# flores_coppock_2018/maintained/tables_c9_c10_logit.R
# Output: output/tables_c9_c10_logit.csv, output/tables_c9_c10_ames.csv
# Depends on: helpers.R
# Description: Appendix Tables C.9 and C.10, logit versions of Tables 5 and 7, plus the
#   average marginal effects the appendix describes as "not shown, but included in the
#   replication archive code".
#   The archive computes those with margins::margins(), which is alive: version 0.3.28
#   was released to CRAN on 31 July 2024 and installs without incident. Using
#   marginaleffects::avg_slopes() here is a modernization, not a forced replacement. The
#   two agree on every average marginal effect to within 1e-4; margins differentiates
#   numerically where avg_slopes() does not, which is where the gap comes from.
#   Each model is fitted on only the columns its formula names, because the deposited
#   files carry 94 to 148 columns and avg_slopes() warns about carrying all of them.

source(here::here("maintained", "helpers.R"))

c9_specs <- list(
  list(formula = bush_general    ~ Z_ad      + Z_survey, data = s1_bil,  candidate = "bush",    sample = "bilingual"),
  list(formula = vela_general    ~ Z_vela    + Z_survey, data = s2_bil,  candidate = "vela",    sample = "bilingual"),
  list(formula = vela_general    ~ Z_vela,               data = s3_mono, candidate = "vela",    sample = "monolingual"),
  list(formula = coffman_general ~ Z_coffman + Z_survey, data = s2_bil,  candidate = "coffman", sample = "bilingual"),
  list(formula = coffman_general ~ Z_coffman,            data = s3_mono, candidate = "coffman", sample = "monolingual")
)

c10_specs <- list(
  list(formula = bush_cares    ~ Z_ad      + Z_survey, data = s1_bil,  candidate = "bush",    sample = "bilingual"),
  list(formula = vela_cares    ~ Z_vela    + Z_survey, data = s2_bil,  candidate = "vela",    sample = "bilingual"),
  list(formula = vela_cares    ~ Z_vela,               data = s3_mono, candidate = "vela",    sample = "monolingual"),
  list(formula = coffman_cares ~ Z_coffman + Z_survey, data = s2_bil,  candidate = "coffman", sample = "bilingual"),
  list(formula = coffman_cares ~ Z_coffman,            data = s3_mono, candidate = "coffman", sample = "monolingual")
)

specs <- c(
  map(c9_specs, \(s) c(s, list(table = "c9"))),
  map(c10_specs, \(s) c(s, list(table = "c10")))
)

fits <- specs |>
  map(\(s) glm(s$formula, family = binomial(link = "logit"),
               data = s$data[all.vars(s$formula)]))

# Coefficients ----
# The appendix prints the log likelihood and AIC beneath each column, so both are
# carried here rather than only the coefficients.
logit_out <- map2(specs, fits, \(s, fit) {
  broom::tidy(fit) |>
    mutate(
      table = s$table,
      candidate = s$candidate,
      sample = s$sample,
      outcome = as.character(s$formula[[2]]),
      n = stats::nobs(fit),
      log_likelihood = as.numeric(stats::logLik(fit)),
      aic = stats::AIC(fit)
    )
}) |>
  list_rbind() |>
  select(table, candidate, sample, outcome, term, estimate, std.error, p.value, n,
         log_likelihood, aic)

write_csv(logit_out, here::here("maintained", "output", "tables_c9_c10_logit.csv"))

# Average marginal effects ----
ames_out <- map2(specs, fits, \(s, fit) {
  as_tibble(avg_slopes(fit)) |>
    mutate(table = s$table, candidate = s$candidate, sample = s$sample,
           outcome = as.character(s$formula[[2]]))
}) |>
  list_rbind() |>
  select(table, candidate, sample, outcome, term, estimate, std.error, conf.low, conf.high)

write_csv(ames_out, here::here("maintained", "output", "tables_c9_c10_ames.csv"))
