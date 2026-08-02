# flores_coppock_2018/download_original.R
# Output: original/ (the deposited replication archive, not redistributed in this repo)
# Depends on: original_manifest.csv
# Description: Fetch the deposited archive from Harvard Dataverse and verify every file.
#   Run this once before running anything in maintained/. Re-running is free: files
#   already present with the right checksum are not downloaded again.
#
#   The manifest carries two checksums per file. md5_served is the MD5 of the bytes
#   Dataverse returns for `?format=original`, which is what this code was written
#   against. md5_published is the checksum Dataverse displays. Here all 14 agree, but
#   they do not always: other deposits carry published checksums that verify neither
#   the deposited file nor the tabular one derived from it, so verification runs
#   against md5_served and any disagreement is reported rather than hidden by a check
#   failing for the wrong reason.
#
#   Every file in this deposit sits under a `replication_archive` directory label, so
#   the manifest paths carry that prefix and the local copy mirrors it.
#
#   Three of the 14 files were ingested by Dataverse into tabular .tab representations;
#   the served_as column records the name Dataverse gives the derived file.
#   `?format=original` returns the deposited .csv bytes in every case.

library(tidyverse)
library(here)

here::i_am("download_original.R")

dataset_doi <- "doi:10.7910/DVN/XGQ2ZA"
base_url <- "https://dataverse.harvard.edu/api/access/datafile"

# Manifest ----
manifest <- read_csv(here::here("original_manifest.csv"), show_col_types = FALSE)

walk(
  unique(dirname(here::here("original", manifest$file))),
  \(d) dir.create(d, showWarnings = FALSE, recursive = TRUE)
)

# Download what is missing or wrong ----
# format=original asks for the deposited bytes rather than the tabular
# representation Dataverse derives for ingested files.
planned <- manifest |>
  mutate(
    path = here::here("original", file),
    url = str_glue("{base_url}/{dataverse_file_id}?format=original"),
    md5_local = unname(tools::md5sum(path)),
    needs_download = is.na(md5_local) | md5_local != md5_served
  )

walk2(
  planned$url[planned$needs_download],
  planned$path[planned$needs_download],
  \(url, path) download.file(url, destfile = path, mode = "wb", quiet = TRUE)
)

print(str_glue("Downloaded {sum(planned$needs_download)} of {nrow(planned)} files; ",
               "{sum(!planned$needs_download)} already present and verified."))

# Verify ----
verified <- planned |>
  mutate(
    md5_downloaded = unname(tools::md5sum(path)),
    match = md5_downloaded == md5_served,
    published_agrees = md5_served == md5_published
  ) |>
  select(file, bytes, md5_served, md5_downloaded, match, published_agrees)

print(verified, n = nrow(verified))

if (!all(verified$match)) {
  stop("Checksum mismatch: the downloaded archive does not match what Dataverse served when this code was written.")
}

# The deposit and nothing else ----
# Both of the archive's own figure scripts save into the directory they run from, and
# the file names they save under are themselves deposited files, so a copy of original/
# that has ever been used as a working directory carries files the deposit does not and
# has lost two that it does. Nothing in maintained/ writes here, and this check says so.
unexpected <- setdiff(
  list.files(here::here("original"), recursive = TRUE),
  manifest$file
)
if (length(unexpected) > 0) {
  print(str_glue("original/ holds {length(unexpected)} file(s) the deposit does not: ",
                 "{paste(unexpected, collapse = ', ')}"))
}

print(str_glue("All {nrow(verified)} files match. ",
               "{sum(!verified$published_agrees)} carry a published checksum that disagrees."))
print(str_glue("Archive: {dataset_doi}"))
