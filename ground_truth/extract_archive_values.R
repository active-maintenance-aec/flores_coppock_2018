# flores_coppock_2018/ground_truth/extract_archive_values.R
# Output: ground_truth/archive_values.csv
# Depends on: one console log per deposited script, produced by running the deposit in a
#   scratch copy (see below). Not part of run_all.R, since it needs the deposited
#   scripts' console output rather than anything this repository builds.
# Description: Recover every number the deposited scripts produce, so the archive side of
#   the ground truth is read off the archive rather than transcribed. Where a script
#   prints a LaTeX table, the numbers are parsed out of its console log. The two figure
#   scripts print nothing at all, so their estimates are recovered by refitting the
#   models they specify, on the deposited data, exactly as written. To rebuild the logs,
#   copy original/replication_archive to a scratch directory and, from that copy, run
#
#     Rscript FC_bilinguals_main_analysis.R > orig_FC_bilinguals_main_analysis.log 2>&1
#
#   and the same for the other seven scripts, then set ARCHIVE_RUN_DIR to that directory
#   before running this script.
#
#   Never run the deposited scripts inside original/ itself. Both figure scripts save
#   under file names that are themselves deposited files, so an in-place run overwrites
#   part of the deposit. See the report.

library(here)
library(tidyverse)
library(estimatr)

here::i_am("ground_truth/extract_archive_values.R")

log_dir <- Sys.getenv("ARCHIVE_RUN_DIR", unset = file.path(tempdir(), "archive_run"))
stopifnot(dir.exists(log_dir))

# Parsing helpers ----
# stargazer prints one LaTeX row per coefficient, with the standard error on the line
# below it, and marks significance with a superscript that has to come off the number.
read_log <- function(script) {
  read_file(file.path(path.expand(log_dir), str_glue("orig_{script}.log")))
}

cells <- function(line) {
  str_trim(str_split_1(str_remove(str_trim(line), "\\\\\\\\$"), "&"))
}

num <- function(cell) {
  c0 <- str_replace_all(cell, fixed("$-$"), "-")
  c0 <- str_remove_all(c0, fixed("$"))
  c0 <- str_remove_all(c0, ",")
  c0 <- str_remove(c0, "\\^\\{\\**\\}")
  c0 <- str_remove_all(c0, "[()]")
  if (str_detect(c0, "^-?[0-9]*\\.?[0-9]+$")) as.numeric(c0) else NA_real_
}

# A stargazer table is either captioned or, where the script passes float = FALSE, a
# bare tabular environment. Both forms appear in this deposit.
tables <- function(text) {
  blocks <- str_match_all(text, regex("\\\\caption\\{(.*?)\\}(.*?)\\\\end\\{tabular\\}",
                                      dotall = TRUE))[[1]]
  if (nrow(blocks) == 0) {
    bodies <- str_match_all(text, regex("\\\\begin\\{tabular\\}(.*?)\\\\end\\{tabular\\}",
                                        dotall = TRUE))[[1]][, 2]
    return(map(bodies, \(b) list(caption = "", body = str_split_1(b, "\n"))))
  }
  map(seq_len(nrow(blocks)),
      \(i) list(caption = str_trim(blocks[i, 2]), body = str_split_1(blocks[i, 3], "\n")))
}

row_line <- function(body, label) {
  hits <- which(str_detect(str_trim(body), str_glue("^{fixed_label(label)}\\s*&")))
  stopifnot(length(hits) > 0)
  hits[1]
}

fixed_label <- function(label) str_replace_all(label, "([().])", "\\\\\\1")

archive <- tibble(table_figure = character(), column = character(),
                  stat = character(), value_script = numeric())

add <- function(tab, column, stat, value) {
  archive <<- add_row(archive, table_figure = tab, column = column,
                      stat = stat, value_script = value)
}

# Reads an estimate row and the standard error row beneath it into one column per model.
add_pair <- function(tab, body, label, stat, keys) {
  i <- row_line(body, label)
  est <- cells(body[i])[-1]
  se <- cells(body[i + 1])[-1]
  for (j in seq_along(keys)) {
    if (!is.na(num(est[j]))) {
      add(tab, keys[j], stat, num(est[j]))
      add(tab, keys[j], paste0(stat, "_se"), num(se[j]))
    }
  }
}

add_single <- function(tab, body, label, stat, keys) {
  vals <- cells(body[row_line(body, label)])[-1]
  for (j in seq_along(keys)) add(tab, keys[j], stat, num(vals[j]))
}

cols_five <- c("bush_bilingual", "vela_bilingual", "vela_monolingual",
               "coffman_bilingual", "coffman_monolingual")

# Tables 5 to 9, from the main analysis script ----
main <- tables(read_log("FC_bilinguals_main_analysis"))
main_map <- c(
  "Effect of Spanish-language Ad on General Election Support" = "table_5",
  "Effect of Spanish-language Ad on Liking Candidate (1-7)" = "table_6",
  "Effect of Spanish-language Ad on Perceptions of Candidate Caring" = "table_7"
)

