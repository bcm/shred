require 'shred/commands/base'

module Shred
  module Commands
    class PlatformDeps < Base
      attr_reader :supported_dependencies

      class Dependency
        attr_reader :sym

        def initialize(sym: nil)
          @sym = sym
        end

        def install(ctx, command_lines)
          ctx.run_shell_command(ShellCommand.new(
            command_lines: command_lines,
            success_msg: "#{sym} installed",
            error_msg: "#{sym} could not be installed"
          ))
        end

        def update(ctx, command_lines)
          ctx.run_shell_command(ShellCommand.new(
            command_lines: command_lines,
            success_msg: "#{sym} updated",
            error_msg: "#{sym} could not be updated"
          ))
        end
      end

      class HomebrewDependency < Dependency
        def install(ctx)
          super(ctx, "brew install #{sym}")
        end

        def update(ctx)
          super(ctx, "brew upgrade #{sym}")
        end
      end

      class RubyGemDependency < Dependency
        def install(ctx)
          super(ctx, "gem install #{sym}")
        end

        def update(ctx)
          super(ctx, "gem update #{sym}")
        end
      end

      class ShellCommandDependency < Dependency
        attr_reader :install_command_lines, :update_command_lines

        def initialize(sym: nil, install_command_lines: nil, update_command_lines: nil)
          super(sym: sym)
          @install_command_lines = install_command_lines
          @update_command_lines = update_command_lines
        end

        def install(ctx)
          super(ctx, install_command_lines)
        end

        def update(ctx)
          super(ctx, update_command_lines)
        end
      end

      desc 'install [dependencies...]', 'Install some or all platform dependencies'
      long_desc <<-LONGDESC
        Installs platform dependencies that the application depends on.

        When no dependencies are specified, all dependencies are installed.

        When one or more dependencies are specified, only those dependencies are installed.
      LONGDESC
      def install(*dependencies)
        invoke_for_dependencies(:install, *dependencies)
      end

      desc 'update [dependencies...]', 'Install some or all platform dependencies'
      long_desc <<-LONGDESC
        Updates platform dependencies that the application depends on.

        When no dependencies are specified, all dependencies are updated.

        When one or more dependencies are specified, only those dependencies are updated.
      LONGDESC
      def update(*dependencies)
        invoke_for_dependencies(:update, *dependencies)
      end

      no_commands do
        def configure
          @supported_dependencies = command_config.each_with_object([]) do |(type, specs), m|
            case type.to_sym
            when :homebrew
              specs.each_with_object(m) { |svc, mm| mm << HomebrewDependency.new(sym: svc.to_sym) }
            when :rubygems
              specs.each_with_object(m) { |svc, mm| mm << RubyGemDependency.new(sym: svc.to_sym) }
            when :shell
              specs.each_with_object(m) do |(svc, keys), mm|
                install = keys['install'] or
                  raise "Missing 'install' config for '#{svc}' platform dependency"
                update = keys['update'] or
                  raise "Missing 'update' config for '#{svc}' platform dependency"
                mm << ShellCommandDependency.new(
                  sym: svc.to_sym,
                  install_command_lines: install,
                  update_command_lines: update
                )
              end
            else raise "Unknown platform dependency type #{type}"
            end
          end
        end

        def invoke_for_dependencies(meth, *dependencies)
          dependencies = supported_dependencies.map { |d| d.sym.to_s} if dependencies.empty?
          dependencies.each do |dependency|
            dependency = supported_dependencies.detect { |d| d.sym.to_s == dependency }
            if dependency
              dependency.send(meth, self)
            else
              say_err("No such dependency #{dependency}")
            end
          end
        end
      end
    end
  end
end
