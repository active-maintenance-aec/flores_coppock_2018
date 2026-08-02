# flores_coppock_2018/run_all.R
# Runs the whole reproduction in order: fetch and verify the deposited archive, then
# every published table, the appendix tables, the figures, and the in-text numbers.
# Every script is self-contained and can also be run on its own, except
# text_in_text_claims.R, which reads the table scripts' output.

library(here)
here::i_am("run_all.R")

# Deposited archive ----
# Downloads from Dataverse on a fresh clone; verifies checksums either way.
source(here::here("download_original.R"))

# Main text tables ----
source(here::here("maintained", "table_2_sample_comparison.R"))
source(here::here("maintained", "table_3_randomization.R"))
source(here::here("maintained", "table_5_general_election.R"))
source(here::here("maintained", "table_6_like_candidate.R"))
source(here::here("maintained", "table_7_candidate_cares.R"))
source(here::here("maintained", "table_8_confidence.R"))
source(here::here("maintained", "table_9_linked_fate.R"))

# Appendix tables ----
source(here::here("maintained", "tables_a1_a4_interaction.R"))
source(here::here("maintained", "tables_b5_b8_pid.R"))
source(here::here("maintained", "tables_c9_c10_logit.R"))

# Figures ----
source(here::here("maintained", "figure_1_main_effects.R"))
source(here::here("maintained", "figure_2_het_fx_party.R"))
source(here::here("maintained", "figure_3_simulation.R"))

# In-text numbers ----
# Reads the table output written above, so it runs after the table scripts.
source(here::here("maintained", "text_in_text_claims.R"))

# Ground truth ----
# Joins what the article prints to what the deposit produces and to everything written
# above, so it runs last of all.
source(here::here("ground_truth", "build_ground_truth.R"))
