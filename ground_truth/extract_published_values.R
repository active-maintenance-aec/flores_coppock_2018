# flores_coppock_2018/ground_truth/extract_published_values.R
# Output: ground_truth/published_values.csv
# Depends on: the published article and appendix PDFs, which this repository does not
#   redistribute. They are available from the journal at the DOI in README.md.
# Description: Read every number out of the typeset tables of the article and its
#   appendix, so the published side of the ground truth is parsed rather than
#   transcribed. Its output, published_values.csv, is committed and is the only place
#   any published value enters this repository. No published value is ever an input to
#   a computation in maintained/.
#
#   This script is not part of run_all.R, because it needs two PDFs the repository does
#   not carry. To re-run it, put the article and appendix PDFs somewhere and set
#   article_pdf and appendix_pdf below. It shells out to pdftotext (poppler) for the
#   layout-preserving text, and every parsed value was checked against the pages
#   rendered as images, which is the only reliable way to confirm that a row of a
#   six- or eight-column regression table lands in the column it belongs to.

library(here)
library(tidyverse)

here::i_am("ground_truth/extract_published_values.R")

article_pdf <- "~/Dropbox/works/catalog/flores_coppock_2018/original_materials/flores_coppock_2018.pdf"
appendix_pdf <- "~/Dropbox/works/catalog/flores_coppock_2018/original_materials/flores_coppock_2018_appendix.pdf"

pdf_lines <- function(pdf) {
  txt <- tempfile(fileext = ".txt")
  system2("pdftotext", c("-layout", shQuote(path.expand(pdf)), shQuote(txt)))
  read_lines(txt)
}

paper <- pdf_lines(article_pdf)
appendix <- pdf_lines(appendix_pdf)

# Parsing helpers ----
# A typeset table row is a label followed by one number per column. Standard errors sit
# on the line below the estimates. Both en dashes and minus signs appear as the negative
# sign, and the thousands separator has to come out before the token is a number.
#
# Every value is kept as the STRING the page prints, because a double does not record
# how many decimals were typeset: 0.020 and 0.02 are the same number and not the same
# published value. Only the typography is normalised away, never the precision. The
# thousands separator goes, the Unicode minus and the en dash become a hyphen, and a
# missing leading zero is supplied, which is the house convention and not a change to
# the printed digits.
#
# Two extraction artifacts are specific to these two PDFs and are worth recording. In
# the article's text layer "=" arrives as a thorn-like glyph and the decimal point of an
# inline math expression arrives as a colon, so the balance test reads
# "(chi 2 = 7:3 , df = 7 , p = 0:40)"; that line is transcribed from a rendered page
# rather than parsed. In the appendix the significance daggers attach to the coefficient
# token, which is why "[$^]" comes out below.
normalise_printed <- function(x) {
  x |>
    str_remove_all(",") |>
    str_replace("^(-?)\\.", "\\10")
}

toks <- function(line) {
  line <- str_replace_all(line, "[–−—]", "-")
  line <- str_remove_all(line, "[$^]")
  hits <- str_extract_all(line, "\\(?-?[0-9][0-9,]*\\.?[0-9]*\\)?")[[1]]
  normalise_printed(str_remove_all(hits, "[()]"))
}

# Lines from the first one containing the anchor, which is always a table caption.
after <- function(lines, anchor, n) {
  i <- which(str_detect(lines, fixed(anchor)))[1]
  stopifnot(!is.na(i))
  lines[i:min(i + n - 1, length(lines))]
}

row_line <- function(lines, label) {
  hits <- which(str_starts(str_trim(lines), fixed(label)))
  stopifnot(length(hits) > 0)
  hits[1]
}

published <- tibble(table_figure = character(), column = character(),
                    stat = character(), value_paper = character())

add <- function(tab, column, stat, value) {
  published <<- add_row(published, table_figure = tab, column = column,
                        stat = stat, value_paper = value)
}

# Column order in the five-column tables (5 to 8 in the text, C.9 and C.10 in the
# appendix). Only the three bilingual-sample columns carry a survey-language term.
cols_five <- c("bush_bilingual", "vela_bilingual", "vela_monolingual",
               "coffman_bilingual", "coffman_monolingual")
survey_cols <- c(1, 2, 4)

# Tables 5 to 8 ----
main_anchors <- c(
  table_5 = "Effect of Spanish-language ad on general election support",
  table_6 = "Effect of Spanish-language ad on liking candidate",
  table_7 = "Effect of Spanish-language ad on perceptions of candidate caring",
  table_8 = "Effect of Spanish-language ad on confidence in candidate to make right decisions about"
)

