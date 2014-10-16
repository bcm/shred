require 'dotenv'
require 'aws-sdk'
require 'shred/commands/base'

module Shred
  module Commands
    class S3 < Base
      desc 'mkbucket NAME [REGION]', 'Create an S3 bucket'
      long_desc <<-LONGDESC
        Create an S3 bucket with the given name in the given region.

        The bucket and region names are used exactly as specified. They are *not* interpolated.

        If region is not specifed the bucket is created in the default S3 region.
      LONGDESC
      def mkbucket(name, region = nil)
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
          cors_cfg = bucket_cfg['cors']

          create_bucket(name, region, cors: cors_cfg)
        end
      end

      no_commands do
        def create_bucket(name, region, cors: nil)
          s3 = AWS::S3.new(region: region)
          region ||= 'default'
          bucket = s3.buckets[name]
          if bucket.exists?
            console.say_ok("S3 bucket #{name} already exists in #{region} region")
          else
            bucket = s3.buckets.create(name)
            console.say_ok("Created S3 bucket #{name} in #{region} region")
          end
          if cors
            rules = cors.map do |id, rule_cfg|
              {
                allowed_methods: Array(rule_cfg['allowed_methods']),
                allowed_origins: Array(rule_cfg['allowed_origins']),
                allowed_headers: Array(rule_cfg['allowed_headers']),
                max_age_seconds:       rule_cfg['max_age_seconds'],
                expose_headers:  Array(rule_cfg['expose_headers'])
              }
            end
            bucket.cors.set(rules)
            console.say_ok("Set CORS config for bucket #{name}")
          end
        end
      end
    end
  end
end
