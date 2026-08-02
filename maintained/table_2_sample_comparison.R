# flores_coppock_2018/maintained/table_2_sample_comparison.R
# Output: output/table_2_sample_comparison.csv
# Depends on: helpers.R
# Description: Table 2, the Lucid column: demographics of the bilingual subjects in the
#   Bush experiment, with standard errors of the mean. The archive deposits no script
#   for this table, so this one is written from the article's row labels against the
#   deposited study_1.csv. The LNS and Pew columns come from two surveys that are not
#   part of the deposit and cannot be recomputed here.
#
#   educ_5 codes "Not Found" as 99. Left in, it returns a mean of 7.95 against the
#   article's 3.01, so the 96 such cases are treated as missing.

source(here::here("maintained", "helpers.R"))

lucid <- s1_bil |>
  mutate(
    education_5 = if_else(educ_5 == 99, NA_real_, educ_5),
    other_hispanic = 1 - mexican - cuban
  ) |>
  select(female, age, education_5, mexican, cuban, other_hispanic, income_7, income_9) |>
  pivot_longer(everything(), names_to = "quantity", values_to = "value") |>
  summarize(
    mean = mean(value, na.rm = TRUE),
    se = sd(value, na.rm = TRUE) / sqrt(sum(!is.na(value))),
    n_nonmissing = sum(!is.na(value)),
    .by = quantity
  )

out <- bind_rows(
  lucid,
  tibble(quantity = "n", mean = nrow(s1_bil), se = NA_real_, n_nonmissing = nrow(s1_bil))
)

write_csv(out, here::here("maintained", "output", "table_2_sample_comparison.csv"))