for (tab in names(main_anchors)) {
  block <- after(paper, main_anchors[[tab]], 40)
  i_ad <- row_line(block, "Spanish-language ad")
  i_sv <- row_line(block, "Spanish-language survey")
  i_const <- row_line(block, "Constant (Control Mean)")
  ad <- toks(block[i_ad]); ad_se <- toks(block[i_ad + 1])
  sv <- toks(block[i_sv]); sv_se <- toks(block[i_sv + 1])
  const <- toks(block[i_const]); const_se <- toks(block[i_const + 1])
  n <- toks(block[row_line(block, "N ")])
  stopifnot(length(ad) == 5, length(ad_se) == 5, length(sv) == 3, length(sv_se) == 3,
            length(const) == 5, length(const_se) == 5, length(n) == 5)
  for (j in seq_along(cols_five)) {
    add(tab, cols_five[j], "Z_ad", ad[j])
    add(tab, cols_five[j], "Z_ad_se", ad_se[j])
    add(tab, cols_five[j], "constant", const[j])
    add(tab, cols_five[j], "constant_se", const_se[j])
    add(tab, cols_five[j], "N", n[j])
    if (j %in% survey_cols) {
      k <- match(j, survey_cols)
      add(tab, cols_five[j], "Z_survey", sv[k])
      add(tab, cols_five[j], "Z_survey_se", sv_se[k])
    }
  }
}

# Table 9 ----
block <- after(paper, "Effect of Spanish-language survey on linked fate", 20)
i_sv <- row_line(block, "Spanish-language survey")
i_const <- row_line(block, "Constant (Control Mean)")
sv <- toks(block[i_sv]); sv_se <- toks(block[i_sv + 1])
const <- toks(block[i_const]); const_se <- toks(block[i_const + 1])
n <- toks(block[row_line(block, "N ")])
for (j in seq_along(c("bush_bilingual", "vela_coffman_bilingual"))) {
  key <- c("bush_bilingual", "vela_coffman_bilingual")[j]
  add("table_9", key, "Z_survey", sv[j])
  add("table_9", key, "Z_survey_se", sv_se[j])
  add("table_9", key, "constant", const[j])
  add("table_9", key, "constant_se", const_se[j])
  add("table_9", key, "N", n[j])
}

# Appendix Tables A.1 to A.4 ----
a_anchors <- c(
  table_a1 = "Table A.1: Effects of Treatments on General Election Support",
  table_a2 = "Table A.2: Effects of Treatments on Perceptions of Candidate Caring",
  table_a3 = "Table A.3: Effects of Treatments on Confidence",
  table_a4 = "Table A.4: Effects of Treatments on Liking Candidate"
)
a_labels <- c(Z_ad = "Spanish-language Ad", Z_survey = "Spanish-language Survey",
              interaction = "Ad X Survey", constant = "Constant (Control Mean)")

for (tab in names(a_anchors)) {
  block <- after(appendix, a_anchors[[tab]], 40)
  for (stat in names(a_labels)) {
    i <- row_line(block, a_labels[[stat]])
    est <- toks(block[i]); se <- toks(block[i + 1])
    stopifnot(length(est) == 3, length(se) == 3)
    for (j in seq_along(c("bush", "vela", "coffman"))) {
      key <- paste0(c("bush", "vela", "coffman")[j], "_bilingual")
      add(tab, key, stat, est[j])
      add(tab, key, paste0(stat, "_se"), se[j])
    }
  }
  n <- toks(block[row_line(block, "N ")])
  stopifnot(length(n) == 3)
  for (j in seq_along(c("bush", "vela", "coffman"))) {
    add(tab, paste0(c("bush", "vela", "coffman")[j], "_bilingual"), "N", n[j])
  }
}

# Appendix Tables B.5 to B.8 ----
b_anchors <- c(
  table_b5 = "Table B.5: Effects of Treatments on General Election Support by Respondent",
  table_b6 = "Table B.6: Effects of Treatments on Liking Candidate",
  table_b7 = "Table B.7: Effects of Treatments on Perceptions of Candidate Caring by Respondent",
  table_b8 = "Table B.8: Effects of Treatments on Confidence"
)
b_cols <- c("vela_bilingual_democrat", "vela_bilingual_republican",
            "vela_monolingual_democrat", "vela_monolingual_republican",
            "coffman_bilingual_democrat", "coffman_bilingual_republican",
            "coffman_monolingual_democrat", "coffman_monolingual_republican")

for (tab in names(b_anchors)) {
  block <- after(appendix, b_anchors[[tab]], 40)
  for (stat in c("Z_ad", "constant")) {
    label <- if (stat == "Z_ad") "Spanish-language Ad" else "Constant (Control Mean)"
    i <- row_line(block, label)
    est <- toks(block[i]); se <- toks(block[i + 1])
    stopifnot(length(est) == 8, length(se) == 8)
    for (j in seq_along(b_cols)) {
      add(tab, b_cols[j], stat, est[j])
      add(tab, b_cols[j], paste0(stat, "_se"), se[j])
    }
  }
  n <- toks(block[row_line(block, "N ")])
  stopifnot(length(n) == 8)
  for (j in seq_along(b_cols)) add(tab, b_cols[j], "N", n[j])
}

