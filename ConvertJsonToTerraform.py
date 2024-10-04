import json
import os

def convert_policy_to_terraform(policy, filename):
    print(f"Converting policy: {filename}")
    
    try:
        terraform = f'''resource "azuread_conditional_access_policy" "{filename}" {{
  display_name = "{policy['displayName']}"
  state        = "disabled"

  conditions {{
    client_app_types = {json.dumps(policy['conditions'].get('clientAppTypes', []))}

    applications {{
      included_applications = {json.dumps(policy['conditions']['applications'].get('includeApplications', []))}
      excluded_applications = {json.dumps(policy['conditions']['applications'].get('excludeApplications', []))}
    }}

    users {{
      included_users = {json.dumps(policy['conditions']['users'].get('includeUsers', []))}
      excluded_users = {json.dumps(policy['conditions']['users'].get('excludeUsers', []))}
      included_groups = {json.dumps(policy['conditions']['users'].get('includeGroups', []))}
      excluded_groups = {json.dumps(policy['conditions']['users'].get('excludeGroups', []))}
      included_roles = {json.dumps(policy['conditions']['users'].get('includeRoles', []))}
      excluded_roles = {json.dumps(policy['conditions']['users'].get('excludeRoles', []))}
    }}
'''

        if 'platforms' in policy['conditions'] and policy['conditions']['platforms']:
            terraform += f'''
    platforms {{
      included_platforms = {json.dumps(policy['conditions']['platforms'].get('includePlatforms', []))}
      excluded_platforms = {json.dumps(policy['conditions']['platforms'].get('excludePlatforms', []))}
    }}
'''

        if 'userRiskLevels' in policy['conditions'] and policy['conditions']['userRiskLevels']:
            terraform += f'''
    user_risk_levels = {json.dumps(policy['conditions']['userRiskLevels'])}
'''

        terraform += '  }\n'

        if policy.get('grantControls'):
            terraform += f'''
  grant_controls {{
    operator          = "{policy['grantControls'].get('operator', 'OR')}"
    built_in_controls = {json.dumps(policy['grantControls'].get('builtInControls', []))}
'''

            if policy['grantControls'].get('authenticationStrength'):
                terraform += f'''    authentication_strength_policy_id = "{policy['grantControls']['authenticationStrength']['id']}"
'''

            terraform += '  }\n'

        if policy.get('sessionControls'):
            terraform += '''
  session_controls {
'''
            if policy['sessionControls'].get('applicationEnforcedRestrictions'):
                terraform += f'''    application_enforced_restrictions_enabled = {str(policy['sessionControls']['applicationEnforcedRestrictions'].get('isEnabled', 'false')).lower()}
'''

            if policy['sessionControls'].get('signInFrequency'):
                sign_in_freq = policy['sessionControls']['signInFrequency']
                if sign_in_freq.get('isEnabled'):
                    terraform += f'''    sign_in_frequency = {sign_in_freq.get('value', 'null')}
    sign_in_frequency_period = "{sign_in_freq.get('type', '')}"
'''
                    if sign_in_freq.get('authenticationType'):
                        terraform += f'''    sign_in_frequency_authentication_type = "{sign_in_freq['authenticationType']}"
'''
                    if sign_in_freq.get('frequencyInterval'):
                        terraform += f'''    sign_in_frequency_interval = "{sign_in_freq['frequencyInterval']}"
'''

            terraform += '  }\n'

        terraform += '}\n'

        return terraform
    except KeyError as e:
        print(f"Error processing policy {filename}: KeyError - {str(e)}")
        return None
    except Exception as e:
        print(f"Unexpected error processing policy {filename}: {str(e)}")
        return None

def main():
    input_dir = './Policies'
    output_dir = './PoliciesTF'

    print(f"Starting conversion process...")
    print(f"Input directory: {input_dir}")
    print(f"Output directory: {output_dir}")

    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        print(f"Created output directory: {output_dir}")

    for filename in os.listdir(input_dir):
        if filename.endswith('.json'):
            print(f"\nProcessing file: {filename}")
            with open(os.path.join(input_dir, filename), 'r') as f:
                try:
                    policy = json.load(f)
                except json.JSONDecodeError:
                    print(f"Error: Invalid JSON in file {filename}")
                    continue

            terraform = convert_policy_to_terraform(policy, filename[:-5])
            if terraform is None:
                continue

            output_filename = f"{filename[:-5]}.tf"
            output_path = os.path.join(output_dir, output_filename)
            
            if os.path.exists(output_path):
                print(f"File {output_filename} already exists. Skipping.")
            else:
                with open(output_path, 'w') as f:
                    f.write(terraform)
                print(f"Created {output_filename}")

    print("\nConversion process completed.")

if __name__ == "__main__":
    main()
