# Clockwork Web Plus

A fully compatible drop-in enhancement to [ankane/clockwork_web](https://github.com/ankane/clockwork_web), providing a modern web interface for [Clockwork](https://github.com/Rykian/clockwork) with fuzzy search, manual job run, overdue visibility, and hourly health checks.

[![Build Status](https://github.com/chaadow/clockwork_web_plus/actions/workflows/build.yml/badge.svg)](https://github.com/chaadow/clockwork_web_plus/actions/workflows/build.yml)

## Preview

<video src="https://github.com/user-attachments/assets/d145a4d5-834d-4c0d-9f11-397272b2d013" controls muted playsinline loop>
  Sorry, your browser doesn't support embedded videos. Here’s a <a href="https://github.com/user-attachments/assets/d145a4d5-834d-4c0d-9f11-397272b2d013">direct link</a>.
</video>

## Features

### Core (from `clockwork_web`)

- see list of jobs
- monitor jobs ( when they were last run at)
- Temporarily disable jobs

### New compared to clockwork_web

- fuzzy find search across jobs
- run any job immediately through the `Run now` button
- view the Ruby implementation of each job
- highlight overdue jobs at a glance
- optional hourly health check callback with custom alerting

## Installation

Add this line to your application’s Gemfile:

```ruby
gem "clockwork_web_plus"
```

> [!TIP]
> Already using `clockwork_web`? Keep your existing `ClockworkWeb::Engine` mount and initializers—no renaming needed. `ClockworkWebPlus` aliases `ClockworkWeb`, so it works out of the box.

And add it to your `config/routes.rb`.

```ruby
mount ClockworkWebPlus::Engine, at: "clockwork"
```

> [!IMPORTANT]
> Secure the dashboard in production. Protect access with Basic Auth, Devise, or your app’s auth layer to avoid exposing job controls and status.

To monitor and disable jobs, hook up Redis in an initializer.

```ruby
ClockworkWebPlus.redis = Redis.new
```

#### Basic Authentication

Set the following variables in your environment or an initializer.

```ruby
ENV["CLOCKWORK_USERNAME"] = "chaadow"
ENV["CLOCKWORK_PASSWORD"] = "secret"
```

> [!NOTE]
> These are example credentials. Use environment-specific secrets and rotate them regularly.

#### Devise

```ruby
authenticate :user, ->(user) { user.admin? } do
  mount ClockworkWebPlus::Engine, at: "clockwork"
end
```

> [!TIP]
> Any authentication framework works—wrap the mount with whatever guard your app already uses for admin/ops access.

## Monitoring

```ruby
ClockworkWebPlus.running?
ClockworkWebPlus.multiple?
```

> [!NOTE]
> `running?` reflects recent heartbeats. `multiple?` indicates multiple active Clockwork processes (based on heartbeat contention).

## Customize

Change clock path

```ruby
ClockworkWebPlus.clock_path = Rails.root.join("clock") # default
```

> [!NOTE]
> The default `clock_path` matches `clockwork_web`. Change it only if your clock file lives elsewhere.

Turn off monitoring

```ruby
ClockworkWebPlus.monitor = false
```

> [!CAUTION]
> Disabling monitoring stops heartbeats and multiple-process detection. The dashboard won’t show “running” status, but other features still work.

### Overdue Jobs & Health Checks

The dashboard highlights overdue jobs based on schedule and last run. You can also configure an hourly health check to alert when jobs are overdue:

```ruby
ClockworkWebPlus.on_health_check = ->(overdue_jobs:) do
  # backlog contains array of hashes with details like:
  # { job:, should_have_run_at:, last_run:, period:, at: { hour:, min: } }
  if overdue_jobs.any?
    # send notification to Slack, email, etc.
  end
end
```

> [!NOTE]
> Overdue detection uses `ClockworkWebPlus.warning_threshold` (default: 300 seconds).  
> - For `@at` schedules: a job is overdue when the most recent scheduled time has passed by more than `warning_threshold` and the job hasn’t run since that time.  
> - For periodic jobs (no `@at`): a job is overdue when `now > last_run + period + warning_threshold`.
>
> Example:
> ```ruby
> # consider jobs overdue 10 minutes after their expected time
> ClockworkWebPlus.warning_threshold = 600
> ```

> [!IMPORTANT]
> With Redis configured, the health check runs at most once per hour across processes. Without Redis, throttling is per-process and approximate.

## History

View the [changelog](CHANGELOG.md)

## Compatibility

This gem is a drop-in replacement for `clockwork_web`. For backward compatibility, the original namespace is aliased:

```ruby
# Both of these work:
mount ClockworkWebPlus::Engine, at: "clockwork"
mount ClockworkWeb::Engine, at: "clockwork"
```

> [!TIP]
> Adopting this gem can be as simple as swapping the gem name in your Gemfile. Your existing `ClockworkWeb` mounts and initializers continue to work unchanged.

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/chaadow/clockwork_web_plus/issues)
- Fix bugs and [submit pull requests](https://github.com/chaadow/clockwork_web_plus/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features

To get started with development:

```sh
git clone https://github.com/chaadow/clockwork_web_plus.git
cd clockwork_web_plus
bundle install
bundle exec rake test
```
