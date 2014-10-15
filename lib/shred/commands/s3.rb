require 'dotenv'
require 'aws-sdk'
require 'shred/commands/base'

module Shred
  module Commands
    class S3 < Base
      desc 'mkbucket NAME REGION', 'Create an S3 bucket'
      long_desc <<-LONGDESC
        Create an S3 bucket with the given name in the given region.

        If the name is prefixed with `dotenv:` then the remaining portion of the value is interpreted as a key in the
        user's .env file whose value is the name of the bucket.

        If the region is prefixed with `dotenv:` then the remaining portion of the value is interpreted as a key in
        the user's .env file whose value is the region in which the bucket is to be created.
      LONGDESC
      def mkbucket(name, region)
        ::Dotenv.load

        if name =~ /^dotenv:(.+)$/
          name = ENV[$1] or raise "$1 not found in .env"
        end

        if region =~ /^dotenv:(.+)$/
          region = ENV[$1] or raise "$1 not found in .env"
        end

        s3 = AWS::S3.new(region: region)
        if s3.buckets[name].exists?
          console.say_ok("S3 bucket #{name} already exists in region #{region}")
        else
          s3.buckets.create(name)
          console.say_ok("Created S3 bucket #{name} in region #{region}")
        end
      end

      desc 'mkbuckets', 'Create all configured S3 buckets'
      long_desc <<-LONGDESC
        Create an S3 bucket for each element of the `commands.s3.buckets` config var.

        If a bucket name is prefixed with `dotenv:` then the remaining portion of the value is interpreted as a key in
        the user's .env file whose value is the name of the bucket.

        If a bucket region is prefixed with `dotenv:` then the remaining portion of the value is interpreted as a key
        in the user's .env file whose value is the region in which the bucket is to be created.
      LONGDESC
      def mkbuckets
        ::Dotenv.load

        cfg('buckets').each do |(key, bucket_cfg)|
          name = bucket_cfg['name']
          if name =~ /^dotenv:(.+)$/
            name = ENV[$1] or raise "$1 not found in .env"
          end

          region = bucket_cfg['region']
          if region =~ /^dotenv:(.+)$/
            region = ENV[$1] or raise "$1 not found in .env"
          end

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
