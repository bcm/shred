require 'shred/commands/base'

module Shred
  module Commands
    class Dotenv < Base
      desc 'heroku', 'Write the environment config file from Heroku config variables'
      long_desc <<-LONGDESC
        Writes the environment config file (.env) by reading Heroku config variables.

        Consults the commands.dotenv.heroku.app_name config item to determine which Heroku
        app to load config vars from.

        Consults the commands.dotenv.heroku.vars config item to determine which Heroku
        config vars to add to the .env file.

        If the commands.dotenv.custom config item lists custom config items, they are also
        added to the .env file.
      LONGDESC
      def heroku
        app_name = cfg('heroku.app_name')
        vars = cfg('heroku.vars')
        custom = cfg('custom.vars', required: false)

        run_shell_command(ShellCommand.new(command_lines: 'heroku auth:whoami'))

        heroku = StringIO.new
        run_shell_command(ShellCommand.new(
          command_lines: "heroku config --app #{app_name} --shell",
          output: heroku
        ))

        outvars = {}

        heroku.string.split("\n").each do |line|
          key, value = line.split('=', 2)
          outvars[key] = value if vars.include?(key)
        end

        if custom
          custom.each do |key, value|
            outvars[key] = interpolate_value(value)
          end
        end

        File.open('.env', 'w') do |dotenv|
          outvars.sort_by(&:first).each do |(key, value)|
            dotenv.write("#{key}='#{value}'\n")
          end
        end

        console.say_ok("Heroku config written to .env")
      end
    end
  end
end
