require 'dotenv'
require 'aws-sdk-v1'
require 'shred/commands/base'

module Shred
  module Commands
    class DynamoDb < Base
      desc 'mktable NAME REGION READ_UNITS WRITE_UNITS', 'Create a DynamoDB table'
      long_desc <<-LONGDESC
        Create a DynamoDB table with the given name in the given region with the given throughput capacity.

        All values are used exactly as specified. They are *not* interpolated.
      LONGDESC
      option :pk, type: :string, default: 'id'
      option :pk_type, type: :string, default: 'string'
      def mktable(name, region, read_capacity_units, write_capacity_units)
        ::Dotenv.load

        create_table(name, region, read_capacity_units.to_i, write_capacity_units.to_i,
                     hash_key: {options[:pk] => options[:pk_type]})
      end

      desc 'mktables', 'Create all configured DynamoDB tables'
      long_desc <<-LONGDESC
        Create a DynamoDB table for each element of the `commands.dynamodb.tables` config var.

        If the `commands.dynamodb.table_prefix` config var is set, its value is prepended to each table name.

        Prefixed table names and region names are interpolated.
      LONGDESC
      def mktables
        ::Dotenv.load

        prefix = cfg('table_prefix', required: false)

        cfg('tables').each do |(name, table_cfg)|
          name = "#{prefix}#{name}" if prefix
          name = interpolate_value(name)
          region = interpolate_value(table_cfg['region'])
          read_capacity_units = table_cfg['read_capacity_units'].to_i
          write_capacity_units = table_cfg['write_capacity_units'].to_i
          pk = table_cfg['primary_key'].fetch('name', 'id')
          pk_type = table_cfg['primary_key'].fetch('type', 'string')

          create_table(name, region, read_capacity_units, write_capacity_units, hash_key: {pk => pk_type})
        end
      end

      no_commands do
        def create_table(name, region, read_capacity_units, write_capacity_units, hash_key: nil)
          ddb = AWS::DynamoDB.new(region: region)
          if ddb.tables[name].exists?
            console.say_ok("Dynamo DB table #{name} already exists in region #{region}")
          else
            table = ddb.tables.create(name, read_capacity_units, write_capacity_units, hash_key)
            sleep 1 while table.status == :creating
            if table.status == :active
              console.say_ok("Created Dynamo DB table #{name} in region #{region}")
            else
              console.say_err("Failed to create Dynamo DB table #{name} in region #{region}: status #{table.status}")
            end
          end
        end
      end
    end
  end
end
