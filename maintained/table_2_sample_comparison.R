# flores_coppock_2018/maintained/table_2_sample_comparison.R
# Output: output/table_2_sample_comparison.csv
# Depends on: helpers.R; licensed_data/national_surveys_stacked.rdata for the LNS and
#   Pew columns, which this repository does not redistribute
# Description: Table 2, all three columns. The Lucid column is the demographics of the
#   bilingual subjects in the Bush experiment, with standard errors of the mean. The
#   archive deposits no script for this table, so this one is written from the article's
#   row labels against the deposited study_1.csv.
#
#   The LNS and Pew columns are weighted means among the bilingual respondents of the
#   2006 Latino National Survey (ICPSR 20862) and Pew's 2012 National Survey of Latinos.
#   Both surveys are licensed and neither may be redistributed, so the derived file the
#   article's own code built from them is not in this repository. Put it at
#   licensed_data/national_surveys_stacked.rdata and the two columns are recomputed here;
#   without it the values already in output/table_2_sample_comparison.csv stand, which
#   are the aggregates the published table prints and the article therefore already made
#   public.
#
#   educ_5 codes "Not Found" as 99 in both the Lucid data and the derived national file.
#   Left in, it returns a Lucid mean of 7.95 against the article's 3.01, so the 96 such
#   cases are treated as missing.

source(here::here("maintained", "helpers.R"))

# The Lucid column ----

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
  ) |>
  mutate(column = "lucid")

lucid <- bind_rows(
  lucid,
  tibble(column = "lucid", quantity = "n", mean = nrow(s1_bil), se = NA_real_,
         n_nonmissing = nrow(s1_bil))
)

# The LNS and Pew columns ----
# The table's note says these entries are weighted means, and the standard error that
# goes with a weighted mean is not the unweighted one: it is the square root of Cochran's
# (1977) variance of a ratio estimator, which is what the article's own code used. It is
# written out here rather than taken from a package so the estimator is visible at the
# one place it is applied.

weighted_se <- function(x, w) {
  w <- w[!is.na(x)]
  x <- x[!is.na(x)]
  n <- length(w)
  x_wbar <- weighted.mean(x, w)
  w_bar <- mean(w)
  variance <- n / ((n - 1) * sum(w)^2) *
    (sum((w * x - w_bar * x_wbar)^2) -
       2 * x_wbar * sum((w - w_bar) * (w * x - w_bar * x_wbar)) +
       x_wbar^2 * sum((w - w_bar)^2))
  sqrt(variance)
}

national_file <- here::here("licensed_data", "national_surveys_stacked.rdata")

if (file.exists(national_file)) {
  # The derived file is a base-R .rdata, so load() is the only way in; it binds
  # bilinguals_stacked, one row per respondent across all three surveys.
  load(national_file)

  national <- bilinguals_stacked |>
    filter(bilingual == 1, survey %in% c("LNS", "Pew")) |>
    mutate(
      column = str_to_lower(survey),
      education_5 = if_else(educ_5 == 99, NA_real_, educ_5),
      mexican = hispanic_mexican,
      cuban = hispanic_cuban,
      other_hispanic = hispanic_other
    ) |>
    select(column, weight, female, age, education_5, mexican, cuban, other_hispanic,
           income_7, income_9) |>
    pivot_longer(-c(column, weight), names_to = "quantity", values_to = "value") |>
    filter(!all(is.na(value)), .by = c(column, quantity)) |>
    summarize(
      mean = weighted.mean(value, weight, na.rm = TRUE),
      se = weighted_se(value, weight),
      n_nonmissing = sum(!is.na(value)),
      .by = c(column, quantity)
    )

  national <- bind_rows(
    national,
    bilinguals_stacked |>
      filter(bilingual == 1, survey %in% c("LNS", "Pew")) |>
      summarize(mean = n(), se = NA_real_, n_nonmissing = n(), .by = survey) |>
      transmute(column = str_to_lower(survey), quantity = "n", mean, se, n_nonmissing)
  )
} else {
  # Nothing is recomputed and nothing is dropped: the committed aggregates are the
  # LNS and Pew columns, and they stay exactly as they were written.
  national <- read_csv(
    here::here("maintained", "output", "table_2_sample_comparison.csv"),
    show_col_types = FALSE
  ) |>
    filter(column %in% c("lns", "pew"))
  print(str_glue(
    "licensed_data/national_surveys_stacked.rdata is not present, so Table 2's LNS and ",
    "Pew columns are carried forward from output/table_2_sample_comparison.csv rather ",
    "than recomputed. The Latino National Survey (ICPSR 20862) and Pew's 2012 National ",
    "Survey of Latinos are licensed and are not redistributed with this repository."
  ))
}

out <- bind_rows(lucid, national) |>
  select(column, quantity, mean, se, n_nonmissing) |>
  arrange(
    match(column, c("lucid", "lns", "pew")),
    match(quantity, c("female", "age", "education_5", "mexican", "cuban",
                      "other_hispanic", "income_7", "income_9", "n"))
  )

write_csv(out, here::here("maintained", "output", "table_2_sample_comparison.csv"))
