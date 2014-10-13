require 'shred/commands/app'
require 'shred/commands/db'
require 'shred/commands/dotenv'
require 'shred/commands/platform_deps'
require 'shred/commands/ruby_deps'
require 'shred/commands/services'
require 'shred/commands/test'
require 'thor'
require 'yaml'

module Shred
  class CLI < Thor
    def self.start(*)
      load_config
      set_up_commands
      super
    end

    def self.load_config
      @config = YAML.load(File.new('shred.yml'))
    end

    def self.set_up_commands
      if config.key?('commands')
        commands = config['commands']
        if commands.key?('platform_deps')
          desc 'platform_deps SUBCOMMAND ...ARGS', 'Manage platform dependencies'
          subcommand 'platform_deps', Commands::PlatformDeps
        end
        if commands.key?('services')
          desc 'services SUBCOMMAND ...ARGS', 'Control platform services'
          subcommand 'services', Commands::Services
        end
        if commands.key?('ruby_deps')
          desc 'ruby_deps SUBCOMMAND ...ARGS', 'Manage Ruby dependencies'
          subcommand 'ruby_deps', Commands::RubyDeps
        end
        if commands.key?('db')
          desc 'db SUBCOMMAND ...ARGS', 'Manage the database'
          subcommand 'db', Commands::Db
        end
        if commands.key?('dotenv')
          desc 'dotenv SUBCOMMAND ...ARGS', 'Manage the environmental configuration'
          subcommand 'dotenv', Commands::Dotenv
        end
        if commands.key?('test')
          desc 'test SUBCOMMAND ...ARGS', 'Run tests'
          subcommand 'test', Commands::Test
        end
        if commands.key?('app')
          desc 'app SUBCOMMAND ...ARGS', 'Control the application'
          subcommand 'app', Commands::App
        end
        if commands.key?('setup')
          desc 'setup', 'First-time application setup'
          def setup
            self.class.config['commands']['setup'].each do |cmd, subcmds|
              invoke(cmd.to_sym, subcmds.map(&:to_sym))
            end
          end
        end
      end
    end

    class << self
      attr_reader :config
    end
  end
end