for (tb in main) {
  tab <- case_when(
    tb$caption %in% names(main_map) ~ unname(main_map[tb$caption]),
    str_detect(tb$caption, "Confidence in Candidate") ~ "table_8",
    str_detect(tb$caption, "Linked Fate") ~ "table_9",
    .default = NA_character_
  )
  if (is.na(tab)) next
  keys <- if (tab == "table_9") c("bush_bilingual", "vela_coffman_bilingual") else cols_five
  if (tab != "table_9") add_pair(tab, tb$body, "Spanish-language Ad", "Z_ad", keys)
  add_pair(tab, tb$body, "Spanish-language Survey", "Z_survey", keys)
  add_pair(tab, tb$body, "Constant (Control Mean)", "constant", keys)
  add_single(tab, tb$body, "N", "N", keys)
}

# Appendix Tables A.1 to A.4 ----
inter <- tables(read_log("FC_bilinguals_interaction_analysis"))
a_keys <- c("bush_bilingual", "vela_bilingual", "coffman_bilingual")
a_labels <- c(Z_ad = "Spanish-language Ad", Z_survey = "Spanish-language Survey",
              interaction = "Ad X Survey", constant = "Constant (Control Mean)")

for (i in seq_along(inter)) {
  tab <- c("table_a1", "table_a2", "table_a3", "table_a4")[i]
  for (stat in names(a_labels)) add_pair(tab, inter[[i]]$body, a_labels[[stat]], stat, a_keys)
  add_single(tab, inter[[i]]$body, "N", "N", a_keys)
}

# Appendix Tables B.5 to B.8 ----
pid <- tables(read_log("FC_bilinguals_pid_analysis"))
b_keys <- c("vela_bilingual_democrat", "vela_bilingual_republican",
            "vela_monolingual_democrat", "vela_monolingual_republican",
            "coffman_bilingual_democrat", "coffman_bilingual_republican",
            "coffman_monolingual_democrat", "coffman_monolingual_republican")

for (i in seq_along(pid)) {
  tab <- c("table_b5", "table_b6", "table_b7", "table_b8")[i]
  add_pair(tab, pid[[i]]$body, "Spanish-language Ad", "Z_ad", b_keys)
  add_pair(tab, pid[[i]]$body, "Constant (Control Mean)", "constant", b_keys)
  add_single(tab, pid[[i]]$body, "N", "N", b_keys)
}

# Appendix Tables C.9 and C.10 ----
logit <- tables(read_log("FC_bilinguals_logit_analysis"))

for (i in seq_along(logit)) {
  tab <- c("table_c9", "table_c10")[i]
  add_pair(tab, logit[[i]]$body, "Spanish-language Ad", "Z_ad", cols_five)
  add_pair(tab, logit[[i]]$body, "Spanish-language Survey", "Z_survey", cols_five)
  add_pair(tab, logit[[i]]$body, "Constant", "constant", cols_five)
  add_single(tab, logit[[i]]$body, "N", "N", cols_five)
  add_single(tab, logit[[i]]$body, "Log Likelihood", "log_likelihood", cols_five)
  add_single(tab, logit[[i]]$body, "AIC", "aic", cols_five)
}

# Table 3, from the in-text stats script ----
# That script prints the raw cross-tabulations and the balance test rather than a
# stargazer table, so it is read from the console output directly.
txt <- read_log("FC_bilinguals_in_text_stats")
chi <- str_match(txt, "X-squared = ([0-9.]+), df = ([0-9]+), p-value = ([0-9.]+)")
add("table_3", "balance", "chi_sq", as.numeric(chi[2]))
add("table_3", "balance", "df", as.numeric(chi[3]))
add("table_3", "balance", "p_value", as.numeric(chi[4]))

count_rows <- str_match_all(txt,
  regex("^(?:english_survey|spanish_survey|tab_3|tab_5)\\s+([0-9]+)\\s+([0-9]+)\\s*$",
        multiline = TRUE))[[1]]
t3_blocks <- c(
  "experiment_1_bush_bilingual_english_survey", "experiment_1_bush_bilingual_spanish_survey",
  "experiment_2_vela_bilingual_english_survey", "experiment_2_vela_bilingual_spanish_survey",
  "experiment_2_vela_monolingual_english_survey",
  "experiment_3_coffman_bilingual_english_survey", "experiment_3_coffman_bilingual_spanish_survey",
  "experiment_3_coffman_monolingual_english_survey"
)
stopifnot(nrow(count_rows) == 8)
for (j in seq_along(t3_blocks)) {
  add("table_3", t3_blocks[j], "english_ad", as.numeric(count_rows[j, 2]))
  add("table_3", t3_blocks[j], "spanish_ad", as.numeric(count_rows[j, 3]))
}

write_csv(archive, here::here("ground_truth", "archive_values.csv"))
print(str_glue("Recovered {nrow(archive)} values from the deposited scripts' output."))

