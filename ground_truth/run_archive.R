# flores_coppock_2018/ground_truth/run_archive.R
# Output: ground_truth/archive_run_status.csv, ground_truth/archive_overwrites.csv
# Depends on: original/ (run download_original.R first)
# Description: Run every deposited script twice, each time in a scratch copy of the
#   deposit and never in original/ itself, and record what each run did.
#
#   The as_shipped pass copies the deposit exactly as Dataverse serves it. The stripped
#   pass copies it without the two figure PDFs, the only files in the deposit that its
#   own code writes, so a script that passes there passes on data and code alone. The
#   deposit ships no intermediate data, so the two passes differ only in those PDFs.
#
#   archive_run_status.csv carries one row per script per pass. All eight scripts are
#   analysis scripts: the deposit has no cleaning step and no helper sourced by another
#   script. archive_overwrites.csv carries one row per file a pass did something to:
#   a deposited file written over, a withheld PDF rebuilt, or a file the deposit never
#   contained added beside it. Both tables record properties of the deposit only; run
#   times go to the console.
#
#   Each script's console output is kept as orig_<script>.log in the pass's own copy,
#   under ARCHIVE_RUN_DIR (a temporary directory unless set). Setting ARCHIVE_RUN_DIR to
#   <that directory>/as_shipped is how extract_archive_values.R reads them.
#
#   This script is not part of run_all.R. It needs the packages the deposit was written
#   against (stargazer, coefplot, ggstance, margins), which the rewrite does not use.

library(here)
library(tidyverse)
library(processx)

here::i_am("ground_truth/run_archive.R")

manifest <- read_csv(here::here("original_manifest.csv"), show_col_types = FALSE)
deposit_dir <- here::here("original", "replication_archive")
run_root <- Sys.getenv("ARCHIVE_RUN_DIR", unset = file.path(tempdir(), "archive_run"))

stopifnot(all(file.exists(here::here("original", manifest$file))))

scripts <- basename(str_subset(manifest$file, "\\.R$"))
shipped_outputs <- basename(str_subset(manifest$file, "\\.pdf$"))
deposited_md5 <- set_names(manifest$md5_served, basename(manifest$file))

# Every deposited script finishes in seconds; the budget is generous so that a timeout
# can only mean a hang.
timeout_seconds <- 600

stopped_at <- function(log) {
  error_line <- str_subset(str_split_1(log, "\n"), "^Error")
  if (length(error_line) == 0) NA_character_ else str_trim(error_line[1])
}

run_script <- function(script, dir) {
  started <- Sys.time()
  result <- tryCatch(
    processx::run("Rscript", script, wd = dir, error_on_status = FALSE,
                  stderr_to_stdout = TRUE, timeout = timeout_seconds),
    system_command_timeout_error = function(e) list(status = NA_integer_, stdout = "",
                                                    timeout = TRUE)
  )
  write_file(result$stdout,
             file.path(dir, str_glue("orig_{str_remove(script, '\\\\.R$')}.log")))
  print(str_glue("{basename(dir)}: {script} exited {result$status} after ",
                 "{round(as.numeric(difftime(Sys.time(), started, units = 'secs')), 1)}s"))
  tibble(
    script,
    exit_status = as.integer(result$status),
    outcome = case_when(
      isTRUE(result$timeout) ~ "timeout",
      result$status == 0 ~ "clean",
      .default = "error"
    ),
    stopped_at = if (isTRUE(result$timeout)) {
      str_glue("killed after {timeout_seconds} seconds")
    } else if (result$status == 0) {
      NA_character_
    } else {
      stopped_at(result$stdout)
    }
  )
}

# The harness's own logs are not something the deposit wrote.
copy_state <- function(dir) {
  files <- setdiff(list.files(dir), list.files(dir, pattern = "^orig_.*\\.log$"))
  tibble(file = files,
         md5 = unname(tools::md5sum(file.path(dir, files))),
         mtime = file.mtime(file.path(dir, files)))
}

run_pass <- function(pass) {
  dir <- file.path(run_root, pass)
  unlink(dir, recursive = TRUE)
  dir.create(dir, recursive = TRUE)
  stripped_here <- if (pass == "stripped") shipped_outputs else character(0)
  copied <- setdiff(basename(manifest$file), stripped_here)
  stopifnot(all(file.copy(file.path(deposit_dir, copied), dir)))
  before <- copy_state(dir)

  # A file copied and then written in the same second would show no change of mtime.
  Sys.sleep(1.1)
  status <- map(scripts, \(s) run_script(s, dir)) |>
    list_rbind() |>
    mutate(pass = pass, role = "analysis", .before = 1)

  after <- copy_state(dir)
  changes <- full_join(before, after, by = "file", suffix = c("_before", "_after")) |>
    mutate(
      effect = case_when(
        is.na(md5_after) ~ "deleted",
        file %in% shipped_outputs & is.na(md5_before) ~ "rebuilt",
        is.na(md5_before) ~ "added",
        mtime_after > mtime_before ~ "overwritten",
        .default = NA_character_
      ),
      matches_deposit = if_else(effect %in% c("overwritten", "rebuilt", "deleted"),
                                md5_after == deposited_md5[file], NA)
    )
  withheld <- tibble(file = setdiff(stripped_here, after$file),
                     effect = "withheld", matches_deposit = NA)
  overwrites <- bind_rows(filter(changes, !is.na(effect)), withheld) |>
    transmute(pass, file, effect, matches_deposit)

  list(status = status, overwrites = overwrites)
}

passes <- map(c("as_shipped", "stripped"), run_pass)

run_status <- map(passes, "status") |>
  list_rbind() |>
  select(pass, script, role, exit_status, outcome, stopped_at)
overwrites <- map(passes, "overwrites") |>
  list_rbind() |>
  arrange(pass, file)

stopifnot(
  nrow(run_status) == 2 * length(scripts),
  all(run_status$outcome %in% c("clean", "error", "timeout", "not_run")),
  all(overwrites$effect %in% c("added", "overwritten", "rebuilt", "withheld", "deleted"))
)

write_csv(run_status, here::here("ground_truth", "archive_run_status.csv"))
write_csv(overwrites, here::here("ground_truth", "archive_overwrites.csv"))
print(run_status, n = nrow(run_status), width = 200)
print(overwrites, n = nrow(overwrites))
