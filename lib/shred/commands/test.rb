require 'shred/commands/base'

module Shred
  module Commands
    class Test < Base
      desc 'all', 'Run all tests'
      def all
        invoke(:server) if cfg('server', required: false)
        invoke(:client) if cfg('client', required: false)
      end

      desc 'server', 'Run only server tests'
      def server
        run_shell_command(ShellCommand.new(command_lines: cfg('server')))
      end

      desc 'client', 'Run only client tests'
      def client
        run_shell_command(ShellCommand.new(command_lines: cfg('client')))
      end
    end
  end
end