# Appendix Tables C.9 and C.10 ----
c_anchors <- c(
  table_c9 = "Table C.9: Effect of Spanish-language Ad on General Election Support (Logit)",
  table_c10 = "Table C.10: Effect of Spanish-language Ad on Perceptions of Candidate Caring (Logit)"
)

for (tab in names(c_anchors)) {
  block <- after(appendix, c_anchors[[tab]], 40)
  i_ad <- row_line(block, "Spanish-language Ad")
  i_sv <- row_line(block, "Spanish-language Survey")
  i_const <- row_line(block, "Constant")
  ad <- toks(block[i_ad]); ad_se <- toks(block[i_ad + 1])
  sv <- toks(block[i_sv]); sv_se <- toks(block[i_sv + 1])
  const <- toks(block[i_const]); const_se <- toks(block[i_const + 1])
  n <- toks(block[row_line(block, "N ")])
  # The typeset log likelihood carries a minus sign the layout text sometimes drops, so
  # the sign is imposed rather than parsed. A log likelihood is negative by construction.
  ll <- paste0("-", str_remove(toks(block[row_line(block, "Log Likelihood")]), "^-"))
  aic <- toks(block[row_line(block, "AIC")])
  stopifnot(length(ad) == 5, length(sv) == 3, length(const) == 5, length(n) == 5,
            length(ll) == 5, length(aic) == 5)
  for (j in seq_along(cols_five)) {
    add(tab, cols_five[j], "Z_ad", ad[j])
    add(tab, cols_five[j], "Z_ad_se", ad_se[j])
    add(tab, cols_five[j], "constant", const[j])
    add(tab, cols_five[j], "constant_se", const_se[j])
    add(tab, cols_five[j], "N", n[j])
    add(tab, cols_five[j], "log_likelihood", ll[j])
    add(tab, cols_five[j], "aic", aic[j])
    if (j %in% survey_cols) {
      k <- match(j, survey_cols)
      add(tab, cols_five[j], "Z_survey", sv[k])
      add(tab, cols_five[j], "Z_survey_se", sv_se[k])
    }
  }
}

# Table 2, the Lucid column ----
# Each row is a mean and a standard error for the Lucid sample, then the same pair for
# the LNS and Pew samples, which come from surveys the deposit does not contain.
block <- after(paper, "Comparison of Lucid bilinguals to national-sample bilinguals", 20)
t2_labels <- c(female = "Female", age = "Age", education_5 = "Education(5 levels)",
               mexican = "Mexican", cuban = "Cuban", other_hispanic = "Other Hispanic",
               income_7 = "Income(7 levels)", income_9 = "Income(9 levels)", n = "N ")
for (stat in names(t2_labels)) {
  line <- block[row_line(block, t2_labels[[stat]])]
  # Three of the row labels carry a digit inside the label itself.
  vals <- toks(str_remove(line, "\\([0-9] levels\\)"))
  add("table_2", "lucid", stat, vals[1])
  if (stat != "n") add("table_2", "lucid", paste0(stat, "_se"), vals[2])
}

# Table 3, the cell counts ----
block <- after(paper, "Design of Experiments 1, 2, and 3", 24)
t3_blocks <- c(
  "experiment_1_bush_bilingual_english_survey", "experiment_1_bush_bilingual_spanish_survey",
  "experiment_2_vela_bilingual_english_survey", "experiment_2_vela_bilingual_spanish_survey",
  "experiment_2_vela_monolingual_english_survey",
  "experiment_3_coffman_bilingual_english_survey", "experiment_3_coffman_bilingual_spanish_survey",
  "experiment_3_coffman_monolingual_english_survey"
)
count_lines <- block[str_detect(block, "^\\s*(English|Spanish)-language [Ss]urvey\\s+[0-9]")]
stopifnot(length(count_lines) == 8)
for (j in seq_along(t3_blocks)) {
  vals <- toks(count_lines[j])
  add("table_3", t3_blocks[j], "english_ad", vals[1])
  add("table_3", t3_blocks[j], "spanish_ad", vals[2])
}

# What this file does not carry ----
# Only the cells of the typeset tables are parsed here. Every number the article states
# in a sentence, including the balance test printed beneath Table 3, is transcribed
# inside build_ground_truth.R against the claim id the extraction gives it, and the
# extraction in published_claims.csv is the second transcription of those same pages.

write_csv(published, here::here("ground_truth", "published_values.csv"))
print(str_glue("Parsed {nrow(published)} published table cells."))
