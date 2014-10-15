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
          command_lines: 'bin/rake db:create:all db:structure:load',
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

      desc 'dump', 'Dump the contents of the database to a file'
      def dump
        command_lines = Array(cfg('dump')).map { |v| interpolate_value(v) }
        run_shell_command(ShellCommand.new(
          command_lines: command_lines,
          success_msg: 'Database dumped',
          error_msg: 'Database could not be dumped'
        ))
      end

      desc 'restore DUMPFILE', 'Load the contents of a dump file into the database'
      def restore(dumpfile)
        context = {dumpfile: dumpfile}
        command_lines = Array(cfg('restore')).map { |v| interpolate_value(v, context: context) }
        run_shell_command(ShellCommand.new(
          command_lines: command_lines,
          success_msg: 'Database restored',
          error_msg: 'Database could not be restored'
        ))
      end
    end
  end
end
