require 'azure'

module Capistrano
  module Azure
    class Deploy
      def initialize(cloud_service_name)

        @cloud_service_name = cloud_service_name

        if Capistrano::Azure.configuration.azure_pem.present?

          pem_file = File.join(File.expand_path(File.dirname(__FILE__)), '/', 'azure_deploy.pem')
          File.open(pem_file, 'w') do |f|
            f.write Capistrano::Azure.configuration.azure_pem
          end
        elsif Capistrano::Azure.configuration.azure_pem_file_path.present?
          pem_file = File.join(Capistrano::Azure.configuration.azure_pem_file_path)
        else
            pem_file = File.join(File.expand_path('config/deploy'), '/', 'azure_deploy.pem')
        end

        ::Azure.configure do |config|
          config.management_certificate = pem_file
          config.subscription_id        = Capistrano::Azure.configuration.subscription_id
          config.management_endpoint    = Capistrano::Azure.configuration.management_endpoint
        end

      end

      def get_deployable_servers
        deployable_servers = []

        vm_service = ::Azure::VirtualMachineManagementService.new
        servers = vm_service.list_virtual_machines(@cloud_service_name)

        servers.each do |s|
          puts "#{s.vm_name} is #{s.status}"

          public_ssh_port = s.tcp_endpoints.select{ |end_point|  end_point[:local_port] == '22' }.to_a.first.fetch(:public_port)

          if s.status == 'ReadyRole'
            if public_ssh_port
              cap_server_uri =  "#{@cloud_service_name}.cloudapp.net:#{public_ssh_port}"
              puts "#{cap_server_uri} can be deployable"

              deployable_servers << { host_name:          "#{s.cloud_service_name}.cloudapp.net",
                                      cloud_service_name: s.cloud_service_name,
                                      port:               public_ssh_port,
                                      vm_name:            s.vm_name,
                                      ipaddress:          s.ipaddress,
                                      hostname:           s.hostname,
                                      deployment_name:    s.deployment_name,
                                      disk_name:          s.disk_name }
            else
              puts "#{s.vm_name} has no public ssh ports for capistrano to deploy."
            end
          else
            puts "#{s.vm_name} is not deployable."
          end
        end
        deployable_servers
      end

      def generate_ssh_config(server_name_format = '%{hostname}.%{cloud_service_name}.cloudapp.net')
        check_ssh_config_file

        File.open('.ssh/config', 'w') do |f|
          get_servers.each do |s|
            host = server_name_format % s
            f.puts "Host #{host}"
            f.puts "  HostName #{ s[:host_name] }"
            f.puts "  Port #{ s[:port] }"
            f.puts ''
          end
        end
      end

      # roles: Array like %w(app)
      # user: String like deployer
      # server_name_format: like %{hostname}.%{cloud_service_name}.cloudapp.net
      #   available_params: cloud_service_name, port, vm_name, ipaddress, hostname

      def generate_capistrano_servers(roles, server_name_format, user = 'deployer', ssh_config = true)

        fail 'Needed roles' unless roles
        fail 'Needed server_name_format' unless server_name_format
        fail 'Needed user' unless user

        generate_ssh_config(server_name_format) if ssh_config

        get_servers.each do |s|
          server server_name_format % s, user: user, roles: roles
        end
      end

      private

      def check_ssh_config_file
        require 'fileutils'

        FileUtils.mkdir_p '.ssh'
        File.new('.ssh/config', 'w')
      end
    end
  end
end