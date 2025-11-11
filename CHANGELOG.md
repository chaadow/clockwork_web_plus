## 1.0.0 (2025-11-11)

- New: Fuzzy find search across jobs
- New: "Run now" — run any job immediately from the index page
- New: View the Ruby implementation of each job
- New: Highlight overdue jobs at a glance
- New: Hourly health check callback via `ClockworkWebPlus.on_health_check`, with detailed overdue context
- New: Redesigned jobs table with a sleeker, modern UI

Note: Versions prior to 1.0.0 (0.x.y) correspond to the original `clockwork_web` project by ankane. See `https://github.com/ankane/clockwork_web`.

## 0.3.1 (2024-09-04)

- Improved CSP support

## 0.3.0 (2024-06-24)

- Dropped support for Clockwork < 3
- Dropped support for Ruby < 3.1 and Rails < 6.1

## 0.2.0 (2023-02-01)

- Dropped support for Ruby < 2.7 and Rails < 6

## 0.1.2 (2023-02-01)

- Fixed CSRF vulnerability with Rails < 5.2 - [more info](https://github.com/ankane/clockwork_web/issues/4)

## 0.1.1 (2020-03-19)

- Fixed load error

## 0.1.0 (2019-10-28)

- Added `on_job_update` hook

## 0.0.5 (2015-05-13)

- Added `running_threshold` option

## 0.0.4 (2015-03-15)

- Better monitoring for multiple processes
