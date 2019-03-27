#  list_template_guids.rb
#
#  Author: Kevin Morey <kevin@redhat.com>
#          Jeff Warnica <jwarnica@redhat.com>
#
#  Description: This method builds a dialog of all template GUIDs based
#     on the RBAC filters applied to a users group.
#
#     Additionally, templates are limited based on the Settings list_template_tag_filters,
#       which is an array of tag category names. This code then filters out templates
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

require 'deep_merge'

module RhcMiqQuickstart
  module Automate
    module Service
      module DynamicDialogs
        class ListTemplateGuilds

          include RedHatConsulting_Utilities::StdLib::Core

          def initialize(handle = $evm)
            @settings = RedHatConsulting_Utilities::StdLib::Core::Settings.new()
            @display_on = @settings.get_setting(:global, :list_templates_show, 'provider').freeze
            @handle = handle
            @tier = @handle.root['tier']
            @DEBUG = true
          end

          def main()
            log(:info, 'Start ' + self.class.to_s + '.' + __method__.to_s)
            @user = get_user
            @rbac_array = get_current_group_rbac_array

            dialog_hash = {}
            dump_root() if @DEBUG
            log(:info, "@rbac_array: [#{@rbac_array}]") if @DEBUG

            options_hash, tags_hash = parse_dialog_entries(@handle.root.attributes)

            @handle.log(:info, "tags_hash: [#{tags_hash}]") if @DEBUG

            this_tier_filter = {}
            filter_array = []
            this_tier_filter.deep_merge!(tags_hash[0])
            this_tier_filter.deep_merge!(tags_hash[@tier.to_i])
            this_tier_filter.each { |c, v| filter_array << { c => v } }

            @handle.log(:info, "this_tier_filter: [#{this_tier_filter}]") if @DEBUG
            @handle.log(:info, "filter_array: [#{filter_array}]") if @DEBUG

            potential_templates = []
            @handle.vmdb(:miq_template).all.each do |template|

              log(:info, "checking template [#{template.name}] with tags [#{template.tags}]") if @DEBUG

              # RBAC first
              next unless object_eligible?(template) || @user.current_group.description == 'EvmGroup-super_administrator'
              next unless object_matches_tag_filter?(template, filter_array)

              potential_templates << template
            end


            potential_templates.each do |template|

              on = ' on ' + template.host.ems_cluster.name if @display_on == 'cluster'
              on = ' on ' + template.ext_management_system.name if @display_on == 'provider'
              dialog_hash[template[:guid]] = "#{template.name}#{on}"

            end

            if dialog_hash.blank?
              log(:info, "No templates found tagged with RBAC: [#{@rbac_array}] and dialog filters: [#{filter_array}]")
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