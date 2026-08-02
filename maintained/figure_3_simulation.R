# flores_coppock_2018/maintained/figure_3_simulation.R
# Output: output/figure_3_simulation.pdf, .png, .csv
# Depends on: helpers.R
# Description: Figure 3, the net effect of a Spanish-language advertising strategy as a
#   function of the share of bilinguals in the electorate and the risk that a monolingual
#   is mistargeted.
#
#   The two effect sizes below are not estimates. They are the supposition the article
#   states on page 18 in order to draw the figure: "Suppose for the moment that the
#   positive effect among bilinguals is 5 percentage points but the effect among
#   English-only monolinguals is negative 15 percentage points." They are round numbers
#   standing in for the estimated effects, which the table scripts produce and
#   text_in_text_claims.R reports beside them. Every other number in output/ is computed
#   from the deposited data.

source(here::here("maintained", "helpers.R"))

assumed_ate_bilingual <- 0.05
assumed_ate_monolingual <- -0.15

gg_df <- expand_grid(
  prop_bilingual = seq(0, 1, by = 0.01),
  prop_mistargeted = seq(0, 1, by = 0.01)
) |>
  mutate(
    net_effect = prop_bilingual * assumed_ate_bilingual +
      (1 - prop_bilingual) * prop_mistargeted * assumed_ate_monolingual
  )

g <- ggplot(gg_df, aes(x = prop_bilingual, y = prop_mistargeted)) +
  geom_tile(aes(fill = net_effect)) +
  stat_contour(aes(z = net_effect), binwidth = 0.02, color = "grey30") +
  scale_fill_gradient2(
    low = scales::muted("red"),
    mid = "white",
    high = scales::muted("blue"),
    midpoint = 0,
    name = "Net Effect of Spanish-Language Ads"
  ) +
  labs(
    x = "Proportion of Bilingual Voters in Electorate\nContour Lines Spaced 2 Percentage Points Apart",
    y = "Proportion of Monolingual Voters Mistargeted"
  ) +
  theme_light() +
  theme(legend.position = "bottom", legend.key.width = unit(3, "lines"))

ggsave(here::here("maintained", "output", "figure_3_simulation.pdf"), g, width = 6, height = 5)
ggsave(here::here("maintained", "output", "figure_3_simulation.png"), g, width = 6, height = 5, dpi = 300)

# Committed summary ----
# The full surface is 10,201 cells. What the figure is read for is the break-even
# frontier, the mistargeting risk at which the net effect turns from positive to
# negative, so that is what is written out alongside a coarse grid of the surface.
surface <- gg_df |>
  filter(prop_bilingual %in% seq(0, 1, by = 0.1),
         prop_mistargeted %in% seq(0, 1, by = 0.1)) |>
  mutate(quantity = "net_effect", value = net_effect) |>
  select(quantity, prop_bilingual, prop_mistargeted, value)

break_even <- tibble(prop_bilingual = seq(0, 1, by = 0.1)) |>
  mutate(
    quantity = "break_even_mistargeting_risk",
    prop_mistargeted = NA_real_,
    value = (prop_bilingual * assumed_ate_bilingual) /
      ((1 - prop_bilingual) * -assumed_ate_monolingual)
  ) |>
  select(quantity, prop_bilingual, prop_mistargeted, value)

write_csv(
  bind_rows(surface, break_even),
  here::here("maintained", "output", "figure_3_simulation.csv")
)
