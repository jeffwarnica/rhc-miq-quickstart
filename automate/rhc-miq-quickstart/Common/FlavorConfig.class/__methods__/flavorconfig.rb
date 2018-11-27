module RhcMiqQuickstart
  module Automate
    module Common
      class FlavorConfig

        # reference later with
        # flavors = RhcMiqQuickstart::Automate::Common::FlavorConfig::FLAVORS
        #
        # disks is an array of disk configurations for additional disks (beyond what the template provides)
        # the keys are eventually migrated into what add_disks_to_vm.rb wants, so could take all those options.
        # Significantly, note that size is in GB

        FLAVORS = [
            # {flavor_name: 'xsmall', number_of_sockets: 1, cores_per_socket: 1, vm_memory: 1024},
            {flavor_name: 'small', number_of_sockets: 1, cores_per_socket: 1, vm_memory: 1024, disks_windows: [{disk_1_size: 25}], disks_linux: [{disk_1_size: 25}]},
            {flavor_name: 'medium', number_of_sockets: 1, cores_per_socket: 2, vm_memory: 2048, disks_windows: [{disk_1_size: 50}],disks_linux: [{disk_1_size: 50}]},
            {flavor_name: 'large', number_of_sockets: 1, cores_per_socket: 4, vm_memory: 4096, disks_windows: [{disk_1_size: 100}],disks_linux: [{disk_1_size: 100}]},
            {flavor_name: 'xlarge', number_of_sockets: 1, cores_per_socket: 8, vm_memory: 8192, disks_windows: [{disk_1_size: 200}],disks_linux: [{disk_1_size: 200}]},
        ].freeze
      end
    end
  end
end