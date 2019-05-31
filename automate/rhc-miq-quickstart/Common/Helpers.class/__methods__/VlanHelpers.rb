#HERE BE DEEP MAGIC
# Helper methods, optionally used for different filtering tasks
#
# Note that these are "Module Methods", and they must exist in their respective modules
# to be found and used.
#
# From configuration to core code, these methods are found by convention; there is no registry or anything.
#
# You can extend the functionality by creating a MIQ "method" which defines additional ruby module methods,
# and have the MIQ "method" embed this, stock, build_vm_provision_request; DO NOT ACTUALLY COPY THIS FILE!
#
# In your local build_vm_provision_request, which then becomes the provisioning entry point,
# define only the new helpers methods in the appropriate namespace, matching their names and arguments
# according to the obvious pattern. Note the use of the *self.* prefix
#
#
# Ensure your new file still executes BuildVmProvisionRequest.new.main()
module RhcMiqQuickstart
  module Automate
    module Service
      module Provisioning
        module StateMachines
          module VlanHelpers


            # VLAN Lookup Strategies

            def self.network_lookup_strategy_simple(caller, merged_options_hash, merged_tags_hash)
              @handle = caller.handle
              @handle.log(:info, 'Processing network_lookup_strategy_simple...')
              caller.settings.get_setting(:global, :network_lookup_simple, {})
            end

            def self.network_lookup_strategy_manualbytag(caller, merged_options_hash, merged_tags_hash)
              @handle = caller.handle
              @handle.log(:info, 'Processing network_lookup_strategy_manualbytag...')

              lookup_extra_keys = caller.settings.get_setting(:global, :network_lookup_manualbytags_keys, {})
              lookup_key = 'network_lookup_manualbytags_lookup'
              lookup_extra_keys.each do |k|
                tag_val = case k
                          when '@vendor'
                            caller.template.vendor.downcase
                          when '@ems'
                            caller.template.ext_management_system.name.gsub(/\W/, "_").downcase
                          else
                            merged_tags_hash[k.to_sym]
                          end
                @handle.log(:info, "adding key from [#{k}] which is [#{tag_val}]")
                lookup_key += "_#{tag_val}"
              end
              lookup_key = lookup_key.to_sym

              @handle.log(:info, "Searching for vlan name with key [#{lookup_key}]")

              begin
                vlan = caller.settings.get_setting(caller.region, lookup_key)
              rescue => err
                @handle.log(:info, "ERROR was [#{err}]")
                error("Generated lookup key [#{lookup_key}] was unable to find a VLAN name")
              end
            end
          end #VlanHelpers
        end
      end
    end
  end
end

