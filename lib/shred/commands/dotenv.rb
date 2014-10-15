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

        io = StringIO.new
        run_shell_command(ShellCommand.new(
          command_lines: "heroku config --app #{app_name} --shell",
          output: io
        ))

        File.open('.env', 'w') do |output|
          io.string.split("\n").each do |line|
            if line =~ /^([^=]+)=/ && vars.include?($1)
              output.write("#{line}\n")
            end
          end
          console.say_ok("Heroku config written to .env")

          if custom
            custom.each do |key, value|
              output.write("#{key}=#{value}\n")
            end
            console.say_ok("Custom config written to .env")
          end
        end
      end
    end
  end
end
