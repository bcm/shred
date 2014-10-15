require 'dotenv'
require 'aws-sdk'
require 'shred/commands/base'

module Shred
  module Commands
    class S3 < Base
      desc 'mkbucket', 'Create an S3 bucket'
      long_desc <<-LONGDESC
        Create an S3 bucket.

        The bucket is created in the region identified by the `region` option or by
        the `commands.s3.bucket.region` config var. If the value of the option or config
        var is prefixed with `dotenv:` then the remaining portion of the value is
        interpreted as a key in the user's .env file whose value is the region in which
        the bucket is to be created.

        The bucket's name is specified by the `name` option or by the
        `commands.s3.bucket.name` config var. If the value of the option or config var is
        prefixed with `dotenv:` then the remaining portion of the value is interpreted
        as a key in the user's .env file whose value is the name of the bucket.
      LONGDESC
      option :name
      option :region
      def mkbucket
        ::Dotenv.load

        region = options[:region] || cfg('bucket.region')
        if region =~ /^dotenv:(.+)$/
          region = ENV[$1] or raise "$1 not found in .env"
        end

        name = options[:name] || cfg('bucket.name')
        if name =~ /^dotenv:(.+)$/
          name = ENV[$1] or raise "$1 not found in .env"
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
