require 'bundler'
require 'open3'
require 'thor'

module Shred
  module Commands
    class ShellCommand
      class CommandLine
        attr_reader :command_line, :out

        def initialize(command_line: nil, out: nil)
          @command_line = command_line
          @out = out
        end

        def run
          Bundler.with_clean_env do
            if out
              Open3.popen3(command_line) do |stdin, stdout, stderr, wait_thr|
                install_signal_handler(wait_thr.pid)

                while out_line = stdout.gets
                  out.write(out_line)
                end

                while err_line = stderr.gets
                  puts err_line
                end

                wait_thr.value
              end
            else
              pid = Process.spawn(command_line)
              install_signal_handler(pid)
              Process.wait(pid)
              $?
            end
          end
        end

        def to_s
          command_line.to_s
        end

      private
        def install_signal_handler(pid)
          # make sure Ctrl-C gets passed on to the child process
          # http://stackoverflow.com/questions/14635318/having-a-io-popen-command-be-killed-when-the-caller-process-is-killed
          Signal.trap('INT') do
            # propagate the signal to the child
            Process.kill('INT', pid)
            # send the signal back to this process
            Signal.trap('INT', 'DEFAULT')
            Process.kill('INT', 0)
          end
        end
      end

      attr_reader :command_lines, :success_msg, :error_msg, :output, :out

      def initialize(command_lines: nil, success_msg: nil, error_msg: nil, output: nil)
        @command_lines = Array(command_lines).compact
        raise ArgumentError, "At least one command line is required" if command_lines.empty?
        @success_msg = success_msg
        @error_msg = error_msg
        @output = output
        @out = if output && output.respond_to?(:write)
          output
        elsif output
          File.open(output, 'w')
        end
      end

      def run(&block)
        exit_status = nil
        command_lines.each_with_index do |command_line, i|
          command_line = CommandLine.new(command_line: command_line, out: out)
          exit_status = if block_given?
            yield(command_line)
          else
            command_line.run
          end
          break unless exit_status.success?
        end
        exit_status
      ensure
        out.close if out
      end
    end

    class ShellCommandRunner
      attr_reader :console

      def initialize(console:)
        @console = console
      end

      def run(shell_command)
        exit_status = shell_command.run do |command_line|
          console.say_trace(command_line)
          command_line.run
        end
        if exit_status.success?
          if shell_command.success_msg
            console.say_ok(shell_command.success_msg)
          end
        elsif
          if shell_command.error_msg
            console.say_err("#{shell_command.error_msg}: #{exit_status}")
          else
            console.say_err(exit_status)
          end
        end
        exit_status
      end
    end

    class Console
      attr_reader :thor

      def initialize(thor: nil)
        @thor = thor
      end

      def say_trace(msg)
        thor.say_status(:TRACE, msg, :green)
      end

      def say_ok(msg)
        thor.say_status(:OK, msg, :blue)
      end

      def say_err(msg)
        thor.say_status(:ERR, msg, :red)
      end
    end

    class Base < Thor
      attr_reader :command_name, :command_config, :console

      def initialize(*args)
        @command_name = args[2][:invocations][Shred::CLI].last
        @command_config = Shred::CLI.config['commands'][@command_name]
        @console = Console.new(thor: self)
        super
        configure
      end

      no_commands do
        def configure
        end

        def cfg(key, required: true)
          base_cfg = command_config
          sub_keys = key.to_s.split('.')
          value = nil
          sub_keys.each_with_index do |sub_key, i|
            if base_cfg && base_cfg.key?(sub_key)
              value = base_cfg = base_cfg[sub_key]
            elsif i < sub_keys.length - 1
              raise "Missing '#{key}' config for '#{command_name}' command"
            else
              value = nil
            end
          end
          raise "Missing '#{key}' config for '#{command_name}' command" if required && !value
          value
        end

        def interpolate_value(value, context: {})
          return nil if value.nil?
          value.gsub(/{[^}]+}/) do |match|
            ref = match.slice(1, match.length)
            ref = ref.slice(0, ref.length - 1)
            if ref =~ /^env\:(.+)$/
              env_key = $1.upcase
              if ENV.key?(env_key)
                ENV[env_key]
              else
                raise "Unset environment variable '#{env_key}' referenced by value '#{value}'"
              end
            elsif context.key?(ref.to_sym)
              context[ref.to_sym]
            else
              raise "Unknown interpolation variable '#{ref}' referenced by value '#{value}'"
            end
          end
        end

        def run_shell_command(command)
          ShellCommandRunner.new(console: console).run(command)
        end

        def load_rails
          unless @rails_loaded
            require File.expand_path('config/environment.rb')
            @rails_loaded = true
          end
        end
      end
    end
  end
end
