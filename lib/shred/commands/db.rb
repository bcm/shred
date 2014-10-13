require 'shred/commands/base'

module Shred
  module Commands
    class Db < Base
      desc 'init', 'Set up the database in development and test environments'
      long_desc <<-LONGDESC
        Recreate the database from the structure.sql file.
      LONGDESC
      def init
        run_shell_command(ShellCommand.new(
          command_lines: 'bin/rake db:create db:structure:load',
          success_msg: 'Database initialized',
          error_msg: 'Database could not be initialized'
        ))
      end

      desc 'migrate', 'Apply pending migrations to the database'
      def migrate
        run_shell_command(ShellCommand.new(
          command_lines: 'bin/rake db:migrate',
          success_msg: 'Migrations applied',
          error_msg: 'Migrations could not be applied'
        ))
      end
    end
  end
end
