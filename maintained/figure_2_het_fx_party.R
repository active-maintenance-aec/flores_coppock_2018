# flores_coppock_2018/maintained/figure_2_het_fx_party.R
# Output: output/figure_2_het_fx_party.pdf, .png, .csv
# Depends on: helpers.R
# Description: Figure 2, the same effects as Figure 1 split by respondent partisanship,
#   for Vela and Coffman only. Bush is absent because Experiment 1 has no monolingual
#   sample to compare against.
#   Same geometry substitution as Figure 1: geom_linerange() and position_dodge() in
#   place of the deprecated geom_errorbarh() and ggstance::position_dodgev().

source(here::here("maintained", "helpers.R"))

specs <- list(
  list(formula = vela_general    ~ Z_vela),
  list(formula = coffman_general ~ Z_coffman),
  list(formula = like_vela       ~ Z_vela),
  list(formula = like_coffman    ~ Z_coffman),
  list(formula = vela_cares      ~ Z_vela),
  list(formula = coffman_cares   ~ Z_coffman),
  list(formula = conf_in_vela    ~ Z_vela),
  list(formula = conf_in_coffman ~ Z_coffman)
)

subgroups <- list(
  list(data = filter(s2_bil, democrat == 1), sample = "Bilingual Sample", party = "Democratic Respondents"),
  list(data = filter(s3_mono, democrat == 1), sample = "Monolingual Sample", party = "Democratic Respondents"),
  list(data = filter(s2_bil, republican == 1), sample = "Bilingual Sample", party = "Republican Respondents"),
  list(data = filter(s3_mono, republican == 1), sample = "Monolingual Sample", party = "Republican Respondents")
)

estimates <- subgroups |>
  map(\(sub) {
    specs |>
      map(\(s) tidy(lm_robust(s$formula, data = sub$data, se_type = "HC2"))) |>
      list_rbind() |>
      mutate(sample = sub$sample, party = sub$party)
  }) |>
  list_rbind() |>
  filter(term != "(Intercept)")

gg_df <- estimates |>
  mutate(
    dv_group = factor(label_dv(outcome), levels = rev(dv_levels)),
    candidate = factor(label_candidate(term), levels = candidate_levels[-1]),
    sample = factor(sample, levels = c("Bilingual Sample", "Monolingual Sample")),
    party = factor(party, levels = c("Democratic Respondents", "Republican Respondents"))
  )

g <- ggplot(gg_df, aes(x = estimate, y = dv_group,
                       group = sample, color = sample, shape = sample)) +
  geom_vline(xintercept = 0, linetype = "dashed") +
  geom_point(size = 2, position = position_dodge(width = -0.5)) +
  geom_linerange(aes(xmin = conf.low, xmax = conf.high),
                 position = position_dodge(width = -0.5)) +
  facet_grid(party ~ candidate) +
  scale_color_manual(values = c("red", "blue")) +
  theme_fc()

ggsave(here::here("maintained", "output", "figure_2_het_fx_party.pdf"), g, width = 7, height = 5)
ggsave(here::here("maintained", "output", "figure_2_het_fx_party.png"), g, width = 7, height = 5, dpi = 300)

write_csv(
  estimates |> select(sample, party, outcome, term, estimate, std.error, conf.low, conf.high, df),
  here::here("maintained", "output", "figure_2_het_fx_party.csv")
)
