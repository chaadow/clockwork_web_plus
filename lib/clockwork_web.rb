# dependencies
require "clockwork"
require "safely/core"

# modules
require_relative "clockwork_web/engine" if defined?(Rails)
require_relative "clockwork_web/version"

module ClockworkWeb
  LAST_RUNS_KEY = "clockwork:last_runs"
  DISABLED_KEY = "clockwork:disabled"
  HEARTBEAT_KEY = "clockwork:heartbeat"
  STATUS_KEY = "clockwork:status"
  HEALTH_CHECK_KEY = "clockwork:health_check"

  class << self
    attr_accessor :clock_path
    attr_accessor :redis
    attr_accessor :monitor
    attr_accessor :running_threshold
    attr_accessor :on_job_update
    attr_accessor :user_method
    attr_accessor :warning_threshold
    attr_accessor :on_health_check
  end
  self.monitor = true
  self.running_threshold = 60 # seconds
  self.user_method = :current_user
  self.warning_threshold = 300 # seconds, default 5 minutes

  def self.enable(job)
    if redis
      redis.srem(DISABLED_KEY, job)
      true
    else
      false
    end
  end

  def self.disable(job)
    if redis
      redis.sadd(DISABLED_KEY, job)
      true
    else
      false
    end
  end

  def self.enabled?(job)
    if redis
      !redis.sismember(DISABLED_KEY, job)
    else
      true
    end
  end

  def self.disabled_jobs
    if redis
      Set.new(redis.smembers(DISABLED_KEY))
    else
      Set.new
    end
  end

  def self.last_runs
    if redis
      Hash[redis.hgetall(LAST_RUNS_KEY).map { |job, timestamp| [job, Time.at(timestamp.to_i)] }.sort_by { |job, time| [time, job] }]
    else
      {}
    end
  end

  def self.set_last_run(job)
    if redis
      redis.hset(LAST_RUNS_KEY, job, Time.now.utc.to_i)
    end
  end

  def self.last_heartbeat
    if redis
      timestamp = redis.get(HEARTBEAT_KEY)
      if timestamp
        Time.at(timestamp.to_i)
      end
    end
  end

  def self.heartbeat
    if redis
      heartbeat = Time.now.utc.to_i
      if heartbeat % 10 == 0 # every 10 seconds
        prev_heartbeat = redis.getset(HEARTBEAT_KEY, heartbeat).to_i
        if prev_heartbeat >= heartbeat
          redis.setex(STATUS_KEY, 60, "multiple")
        end
      end
    end
  end

  def self.running?
    last_heartbeat && last_heartbeat > Time.now.utc - running_threshold
  end

  def self.multiple?
    redis && redis.get(STATUS_KEY) == "multiple"
  end

  # Runs at most once per hour across processes. When triggered, gathers overdue jobs and
  # invokes the configured on_health_check callback if any are found.
  def self.health_check
    return unless on_health_check

    now = Time.now.utc.to_i
    proceed = false

    if redis
      last = redis.get(HEALTH_CHECK_KEY).to_i
      if last == 0 || (now - last) >= 3600
        prev = redis.getset(HEALTH_CHECK_KEY, now).to_i
        proceed = (prev == last) || (now - prev) >= 3600
      end
    else
      @last_health_check ||= 0
      if (now - @last_health_check) >= 3600
        @last_health_check = now
        proceed = true
      end
    end

    return unless proceed

    events = Clockwork.manager.events
    last_runs = ClockworkWeb.last_runs
    overdue_jobs = ClockworkWeb.overdue_details(events, last_runs)
    ClockworkWeb.on_health_check.call(overdue_jobs: overdue_jobs) if overdue_jobs.any?
  end

  # Returns the last time this event should have run before now.
  # For @at schedules, computes the most recent scheduled time at the declared hour/minute,
  # respecting common periods (daily, multi-day, hourly). For simple periodic jobs (no @at),
  # returns last_run + period when that is in the past. Returns nil when it cannot be determined.
  # Convert a given time to the event timezone if supported; default to UTC.
  def self.now_in_event_timezone(event, base_now = Time.now.utc)
    if event.respond_to?(:convert_timezone)
      event.convert_timezone(base_now)
    else
      base_now
    end
  end

  def self.should_have_run_at(event, last_run_time, now = Time.now.utc)
    period = event.instance_variable_get(:@period)
    return nil unless period

    at = event.instance_variable_get(:@at)
    if at
      now_for_event = now_in_event_timezone(event, now)
      hour = at.instance_variable_get(:@hour) || 0
      min = at.instance_variable_get(:@min) || 0
      wday = at.instance_variable_get(:@wday) rescue nil

      # Weekly or multi-week schedules with specific weekday
      if !wday.nil?
        step_weeks = (period % 604_800).zero? ? [(period / 604_800).to_i, 1].max : 1
        days_ago = (now_for_event.wday - wday) % 7
        day = now_for_event.to_date - days_ago
        candidate = Time.new(day.year, day.month, day.day, hour, min, 0, now_for_event.utc_offset)
        candidate -= 604_800 if candidate > now
        if step_weeks > 1
          anchor = last_run_time || candidate
          while (((anchor.to_date - candidate.to_date).to_i / 7) % step_weeks) != 0
            candidate -= 604_800
          end
        end
        return candidate
      end

      # Daily or multi-day schedules
      if (period % 86_400).zero?
        step_days = [(period / 86_400).to_i, 1].max
        base_day = now_for_event.to_date
        # Try the most recent aligned day within one full cycle
        0.upto(step_days - 1) do |offset|
          day = base_day - offset
          candidate = Time.new(day.year, day.month, day.day, hour, min, 0, now_for_event.utc_offset)
          if candidate <= now_for_event
            # Alignment: only consider days separated by the step length
            return candidate if (base_day - day).to_i % step_days == 0
          end
        end
        # Fallback to previous aligned cycle
        day = base_day - step_days
        return Time.new(day.year, day.month, day.day, hour, min, 0, now_for_event.utc_offset)
      end

      # Hourly or multi-hour schedules (e.g., every 2 hours at minute 15)
      if (period % 3600).zero?
        step_hours = [(period / 3600).to_i, 1].max
        aligned_hour = (now_for_event.hour / step_hours) * step_hours
        candidate = Time.new(now_for_event.year, now_for_event.month, now_for_event.day, aligned_hour, min, 0, now_for_event.utc_offset)
        candidate -= step_hours * 3600 if candidate > now
        return candidate
      end

      # Fallback: treat as daily at the given time
      candidate = Time.new(now_for_event.year, now_for_event.month, now_for_event.day, hour, min, 0, now_for_event.utc_offset)
      candidate -= 86_400 if candidate > now_for_event
      return candidate
    else
      # Simple periodic job (no @at) – use last_run anchor
      return nil unless last_run_time
      expected = last_run_time + period
      return expected if expected <= (now || Time.now.utc)
      return nil
    end
  end

  # Determines whether an event is overdue given its schedule and last run.
  def self.overdue?(event, last_run_time, now = Time.now.utc)
    period = event.instance_variable_get(:@period) || 0
    at_time = should_have_run_at(event, last_run_time, now)
    now_for_event = now_in_event_timezone(event, now)

    # If an if-lambda is present and evaluates false at current event-local time,
    # do not consider the job overdue.
    if_lambda = event.instance_variable_get(:@if)
    if if_lambda
      begin
        allowed = if if_lambda.arity == 1
          if_lambda.call(now_for_event)
        else
          if_lambda.call
        end
        return false unless allowed
      rescue StandardError
        return true
      end
    end

    if event.instance_variable_get(:@at)
      return false unless at_time
      # Overdue if the scheduled time has passed by more than the threshold and we haven't run since
      return (now_for_event - at_time) > warning_threshold && (last_run_time.nil? || last_run_time < at_time)
    else
      return false unless last_run_time && period.positive?
      return now_for_event > (last_run_time + period + warning_threshold)
    end
  end

  # Collect details about overdue events for alerting or diagnostics.
  def self.overdue_details(events, last_runs, now = Time.now)
    events.filter_map do |event|
      next unless ClockworkWeb.enabled?(event.job)
      lr = last_runs[event.job]
      if overdue?(event, lr, now)
        should_at = should_have_run_at(event, lr, now)
        {
          job: event.job,
          should_have_run_at: should_at,
          last_run: lr,
          period: event.instance_variable_get(:@period),
          at: event.instance_variable_get(:@at) && {
            hour: event.instance_variable_get(:@at).instance_variable_get(:@hour),
            min: event.instance_variable_get(:@at).instance_variable_get(:@min)
          }
        }
      end
    end
  end
end

module Clockwork
  on(:before_tick) do
    ClockworkWeb.heartbeat if ClockworkWeb.monitor
    ClockworkWeb.health_check if ClockworkWeb.on_health_check
    true
  end

  on(:before_run) do |event, t|
    run = true

    Safely.safely do
      run = ClockworkWeb.enabled?(event.job)
      unless run
        manager.log "Skipping '#{event}'"
        event.last = event.convert_timezone(t)
      end
    end

    run
  end

  on(:after_run) do |event, _t|
    ClockworkWeb.set_last_run(event.job) if ClockworkWeb.enabled?(event.job)
  end

end
