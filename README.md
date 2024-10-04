# CA-Terraform-json
Converts Conditional Access Policies from json to Terraform

Export polices as json/templates and convert to Terraform. 
Checks if file exists and skips recreating the policy as the goal is to do an initial conversion and then maintain policies/state through the Terraform but provides flexibility to add/remove new templates over time.

Tested on the example policies provided by Microsoft and downloadable from Conditional Access section in a dev tenant.

Assume json is stored in ./Policies and outputs to a folder ./PoliciesTF. Includes basic debugging output.

