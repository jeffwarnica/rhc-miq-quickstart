#  build_vm_provision_request_code.rb

#  Original Author: Kevin Morey <kevin@redhat.com>
#  Reduced to more basic functionality by: Jeffrey Cutter <jcutter@redhat.com>
#  Converted to class format, with heavy extensions: Jeff Warnica <jwarnica@redhat.com> 2018-08-16
#
# NOTE: This file (as a CloudForms "method") is not intended to be called directly.
#       Please use build_vm_provision_request_entry. The design here is that _entry can be copied
#       to a site specific domain (its minimal code unchanged), and that can be used to embed additional "helpers"
#
#
#  Inputs: dialog_option_[0-9]_guid, dialog_option_[0-9]_flavor, dialog_tag_[0-9]_environment, etc...
#-------------------------------------------------------------------------------
#   Copyright 2016 Kevin Morey <kevin@redhat.com>
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#-------------------------------------------------------------------------------

module RhcMiqQuickstart
  module Automate
    module Service
      module Provisioning
        module StateMachines
          class BuildVmProvisionRequest
            include RedHatConsulting_Utilities::StdLib::Core

            attr_reader :handle, :template, :region, :settings, :DEBUG, :user

            def initialize(handle = $evm)
              @handle = handle
              @DEBUG = true

              @task = get_stp_task
              @service = @task.destination
              @region = @service.region_number
              @settings = RedHatConsulting_Utilities::StdLib::Core::Settings.new

            end

            # create the categories and tags
            def create_tags(category, tag, single_value = true)
              log(:info, 'Processing create_tags...', true)
              # Convert to lower case and replace all non-word characters with underscores
              category_name = category.to_s.downcase.gsub(/\W/, '_')
              tag_name = tag.to_s.downcase.gsub(/\W/, '_')

              unless @handle.execute('category_exists?', category_name)
                log(:info, "Category #{category_name} doesn't exist, creating category")
                @handle.execute('category_create', name: category_name, single_value: single_value, description: category.to_s)
              end
              # if the tag exists else create it
              unless @handle.execute('tag_exists?', category_name, tag_name)
                log(:info, "Adding new tag #{tag_name} in Category #{category_name}")
                @handle.execute('tag_create', category_name, name: tag_name, description: tag.to_s)
              end
              log(:info, 'Processing create_tags...Complete', true)
            end

            def process_tag(tag_category, tag_value)
              return if tag_value.blank?
              create_tags(tag_category, tag_value, true)
            end

            # service_tagging - tag the service with tags in tags_hash
            def tag_service(tags_hash)
              log(:info, "Processing tag_service...", true)
              tags_hash.each do |key, value|
                log(:info, "Processing tag: #{key.inspect} value: #{value.inspect}")
                tag_category = key.downcase
                Array.wrap(value).each do |tag_entry|
                  process_tag(tag_category, tag_entry.downcase)
                  log(:info, "Assigning Tag: {#{tag_category}=>#{tag_entry}} to Service: #{@service.name}")
                  @service.tag_assign("#{tag_category}/#{tag_entry}")
                end
                log(:info, "Processing tag_service...Complete", true)
              end
            end

            # fix_dialog_tags_hash to allow for support of Tag Control items in dialogs.  Previously, the Tag Control would
            # push values in as an array, which is not supported.  The fix_dialog_tag_hash parsed the dialog_tags_hash and changes
            # all array values to strings.
            def fix_dialog_tags_hash(dialog_tags_hash)
              unless dialog_tags_hash.empty?
                dialog_tags_hash.each do |build_num, build_tags_hash|
                  build_tags_hash.each do |k, v|
                    if v.is_a?(Array)
                      log(:info, "fix_dialog_tags_hash: Build #{build_num}: updating key <#{k}> with array value <#{v}> to <#{v.first}>")
                      build_tags_hash[k] = v.first if v.is_a?(Array)
                    end
                  end
                end
              end
              dialog_tags_hash
            end

            def yaml_data(option)
              @task.get_option(option).nil? ? nil : YAML.load(@task.get_option(option))
            end

            # check to ensure that dialog_parser has ran
            def parsed_dialog_information
              dialog_options_hash = yaml_data(:parsed_dialog_options)
              dialog_tags_hash = yaml_data(:parsed_dialog_tags)
              if dialog_options_hash.blank? && dialog_tags_hash.blank?
                log(:info, 'Instantiating dialog_parser to populate dialog options')
                @handle.instantiate('/Service/Provisioning/StateMachines/Methods/DialogParser')
                dialog_options_hash = yaml_data(:parsed_dialog_options)
                dialog_tags_hash = yaml_data(:parsed_dialog_tags)
                raise 'Error loading dialog options' if dialog_options_hash.blank? && dialog_tags_hash.blank?
              end
              log(:info, "dialog_options_hash: #{dialog_options_hash.inspect}")
              log(:info, "dialog_tags_hash: #{dialog_tags_hash.inspect}")
              return dialog_options_hash, fix_dialog_tags_hash(dialog_tags_hash)
            end

            def merge_service_item_dialog_values(build, dialogs_hash)
              # merged_hash = Hash.new { |h, k| h[k] = {} }
              merged_hash = if dialogs_hash[0].nil?
                              dialogs_hash[build] || {}
                            else
                              dialogs_hash[0].merge(dialogs_hash[build] || {})
                            end
              merged_hash
            end

            # merge dialog information
            def merge_dialog_information(build, dialog_options_hash, dialog_tags_hash)
              merged_options_hash = merge_service_item_dialog_values(build, dialog_options_hash)
              merged_tags_hash = merge_service_item_dialog_values(build, dialog_tags_hash)
              log(:info, "build: #{build} merged_options_hash: #{merged_options_hash.inspect}")
              log(:info, "build: #{build} merged_tags_hash: #{merged_tags_hash.inspect}")
              [merged_options_hash, merged_tags_hash]
            end

            def get_array_of_builds(dialogs_options_hash)
              builds = []
              dialogs_options_hash.each do |build, options|
                next if build.zero?
                builds << build
              end
              builds.sort
            end

            ##
            # determine who the requesting user is
            #
            # if the dialog has a user_id filed populated, we will do a lookup
            # (against both the totally useless CF integer ID and string userid),
            # and if that is a valid CF user, we will order the VMs for that user
            #
            # Also if @settings has
            #
            def get_requester(build, merged_options_hash, merged_tags_hash)
              log(:info, 'Processing get_requester...', true)
              @user = @handle.vmdb('user').find_by_id(merged_options_hash[:user_id]) ||
                @handle.vmdb('user').find_by_userid(merged_options_hash[:user_id]) ||
                @handle.root['user']
              merged_options_hash[:user_name] = @user.userid
              merged_options_hash[:owner_first_name] = @user.first_name ? @user.first_name : 'Cloud'
              merged_options_hash[:owner_last_name] = @user.last_name ? @user.last_name : 'Admin'
              merged_options_hash[:owner_email] = @user.email ? @user.email : @handle.object['to_email_address']
              log(:info, "Build: #{build} - User: #{merged_options_hash[:user_name]} " \
                  "email: #{merged_options_hash[:owner_email]}")
              # Stuff the current group information
              merged_options_hash[:group_id] = @user.current_group.id
              merged_options_hash[:group_name] = @user.current_group.description
              log(:info, "Build: #{build} - Group: #{merged_options_hash[:group_name]} " \
                  "id: #{merged_options_hash[:group_id]}")

              if (@settings.get_setting(@region, 'service_set_owner_to_user', true))
                @service.owner = @user
                @service.group = @user.current_group_id
              end

              log(:info, 'Processing get_requester...Complete', true)
            end

            # Search for a template with the priority of
            #  guid
            #  ~~~name
            #  ~~~"product"
            #  OS
            def get_template(build, merged_options_hash, merged_tags_hash)
              log(:info, 'Processing get_template...', true)

              template_search_by_guid = merged_options_hash[:guid]
              template_search_by_name = merged_options_hash[:template] || merged_options_hash[:name]
              # template_search_by_product = merged_options_hash[:product]
              template_search_by_os = merged_options_hash[:os] || merged_tags_hash[:os]

              templates = []
              templates = get_templates_by_guid(template_search_by_guid) if template_search_by_guid
              templates = get_templates_by_name(template_search_by_name) if template_search_by_name && templates.blank?
              # templates = get_templates_by_os(template_search_by_os) if template_search_by_os && templates.blank?
              templates = @handle.vmdb(:miq_template).all if templates.blank?

              log(:info, "\tFound [#{templates.size}] matching templates")

              match_chain = @settings.get_setting(:global, :template_match_methods, [])
              log(:info, "\tFollowing template match chain:[#{match_chain}]")

              match_chain.each do |method_to_call|
                method_to_call = "match_templates_by_#{method_to_call}"
                unless RhcMiqQuickstart::Automate::Service::Provisioning::StateMachines::TemplateHelpers.methods.include?(method_to_call.to_sym)
                  error("ERROR: Attempted to use method [#{method_to_call}] in template match chain, but does not exist")
                end
                m = RhcMiqQuickstart::Automate::Service::Provisioning::StateMachines::TemplateHelpers.method(method_to_call.to_sym)
                needed_signature = [[:req, :caller], [:req, :build], [:req, :templates], [:req, :merged_options_hash], [:req, :merged_tags_hash]]
                unless m.parameters == needed_signature
                  log(:info, "\tLooking for signature: #{needed_signature}")
                  log(:info, "\t...But got signature: #{m.parameters}")
                  error("ERROR: Attempted to use method [#{method_to_call}] in template match chain, but does not match required signature")
                end
                templates = m.call(self, build, templates, merged_options_hash, merged_tags_hash)
              end

              log(:info, "\tHave [#{templates.size}] templates after match processing.")
              error("Found 0 templates after filtering. Can not proceed") if templates.size.zero?

              log(:info, "\tAs we still have >1, going to select one basically randomly.") if templates.size > 1

              # Randomly select 1 template from whatever is still here.
              @template = templates.sample(1).first

              log(:info, "\tBuild: #{build} - template: #{@template.name} guid: #{@template.guid} on provider: #{@template.ext_management_system.name}")
              merged_options_hash[:name] = @template.name
              merged_options_hash[:guid] = @template.guid
              log(:info, 'Processing get_template...Complete', true)
            end

            def get_templates_by_guid(guid)
              log(:info, "Searching for templates tagged with #{@rbac_array} that " \
                  "match guid: #{guid}")
              templates = @handle.vmdb(:miq_template).all.select do |t|
                object_eligible?(t) && t.ext_management_system && t.guid == guid
              end
              if templates.empty?
                error('Unable to find a matching template. Is RBAC configured?')
              end
              templates
            end

            def get_templates_by_name(name)
              log(:info, "Searching for templates tagged with #{@rbac_array} that " \
                  "match name: #{name}")
              templates = @handle.vmdb(:miq_template).all.select do |t|
                object_eligible?(t) && t.ext_management_system && t.name == name
              end
              if templates.empty?
                error('Unable to find a matching template. Is RBAC configured?')
              end
              templates
            end

            def get_templates_by_os(os)
              os_category = 'os'
              log(:info, "Searching for templates tagged with #{@rbac_array} that " \
                  "{#{os_category.to_sym}=>#{os}}")
              templates = @handle.vmdb(:miq_template).all.select do |t|
                object_eligible?(t) && t.ext_management_system && t.tagged_with?(os_category, os)
              end
              if templates.empty?
                error('Unable to find a matching template. Is RBAC configured, and template(s) tagged correctly?')
              end
              templates
            end

            def get_provision_type(build, merged_options_hash, merged_tags_hash)
              log(:info, 'Processing get_provision_type...', true)
              case @template.vendor.downcase
              when 'vmware'
                # Valid types for vmware:  vmware, pxe, netapp_rcu
                if merged_options_hash[:provision_type].blank?
                  merged_options_hash[:provision_type] = 'vmware'
                end
              when 'redhat'
                # Valid types for rhev: iso, pxe, native_clone
                if merged_options_hash[:provision_type].blank?
                  merged_options_hash[:provision_type] = 'native_clone'
                end
              end
              if merged_options_hash[:provision_type]
                log(:info, "Build: #{build} - provision_type: #{merged_options_hash[:provision_type]}")
              end
              log(:info, 'Processing get_provision_type...Complete', true)
            end

            def get_vm_name(build, merged_options_hash, merged_tags_hash)
              log(:info, 'Procesprovision_typesing get_vm_name', true)
              new_vm_name = merged_options_hash[:vm_name] || merged_options_hash[:vm_target_name] || 'changeme'
              proposed_vm_name = nil
              if new_vm_name.include?('*')
                log(:info, 'Processing VM name prepended by *')
                raise 'vm_name cannot contain a * when provisioning multiple VMs' if merged_options_hash[:number_of_vms] > 1
                raise "vm_name #{new_vm_name} already exists." if @handle.vmdb(:vm_or_template).find_by_name(new_vm_name.gsub('*', ''))
                proposed_vm_name = new_vm_name
              else
                # Loop through 00-99 and look to see if the vm_name already exists in the vmdb to avoid collisions
                (1..100).each do |i|
                  raise "All VM names used for #{new_vm_name} 00-99" if i == 100
                  proposed_vm_name = "#{new_vm_name}#{i.to_s.rjust(2, "0")}"
                  log(:info, "Checking for existence of vm: #{proposed_vm_name}")
                  if @handle.vmdb(:vm_or_template).find_by_name(proposed_vm_name).blank?
                    proposed_vm_name = new_vm_name
                    break
                  end
                end
              end
              merged_options_hash[:vm_name] = proposed_vm_name
              merged_options_hash[:linux_host_name] = proposed_vm_name
              log(:info, "Build: #{build} - VM Name: #{merged_options_hash[:vm_name]}")
              log(:info, 'Processing get_vm_name...Complete', true)
            end

            ##
            # Sets a sane network for the VM request
            #
            # Looks up a vlan (or DVS, or whatever) name from settings.rb
            # from the key 'network_[providerType][_[tag]]', for 0..n tags, based on :network_lookup_keys
            #
            # NOTE: microsoft is special, and I don't know why.
            #
            def get_network(build, merged_options_hash, merged_tags_hash)
              log(:info, 'Processing get_network...', true)

              lookup_strategy = @settings.get_setting(:global, :network_lookup_strategy, 'simple')

              method_to_call = "network_lookup_strategy_#{lookup_strategy}"

              unless RhcMiqQuickstart::Automate::Service::Provisioning::StateMachines::VlanHelpers.methods.include?(method_to_call.to_sym)
                error("ERROR: Attempted to use network lookup strategy [#{method_to_call}], but does not exist")
              end
              m = RhcMiqQuickstart::Automate::Service::Provisioning::StateMachines::VlanHelpers.method(method_to_call.to_sym)
              needed_signature = [[:req, :caller], [:req, :merged_options_hash], [:req, :merged_tags_hash]]
              unless m.parameters == needed_signature
                log(:info, "Looking for signature: #{needed_signature}")
                log(:info, " ...But got signature: #{m.parameters}")
                error("ERROR: Attempted to use network lookup strategy [#{method_to_call}], but does not match required signature")
              end

              vlan = m.call(self, merged_options_hash, merged_tags_hash)
              ems = @template.ext_management_system

              case @template.vendor.downcase
              when 'vmware' # Nothing special
                log(:info, "\tsetting vlan to: [#{vlan}]")
                merged_options_hash[:vlan] = vlan
              when 'redhat'
                vnic_profile_id = Automation::Infrastructure::VM::RedHat::Utils.new(@template.ext_management_system).vnic_profile_id(vlan)
                log(:info, "RHV takes a vnic_profile_id => #{vnic_profile_id}") if @DEBUG
                vlan = vnic_profile_id
                log(:info, "\tsetting vlan to: [#{vlan}]")
                merged_options_hash[:vlan] = vlan
              when 'openstack'
                cloud_network = ems.cloud_networks.detect { |cn| cn.name == vlan }
                log(:info, "vlan: [#{vlan}] is id: [#{cloud_network.id}]")
                merged_options_hash[:cloud_network] = [cloud_network.id, cloud_network]
                merged_options_hash[:cloud_network_id] = cloud_network.id
              end


              # @TODO: Sanity check the vlan exists in the templates provider, at least.
              #       At least we can make sure that create_provision_request doesn't barf


              log(:info, "Build: [#{build}] - vlan: [#{merged_options_hash[:vlan]}], cloud_network: [#{merged_options_hash[:cloud_network]}]")
              log(:info, 'Processing get_network...Complete', true)
            end


            # @todo: Static flavor -> cloud flavor is lacking as a general solutions.
            #        Works well for basic hand defined tshirt sizes, but exact details of a hand
            #        defined "Size X" to multiple clouds is ... leaking abstractions all over the place
            #
            def get_flavor(build, merged_options_hash, merged_tags_hash)
              log(:info, 'Processing get_flavor...', true)

              flavors = RhcMiqQuickstart::Automate::Common::FlavorConfig::FLAVORS
              log(:info, flavors) if @DEBUG

              flavor = flavors.find { |f| f[:flavor_name] == merged_options_hash[:flavor] }
              error("Unable to locate flavor: [#{merged_options_hash[:flavor]}]") unless flavor

              log(:info, "t.v.d: [#{@template.vendor.downcase}]")
              case @template.vendor.downcase
              when 'openstack', 'amazon'; #@TODO: and whatever the other 'cloud' things are called
                log(:info, 'Dealing with cloudy template type')
                key = "cloud_#{@template.vendor.downcase}_flavor"
                cloud_flavor_name = flavor[key.to_sym]
                # @todo: sanity check if cloud_flavor exists and give nice error
                log(:info, "Trying to get cloud_flavor from key: [#{key}], which is: [#{cloud_flavor_name}]")

                cloud_flavor = @template.ext_management_system.flavors.detect { |fl| fl.name.downcase == cloud_flavor_name }
                if cloud_flavor.nil?
                  log(:warn, "Unable to match cloud_flavor [#{cloud_flavor_name}] to flavor on provider: [#{@template.ext_management_system.name}]")
                else
                  log(:info, "Setting instance_type to id: [#{cloud_flavor.id}]")
                end

                merged_options_hash[:instance_type] = cloud_flavor.id
              else

                [:number_of_sockets, :cores_per_socket, :vm_memory].each do |sym|
                  merged_options_hash[sym] = flavor[sym]
                end
              end


              if flavor.has_key?(:disks)
                log(:info, 'adding disks from flavor config')
                flavor[:disks].each do |disk|
                  log(:info, "\tMerging in disk: [#{disk.inspect}]")
                  disk.each { |k, v| merged_options_hash[k] = v }
                end
              end

              os_tag = @template.tags('os').first

              if os_tag.nil?
                error("Template [#{@template.name}] does not have an OS tag.")
              end

              os_specific_disk_key = ('disks_' + os_tag).to_sym

              if flavor.has_key?(os_specific_disk_key)
                log(:info, 'adding disks from flavor config because of OS tag')
                flavor[os_specific_disk_key].each do |disk|
                  log(:info, "\tMerging in disk: [#{disk.inspect}]")
                  disk.each { |k, v| merged_options_hash[k] = v }
                end
              end

              if @template.vendor.downcase == 'redhat'
                reserve = merged_options_hash[:vm_memory]
                log(:info, "Force setting memory_reserve for a RHV provision to same as 'vm_memory', [#{reserve}]")
                merged_options_hash[:memory_reserve] = reserve
              end

              # TODO: reimplement cloud flavor mapping
              log(:info, 'Processing get_flavor...Complete', true)
            end

            def get_retirement(build, merged_options_hash, merged_tags_hash)
              log(:info, 'Processing get_retirement...', true)

              no_retirement_groups = %w[EvmGroup-super_administrator]
              user_group = @user.current_group.description
              if no_retirement_groups.include?(user_group) # Set a default retirement here
                # note here that CloudForms has a single retirement warning date. Magic happens
                # in the retirement warning email method to reset it and thus send multiple warnings
                log(:info, "\tRequesting user is in group [#{user_group}]. Not setting retirement values")
              else
                merged_options_hash[:retirement] = @settings.get_setting(@region, :retirement, 30.days.to_i)
                merged_options_hash[:retirement_warn] = @settings.get_setting(@region, :retirement_warn, 14.days.to_i)
              end
              log(:info, "Build: #{build} - retirement: #{merged_options_hash[:retirement]}" \
        " retirement_warn: #{merged_options_hash[:retirement_warn]}")
              log(:info, 'Processing get_retirement...Complete', true)
            end

            ##
            # Tag the service with the tags of the Service Catalog itself, and also whatever
            # the dialog has in merged_tags_hash
            #
            # This ensures that RBAC visibility tags like prov_scope will tag on the generated
            # service & VMs
            #
            def copy_tags(build, merged_options_hash, merged_tags_hash)
              return if @settings.get_setting(:global, :skip_copy_rbac_tags, false)
              # tag service with all rbac filter tags (for roles with vm access restrictions set to none)
              @rbac_array.each { |rbac_hash| tag_service(rbac_hash) }

              # add all rbac filter tags to merged_tags_hash (again ensure that the miq_provision has all of our tags)
              @rbac_array.each do |rbac_hash|
                rbac_hash.each do |rbac_category, rbac_tag|
                  Array.wrap(rbac_tag).each do |rbac_tag_entry|
                    log(:info, "Assigning Tag: {#{rbac_category}=>#{rbac_tag_entry}} to build: #{build}")
                    merged_tags_hash[rbac_category.to_sym] = rbac_tag_entry
                  end
                end
              end
            end

            def get_extra_options(build, merged_options_hash, merged_tags_hash)
              log(:info, 'Processing get_extra_options...', true)
              # stuff the service guid & id so that the VMs can be added to the service later (see AddVMToService)
              merged_options_hash[:service_id] = @service.id unless @service.nil?
              merged_options_hash[:service_guid] = @service.guid unless @service.nil?
              log(:info, "Build: #{build} - service_id: #{merged_options_hash[:service_id]} " \
          "service_guid: #{merged_options_hash[:service_guid]}")
              log(:info, 'Processing get_extra_options...Complete', true)
            end

            def process_builds(dialog_options_hash, dialog_tags_hash)
              builds = get_array_of_builds(dialog_options_hash)
              log(:info, "builds: #{builds.inspect}")
              vm_prov_request_ids = []
              builds.each do |build|
                merged_options_hash, merged_tags_hash = merge_dialog_information(build, dialog_options_hash, dialog_tags_hash)

                # get requester (figure out who the requester/user is)
                get_requester(build, merged_options_hash, merged_tags_hash)

                # now that we have the requester get the users' rbac tag filters
                @rbac_array = get_current_group_rbac_array

                # get template (search for an available template)
                get_template(build, merged_options_hash, merged_tags_hash)

                # get the provision type (for vmware, rhev, msscvmm only)
                get_provision_type(build, merged_options_hash, merged_tags_hash)

                # get vm_name (either generate a vm name or use defaults)
                get_vm_name(build, merged_options_hash, merged_tags_hash)

                # get vLAN, cloud_network, security group, keypair information
                get_network(build, merged_options_hash, merged_tags_hash)

                # get cpu and memory (set the flavor)
                get_flavor(build, merged_options_hash, merged_tags_hash)

                # get retirement (set default retirement for workloads)
                get_retirement(build, merged_options_hash, merged_tags_hash)

                # get extra options ( use this section to override any options/tags that you want)
                get_extra_options(build, merged_options_hash, merged_tags_hash)

                copy_tags(build, merged_options_hash, merged_tags_hash)

                # create all specified categories/tags again just to be sure we got them all
                merged_tags_hash.each do |key, value|
                  log(:info, "Processing tag: #{key.inspect} value: #{value.inspect}")
                  tag_category = key.downcase
                  Array.wrap(value).each do |tag_entry|
                    process_tag(tag_category, tag_entry.downcase)
                  end
                end

                # log each build's tags and options
                log(:info, "Build: #{build} - merged_tags_hash: #{merged_tags_hash.inspect}")
                log(:info, "Build: #{build} - merged_options_hash: #{merged_options_hash.inspect}")

                # call build_provision_request using merged_options_hash and merged_tags_hash to send
                # the payload to miq_request and miq_provision
                request = build_provision_request(build, merged_options_hash, merged_tags_hash)
                log(:info, "Build: #{build} - VM Provision request #{request.id} for " \
            "#{merged_options_hash[:vm_name]} successfully submitted", true)
                vm_prov_request_ids << request.id
              end
              log(:info, "Setting state var :vm_prov_request_ids to #{vm_prov_request_ids.inspect}")
              @handle.set_state_var(:vm_prov_request_ids, vm_prov_request_ids)
            end

            def set_valid_provisioning_args
              # set provisioning dialog fields everything not listed below will get stuffed into :ws_values
              valid_templateFields = [:name, :request_type, :guid, :cluster]

              valid_vmFields = [:vm_name, :number_of_vms, :vm_description, :vm_prefix]
              valid_vmFields += [:number_of_sockets, :cores_per_socket, :vm_memory, :memory_reserve, :mac_address]
              valid_vmFields += [:root_password, :provision_type, :linux_host_name, :vlan, :customization_template_id]
              valid_vmFields += [:retirement, :retirement_warn, :placement_auto, :vm_auto_start]
              valid_vmFields += [:linked_clone, :network_adapters, :placement_cluster_name, :request_notes]
              valid_vmFields += [:monitoring, :floating_ip_address, :placement_availability_zone, :guest_access_key_pair]
              valid_vmFields += [:security_groups, :cloud_tenant, :cloud_network, :cloud_subnet, :instance_type]

              valid_requester_args = [:user_name, :owner_first_name, :owner_last_name, :owner_email, :auto_approve]
              [valid_templateFields, valid_vmFields, valid_requester_args]
            end

            def build_provision_request(build, merged_options_hash, merged_tags_hash)
              log(:info, 'Processing build_provision_request...', true)
              valid_templateFields, valid_vmFields, valid_requester_args = set_valid_provisioning_args

              # arg1 = version
              args = ['1.1']

              # arg2 = templateFields
              template_args = {}
              merged_options_hash.each { |k, v| template_args[k.to_s] = v.to_s if valid_templateFields.include?(k) }
              valid_templateFields.each { |k| merged_options_hash.delete(k) }
              args << template_args

              # arg3 = vmFields
              vm_args = {}
              merged_options_hash.each { |k, v| vm_args[k.to_s] = v.to_s if valid_vmFields.include?(k) }
              valid_vmFields.each { |k| merged_options_hash.delete(k) }
              args << vm_args

              # arg4 = requester
              requester_args = {}
              merged_options_hash.each { |k, v| requester_args[k.to_s] = v.to_s if valid_requester_args.include?(k) }
              valid_requester_args.each { |k| merged_options_hash.delete(k) }
              args << requester_args

              # arg5 = tags
              tag_args = {}
              merged_tags_hash.each { |k, v| tag_args[k.to_s] = v.to_s }
              args << tag_args

              # arg6 = Aditional Values (ws_values)
              # put all remaining merged_options_hash and merged_tags_hash in ws_values hash for later use in the state machine
              ws_args = {}
              merged_options_hash.each { |k, v| ws_args[k.to_s] = v.to_s }
              args << ws_args.merge(tag_args)

              # arg7 = emsCustomAttributes
              args << nil

              # arg8 = miqCustomAttributes
              args << nil

              log(:info, "Build: #{build} - Building provision request with the following arguments: #{args.inspect}")
              request = @handle.execute('create_provision_request', *args)

              # Reset the global variables for the next build
              @template = @user = nil
              log(:info, 'Processing build_provision_request...Complete', true)
              request
            end

            def main

              if @DEBUG
                @handle.root.attributes.sort.each { |k, v| log(:info, "\t Attribute: #{k} = #{v}") }
                log(:info, "Available Helper Methods:")
                log(:info, "\tVlanHelpers methods    : [#{RhcMiqQuickstart::Automate::Service::Provisioning::StateMachines::VlanHelpers.methods(false).join(",")}]")
                log(:info, "\tTemplateHelpers methods: [#{RhcMiqQuickstart::Automate::Service::Provisioning::StateMachines::TemplateHelpers.methods(false).join(",")}]")
              end


              log(:info, "Service: #{@service.name} id: #{@service.id} tasks: #{@task.miq_request_tasks.count}")

              dialog_options_hash, dialog_tags_hash = parsed_dialog_information

              tag_service(dialog_tags_hash.fetch(0, {}))

              # prepare the builds and execute them
              process_builds(dialog_options_hash, dialog_tags_hash)

            rescue => err
              log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
              @task['status'] = 'Error' if @task
              @task.finished("#{err}") if @task
              @service.remove_from_vmdb if @service
              exit MIQ_ABORT
            end
          end #class
        end
      end
    end
  end
end
