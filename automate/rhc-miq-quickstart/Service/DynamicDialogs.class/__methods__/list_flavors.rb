#  list_flavors.rb
#
#  Author: Jeff Warnica <jwarnica@redhat.com>
#
#  Description: Method to build a drop down of the flavors configured in flavours.rb
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

            dialog_hash = {}

            # We either have a dialog that has a template (selected or hardcoded, we don't know or care)
            # If so, we use the OS from that template
            if @handle.root["dialog_option_#{@tier}_guid"] || @handle.root['dialog_option_0_guid'] ||
               @handle.root["dialog_option_#{@tier}_template"] || @handle.root['dialog_option_0_template']

              @handle.log(:info, 'Detected dialog with selected template. Attempting to list relevant flavors')

              if @handle.root["dialog_option_#{@tier}_guid"] || @handle.root['dialog_option_0_guid']
                # We are looking for a template, first by guid from our tier, or the service
                template_guid = @handle.root["dialog_option_#{@tier}_guid"] || @handle.root["dialog_option_0_guid"]
                @template = @handle.vmdb(:vm_or_template).where(guid: template_guid).first
              else
                template_name = @handle.root["dialog_option_#{@tier}_template"] || @handle.root["dialog_option_0_template"]
                #very stupid logic. Kinda intentional
                templates = @handle.vmdb(:vm_or_template).where(name: template_name)
                templates = templates.select do |t|
                  t.tagged_with?('prov_scope', 'all')
                end
                @template = templates.first
              end


              if @template.nil?
                dialog_hash[''] = "< No template selected >"
                default_value = dialog_hash.first[0]
              else

                @template_os = @template.tags('os').first || ''
                log(:info, "Interrogating template: [#{@template.name}], guid: [#{@template.guid}]")

                if @template.tags('os').size == 0 || @template.tags('prov_scope').size == 0
                  log(:info, "OS tag size: [#{@template.tags('os').size}], prov_scope tag size: [#{@template.tags('prov_scope').size}]")
                  msg = "Template '#{@template.name}' found, but improperly tagged"
                  dialog_hash[''] = "< #{msg} >"
                  default_value = dialog_hash.first[0]
                else
                  dialog_hash, default_value = getDialogValues(@template_os)
                end

              end

            elsif @handle.root["dialog_option_#{@tier}_os"] || @handle.root['dialog_option_0_os'] ||
                  @handle.root["dialog_tag_#{@tier}_os"] || @handle.root['dialog_tag_0_os']
              os = @handle.root['dialog_tag_0_os'] || @handle.root["dialog_tag_#{@tier}_os"] ||
                   @handle.root['dialog_option_0_os'] || @handle.root["dialog_option_#{@tier}_os"]
              @handle.log(:info, 'Detected dialog with OS selected. Attempting to list relevant flavors')
              dialog_hash, default_value = getDialogValues(os)
            else
              @handle.log(:info, 'Dialog has nether template name/guid, or an OS tag. Womp womp')
              dialog_hash[''] = "< Unable to find template or os in dialog >"
              default_value = dialog_hash.first[0]
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

          def getDialogValues(os)
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
              elsif flavor.has_key?(("disks_" + os).to_sym)
                flavor[("disks_" + os).to_sym].each do |d|
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

