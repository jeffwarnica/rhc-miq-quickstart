module RhcMiqQuickstart
  module Automate
    module Common
      class FlavorConfig
        FLAVORS = [
          { flavor_name: 'xsmall', number_of_sockets: 1, cores_per_socket: 1, vm_memory: 1024 },
          { flavor_name: 'small',  number_of_sockets: 1, cores_per_socket: 1, vm_memory: 2048 },
          { flavor_name: 'medium', number_of_sockets: 1, cores_per_socket: 2, vm_memory: 4096 },
          { flavor_name: 'large' , number_of_sockets: 1, cores_per_socket: 4, vm_memory: 8192 },
          { flavor_name: 'xlarge', number_of_sockets: 1, cores_per_socket: 8, vm_memory: 16384 }
        ].freeze
      end
    end
  end
end