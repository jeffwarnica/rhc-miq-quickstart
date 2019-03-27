#  settingsstore.rb
#
#  Author: Jeff Warnica <jwarnica@redhat.com> 2018-08-16
#
# The settingstore for RHC-MIQ-Quickstart
#
# JeffW: Contrived examples matching names in RHPDS v2v 1.2 environment (or a tuned one, anyway)
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


            # Network selection look strategy.
            #
            #   Ultimately, we want a "network name", for a very lose concept of network name
            #             RHV, this is actually vNic profile name
            #
            # Valid options are: 'simple' or 'manualbytag'
            network_lookup_strategy: 'manualbytag',

            # simple is dead simple. Set the "network name"
            network_lookup_simple: 'ovirtmgmt',

            # ordered list of CF tag category names to use to create the vlan settings key
            #
            # Provides a level of indirection for finding VLAN names. Dynamically hunts for configuration
            # keys, from the configured tag categories, and user provided values from a dialog
            #
            # Format is as:
            #    network_<template>_key1_key2_..._keyN
            #
            # SPECIAL MAGICAL TAGS THAT OBVIOUSLY ARE NOT TAG CATEGORIES AND ONLY USEFUL HERE
            #   @vendor --> translates to the templates 'vendor', which means like 'vmware' or 'redhat'
            #   @ems    --> translates to the templates providers _name_, which is downcased,
            #                 and non-word characters translated to underscores
            #                 e.g. "my vcenter"         --> "my_vcenter"
            #                      "vmware Rocks! kids" --> "vmware_rocks__kids"
            #
            # consider the following examples
            #
            # network_lookup_manualbytags_keys: %w(@vendor location environment)
            #   we generate a new "lookup key" that might look like the following:
            #     ---> network_lookup_manualbytags_lookup_vmware_nyc_dev
            #     ---> network_lookup_manualbytags_lookup_vmware_paris_qa
            #   and you configure here the actual "vlan name". e.g.
            #
            #         network_lookup_manualbytags_lookup_vmware_nyc_dev: 'dvs_810_nyc_dev;
            #         network_lookup_manualbytags_lookup_vmware_paris_qa: 'dvs_164_paris_qa',
            #
            # Obviously, you can have the same "vlan" in a few places. And IDK what crazyness you might get to
            # in naming a provider. Say you got one named 'Extra C00l vSpheré'
            # network_lookup_manualbytags_keys: %w(@ems servicelevel location environment)
            #
            #         network_lookup_manualbytags_lookup_extra_c00l_vspher__gold_nyc_dev: 'dvs_131_nyc',
            #         network_lookup_manualbytags_lookup_extra_c00l_vspher__silver_nyc_dev: 'dvs_131_nyc',
            #         network_lookup_manualbytags_lookup_extra_c00l_vspher__silver_nyc_dev: 'dvs_131_nyc',
            #         network_lookup_manualbytags_lookup_extra_c00l_vspher__bronze_nyc_dev: 'dvs_nyc_old_10bT',
            #   (note the double __ as é --> _ + the separator)

            network_lookup_manualbytags_keys: %w(@vendor @ems environment),

            #NOTE: Put these in global: or a region
            #network_lookup_manualbytags_lookup_XXXXX: 'my_vlan',


            # triggers prov.set_option(:vm_auto_start, [false, 0]) if true.
            # Helpful for post-provisioning hardware updates (e.g. additional disks)
            vm_auto_start_suppress: true,


            # Dynamic Dialog Helper Settings

            # A list of tag category names that list_template_guids will filter on.
            #
            # This would allow a dialog to have tag categories like env: test/dev/prod or os: linux/windows
            #
            # In given tier, use , use tag_0_<thingy>, and override with tag_N_<thingy>
            #
            # If a given dialog is missing tag_N_<thingy>, that filter is ignored
            #
            list_template_guid_match_tags: %w(os env),
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

            #Our vlans are the same in all regions (HA!)

            network_lookup_manualbytags_lookup_vmware_vsphere_prod: 'VM Network',
            network_lookup_manualbytags_lookup_vmware_vsphere_test: 'VM Network',
            network_lookup_manualbytags_lookup_vmware_vsphere_dev: 'VM Network',
            network_lookup_manualbytags_lookup_vmware_vsphere_qa: 'VM Network',
            network_lookup_manualbytags_lookup_vmware_vsphere_quar: 'VM Network',

            network_lookup_manualbytags_lookup_redhat_rhv_prod: 'ovirtmgmt',
            network_lookup_manualbytags_lookup_redhat_rhv_test: 'ovirtmgmt',
            network_lookup_manualbytags_lookup_redhat_rhv_dev: 'ovirtmgmt',
            network_lookup_manualbytags_lookup_redhat_rhv_qa: 'ovirtmgmt',
            network_lookup_manualbytags_lookup_redhat_rhv_quar: 'ovirtmgmt',
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

