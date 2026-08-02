# flores_coppock_2018/maintained/text_in_text_claims.R
# Output: output/text_in_text_claims.csv
# Depends on: table_5_general_election.R, table_9_linked_fate.R, tables_b5_b8_pid.R,
#   tables_c9_c10_logit.R output
# Description: The numbers the article states in prose rather than in a table. Each row
#   is read out of a committed output file, so no in-text claim rests on a value typed
#   into a script. Runs after the table scripts.

source(here::here("maintained", "helpers.R"))

t5 <- read_csv(here::here("maintained", "output", "table_5_general_election.csv"),
               show_col_types = FALSE)
t7 <- read_csv(here::here("maintained", "output", "table_7_candidate_cares.csv"),
               show_col_types = FALSE)
t9 <- read_csv(here::here("maintained", "output", "table_9_linked_fate.csv"),
               show_col_types = FALSE)
b5_b8 <- read_csv(here::here("maintained", "output", "tables_b5_b8_pid.csv"),
                  show_col_types = FALSE)
ames <- read_csv(here::here("maintained", "output", "tables_c9_c10_ames.csv"),
                 show_col_types = FALSE)

treatment_terms <- c("Z_ad", "Z_vela", "Z_coffman")

# Page 13, effects on general election support ----
p13 <- t5 |>
  filter(term %in% treatment_terms) |>
  mutate(
    claim = str_glue("p13_general_{candidate}_{sample}"),
    estimate_pp = estimate * 100,
    std_error_pp = std.error * 100
  ) |>
  select(claim, estimate_pp, std_error_pp)

# Page 13, effect of the Spanish-language survey on support for Vela ----
p13_survey <- t5 |>
  filter(term == "Z_survey", candidate == "vela") |>
  mutate(claim = "p13_survey_language_vela_bilingual",
         estimate_pp = estimate * 100, std_error_pp = std.error * 100) |>
  select(claim, estimate_pp, std_error_pp)

# Page 14, effects on perceptions of caring among monolinguals ----
p14 <- t7 |>
  filter(term %in% treatment_terms, sample == "monolingual") |>
  mutate(claim = str_glue("p14_cares_{candidate}_monolingual"),
         estimate_pp = estimate * 100, std_error_pp = std.error * 100) |>
  select(claim, estimate_pp, std_error_pp)

# Page 16, the Coffman monolingual effect by party ----
p16 <- b5_b8 |>
  filter(table == "b5", candidate == "coffman", sample == "monolingual",
         term %in% treatment_terms) |>
  mutate(claim = str_glue("p16_coffman_monolingual_{party}"),
         estimate_pp = estimate * 100, std_error_pp = std.error * 100) |>
  select(claim, estimate_pp, std_error_pp)

# Page 17, linked fate, reported in scale points rather than percentage points ----
p17 <- t9 |>
  filter(term == "Z_survey") |>
  mutate(claim = str_glue("p17_linked_fate_{experiment}"),
         estimate_pp = estimate, std_error_pp = std.error) |>
  select(claim, estimate_pp, std_error_pp)

# Appendix C, the claim that average marginal effects match OLS ----
# "we obtain answers that match the OLS models to the second decimal place or better."
ols <- bind_rows(
  t5 |> mutate(table = "c9"),
  t7 |> mutate(table = "c10")
) |>
  filter(term %in% treatment_terms) |>
  select(table, candidate, sample, ols_estimate = estimate)

ame_vs_ols <- ames |>
  filter(term %in% treatment_terms) |>
  left_join(ols, by = c("table", "candidate", "sample")) |>
  mutate(
    claim = str_glue("appendixC_ame_minus_ols_{table}_{candidate}_{sample}"),
    estimate_pp = estimate - ols_estimate,
    std_error_pp = NA_real_
  ) |>
  select(claim, estimate_pp, std_error_pp)

out <- bind_rows(p13, p13_survey, p14, p16, p17, ame_vs_ols)

write_csv(out, here::here("maintained", "output", "text_in_text_claims.csv"))
