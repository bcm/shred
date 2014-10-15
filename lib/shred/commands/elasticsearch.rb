require 'dotenv'
require 'elasticsearch'
require 'shred/commands/base'

module Shred
  module Commands
    class Elasticsearch < Base
      desc 'mkindex NAME', 'Create a search index'
      long_desc <<-LONGDESC
        Create the search index with the given name.

        If the `commands.elasticsearch.indexes.<name>.create` config var is present, it is taken to specify a list
        of shell commands to be used to create the index. This mode supports creating indices with custom mappings
        or settings.

        The index name is used exactly as specified; it is *not* interpolated. However, the shell commands *are*
        interpolated.
      LONGDESC
      def mkindex(name)
        ::Dotenv.load
        create_index(name, cfg("indexes.#{name}", required: false))
      end

      desc 'mkindices', 'Create all configured search indexes'
      long_desc <<-LONGDESC
        Creates each search index listed for the `commands.elasticsearch.indexes` config var.

        If the `commands.elasticsearch.indexes.<name>.create` config var is present, it is taken to specify a list
        of shell commands to be used to create the index. This mode supports creating indices with custom mappings
        or settings.

        Each index name and shell command is interpolated.
      LONGDESC
      def mkindices
        ::Dotenv.load
        Array(cfg('indexes')).each do |name, index_cfg|
          create_index(name, index_cfg)
        end
      end

      desc 'rmindex NAME', 'Delete a search index'
      long_desc <<-LONGDESC
        Delete the search index with the given name.

        The index name is used exactly as specified; it is *not* interpolated.
      LONGDESC
      def rmindex(name)
        ::Dotenv.load
        delete_index(name)
      end

      desc 'rmindices', 'Delete all configured search indexes'
      long_desc <<-LONGDESC
        Deletes each search index listed for the `commands.elasticsearch.indexes` config var.

        Each index name is interpolated.
      LONGDESC
      def rmindices
        ::Dotenv.load
        Array(cfg('indexes').keys).each do |name|
          delete_index(name)
        end
      end

      desc 'import NAME', 'Import data into a search index'
      long_desc <<-LONGDESC
        Imports data into the search index with the given name.

        Executes one or more shell commands taken from the `commands.elasticsearch.indexes.<name>.import` config var.

        The index name is used exactly as specified; it is *not* interpolated. However, the shell commands *are*
        interpolated.
      LONGDESC
      def import(name)
        ::Dotenv.load
        command_lines = Array(cfg("indexes.#{name}.import")).map { |l| interpolate_value(l) }
        run_shell_command(ShellCommand.new(
          command_lines: command_lines,
          success_msg: "Data imported into index #{name}",
          error_msg: "Failed to import data into index #{name}"
        ))
      end

      no_commands do
        def client
          url = interpolate_value(cfg('url'))
          @client ||= ::Elasticsearch::Client.new(url: url)
        end

        def create_index(name, index_cfg = nil)
          if index_cfg && index_cfg['create']
            command_lines = Array(index_cfg['create']).map { |l| interpolate_value(l) }
            run_shell_command(ShellCommand.new(
              command_lines: command_lines,
              success_msg: "Created index #{name}",
              error_msg: "Failed to create index #{name}"
            ))
          else
            begin
              client.indices.create(index: name)
              console.say_ok("Created index #{name}")
            rescue ::Elasticsearch::Transport::Transport::Errors::BadRequest => e
              raise unless e.to_s =~ /IndexAlreadyExistsException/
              console.say_err("Index #{name} already exists")
            end
          end
        end

        def delete_index(name)
          client.indices.delete(index: name)
          console.say_ok("Deleted index #{name}")
        rescue ::Elasticsearch::Transport::Transport::Errors::NotFound => e
          raise unless e.to_s =~ /IndexMissingException/
          console.say_err("Index #{name} does not exist")
        end
      end
    end
  end
end
