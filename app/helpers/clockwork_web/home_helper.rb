module ClockworkWeb
  module HomeHelper
    def friendly_period(period)
      if period % 1.day == 0
        pluralize(period / 1.day, "day")
      elsif period % 1.hour == 0
        pluralize(period / 1.hour, "hour")
      elsif period % 1.minute == 0
        "#{period / 1.minute} min"
      else
        "#{period} sec"
      end
    end

    def last_run(time)
      if time
        "#{time_ago_in_words(time, include_seconds: true)} ago"
      end
    end

    def friendly_time_part(time_part)
      if time_part
        time_part.to_s.rjust(2, "0")
      else
        "**"
      end
    end

    def overdue?(event, last_run)
      ClockworkWeb.overdue?(event, last_run)
    end

    def should_have_run_at(event, last_run)
      ClockworkWeb.should_have_run_at(event, last_run)
    end

    def friendly_should_have_run(event, last_run)
      at = should_have_run_at(event, last_run)
      if at
        "#{time_ago_in_words(at, include_seconds: true)} ago"
      end
    end

    def friendly_extract_source_from_callable(callable, with_affixes: true)
      iseq = RubyVM::InstructionSequence.of(callable)
      source =
        if iseq.script_lines
          iseq.script_lines.join("\n")
        elsif File.readable?(iseq.absolute_path)
          File.read(iseq.absolute_path)
        end
      return '-' unless source

      location = iseq.to_a[4][:code_location]
      return callable unless location

      lines = source.lines[(location[0] - 1)..(location[2] - 1)]
      lines[-1] = lines[-1].byteslice(...location[3])
      lines[0] = lines[0].byteslice(location[1]...)
      source = lines.join.strip

      source.tap do |source|
        source.delete_prefix!('{')
        source.delete_suffix!('}')

        source.delete_prefix!('do')
        source.delete_suffix!('end')
      end
    end
  end
end
