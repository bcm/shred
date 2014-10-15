require 'dotenv'
require 'aws-sdk'
require 'shred/commands/base'

module Shred
  module Commands
    class S3 < Base
      desc 'mkbucket NAME REGION', 'Create an S3 bucket'
      long_desc <<-LONGDESC
        Create an S3 bucket with the given name in the given region.

        The bucket and region names are used exactly as specified. They are *not* interpolated.
      LONGDESC
      def mkbucket(name, region)
        ::Dotenv.load

        create_bucket(name, region)
      end

      desc 'mkbuckets', 'Create all configured S3 buckets'
      long_desc <<-LONGDESC
        Create an S3 bucket for each element of the `commands.s3.buckets` config var.

        Bucket and region names are interpolated.
      LONGDESC
      def mkbuckets
        ::Dotenv.load

        cfg('buckets').each do |(key, bucket_cfg)|
          name = interpolate_value(bucket_cfg['name'])
          region = interpolate_value(bucket_cfg['region'])

          create_bucket(name, region)
        end
      end

      no_commands do
        def create_bucket(name, region)
          s3 = AWS::S3.new(region: region)
          if s3.buckets[name].exists?
            console.say_ok("S3 bucket #{name} already exists in region #{region}")
          else
            s3.buckets.create(name)
            console.say_ok("Created S3 bucket #{name} in region #{region}")
          end
        end
      end
    end
  end
end
