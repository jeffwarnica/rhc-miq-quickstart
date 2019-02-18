#  list_template_guids.rb
#
#  Author: Kevin Morey <kevin@redhat.com>
#          Jeff Warnica <jwarnica@redhat.com>
#
#  Description: This method builds a dialog of all tempalate guids based
#     on the RBAC filters applied to a users group.
#
# ------------------------------------------------------------------------------
#    Copyright 2016 Kevin Morey <kevin@redhat.com>
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
        class ListTemplateGuilds

          include RedHatConsulting_Utilities::StdLib::Core
          #TODO: Move to settings.rb
          DISPLAY_ON = 'provider'.freeze # 'cluster' or 'provider'

          def initialize(handle = $evm)
            @handle = handle
            @DEBUG = false
          end

          def main()
            log(:info, 'Start ' + self.class.to_s + '.' + __method__.to_s)
            @user = get_user
            @rbac_array = get_current_group_rbac_array

            dialog_hash = {}
            dump_root() if @DEBUG

            os = ''
            if @handle.root.attributes.key?('dialog_tag_0_os')
              os = @handle.root['dialog_tag_0_os']
            end

            @handle.vmdb(:miq_template).all.each do |template|

              log(:info, "checking template [#{template.name}] with tags [#{template.tags}]") if @DEBUG
              if object_eligible?(template) && template.tagged_with?("os", os)
                on = ' on ' + template.host.ems_cluster.name if DISPLAY_ON == 'cluster'
                on = ' on ' + template.ext_management_system.name if DISPLAY_ON == 'provider'
                dialog_hash[template[:guid]] = "#{template.name}#{on}"
              end

            end

            if dialog_hash.blank?
              dialog_hash[''] = "< No templates found tagged with #{@rbac_array} #{os}>"
            else
              @handle.object['default_value'] = dialog_hash.first[0]
            end

            @handle.object["values"] = dialog_hash
            log(:info, "@handle.object['values']: #{@handle.object['values'].inspect}")

          rescue => err
            log(:error, "[(#{err.class})#{err}]\n#{err.backtrace.join("\n")}")
            exit MIQ_ABORT
          ensure
            log(:info, 'Finishing ' + self.class.to_s + '.' + __method__.to_s)
          end
          
          
          private
          
          def get_user
            user_search = @handle.root['dialog_option_0_user_id'] || @handle.root['dialog_userid'] || @handle.root['dialog_evm_owner_id']
            user = @handle.vmdb('user').find_by_id(user_search) || @handle.vmdb('user').find_by_userid(user_search) ||
                @handle.root['user']
            user
          end
        end
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  RhcMiqQuickstart::Automate::Service::DynamicDialogs::ListTemplateGuilds.new.main()
end

