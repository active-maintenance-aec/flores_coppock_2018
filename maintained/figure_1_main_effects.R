# flores_coppock_2018/maintained/figure_1_main_effects.R
# Output: output/figure_1_main_effects.pdf, .png, .csv
# Depends on: helpers.R
# Description: Figure 1, the estimated effects of the Spanish-language advertisement on
#   all four outcomes for all three candidates, in the bilingual and monolingual samples.
#   These are the unadjusted models, without the survey-language covariate the tables add.
#   geom_errorbarh() was deprecated in ggplot2 4.0.0 and ggstance::position_dodgev() is
#   no longer needed, so the intervals are drawn with geom_linerange() and dodged with
#   position_dodge() along the discrete y axis.

source(here::here("maintained", "helpers.R"))

bil_specs <- list(
  list(formula = bush_general    ~ Z_ad,      data = s1_bil),
  list(formula = vela_general    ~ Z_vela,    data = s2_bil),
  list(formula = coffman_general ~ Z_coffman, data = s2_bil),
  list(formula = like_vela       ~ Z_vela,    data = s2_bil),
  list(formula = like_coffman    ~ Z_coffman, data = s2_bil),
  list(formula = like_bush       ~ Z_ad,      data = s1_bil),
  list(formula = vela_cares      ~ Z_vela,    data = s2_bil),
  list(formula = coffman_cares   ~ Z_coffman, data = s2_bil),
  list(formula = bush_cares      ~ Z_ad,      data = s1_bil),
  list(formula = conf_in_vela    ~ Z_vela,    data = s2_bil),
  list(formula = conf_in_coffman ~ Z_coffman, data = s2_bil),
  list(formula = conf_in_bush    ~ Z_ad,      data = s1_bil)
)

mono_specs <- list(
  list(formula = vela_general    ~ Z_vela,    data = s3_mono),
  list(formula = coffman_general ~ Z_coffman, data = s3_mono),
  list(formula = like_vela       ~ Z_vela,    data = s3_mono),
  list(formula = like_coffman    ~ Z_coffman, data = s3_mono),
  list(formula = vela_cares      ~ Z_vela,    data = s3_mono),
  list(formula = coffman_cares   ~ Z_coffman, data = s3_mono),
  list(formula = conf_in_vela    ~ Z_vela,    data = s3_mono),
  list(formula = conf_in_coffman ~ Z_coffman, data = s3_mono)
)

estimates <- bind_rows(
  bil_specs |>
    map(\(s) tidy(lm_robust(s$formula, data = s$data, se_type = "HC2"))) |>
    list_rbind() |>
    mutate(sample = "Bilingual Sample"),
  mono_specs |>
    map(\(s) tidy(lm_robust(s$formula, data = s$data, se_type = "HC2"))) |>
    list_rbind() |>
    mutate(sample = "Monolingual Sample")
) |>
  filter(term != "(Intercept)")

gg_df <- estimates |>
  mutate(
    dv_group = factor(label_dv(outcome), levels = rev(dv_levels)),
    candidate = factor(label_candidate(term), levels = candidate_levels),
    sample = factor(sample, levels = c("Bilingual Sample", "Monolingual Sample"))
  )

g <- ggplot(gg_df, aes(x = estimate, y = dv_group,
                       group = sample, color = sample, shape = sample)) +
  geom_vline(xintercept = 0, linetype = "dashed") +
  geom_point(size = 2, position = position_dodge(width = -0.5)) +
  geom_linerange(aes(xmin = conf.low, xmax = conf.high),
                 position = position_dodge(width = -0.5)) +
  facet_grid(~ candidate) +
  scale_color_manual(values = c("red", "blue")) +
  theme_fc()

ggsave(here::here("maintained", "output", "figure_1_main_effects.pdf"), g, width = 7, height = 5)
ggsave(here::here("maintained", "output", "figure_1_main_effects.png"), g, width = 7, height = 5, dpi = 300)

write_csv(
  estimates |> select(sample, outcome, term, estimate, std.error, conf.low, conf.high, df),
  here::here("maintained", "output", "figure_1_main_effects.csv")
)
