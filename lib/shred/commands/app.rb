require 'shred/commands/base'

module Shred
  module Commands
    class App < Base
      desc 'start', 'Start the application processes'
      def start
        run_shell_command(ShellCommand.new(command_lines: cfg('start')))
      end
    end
  end
end
