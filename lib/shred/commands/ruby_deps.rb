require 'shred/commands/base'

module Shred
  module Commands
    class RubyDeps < Base
      desc 'install', 'Install Ruby dependencies'
      def install
        run_shell_command(ShellCommand.new(
          command_lines: 'bundle install',
          success_msg: "Ruby dependencies installed",
          error_msg: "Ruby dependencies could not be installed"
        ))
      end
    end
  end
end
