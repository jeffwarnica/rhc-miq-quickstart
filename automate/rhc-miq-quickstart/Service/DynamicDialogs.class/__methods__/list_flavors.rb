#  list_flavors.rb
#
#  Author: Jeff Warnica <jwarnica@redhat.com>
#
#  Description: Method to build a drop down of the flavors configured in
#
# ------------------------------------------------------------------------------
#    Copyright 2018 Jeff Warnica <jwarnica@redhat.com>
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
# ------------------------------------------------------------------------------

module RhcMiqQuickstart
  module Automate
    module Service
      module DynamicDialogs
        class ListFlavors

          include RedHatConsulting_Utilities::StdLib::Core

          def initialize(handle = $evm)
            @handle = handle
            @DEBUG = true
            @tier = @handle.root['tier']
            dump_root() if @DEBUG

          end

          def main()
            log(:info, 'Start ' + self.class.to_s + '.' + __method__.to_s)

            # We are looking for a template, first by guid from our tier, or the service
            template_guid = @handle.root["dialog_option_#{@tier}_guid"] || @handle.root["dialog_option_0_guid"]
            @template = @handle.vmdb(:vm_or_template).where(guid: template_guid).first

            # ... and if no guid, by name from our tier, or the service
            unless @template
              template_name = @handle.root["dialog_option_#{@tier}_template"] || @handle.root["dialog_option_0_template"]

              #very stupid logic. Kinda intentional
              templates = @handle.vmdb(:vm_or_template).where(name: template_name)
              templates = templates.select do |t|
                t.tagged_with?('prov_scope', 'all')
              end
              @template = templates.first
            end
            @template_os = @template.tags('os').first || ''


            log(:info, "Interrogating template: [#{@template.name}], guid: [#{@template.guid}]")

            if @template.tags('os').size == 0 || @template.tags('prov_scope').size == 0
              dialog_hash = {}
              log(:info, "OS tag size: [#{@template.tags('os').size}], prov_scope tag size: [#{@template.tags('prov_scope').size}]")
              msg = "Template '#{@template.name}' found, but improperly tagged"
              dialog_hash[''] = "< #{msg} >"
              default_value = dialog_hash.first[0]
            else
              dialog_hash, default_value = getDialogValues()
            end


            @handle.object['default_value'] = default_value
            @handle.object['values'] = dialog_hash
            @handle.object['sort_by'] = 'none'

            log(:info, "@handle.object['values']: #{@handle.object['values'].inspect}")

            log(:info, 'Finishing ' + self.class.to_s + '.' + __method__.to_s)
          end

          #bad form to duplicate this code (runninng it at all, let alone copy/paste )
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

          def getDialogValues()
            flavors = RhcMiqQuickstart::Automate::Common::FlavorConfig::FLAVORS

            log(:info, flavors) if @DEBUG

            dialog_hash = {}
            flavors.each do |flavor|
              cpu = flavor[:number_of_sockets] * flavor[:cores_per_socket]
              disks = ''
              total = 0

              if flavor.has_key?(:disks)
                flavor[:disks].each do |d|
                  d.each do |k, v|
                    if k.match(/disk_\d+_size/)
                      total += v
                    end
                  end
                end
                disks = ", #{total}GB disk"
              elsif flavor.has_key?(("disks_" + @template_os).to_sym)
                flavor[("disks_" + @template_os).to_sym].each do |d|
                  d.each do |k, v|
                    if k.match(/disk_\d+_size/)
                      total += v
                    end
                  end
                end
                disks = ", #{total}GB disk"
              end
              cost = ''
              if flavor.has_key?(:est_cost)
                cost = " est #{flavor[:est_cost]}"
              end

              dialog_hash[flavor[:flavor_name]] = "#{flavor[:flavor_name]} - #{cpu} vCPUs, #{flavor[:vm_memory]} MB RAM#{disks} #{cost}"
            end

            if dialog_hash.blank?
              dialog_hash[''] = "< No flavors configured >"
            end
            default_value = dialog_hash.first[0]
            return dialog_hash, default_value
          end
        end
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  RhcMiqQuickstart::Automate::Service::DynamicDialogs::ListFlavors.new.main()
end

