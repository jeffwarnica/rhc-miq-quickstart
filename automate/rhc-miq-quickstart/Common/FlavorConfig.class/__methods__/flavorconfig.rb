module RhcMiqQuickstart
  module Automate
    module Common
      class FlavorConfig

        # reference later with
        # flavors = RhcMiqQuickstart::Automate::Common::FlavorConfig::FLAVORS
        #
        # est_cost is optional
        # cloud_flavor provides mapping to cloud flavor name.
        #
        # disks, or disks_<os tag> is an array of disk configurations for additional disks,
        # beyond what the template provides, either generically for all VMs or per OS.
        #
        # The keys are eventually migrated into what add_disks_to_vm.rb wants, so could take all those options.
        # Significantly, note that size is in GB

        FLAVORS = [
          # {flavor_name: 'xsmall', number_of_sockets: 1, cores_per_socket: 1, vm_memory: 1024},
          { flavor_name: 'small',  cloud_flavor: 'm1.mini',   est_cost: '$37/mo',  number_of_sockets: 1, cores_per_socket: 1, vm_memory: 1024, disks: [{ disk_1_size: 25 }] },
          { flavor_name: 'medium', cloud_flavor: 'm1.medium', est_cost: '$59/mo',  number_of_sockets: 1, cores_per_socket: 2, vm_memory: 2048, disks_windows: [{ disk_1_size: 50 }], disks_linux: [{ disk_1_size: 50 }] },
          { flavor_name: 'large',  cloud_flavor: 'm1.large',  est_cost: '$105/mo', number_of_sockets: 1, cores_per_socket: 4, vm_memory: 4096, disks_windows: [{ disk_1_size: 100 }], disks_linux: [{ disk_1_size: 100 }] },
          { flavor_name: 'xlarge', cloud_flavor: 'm1.xlarge', est_cost: '$95/mo',  number_of_sockets: 1, cores_per_socket: 8, vm_memory: 8192, disks_windows: [{ disk_1_size: 200 }], disks_linux: [{ disk_1_size: 200 }] },
        ].freeze
      end
    end
  end
end