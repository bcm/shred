require 'shred/commands/base'

module Shred
  module Commands
    class JsDeps < Base
      desc 'install', 'Install JavaScript dependencies'
      def install
        run_shell_command(ShellCommand.new(
          command_lines: 'bin/rake bower:install',
          success_msg: "JavaScript dependencies installed",
          error_msg: "JavaScript dependencies could not be installed"
        ))
      end
    end
  end
end
