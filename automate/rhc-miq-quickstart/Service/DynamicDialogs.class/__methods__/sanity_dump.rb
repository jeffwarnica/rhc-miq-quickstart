#  sanity_dump.rb
#
#  Author: Jeff Warnica <jwarnica@redhat.com>
#
#  Description: Method to sanity check an install, including printing out the parsed/combined settings hash, e.g. for putting in a dynamic element of a service catalog
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
        class SanityDump

          include RedHatConsulting_Utilities::StdLib::Core

          def initialize(handle = $evm)
            @handle = handle
            @DEBUG = true
          end

          def main()
            log(:info, 'Start ' + self.class.to_s + '.' + __method__.to_s)


            flavors = RhcMiqQuickstart::Automate::Common::FlavorConfig::FLAVORS
            settings = RedHatConsulting_Utilities::StdLib::Core::Settings.new()

            value = "*** RUNTIME CONFIGURATION ***\n"
            value += "*** FLAVORS:\n" + flavors.to_s + "\n\n"
            value += "*** SETTINGS:\n" + settings.get_effective_settings.to_s + "\n\n"

            value += "*** Sanity Checking Providers ***\n\n"

            @handle.vmdb(:ems).all.each do |provider|
              value += "Provider: [#{provider.name}] is a [#{provider.type}]"
              case provider.type
              when 'ManageIQ::Providers::Redhat::InfraManager'
                value += "\n"
                value += "\tHosts:      >0 tagged? [" + (provider.hosts.any? { |h| h.tags.size > 0 } ? 'yes' : 'no - ERROR') + "]\n"
                value += "\tDatastores: >0 tagged? [" + (provider.storages.any? { |s| s.tags.size > 0 } ? 'yes' : 'no - ERROR') + "]\n"
                value += "\tCluster:    >0 tagged? [" + (provider.ems_clusters.any? { |s| s.tags.size > 0 } ? 'yes' : 'no - ERROR - RHV needs tagged clusters') + "]\n"
                value += "\t" + getTemplateTagsForProvider(provider) + "\n"
              when 'ManageIQ::Providers::Vmware::InfraManager'
                value += "\n"
                value += "\tHosts:      >0 tagged? [" + (provider.hosts.any? { |h| h.tags.size > 0 } ? 'yes' : 'no - ERROR') + "]\n"
                value += "\tDatastores: >0 tagged? [" + (provider.storages.any? { |s| s.tags.size > 0 } ? 'yes' : 'no - ERROR') + "]\n"
                value += "\tCluster:    >0 tagged? [" + (provider.ems_clusters.any? { |s| s.tags.size > 0 } ? 'yes' : 'no - WARNING - If DRS, tags needed') + "]\n"
                value += "\t" + getTemplateTagsForProvider(provider) + "\n"
              else
                value += "\tNo sanity check implemented"
              end
              value += "\n"
            end



            @handle.object['value'] = value

            log(:info, "@handle.object['value']: #{@handle.object['valuee'].inspect}")

            log(:info, 'Finishing ' + self.class.to_s + '.' + __method__.to_s)
          end

          def getTemplateTagsForProvider(ext_management_system)
            desired_tags = %w(os prov_scope env)
            dt_results = {}
            @handle.vmdb(:vm_or_template).where(template: true, ext_management_system: ext_management_system.id).each do |tmpl|
              desired_tags.each do |dt|
                if tmpl.tags(dt).size> 0
                  dt_results[dt] = 0 if dt_results[dt].nil?
                  dt_results[dt] += 1
                end
              end
            end
            msg = "Template tagging "
            desired_tags.each do |dt|
              msg += "with #{dt}: [#{dt_results[dt]}] "
            end

            return msg

          end

        end
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  RhcMiqQuickstart::Automate::Service::DynamicDialogs::SanityDump.new.main()
end

