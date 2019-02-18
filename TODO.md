# Flavors
* Have an embeddable method that includes a hash of the flavor name, sizes, details
  per the classic CF_E style.
* Have a drop down builder, which simply builds a dropdown from the included structure.
  (and update the sample dialogs)
* Include that structure in BVmPr and do the right thing, updating infrastructure
  providers, matching to cloud flavors.
  
# Template matching
* list_template_guids should implement the same template logic as BVmPr, implying
  moving the matching methods from BVmPr to a shared method.
  
# Logging
* Consider a central place to configure @DEBUG, filtered by class?  