# Figures 1 and 2 ----
# Neither figure script prints or saves any estimate: FC_bilinguals_figure_1.R and
# FC_bilinguals_figure_2.R build a plotting frame, draw it, and save a PDF, and
# FC_bilinguals_simulation.R does not even save. So the archive's plotted values exist
# nowhere in its output and are recovered here by refitting the models those two scripts
# specify, on the deposited data, with the same estimator and the same subsamples. The
# published figures print no numbers, so these are the only comparison a reader can make
# against the figures, and build_ground_truth.R makes it.

study_1 <- read_csv(file.path(path.expand(log_dir), "study_1.csv"), show_col_types = FALSE)
study_2 <- read_csv(file.path(path.expand(log_dir), "study_2.csv"), show_col_types = FALSE)
study_3 <- read_csv(file.path(path.expand(log_dir), "study_3.csv"), show_col_types = FALSE)

s1_bil <- filter(study_1, bilingual == 1)
s2_bil <- filter(study_2, bilingual == 1) |>
  mutate(democrat = as.numeric(pid_7 %in% c(1, 2, 3)),
         republican = as.numeric(pid_7 %in% c(5, 6, 7)))
s3_mono <- filter(study_3, bilingual == 0) |>
  mutate(democrat = as.numeric(pid_7 %in% c(1, 2, 3)),
         republican = as.numeric(pid_7 %in% c(5, 6, 7)))

# The archive leaves study_1's Z_ad as a character column, so lm_robust names its
# coefficient Z_adspanish_ad. The rewrite makes it 0/1 and names it Z_ad. Same contrast,
# same estimate; the name is aligned here so the two can be joined.
tidy_fits <- function(specs) {
  map(specs, \(s) tidy(lm_robust(s$formula, data = s$data))) |>
    list_rbind() |>
    filter(term != "(Intercept)") |>
    mutate(term = if_else(term == "Z_adspanish_ad", "Z_ad", term))
}

fig_1_specs <- list(
  list(formula = bush_general ~ Z_ad, data = s1_bil),
  list(formula = vela_general ~ Z_vela, data = s2_bil),
  list(formula = coffman_general ~ Z_coffman, data = s2_bil),
  list(formula = like_vela ~ Z_vela, data = s2_bil),
  list(formula = like_coffman ~ Z_coffman, data = s2_bil),
  list(formula = like_bush ~ Z_ad, data = s1_bil),
  list(formula = vela_cares ~ Z_vela, data = s2_bil),
  list(formula = coffman_cares ~ Z_coffman, data = s2_bil),
  list(formula = bush_cares ~ Z_ad, data = s1_bil),
  list(formula = conf_in_vela ~ Z_vela, data = s2_bil),
  list(formula = conf_in_coffman ~ Z_coffman, data = s2_bil),
  list(formula = conf_in_bush ~ Z_ad, data = s1_bil)
)

fig_1_mono_specs <- list(
  list(formula = vela_general ~ Z_vela, data = s3_mono),
  list(formula = coffman_general ~ Z_coffman, data = s3_mono),
  list(formula = like_vela ~ Z_vela, data = s3_mono),
  list(formula = like_coffman ~ Z_coffman, data = s3_mono),
  list(formula = vela_cares ~ Z_vela, data = s3_mono),
  list(formula = coffman_cares ~ Z_coffman, data = s3_mono),
  list(formula = conf_in_vela ~ Z_vela, data = s3_mono),
  list(formula = conf_in_coffman ~ Z_coffman, data = s3_mono)
)

figure_1 <- bind_rows(
  tidy_fits(fig_1_specs) |> mutate(sample = "Bilingual Sample"),
  tidy_fits(fig_1_mono_specs) |> mutate(sample = "Monolingual Sample")
) |>
  mutate(figure = "figure_1", party = NA_character_)

fig_2_formulas <- list(
  vela_general ~ Z_vela, coffman_general ~ Z_coffman,
  like_vela ~ Z_vela, like_coffman ~ Z_coffman,
  vela_cares ~ Z_vela, coffman_cares ~ Z_coffman,
  conf_in_vela ~ Z_vela, conf_in_coffman ~ Z_coffman
)

fig_2_subgroups <- list(
  list(data = filter(s2_bil, democrat == 1), sample = "Bilingual Sample", party = "Democratic Respondents"),
  list(data = filter(s3_mono, democrat == 1), sample = "Monolingual Sample", party = "Democratic Respondents"),
  list(data = filter(s2_bil, republican == 1), sample = "Bilingual Sample", party = "Republican Respondents"),
  list(data = filter(s3_mono, republican == 1), sample = "Monolingual Sample", party = "Republican Respondents")
)

figure_2 <- fig_2_subgroups |>
  map(\(sub) {
    tidy_fits(map(fig_2_formulas, \(f) list(formula = f, data = sub$data))) |>
      mutate(sample = sub$sample, party = sub$party)
  }) |>
  list_rbind() |>
  mutate(figure = "figure_2")

figures <- bind_rows(figure_1, figure_2) |>
  select(figure, sample, party, outcome, term, estimate, std.error, conf.low, conf.high)

write_csv(figures, here::here("ground_truth", "archive_figure_estimates.csv"))
print(str_glue("Recovered {nrow(figures)} plotted estimates from the two figure scripts."))
