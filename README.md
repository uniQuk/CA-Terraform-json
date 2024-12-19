# CA-Terraform-json
Converts Conditional Access Policies from json to Terraform

Export polices as json/templates and convert to Terraform. 
Checks if file exists and skips recreating the policy as the goal is to do an initial conversion and then maintain policies/state through the Terraform but provides flexibility to add/remove new templates over time.

Tested on the example policies provided by Microsoft and downloadable from Conditional Access section in a dev tenant.

- Assume json is stored in ./Policies and outputs to a folder ./PoliciesTF Includes basic debugging output.
- The PS script outputs to PoliciesTF2. This was to compare output during conversion. 

# Usage:
- Added simple script that can download your tenants Conditional Access Policies (CAP) and store them in a folder called /Policies
- Use either the Python (original/most tested) or PowerShell script to convert the Policies to Terraform

## Disclaimer:
- This was created as a Proof of Concept (POC) using the available Microsoft Conditional Access Templates Policies.
- Later added a simple script to pull CAP Policies from a tenant.
- While safe as it doesn't modify the original policies and only generates new Terraform files locally it is still a POC.

## Update 19th December 2024

### The python script updated to include Location and Device blocks.

#### Added a PowerShell script - this is a WIP. 
Produced valid Terraform. Not properly tested. Would reccomend the Python Script as more complete for now.
#### Added a basic script to download existing policies from a tenant.
- Todo: Save as friendly names (currently saves as the Policy ID by default).
