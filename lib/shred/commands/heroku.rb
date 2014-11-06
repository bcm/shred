require 'dotenv'
require 'platform-api'
require 'shred/commands/base'

module Shred
  module Commands
    class Heroku < Base
      desc 'restartall ENVIRONMENT', 'Restart all app dynos'
      long_desc <<-LONGDESC
        Restarts all of the application's dynos.

        Consults the commands.heroku.<environment>.app_name config item to determine which Heroku
        app to restart.
      LONGDESC
      def restartall(environment)
        app_name = cfg("#{environment}.app_name")
        connection.dyno.restart_all(app_name)
        console.say_ok("Restarted all dynos for #{app_name}")
      end

      no_commands do
        def connection
          @connection ||= begin
            ::Dotenv.load
            begin
              PlatformAPI.connect_oauth(ENV['HEROKU_DEPLOY_TOKEN'])
            rescue Excon::Errors::Unauthorized
              console.say_err("Access to Heroku is not authorized. Did you set the HEROKU_DEPLOY_TOKEN environment variable?")
              exit(1)
            end
          end
        end
      end
    end
  end
end
