#  list_template_guids.rb
#
#  Author: Jeff Warnica <jwarnica@redhat.com>
#  Loosely inspired by the works of Kevin Morey <kevin@redhat.com>
#
#  Description: This method builds a dialog of template GUIDs based
#     on the configuration in Settings.rb, RBAC, and settings in the Dialog
#
#
# ------------------------------------------------------------------------------
#    Copyright 2019 Jeff Warnica <jwarnica@redhat.com>
#              2016 Kevin Morey <kevin@redhat.com>
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

require 'deep_merge'

module RhcMiqQuickstart
  module Automate
    module Service
      module DynamicDialogs
        class ListTemplateGuilds

          include RedHatConsulting_Utilities::StdLib::Core

          #Allows read access to these attributes by the helper methods
          attr_reader :handle, :settings, :region

          def initialize(handle = $evm)
            @settings = RedHatConsulting_Utilities::StdLib::Core::Settings.new()
            @display_on = @settings.get_setting(:global, :list_templates_show, 'provider').freeze
            @handle = handle
            @tier = @handle.root['tier'].to_i
            @region = @handle.root['miq_server'].region_number
            @DEBUG = true
          end

          def main()
            log(:info, 'Start ' + self.class.to_s + '.' + __method__.to_s)

            options_hash, tags_hash = parse_dialog_entries(@handle.root.attributes)

            merged_options_hash = merge_service_item_dialog_values(@tier, options_hash)
            merged_tags_hash = merge_service_item_dialog_values(@tier, tags_hash)

            if @DEBUG
              @handle.log(:info, "options_hash: [#{options_hash}]")
              @handle.log(:info, "tags_hash: [#{tags_hash}]")

              @handle.log(:info, "merged_options_hash: [#{merged_options_hash}]")
              @handle.log(:info, "merged_tags_hash: [#{merged_tags_hash}]")
            end

            # potential_templates_old = getOldWay(options_hash, tags_hash)
            potential_templates_new = getNewWay(merged_options_hash, merged_tags_hash)

            # log(:info, "OldWayResults: [#{potential_templates_old.map{|t| t.name}}]")
            log(:info, "NewWayResults: [#{potential_templates_new.map{|t| t.name}}]")

            potential_templates = potential_templates_new

            dialog_hash = {}
            dump_root() if @DEBUG

            potential_templates.each do |template|

              on = ' on ' + template.host.ems_cluster.name if @display_on == 'cluster'
              on = ' on ' + template.ext_management_system.name if @display_on == 'provider'
              dialog_hash[template[:guid]] = "#{template.name}#{on}"

            end

            if dialog_hash.blank?
              log(:info, "No templates found tagged with RBAC: [#{@rbac_array}] and dialog tags: [#{merged_tags_hash}]")
              dialog_hash[''] = "< No templates found suitably tagged >"
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

          def getOldWay(options_hash, tags_hash)
            @user = get_user
            @rbac_array = get_current_group_rbac_array

            log(:info, "@rbac_array: [#{@rbac_array}]") if @DEBUG

            this_tier_filter = {}
            filter_array = []
            this_tier_filter.deep_merge!(tags_hash[0])
            this_tier_filter.deep_merge!(tags_hash[@tier.to_i])
            this_tier_filter.each { |c, v| filter_array << { c => [v, '_any_'] } }

            @handle.log(:info, "this_tier_filter: [#{this_tier_filter}]") if @DEBUG
            @handle.log(:info, "filter_array: [#{filter_array}]") if @DEBUG

            potential_templates = []
            @handle.vmdb(:miq_template).all.each do |template|

              log(:info, "checking template [#{template.name}] with tags [#{template.tags}]") if @DEBUG

              # RBAC first
              next unless object_eligible?(template) #|| @user.current_group.description == 'EvmGroup-super_administrator'
              next unless object_matches_any_tag_filter?(template, filter_array)

              potential_templates << template
            end

          end

          #Similar logic to get_template from BVmPr
          def getNewWay(merged_options_hash, merged_tags_hash)
            log(:info, 'Processing get_template...', true)

            # template_search_by_guid = merged_options_hash[:guid]
            # template_search_by_name = merged_options_hash[:template] || merged_options_hash[:name]
            # # template_search_by_product = merged_options_hash[:product]
            # template_search_by_os = merged_options_hash[:os] || merged_tags_hash[:os]
            #
            # templates = []
            # templates = get_templates_by_guid(template_search_by_guid) if template_search_by_guid
            # templates = get_templates_by_name(template_search_by_name) if template_search_by_name && templates.blank?
            # # templates = get_templates_by_os(template_search_by_os) if template_search_by_os && templates.blank?
            templates = @handle.vmdb(:miq_template).all

            log(:info, "\tFound [#{templates.size}] templates in vmdb")

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
              templates = m.call(self, nil, templates, merged_options_hash, merged_tags_hash)
            end

            return templates
          end



          def get_user
            user_search = @handle.root['dialog_option_0_user_id'] || @handle.root['dialog_userid'] || @handle.root['dialog_evm_owner_id']
            user = @handle.vmdb('user').find_by_id(user_search) || @handle.vmdb('user').find_by_userid(user_search) ||
              @handle.root['user']
            user
          end


          def add_hash_value(sequence_id, option_key, value, hash)
            @handle.log("info", "Adding seq_id: #{sequence_id} key: #{option_key} value: #{value} ")
            hash[sequence_id][option_key] = value
          end

          def process_comma_separated_object_array(sequence_id, option_key, value, hash)
            return if value.nil?
            options_value_array = []
            value.split(",").each do |entry|
              next if entry.blank?
              vmdb_obj = vmdb_object_from_array_entry(entry)
              options_value_array << if vmdb_obj.nil?
                                       entry
                                     else
                                       (vmdb_obj.respond_to?(:name) ? vmdb_obj.name : "#{vmdb_obj.class.name}::#{vmdb_obj.id}")
                                     end
            end
            hash[sequence_id][option_key] = options_value_array
          end

          def tag_hash_value(dialog_key, dialog_value, tags_hash)
            return false unless /^dialog_tag_(?<sequence>\d*)_(?<option_key>.*)/i =~ dialog_key
            add_hash_value(sequence.to_i, option_key.to_sym, dialog_value, tags_hash)
            true
          end

          def tag_array_value(dialog_key, dialog_value, tags_hash)
            return false unless /^array::dialog_tag_(?<sequence>\d*)_(?<option_key>.*)/i =~ dialog_key
            process_comma_separated_object_array(sequence.to_i, option_key.to_sym, dialog_value, tags_hash)
            true
          end

          def parse_dialog_entries(dialog_options)
            options_hash = Hash.new { |h, k| h[k] = {} }
            tags_hash = Hash.new { |h, k| h[k] = {} }

            dialog_options.each do |key, value|
              next if value.blank?
              set_dialog_value(key, value, options_hash, tags_hash)
            end
            return options_hash, tags_hash
          end

          def set_dialog_value(key, value, options_hash, tags_hash)
            # option_hash_value(key, value, options_hash) ||
            #   option_array_value(key, value, options_hash) ||
            #   option_password_value(key, value, options_hash) ||
            tag_hash_value(key, value, tags_hash) ||
              tag_array_value(key, value, tags_hash) #||
            # generic_dialog_value(key, value, options_hash) ||
            # generic_dialog_array_value(key, value, options_hash) ||
            #     generic_password_value(key, value, options_hash)
          end

          def merge_service_item_dialog_values(build, dialogs_hash)
            log(:info, "merge_service_item_dialog_values for [#{build}] of [#{dialogs_hash}] (tier hash): [#{dialogs_hash[build]}]")
            merged_hash = dialogs_hash[0]
            dialogs_hash[build].each do |k,v|
              log(:info, "\tadding overriding merged_hash[#{k}] <-- [#{v}]")
              merged_hash[k] = v
            end
            merged_hash
          end


        end
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  RhcMiqQuickstart::Automate::Service::DynamicDialogs::ListTemplateGuilds.new.main()
end

# foo = { a: "a" }
# bar = { b: "b" }
# baz = { a: "baz override" }
#
# foo.deep_merge!(bar).deep_merge!(baz)
# puts foo