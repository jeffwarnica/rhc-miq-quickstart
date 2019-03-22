# RHC-MIQ-Quickstart

This is a collection of automate code and dialogs to quickly get up
a useful CloudForms (ManageIQ) setup.

# Requirements
This has been "tested" against CloudForms 4.6 & 4.7.

This requires at least the automate part of
https://github.com/RedHatOfficial/miq-Utilities


# Setup



# Features


# Design goals
To facilitate getting CloudForms up and running quickly, to demonstrate
some advance functionality with field proven processes not available
in the core product.

Emphasize and continue with the "[CloudForms Essentials](https://github.com/ramrexx/CloudForms_Essentials/)"
style of Generic Provisioning vs Bundles.

Tracking current CF releases is more important than backwards compatibility.

Maintaining functionality is more important than chasing shiny.

Longer, more complex, but configurable methods are favoured over multiple drop
in replacement implementations.


# Development Process

The inspiration and design for this is the CF 4.2 targeted version of CloudForms
Essentials, and to get to 1.0, it is anticipated that much code from that will
simply be copied from that project, refactored to the class structure of code,
and with advanced and complex features dropped.

To not directly require the now old (4.2) versions of CF_E which I consider
useful. This implies I'm allowing myself to straight copy some of those files.
This includes drop down helpers, and will expand as I need them.


# Inspiration & Sources

The aforementioned miq-Utilities.

https://github.com/ramrexx/CloudForms_Essentials/

https://github.com/jeffmcutter/cf_shortcuts/tree/master/build_vm_provision_request

