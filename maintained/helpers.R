# flores_coppock_2018/maintained/helpers.R
# Output: none
# Depends on: original/ (fetched by download_original.R)
# Description: Packages, the three deposited data files, the analysis subsamples, and
#   the shared figure labels. Every other script in maintained/ sources this first.

library(here)
library(tidyverse)
library(estimatr)
library(marginaleffects)

here::i_am("maintained/helpers.R")

# Data ----

study_1 <- read_csv(here::here("original", "replication_archive", "study_1.csv"),
                    show_col_types = FALSE)
study_2 <- read_csv(here::here("original", "replication_archive", "study_2.csv"),
                    show_col_types = FALSE)
study_3 <- read_csv(here::here("original", "replication_archive", "study_3.csv"),
                    show_col_types = FALSE)

# Study 1: Jeb Bush, bilingual sample. Z_ad and Z_survey are deposited as character
# labels; the archive converts Z_ad to 0/1 and leaves Z_survey as a two-level factor,
# which lm() codes identically. Both are made numeric here so every script sees the
# same predictors.
s1_bil <- study_1 |>
  filter(bilingual == 1) |>
  mutate(
    Z_ad = as.integer(Z_ad == "spanish_ad"),
    Z_survey = as.integer(Z_survey == "spanish_survey")
  )

# Study 2: Vela and Coffman, bilingual sample. Z_vela and Z_coffman are deposited 0/1.
# The partisanship dummies use the archive's pid_7 cut points.
s2_bil <- study_2 |>
  filter(bilingual == 1) |>
  mutate(
    Z_survey = as.integer(Z_survey == "spanish_survey"),
    democrat = as.integer(pid_7 %in% c(1, 2, 3)),
    republican = as.integer(pid_7 %in% c(5, 6, 7))
  )

# Study 3: Vela and Coffman, monolingual sample. Monolinguals took the survey in
# English only, so there is no survey-language factor.
s3_mono <- study_3 |>
  filter(bilingual == 0) |>
  mutate(
    democrat = as.integer(pid_7 %in% c(1, 2, 3)),
    republican = as.integer(pid_7 %in% c(5, 6, 7))
  )

# Figure labels ----

dv_levels <- c(
  "Support Candidate in General\n(0-1)",
  "Like Candidate\n(1-7)",
  "Candidate Cares\n(0-1)",
  "Confidence Re: Immigration\n(1-4)"
)

candidate_levels <- c(
  "White Republican\nPres. Candidate (Bush)",
  "Latino Democratic\nCong. Candidate (Vela)",
  "White Republican\nCong. Candidate (Coffman)"
)

label_dv <- function(outcome) {
  case_when(
    outcome %in% c("bush_general", "vela_general", "coffman_general") ~
      "Support Candidate in General\n(0-1)",
    outcome %in% c("like_bush", "like_vela", "like_coffman") ~
      "Like Candidate\n(1-7)",
    outcome %in% c("bush_cares", "vela_cares", "coffman_cares") ~
      "Candidate Cares\n(0-1)",
    outcome %in% c("conf_in_bush", "conf_in_vela", "conf_in_coffman") ~
      "Confidence Re: Immigration\n(1-4)"
  )
}

label_candidate <- function(term) {
  case_when(
    term == "Z_ad" ~ "White Republican\nPres. Candidate (Bush)",
    term == "Z_vela" ~ "Latino Democratic\nCong. Candidate (Vela)",
    term == "Z_coffman" ~ "White Republican\nCong. Candidate (Coffman)"
  )
}

theme_fc <- function() {
  theme_bw() %+replace% theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    axis.title = element_blank(),
    strip.background = element_blank()
  )
}

# Output ----

dir.create(here::here("maintained", "output"), showWarnings = FALSE, recursive = TRUE)

# Blank a figure PDF's embedded timestamps ----
# R's pdf() device stamps /CreationDate and /ModDate with the wall clock, so an
# otherwise deterministic pipeline writes a different file on every run. The epoch
# string is the same width as what it replaces, which keeps the cross-reference byte
# offsets valid, and a file with no timestamp is left alone.
blank_pdf_timestamps <- function(path) {
  epoch <- charToRaw("D:19700101000000")
  raw_pdf <- readBin(path, "raw", file.size(path))
  hits <- grepRaw("D:[0-9]{14}", raw_pdf, all = TRUE)
  if (length(hits) == 0) return(invisible(path))
  for (h in hits) raw_pdf[h:(h + length(epoch) - 1L)] <- epoch
  writeBin(raw_pdf, path)
  invisible(path)
}
