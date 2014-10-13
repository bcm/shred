require 'shred/commands/base'

module Shred
  module Commands
    class Services < Base
      attr_reader :supported_services

      class Service
        attr_reader :sym

        def initialize(sym: nil)
          @sym = sym
        end

        def start(ctx, command_lines)
          ctx.run_shell_command(ShellCommand.new(
            command_lines: command_lines,
            success_msg: "#{sym} started",
            error_msg: "#{sym} could not be started"
          ))
        end

        def stop(ctx, command_lines)
          ctx.run_shell_command(ShellCommand.new(
            command_lines: command_lines,
            success_msg: "#{sym} stopped",
            error_msg: "#{sym} could not be stopped"
          ))
        end
      end

      class LaunchctlService < Service
        attr_reader :plist

        def initialize(sym: nil, plist: nil)
          super(sym: sym)
          @plist = plist
        end

        def start(ctx)
          super(ctx, "launchctl load -w -F #{plist}")
        end

        def stop(ctx)
          super(ctx, "launchctl unload #{plist}")
        end
      end

      class ShellCommandService < Service
        attr_reader :start_command_lines, :stop_command_lines

        def initialize(sym: nil, start_command_lines: nil, stop_command_lines: nil)
          super(sym: sym)
          @start_command_lines = start_command_lines
          @stop_command_lines = stop_command_lines
        end

        def start(ctx)
          super(ctx, start_command_lines)
        end

        def stop(ctx)
          super(ctx, stop_command_lines)
        end
      end

      desc 'start [services...]', 'Start some or all platform services'
      long_desc <<-LONGDESC
        Starts platform services that the application uses.

        When no services are specified, all services are started.

        When one or more services are specified, only those services are started.
      LONGDESC
      def start(*services)
        invoke_for_services(:start, *services)
      end

      desc 'stop [services...]', 'Stop some or all platform services'
      long_desc <<-LONGDESC
        Stops platform services that the application uses.

        When no services are specified, all services are stopped.

        When one or more services are specified, only those services are stopped.
      LONGDESC
      def stop(*services)
        invoke_for_services(:stop, *services)
      end

      no_commands do
        def configure
          @supported_services = command_config.each_with_object([]) do |(type, specs), m|
            case type.to_sym
            when :launchctl
              specs.each_with_object(m) do |(svc, keys), mm|
                plist = keys['plist'] or
                  raise "Missing 'plist' config for '#{svc}' platform service"
                mm << LaunchctlService.new(
                  sym: svc.to_sym,
                  plist: plist
                )
              end
            when :shell
              specs.each_with_object(m) do |(svc, keys), mm|
                start = keys['start'] or
                  raise "Missing 'start' config for '#{svc}' platform service"
                stop = keys['stop'] or
                  raise "Missing 'stop' config for '#{svc}' platform service"
                mm << ShellCommandService.new(
                  sym: svc.to_sym,
                  start_command_lines: start,
                  stop_command_lines: stop
                )
              end
            else raise "Unknown platform service type #{type}"
            end
          end
        end

        def invoke_for_services(meth, *services)
          services = supported_services.map { |d| d.sym.to_s} if services.empty?
          services.each do |service|
            service = supported_services.detect { |d| d.sym.to_s == service }
            if service
              service.send(meth, self)
            else
              say_err("No such service #{service}")
            end
          end
        end
      end
    end
  end
end
