# flores_coppock_2018/ground_truth/extract_published_table_4.R
# Output: ground_truth/published_table_4_transcripts.csv
# Depends on: the published article PDF, which this repository does not redistribute.
#   It is available from the journal at the DOI in README.md.
# Description: Read Table 4 out of the published article. The table is the six
#   advertisement treatments: for each of the three experiments, the English- and
#   Spanish-language advertisement's title, running time, YouTube link and full
#   transcript. It carries no estimate, so it appears in the ground truth only as a
#   count of numbers; what it holds is text, and the text is what this file transcribes.
#
#   The transcripts are the article's own published Table 4, so committing them here
#   reproduces the article rather than publishing anything new. Nothing in maintained/
#   reads this file.
#
#   Like extract_published_values.R, this script is not part of run_all.R, because it
#   needs a PDF the repository does not carry. It uses pdftools::pdf_data rather than
#   layout text because the table is three columns of wrapped prose: the label, the
#   English cell and the Spanish cell are told apart by the x coordinate of each word,
#   and a layout dump merges the first line of a Transcript row into a single line of
#   all three at once ("Transcript I'm proud of what we accomplished Estoy muy
#   orgulloso de lo que").

library(here)
library(tidyverse)
library(pdftools)

here::i_am("ground_truth/extract_published_table_4.R")

article_pdf <- "~/Dropbox/works/catalog/flores_coppock_2018/original_materials/flores_coppock_2018.pdf"

# Table 4 runs across published pages 620 and 621, which are pages 10 and 11 of the PDF.
# The table body on each page is everything between the column-header row and the first
# line that is no longer part of the table.
page_bounds <- tribble(
  ~page, ~y_min, ~y_max,
  10, 110, 600,  # from below the column headers to above "(Continued )"
  11, 110, 570   # from below the column headers to above "Outcome Measures"
)

# The three column edges, in PDF points. The label column starts at 71.7, the
# English-language cell at 125.5 (its wrapped lines at 135.5), and the Spanish-language
# cell at 281.9.
label_edge <- 122
spanish_edge <- 275

words <- map(
  page_bounds$page,
  \(p) pdf_data(path.expand(article_pdf))[[p]] |> mutate(page = p)
) |>
  list_rbind() |>
  inner_join(page_bounds, by = "page") |>
  filter(y >= y_min, y <= y_max) |>
  mutate(
    column = case_when(x < label_edge ~ "label",
                       x < spanish_edge ~ "english",
                       .default = "spanish"),
    # Words on one visual line share a top coordinate to within a point or two: the
    # opening quotation mark of a transcript is set in a larger face and sits two
    # points higher than the words beside it.
    line = round(y / 3)
  ) |>
  # Within a line the reading order is left to right, and it must be taken from x
  # alone. Sorting on y first puts that raised quotation mark before the words that
  # precede it ("What People ask me, do you think").
  arrange(page, line, x)

# A panel heading spans the whole table width, so its words would otherwise be split
# across the two language columns, and it has to be recognised before they are read.
lines <- words |>
  summarize(
    label = paste(text[column == "label"], collapse = " "),
    english = paste(text[column == "english"], collapse = " "),
    spanish = paste(text[column == "spanish"], collapse = " "),
    whole = paste(text, collapse = " "),
    .by = c(page, line)
  ) |>
  arrange(page, line) |>
  # Only four labels open a row of the table. Anything else reaching into the label
  # column is panel heading, including the second, indented line each of the two
  # longer headings wraps onto.
  mutate(is_heading = label != "" &
           !str_detect(label, "^(Title|Length|Link|Transcript)\\b"))

# Walk the lines in order, carrying the panel and the field each cell belongs to. A
# non-empty label cell opens a new field; every line after it continues that field until
# the next label or the next panel heading.
rows <- tibble()
current_panel <- NA_character_
current_field <- NA_character_
headings <- character()

for (j in seq_len(nrow(lines))) {
  if (lines$is_heading[j]) {
    if (str_detect(lines$label[j], "^Experiment [0-9]:")) {
      current_panel <- str_extract(lines$label[j], "^Experiment [0-9]")
      headings[current_panel] <- lines$whole[j]
    } else {
      headings[current_panel] <- paste(headings[current_panel], lines$whole[j])
    }
    next
  }
  if (lines$label[j] != "") current_field <- str_to_lower(lines$label[j])
  rows <- bind_rows(rows, tibble(
    panel = current_panel, field = current_field,
    english = lines$english[j], spanish = lines$spanish[j]
  ))
}

# The published line breaks are the typesetter's, not the text's, so the cells are
# rejoined. A link is broken mid-URL and rejoins with nothing between; every other cell
# rejoins with a space. No transcript line ends in a hyphen, which is asserted rather
# than assumed, so no word has to be reassembled across a break.
stopifnot(!any(str_detect(c(rows$english, rows$spanish), "-$")))

table_4 <- rows |>
  summarize(
    english = if (first(field) == "link") paste(english[english != ""], collapse = "")
              else str_squish(paste(english, collapse = " ")),
    spanish = if (first(field) == "link") paste(spanish[spanish != ""], collapse = "")
              else str_squish(paste(spanish, collapse = " ")),
    .by = c(panel, field)
  ) |>
  mutate(heading = unname(headings[panel]), .after = panel)

stopifnot(
  nrow(table_4) == 12,
  setequal(table_4$field, c("title", "length", "link", "transcript")),
  all(str_starts(table_4$english[table_4$field == "link"], "https://www.youtube.com/")),
  all(str_starts(table_4$spanish[table_4$field == "link"], "https://www.youtube.com/"))
)

write_csv(table_4, here::here("ground_truth", "published_table_4_transcripts.csv"))
print(str_glue("Parsed {nrow(table_4)} rows of Table 4 across ",
               "{n_distinct(table_4$panel)} advertisement pairs."))
