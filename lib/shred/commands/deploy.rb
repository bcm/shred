require 'dotenv'
require 'platform-api'
require 'shred/commands/base'

module Shred
  module Commands
    class Deploy < Base
      class_option :environment
      class_option :branch

      desc 'all', 'Fully deploy the application by performing all deploy steps'
      long_desc <<-LONGDESC
        Fully deploy the application by performing all deploy steps in this order:

          1. update_code_from_heroku
          2. detect_pending_migrations
          3. if migrations were detected,
             a. maintenance_on
             b. scale_down
          4. push_code_to_heroku
          5. if migrations were detected,
             a. snapshot_db
             b. migrate_db
             c. scale_up
             d. restart_app
             e. maintenance_off
          6. send_notifications
      LONGDESC
      def all
        invoke(:update_code_from_heroku)
        invoke(:detect_pending_migrations)
        if migration_count > 0
          maintenance_on
          scale_down
        end
        push_code_to_heroku
        if migration_count > 0
          snapshot_db
          migrate_db
          scale_up
          restart_app
          maintenance_off
        end
        send_notifications
      end

      desc 'update_code_from_heroku', 'Update local copy of Heroku git remote'
      def update_code_from_heroku
        exit_status = run_shell_command(ShellCommand.new(
          command_lines: "git remote | grep #{heroku_remote_name} > /dev/null"
        ))
        unless exit_status.success?
          run_shell_command(ShellCommand.new(
            command_lines: "git remote add #{heroku_remote_name} #{heroku_info['git_url']}"
          ))
        end
        run_shell_command(ShellCommand.new(
          command_lines: "git fetch #{heroku_remote_name}"
        ))
        console.say_ok("Updated code from #{heroku_app_name} Heroku app")
      end

      desc 'detect_pending_migrations', 'Detect whether or not the local branch has pending migrations to apply'
      def detect_pending_migrations
        if migration_count > 1
          console.say_ok("#{migration_count} pending database migrations detected")
        elsif migration_count == 1
          console.say_ok("#{migration_count} pending database migration detected")
        else
          console.say_ok("No pending database migrations detected")
        end
      end

      desc 'maintenance_on', 'Enable maintenance mode for the Heroku app'
      def maintenance_on
        heroku.app.update(heroku_app_name, maintenance: true)
        console.say_ok("Maintenance mode enabled")
      end

      desc 'scale_down', 'Scale down all non-web processes'
      def scale_down
        updates = process_counts.each_with_object([]) do |(process_type, count), m|
          m << {'process' => process_type.to_s, 'quantity' => 0} if count > 0
        end
        heroku.formation.batch_update(heroku_app_name, 'updates' => updates)
        updated = process_counts.map do |(process_type, count)|
          if count > 1
            "#{count} #{process_type} processes"
          elsif count == 1
            "#{count} #{process_type} process"
          else
            nil
          end
        end.compact
        if updated.any?
          console.say_ok("Scaled down #{updated.join(', ')}")
        else
          console.say_ok("No non-web processes to scale down")
        end
      end

      desc 'push_code_to_heroku', 'Push local git branch to Heroku remote'
      def push_code_to_heroku
        run_shell_command(ShellCommand.new(
          command_lines: "git push -f #{heroku_remote_name} #{branch}:master"
        ))
        console.say_ok("Pushed code to Heroku")
      end

      desc 'snapshot_db', 'Capture a snapshot of the Heroku database'
      def snapshot_db
        run_shell_command(ShellCommand.new(
          command_lines: "heroku pgbackups:capture --expire --app #{heroku_app_name}"
        ))
        console.say_ok("Database snapshot captured")
      end

      desc 'migrate_db', 'Apply pending migrations to the database'
      def migrate_db
        if migration_count > 0
          dyno = heroku.dyno.create(heroku_app_name, command: 'rake db:migrate db:seed')
          poll_one_off_dyno_until_done(dyno)
          console.say_ok("Pending database migrations applied")
        else
          console.say_ok("No pending database migrations to apply")
        end
      end

      desc 'scale_up [--worker=NUM] [--clock=NUM]', 'Scale up all non-web processes'
      option :worker, type: :numeric
      option :clock, type: :numeric
      def scale_up
        updates = if options[:worker] || options[:clock]
          [:worker, :clock].each_with_object([]) do |process_type, m|
            m << {'process' => process_type.to_s, 'quantity' => options[process_type]}
          end
        else
          [:worker, :clock].each_with_object([]) do |process_type, m|
            count = process_counts[process_type] || 0
            m << {'process' => process_type.to_s, 'quantity' => count} if count > 0
          end
        end
        heroku.formation.batch_update(heroku_app_name, 'updates' => updates)
        updated = process_counts.map do |(process_type, count)|
          if count > 1
            "#{count} #{process_type} processes"
          elsif count == 1
            "#{count} #{process_type} process"
          else
            nil
          end
        end.compact
        if updated.any?
          console.say_ok("Scaled up #{updated.join(', ')}")
        else
          console.say_ok("No non-web processes to scale up")
        end
      end

      desc 'restart_app', 'Restart the Heroku app'
      def restart_app
        dynos = heroku.dyno.list(heroku_app_name).find_all { |d| d['type'] == 'web' }
        dynos.each do |dyno|
          heroku.dyno.restart(heroku_app_name, dyno['id'])
        end
        if dynos.count > 1
          console.say_ok("Restarted #{dynos.count} web dynos")
        elsif dynos.count == 1
          console.say_ok("Restarted #{dynos.count} web dyno")
        else
          console.say_ok("No web dynos to restart")
        end
      end

      desc 'maintenance_off', 'Disable maintenance mode for the Heroku app'
      def maintenance_off
        heroku.app.update(heroku_app_name, maintenance:false)
        console.say_ok("Maintenance mode disabled")
      end

      desc 'send_notifications', 'Send deploy notifications to external services'
      def send_notifications
        Array(cfg('notifications', required: false)).each do |(service, command)|
          command.
            gsub!(%r[{environment}], environment).
            gsub!(%r[{revision}], revision)
          dyno = heroku.dyno.create(heroku_app_name, command: command)
          poll_one_off_dyno_until_done(dyno)
          console.say_ok("Notification sent to #{service}")
        end
      end

      no_commands do
        def environment
          @environment ||= begin
            env = options[:environment] || cfg('default_environment', required: false)
            return env if env
            console.say_err("Deployment environment must be specified, either with --environment or with 'default_environment' config for '#{command_name}' command")
            exit(1)
          end
        end

        def branch
          @branch ||= begin
            br = options[:branch] || cfg("#{environment}.branch", required: false)
            return br if br
            console.say_err("Local branch name must be specified, either with --branch or with '#{environment}.branch' config for '#{command_name}' command")
          end
        end

        def revision
          `git rev-parse #{branch}`
        end

        def heroku
          @heroku ||= begin
            ::Dotenv.load
            begin
              PlatformAPI.connect_oauth(ENV['HEROKU_DEPLOY_TOKEN'])
            rescue Excon::Errors::Unauthorized
              console.say_err("Access to Heroku is not authorized. Did you set the HEROKU_DEPLOY_TOKEN environment variable?")
              exit(1)
            end
          end
        end

        def heroku_info
          @heroku_info ||= heroku.app.info(heroku_app_name)
        end

        def migration_count
          @migration_count ||= `git diff #{branch} #{heroku_remote_name}/master --name-only -- db | wc -l`.strip!.to_i
        end

        def process_counts
          @process_counts ||= begin
            formations = heroku.formation.list(heroku_app_name).each_with_object({}) { |f, m| m[f['type'].to_sym] = f }
            [:worker, :clock].each_with_object({}) do |process_type, m|
              quantity = formations.fetch(process_type, {}).fetch('quantity', 0)
              m[process_type] = quantity if quantity > 0
            end
          end
        end

        def heroku_app_name
          @heroku_app_name ||= cfg("#{environment}.heroku.app_name")
        end

        def heroku_remote_name
          @heroku_remote_name ||= cfg("#{environment}.heroku.remote_name", required: false) || heroku_app_name
        end

        def poll_one_off_dyno_until_done(dyno)
          done = false
          state = 'starting'
          console.say_trace("Starting process with command `#{dyno['command']}`")
          while !done do
            begin
              dyno = heroku.dyno.info(heroku_app_name, dyno['id'])
              if dyno['state'] != state
                console.say_trace("State changed from #{state} to #{dyno['state']}")
                state = dyno['state']
              end
              sleep 2
            rescue Excon::Errors::NotFound
              done = true
              console.say_trace("State changed from #{state} to complete")
            end
          end
        end
      end
    end
  end
end
