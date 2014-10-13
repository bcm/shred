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
      LONGDESC
      def heroku
        app_name = cfg('heroku.app_name')
        vars = cfg('heroku.vars')
        mode = cfg('heroku.mode') == 'a' ? 'a' : 'w'

        authenticate_to_heroku

        run_shell_command(ShellCommand.new(
          command_lines: "heroku config --app #{app_name} --shell",
          output: '.heroku.env'
        ))
        File.open('.heroku.env') do |input|
          File.open('.env', mode) do |output|
            input.readlines.each do |line|
              line.chomp!
              if line =~ /^([^=]+)=/ && vars.include?($1)
                output.write("#{line}\n")
              end
            end
          end
        end
        File.unlink('.heroku.env')
        console.say_ok("Heroku config written to environment config file")
      end

      desc 'custom', 'Write custom config items to the environment config file'
      long_desc <<-LONGDESC
        Writes custom config items to the environment config file (.env).

        Consults the commands.dotenv.custom config item to determine the custom config items to
        add to the .env file.
      LONGDESC
      option :append, type: :boolean, default: false
      def custom
        custom = cfg('custom.vars')
        mode = cfg('custom.mode') == 'a' ? 'a' : 'w'

        File.open('.env', mode) do |output|
          custom.each do |key, value|
            output.write("#{key}=#{value}\n")
          end
        end
        console.say_ok("Custom config written to environment config file")
      end

      no_commands do
        def authenticate_to_heroku
          run_shell_command(ShellCommand.new(command_lines: 'heroku auth:whoami'))
        end
      end
    end
  end
end
