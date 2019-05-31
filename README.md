# RHC-MIQ-Quickstart

This is a collection of automate code and dialogs to quickly get up
a useful CloudForms (ManageIQ) setup.

# Requirements
This has been "tested" against CloudForms 4.7.

This requires at least the automate part of
https://github.com/RedHatOfficial/miq-Utilities

(Actually, https://github.com/jeffwarnica/miq-Utilities/tree/mar21 )


# Quickstart and Demo

## Setup - TL;dr

Checkout [RHPDS Testing Notes](TESTING_NOTES-RHPDS.md). There are some big enough labs in RHPDS
to test this out and kick the tires. Integration into a home lab, or a real world environment, will
require some care and feeding. I highly recommend playing with this in a home lab or RHPDS before an engagement.

## Prerequisite 

* [miqimport/export scripts](https://github.com/rhtconsulting/cfme-rhconsulting-scripts)
* [miq-Utilities](https://github.com/RedHatOfficial/miq-Utilities)
  * "mar21" branch of (https://github.com/jeffwarnica/miq-Utilities)

### Nice to have
* Jeff Cutters appliance tools [CF Environment and Shortcuts](https://github.com/jeffmcutter/cf_shortcuts.git)

## Step By Step
* From CF UI:
  * Enable 'Git Repositories Owner' role, if necessary.
  * Import GIT Automate repositories:
    * https://github.com/rhtconsulting/miq-Utilities.git
        * Actually: https://github.com/jeffwarnica/miq-Utilities.git with mar21 branch
    * https://github.com/jeffwarnica/rhc-miq-quickstart.git
  * Create your local, customization Domain for local code and settings
    * Create a new domain, say "Lab"
    * Copy from rhc-miq-quickstart the following:
      * `/StdLib/Settings/settingsstore`
      	* Here, you will store your local settings.
		  * Change the class name from "SettingsStorage" to anything else ("SettingsStorageLab", say)
		  * Change the priority from 0 to, say 100
      * `/StdLib/Settings/settings`
      	* Absent a "Automate Class Path Loader", we have to use what we got, so: edit `settings` adding additional embedded methods - all of the settingstores in Automate, essentially
      	  * Ensure that they are included with the Domain Prefix, as they should live in the same location in their respective domains
      * `/StdLib/Settings/settingsstore`
  * Configure and wire up "Settings". This involves creating a new Domain, copying some files, and
    providing your own settings.
    * Create a "variables" domain, top priority
    * From Automate/RedHatConsulting_Utilities/StdLib/Settings, copy settings and settingsstore, to your new domain
    * In settings, configure Embedded Methods, including settingsstore from
      miq-Utilities and rhc-miq-quickstart (including domain prefix!)
    * In settingsstore:
  * Datstores might look like this: ![like this](Docs/AutomateSetup.png)
  * If you plan on making any changes, my convention is to have matching xxx_working domains, just above in priority, 
        to their respective git backed domains.
  * Import the Service Dialogs, Service Catalogs and tags, from this project, with the command line tools:
    `[root@cf rhc-miq-quickstart]# miqimport service_dialogs service_dialogs/`
    `[root@cf rhc-miq-quickstart]# miqimport service_catalogs service_catalogs/`
    `[root@cf rhc-miq-quickstart]# miqimport tags tags/VM_Tier.yaml`
    `[root@cf rhc-miq-quickstart]# miqimport tags tags/Operating_System.yaml`
  * Tag some things
    * Templates get Prov Scope, OS and Environment tags
      * RHV and vSphere each have a RHEL template.
        OS=>Linux
        Prov Scope=>All
      * The default configuration is going to have dialogs that key on Env, so tag
        the RHV and vsphere templates to some env, say:
        Environment=>
           rhv->QA
           vmware->prod
  * You can copy the templates and create a combination with different environments, prov_scope
  env, os , etc, and/or tag some of the templates with '\_any_' as the environment
  Copy those templates with Windows-y names. per above, prov_scope, os, env
    This may involve logging into RHV or vSphere directly??
  * Tag RHV & vmware hosts as prov_scope=>all
  * Tag RHV & vmware datastores as prov_scope=>all (not Export or ISO)
  * Tags clusters as prov_scope=>all

* Review "Admin Sanity Check" SC : the dynamic text output should help guiding
  additional tagging and other configuration you need to do.
** HELP: If there is additional mindless configuration you find later that you need to do, 
   and can easily be detected, please update Service/DynamicDialogs.class/__methods__/sanity_dump.rb and submit
   a PR.

At this point, you should be able to _attempt_ to provision VMs with the provided dialog, to see what further
configuration is required.

# Setup & Configuration

The basic CF VM Deployment process is unchanged, and is often described as "create provision request" 
(from the $evm.execute method name) or "build vm provision request" or "ramrexx" method, from the
 CF method name of the main monstrosity, and github username of Kevin Morey. 

Morey original logic flow was to front load the decision making; A wide range dialogs can be quite robust, 
and all feed into the same entry point (build_vm_provision_request), which is heavily customized to local 
business logic, and VM (actually, tiers of identical VMs) provisioned through 
`$evm.execute('create provision request')`. The actual VM state machine and methods can remain relatively
untouched. Yes, there is still VM placement logic, but the user, the dialog, and bVmPr decided the VM 
was "production" (a business decision); the placement method only finds a technically suitable production
host/cluster/datastore/vlan.

This projects main goal is to have functional abstract code, which is controlled through configuration, 
not more code.

Currently, the "template finding" logic has been so updated, and the VLAN selection logic is in progress.

The provided example Service Dialogs and Catalog Items either provision based on hand selecting a template, 
or selecting some tags, with the template being searched for. (There is a TODO to reconcile the dropdown 
code with the bVmPr code so these can not be different, right now they have widely different 
implementations.)


## Template Lookup

Ultimately, a template is the key object to be provisioned. A template is selected either
directly in a dialog, or logically in bVmPr. The processing logic in b_vm_p_r is to take all templates
and pass them through a "match chain" to end up with (ideally) one template. If there is more than one, 
one is randomly selected from whatever is left.

Actually, even if a template is manually selected by the user in the UI, it still goes through the 
"match chain". 

### Template Match Chain Implementations

#### align_tags

The default configuration is a single match chain method, "align_tags". This is influenced by the 
setting `template_match_method_align_tags_consider_as_tags`, which selects which tags to align between 
what is requested and how the templates are tagged. It is worth noting that a template would need to 
match on all categories, but only one value per category. Also of note, templates can be tagged with
a somewhat special tag value '\_any_'. This is a workaround around some tag categories being single-value. 

### provider_location

Matches templates on a location tag, to the templates provider's location tag. Suitable for tagging 
provider based on datacenter, for example, without having to manually tag every template.


## VLAN Lookup Logic

Configure `network_lookup_strategy` to be `simple` or `manualbytag`. 

### simple
`simple` is dead simple, and sets the "network name" to the value of `network_lookup_simple`. 

### "Network Name" 
"Neetwork Name" is a relative concept. For RHV this is a vNIC Profile Name. Otherwise, the usual CloudForms 
hilarious "rules" apply, I'd expect DVS networks to need dvs_ prepended, etc.

### manualbytag

From the VMs tags, directly place VMs into suitable networks, via a configured naming convention for settings
keys. This does not require the existing network names to conform to any standard (if they do, I would suggest
a custom lookup method.) 

This has the downside of needing to a lot of mostly duplicate configuration lines, but zero programming.

Details are in settingsstore.rb.


# Design Philosophy and Goals 
* To facilitate getting a real-world useful CloudForms up and running quickly.
* To demonstrate advance functionality with field proven processes not available
in the core product.
* Configuration over coding.
* Configuration in one location over instance variables.
* Logging serves as comments and for runtime debugging. More is better. Strive for
  people needing to debug code only when code is broken - if configuration or environment
  is broken, that should be obvious in the logs.
* Especially print human readable error messages, if possible, with fix
  suggestions (eg "did you tag?")
* Tracking current CF releases is more important than backwards compatibility.
* Maintaining functionality is more important than chasing shiny.
* Longer, more complex, but _configurable_ methods are favoured over multiple drop 
  in replacement implementations.



# Features

## Real World Useful

This project targets what real world experience has proven to be normal CloudForms
use cases. Copying & editing has been replaced with generalizing & configuring.


## Build VM Provision Request style provisioning

This project is built around service deployment of VMs, using _Generic_ catalog
type, rather then the built in concept of service bundles.

The puts most of the logic up front, into the service catalog dialog (and dynamic
dialog helpers), and then build_vm_provision_request.rb.

## Configuration in one place, over code editing

A never ending goal, but general code flow here should be site-agnostic. Algorithms
themselves be relatively generic, taking configuration for trivial tweaks.
Further, as a log of logic is taking a long list of things (eg. templates,
VLANs, Datastores), and filtering that down to either one single item, or mostly
good enough itmes, we want to allow configuring the filter chain to change
operation of code via configuration, rather then editing code.

This does somewhat imply a meta framework, or a meta naming standard. Future work
would provide an easily configurable different "meta chain" for any decision point.

Configuration should be done in settings.rb, and not instance variables.

If custom code is required, minimal helper configuration should be included
dynamically, through configuration, for example the above noted "filter" style
flow is a chain of simple filters, selectable and ordered, by configuration,
not editing code.

## Flavor, as mostly a high level concept

Flavors, or t-shirt sizing, is configured in one place and used throughout
as a high level concept.

Flavors are configured in /Common/FlavorConfig/flavorconfig.

Currently, flavors do not support mapping "cloud flavors".

## A few Dialog Samples

A handful of sample dialog are provided. They fall into two extremes: extremely
trivial and very complex.

The trivial are more likely to be useful, the complex serve are a demonstration
of the interactions between the collection of dynamic elements. Ultimately,
as the complex dialogs filter down to a template dropdown, absent a lot of
tagging, they will often produce no results, and not even be able to be subimitted,
but may be a good admin/debugging tool.


## A bunch of drop down helpers


# Success Criteria


# Inspiration & Sources

The aforementioned miq-Utilities.

https://github.com/ramrexx/CloudForms_Essentials/

https://github.com/jeffmcutter/cf_shortcuts/tree/master/build_vm_provision_request

# Extensions and Configuration

