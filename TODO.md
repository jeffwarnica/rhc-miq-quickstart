# Flavors
* Support flavours without templates needing OS tag
* Support cloud flavor passthrough(???)
  
# Template matching
* list_template_guids should implement the same template logic as BVmPr, implying
  moving the matching methods from BVmPr to a shared method.
  
# Logging
* Consider a central place to configure @DEBUG, filtered by class?  

# Settings
* Consider providing a way to override settings (for an entire VM provisioning run)
  from a dialog.