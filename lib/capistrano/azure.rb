require "capistrano/azure/version"
require "capistrano/azure/deploy"

module Capistrano
  module Azure

    class << self
      attr_accessor :configuration
    end

    def self.configure
      self.configuration ||= Configuration.new
      yield(configuration)
    end

    class Configuration
      attr_accessor :subscription_id, :management_endpoint, :azure_pem, :azure_pem_file_path

      def initialize
        @subscription_id      = nil
        @azure_pem            = nil
        @azure_pem_file_path  = nil
        @management_endpoint  = 'https://management.core.windows.net'
      end
    end
  end
end
