#  settingsstore.rb
#
#  Author: Jeff Warnica <jwarnica@redhat.com> 2018-08-16
#
# Provides a common location for settings for RedHatConsulting_Utilities,
# and some defaults for the children project like rhc-miq-quickstart
#
# Settings are Global, Default, and by RegionID, with regional settings falling through to Default
#-------------------------------------------------------------------------------
#   Copyright 2018 Jeff Warnica <jwarnica@redhat.com>
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
  module StdLib
    module Core

      # Settings handles storage and access of, er, settings. These can be Global, or bound to a RegionID, or a default
      # in the cases where there are no specific region settings.
      class SettingsStorage < RedHatConsulting_Utilities::StdLib::Core::Settings

        PRIORITY = 0

        SETTINGS = {
          global: {
            # ordered list of CF tag names to use to create the vlan settings key,
            #
            # This helps build the setting name for VLAN lookups. Format is as:
            #    network_<template vendor>_key1_key2_..._keyN
            # consider the following examples
            #
            # vmware templates:
            # network_lookup_keys: %w(location environment)
            #         ---> network_vmware_NYC_DEV OR network_vmware_PARIS_QA
            # network_lookup_keys: %w(servicelevel location environment)
            #         ---> network_vmware_GOLD_NYC_DEV OR network_vmware_BRONZE_PARIS_QA
            #
            network_lookup_keys: %w(environment),

            # triggers prov.set_option(:vm_auto_start, [false, 0]) if true.
            # Helpful for post-provisioning hardware updates (e.g. additional disks)
            vm_auto_start_suppress: true,
          },

          default: {

            # network/vlan/dvs names for the providers
            # these _must_ exist, for b_vm_pr_r to request a VM provisioning, but likely will change later
            # in that VM provisioning process
            network_vmware: 'VM Network',
            network_redhat: '<Template>',

            # Retirement warning schedule
            retirement: 30.days.to_i,
            retirement_warn: 14.days.to_i,

            # maximum number of user triggered retirement extensions
            retirement_max_extensions: 3,
          },

          r901: {
            network_vmware: 'dvs_0810_INF_VMS_PRD_HFLEX',
            network_vmware_test: 'dvs_0820_Self_Prov_Test(10.43.181.x)',
            network_vmware_dev: 'dvs_0821_Self_Prov_Dev(10.43.182.x)',
            default_custom_spec: 'Win2016(all versions)-Dev-Test-len',
            default_custom_spec_prefix: 'Win2016(all versions)-Dev-Test',
            infoblox_url: 'https://10.111.105.203/wapi/v2.6.1/',
          },
        }.freeze

      end
    end
  end
end

