module ClockworkWeb
  class HomeController < ActionController::Base
    layout false
    helper ClockworkWeb::HomeHelper

    protect_from_forgery with: :exception

    http_basic_authenticate_with name: ENV["CLOCKWORK_USERNAME"], password: ENV["CLOCKWORK_PASSWORD"] if ENV["CLOCKWORK_PASSWORD"]

    def index
      @last_runs = ClockworkWeb.last_runs
      @disabled = ClockworkWeb.disabled_jobs
      @events =
        Clockwork.manager.instance_variable_get(:@events).sort_by do |e|
          at = e.instance_variable_get(:@at)
          enabled = !@disabled.include?(e.job)
          overdue = enabled && ClockworkWeb.overdue?(e, @last_runs[e.job])
          [
            overdue ? 0 : 1, # prioritize overdue first
            e.instance_variable_get(:@period),
            (at && at.instance_variable_get(:@hour)) || -1,
            (at && at.instance_variable_get(:@min)) || -1,
            e.job.to_s
          ]
        end

      @last_heartbeat = ClockworkWeb.last_heartbeat
    end

    def job
      job = params[:job]
      enable = params[:enable] == "true"
      if enable
        ClockworkWeb.enable(job)
      else
        ClockworkWeb.disable(job)
      end
      ClockworkWeb.on_job_update.call(job: job, enable: enable, user: try(ClockworkWeb.user_method)) if ClockworkWeb.on_job_update
      redirect_to root_path
    end

    def execute
      job = params[:job]

      event = Clockwork.manager.events.find { _1.job == params[:job] }

      event.run(Time.now.utc)
      ClockworkWeb.set_last_run(event.job)

      redirect_to root_path
    end
  end
end
