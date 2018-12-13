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
            @DEBUG = false
            @tier = @handle.root['tier']
            dump_root

            template_guid = @handle.root["dialog_option_#{@tier}_guid"]
            @template = @handle.vmdb(:vm_or_template).find_by_guid(template_guid)

            unless @template
              template_name = @handle.root["dialog_option_#{@tier}_template"]
              @template = @handle.vmdb(:vm_or_template).find_by_name(template_name)
            end
            @template_os = @template.tags('os').first
          end

          def main()
            log(:info, 'Start ' + self.class.to_s + '.' + __method__.to_s)
            flavors = RhcMiqQuickstart::Automate::Common::FlavorConfig::FLAVORS

            log(:info, flavors)

            dialog_hash = {}
            flavors.each do |flavor|
              cpu = flavor[:number_of_sockets] * flavor[:cores_per_socket]
              disks = ''
              total = 0

              if flavor.has_key?(:disks)
                flavor[:disks].each do |d|
                  d.each do |k,v|
                    if k.match(/disk_\d+_size/)
                      total += v
                    end
                  end
                end
                disks = ", #{total}GB disk"
              elsif flavor.has_key?(("disks_" + @template_os).to_sym)
                flavor[("disks_" + @template_os).to_sym].each do |d|
                  d.each do |k,v|
                    if k.match(/disk_\d+_size/)
                      total += v
                    end
                  end
                end
                disks = ", #{total}GB disk"
              end
              cost = ''
              if flavor.has_key?(:est_cost)
                cost = " est #{flavor[:est_cost]}/mo"
              end

              dialog_hash[flavor[:flavor_name]] = "#{flavor[:flavor_name]} - #{cpu} vCPUs, #{flavor[:vm_memory]} MB RAM#{disks} #{cost}"
            end

            if dialog_hash.blank?
              dialog_hash[''] = "< No flavors configured >"
            else
              @handle.object['default_value'] = dialog_hash.first[0]
            end

            @handle.object['values'] = dialog_hash
            @handle.object['sort_by'] = 'none'

            log(:info, "@handle.object['values']: #{@handle.object['values'].inspect}")

            log(:info, 'Finishing ' + self.class.to_s + '.' + __method__.to_s)
          end
        end
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  RhcMiqQuickstart::Automate::Service::DynamicDialogs::ListFlavors.new.main()
end

