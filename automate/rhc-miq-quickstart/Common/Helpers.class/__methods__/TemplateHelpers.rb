module RhcMiqQuickstart
  module Automate
    module Service
      module Provisioning
        module StateMachines

          # Template matching helpers
          #
          # Methods here are module methods, matching a particular signature, and named in the format
          # match_tempate_by_<user defined name>, where <user defined name> us used as a settings option.
          #
          # Methods _Must_ match the signature
          #     [[:req, :caller], [:req, :build], [:req, :templates], [:req, :merged_options_hash], [:req, :merged_tags_hash]]
          # which with ruby isn't hard.
          #
          #   caller is passed as the calling method, to allow access to caller.handle, caller.settings, etc
          #   build is the build/tier #, probably only useful for logging
          #   templates is the input array of potential templates
          #   merged_options_hash  parsed and processed dialog options
          #   merged_tags_hash     parsed and processed dialog tags
          #
          # returns array of templates (presumably a subset of what was passed)
          module TemplateHelpers

            # Given templates, returns templates
            #   Passed template matches at least one tag value of each of the required tag categories.
            def self.match_templates_by_align_tags(caller, build, templates, merged_options_hash, merged_tags_hash)

              @handle = caller.handle
              @handle.log(:info, "\tmatch_templates_by_align_tags()")

              consider_as_tags = caller.settings.get_setting(:global, :template_match_method_align_tags_consider_as_tags, %w[os environment])
              @handle.log(:info, "Configured tag categories for filtering: [#{consider_as_tags}]")

              tags_to_match = {}
              merged_tags_hash.each do |c, v|
                next unless consider_as_tags.map { |x| x.to_sym }.include?(c)
                tags_to_match[c] = [v, '_any_']
              end
              merged_options_hash.each do |c, v|
                next unless consider_as_tags.map { |x| x.to_sym }.include?(c)
                tags_to_match[c] = [v, '_any_']
              end

              @handle.log(:info, "\t\tThis run, filtering with: [#{tags_to_match}]")

              template_matching_tag = {}

              # loop through each tag category, finding, for each category, templates that match
              tags_to_match.each do |category, values|
                @handle.log(:info, "\t\t\tChecking templates to find matched with [#{category} -> #{values}]")
                templates.find_all do |template|
                  template_matching_tag[category.to_sym] ||= []
                  if Array.wrap(values).find { |value| template.tagged_with?(category, value) }
                    template_matching_tag[category.to_sym] << template
                  end
                end
                @handle.log(:info, "\t\t\tGot [#{template_matching_tag[category.to_sym].size}] that match " \
                        "which are: [#{template_matching_tag[category.to_sym].map { |t| t.name }} ]")
              end

              @handle.log(:info, "\t\tGoing to [ <everything> ∩ " + template_matching_tag.keys.join(" ∩ ") + " ]")

              # and then find the intersection of those
              potential_templates = templates #template_matching_tag[irrelevant_valid_category]
              template_matching_tag.each do |category, arr_of_templates|
                potential_templates &= arr_of_templates
              end
              @handle.log(:info, "\t\t\tMatching templates = [#{potential_templates.map { |t| t.name }}]")
              @handle.log(:info, "\tmatch_templates_by_align_tags returning [#{potential_templates.size}] templates")
              potential_templates
            end


            ##
            # Filters out templates whose provider does not match the location tag
            # e.g. for deployment by template name into a particular provider, where the templates are "the same"
            # across multiple providers

            def self.match_templates_by_provider_location(caller, build, templates, merged_options_hash, merged_tags_hash)
              @handle = caller.handle
              @handle.log(:info, "\tmatch_templates_by_provider_location()")
              error('searching by provider location but no location found in form') unless merged_tags_hash.key?(:location)
              templates.find_all do |t|
                t.ext_management_system.tagged_with?('location', merged_tags_hash[:location])
              end
            end

            def self.match_templates_by_location(caller, build, templates, merged_options_hash, merged_tags_hash)
              @handle = caller.handle
              @handle.log(:info, "\tmatch_templates_by_locaiton()")
              match_template_by_tag(@handle, build, templates, 'location', merged_tags_hash[:location])
            end

            def self.match_template_by_tag(caller, build, templates, category, value)
              @handle = caller.handle
              @handle.log(:info, "\tmatch_templates_by_tag, [#{category}] has [#{value}]?")
              templates.find_all do |t|
                t.tagged_with?(category, value)
              end
            end
          end #TemplateHelpers

        end
      end
    end
  end
end

