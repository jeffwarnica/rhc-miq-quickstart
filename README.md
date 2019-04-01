# RHC-MIQ-Quickstart

This is a collection of automate code and dialogs to quickly get up
a useful CloudForms (ManageIQ) setup.

# Requirements
This has been "tested" against CloudForms 4.6 & 4.7.

This requires at least the automate part of
https://github.com/RedHatOfficial/miq-Utilities


# Setup & Demo

## Setup - TL;dr

* Recommended: install on an appliance the [miqimport/export scripts](https://github.com/rhtconsulting/cfme-rhconsulting-scripts)
* Install [miq-Utilities](https://github.com/RedHatOfficial/miq-Utilities), at least the automate part
* Install this project
* Update 'settings.rb' to include other settingsstore's
  * Create or reusing a high-priority 'variables' domain:
  * Copy RedHatConsulting_Utilities/StdLib/Settings/settings into the variables domain
  * Copy rhc-miq-quickstart/StdLib/Settings/settingsstore into the variable domain

    For settingsstore, change the Module name. This avoids erroneous but scary log messages.
* Create a Service Catalog item using the 'RHC Sanity Check' Service Dialog.
  Entry point is irrelevant, it will fail if submitted, and a regex check should
  make that impossible.
  * The dynamic text output should help guiding additional tagging and other
    configuration you need to do.

## Setup - Settings

This project, today, does not provide revolutionary features,


# Design goals
* To facilitate getting CloudForms up and running quickly.
* To demonstrate advance functionality with field proven processes not available
in the core product.
* Configuration over coding.
* Configuration in one location over instance variables.
* Using gratuitous amounts of log messages (at DEBUG or not) for onging
  debugging and code documentation purposes
* Especially print human readable error messages, if possible, with fix
  suggestions (eg "did you tag?")


Tracking current CF releases is more important than backwards compatibility.

Maintaining functionality is more important than chasing shiny.

Longer, more complex, but configurable methods are favoured over multiple drop
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

