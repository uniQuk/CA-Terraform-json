# Convert conditional access policies from Json to Terraform using PowerShell
# This is a conversion of the existing python script
# It produced valid terraform files for the policies in the Policies folder
# The output is saved in the PoliciesTF2 folder
# Todo: fix some spacing inconsistencies in the optional conditions blocks

# Version 0.1
# Author: uniQuk Dec 2024

# Helper functions
function Convert-ArrayToTerraform {
    param (
        [Parameter(Mandatory = $false)]
        $Array
    )
    if ($null -eq $Array -or $Array.Count -eq 0) {
        return "[]"
    }
    return $(ConvertTo-Json $Array -Compress)
}

function Get-ApplicationBlock {
    param (
        [Parameter(Mandatory = $true)]
        $Applications
    )
    return @"

    applications {
      included_applications = $(Convert-ArrayToTerraform $Applications.includeApplications)
      excluded_applications = $(Convert-ArrayToTerraform $Applications.excludeApplications)
    }
"@
}

function Get-UsersBlock {
    param (
        [Parameter(Mandatory = $true)]
        $Users
    )
    return @"

    users {
      included_users = $(Convert-ArrayToTerraform $Users.includeUsers)
      excluded_users = $(Convert-ArrayToTerraform $Users.excludeUsers)
      included_groups = $(Convert-ArrayToTerraform $Users.includeGroups)
      excluded_groups = $(Convert-ArrayToTerraform $Users.excludeGroups)
      included_roles = $(Convert-ArrayToTerraform $Users.includeRoles)
      excluded_roles = $(Convert-ArrayToTerraform $Users.excludeRoles)
    }
"@
}

function Add-BlockWithSpacing {
    param (
        [string]$ExistingContent,
        [string]$NewBlock,
        [bool]$AddExtraLine = $false,
        [bool]$IsConditionBlock = $false
    )
    
    if ([string]::IsNullOrWhiteSpace($ExistingContent)) {
        return $NewBlock
    }
    
    $spacing = if ($IsConditionBlock) {
        "`n"
    } elseif ($AddExtraLine) {
        "`n`n"
    } else {
        "`n"
    }
    return $ExistingContent + $spacing + $NewBlock
}

function Get-OptionalConditionBlock {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Policy
    )
    
    $blocks = @()

    if ($Policy.conditions.platforms) {
        $blocks += @"

    platforms {
      included_platforms = $(Convert-ArrayToTerraform $Policy.conditions.platforms.includePlatforms)
      excluded_platforms = $(Convert-ArrayToTerraform $Policy.conditions.platforms.excludePlatforms)
    }
"@
    }

    if ($Policy.conditions.userRiskLevels) {
        $blocks += @"

    user_risk_levels = $(Convert-ArrayToTerraform $Policy.conditions.userRiskLevels)
"@
    }

    if ($Policy.conditions.locations) {
        $blocks += @"

    locations {
      included_locations = $(Convert-ArrayToTerraform $Policy.conditions.locations.includeLocations)
      excluded_locations = $(Convert-ArrayToTerraform $Policy.conditions.locations.excludeLocations)
    }
"@
    }

    if ($Policy.conditions.devices.deviceFilter) {
        $deviceFilter = $Policy.conditions.devices.deviceFilter
        $blocks += @"

    devices {
      filter {
        mode = "$($deviceFilter.mode.ToLower())"
        rule = "$($deviceFilter.rule -replace '"', '\"')"
      }
    }
"@
    }

    return $blocks -join ""
}

function Convert-PolicyToTerraform {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Policy,
        
        [Parameter(Mandatory = $true)]
        [string]$Filename
    )

    Write-Host "Converting policy: $Filename"

    try {
        # Get optional conditions
        $optionalConditions = Get-OptionalConditionBlock -Policy $Policy

        # Initialize empty blocks
        $grantControlsBlock = ""
        $sessionControlsBlock = ""

        # Start with base policy and required conditions
        $terraform = @"
resource "azuread_conditional_access_policy" "$Filename" {
  display_name = "$($Policy.displayName)"
  state        = "disabled"

  conditions {
    client_app_types = $(Convert-ArrayToTerraform $Policy.conditions.clientAppTypes)
$(Get-ApplicationBlock $Policy.conditions.applications)
$(Get-UsersBlock $Policy.conditions.users)$($optionalConditions)
  }
"@

        # Build grant controls block if present
        if ($Policy.grantControls) {
            $grantControlsBlock = @"

  grant_controls {
    operator          = "$($Policy.grantControls.operator)"
    built_in_controls = $(Convert-ArrayToTerraform $Policy.grantControls.builtInControls)
"@
            if ($Policy.grantControls.authenticationStrength) {
                $grantControlsBlock += "`n    authentication_strength_policy_id = `"$($Policy.grantControls.authenticationStrength.id)`""
            }
            $grantControlsBlock += "`n  }"
        }

        # Build session controls block if present
        if ($Policy.sessionControls) {
            $sessionControlsBlock = "`n  session_controls {`n"
            
            if ($Policy.sessionControls.signInFrequency) {
                $signInFreq = $Policy.sessionControls.signInFrequency
                if ($signInFreq.isEnabled) {
                    $value = if ($signInFreq.value) { $signInFreq.value } else { "null" }
                    $type = if ($signInFreq.type) { "`"$($signInFreq.type)`"" } else { "`"None`"" }
                    
                    $sessionControlsBlock += @"
    sign_in_frequency = $value
    sign_in_frequency_period = $type
"@
                    if ($signInFreq.authenticationType) {
                        $sessionControlsBlock += "`n    sign_in_frequency_authentication_type = `"$($signInFreq.authenticationType)`""
                    }
                    if ($signInFreq.frequencyInterval) {
                        $sessionControlsBlock += "`n    sign_in_frequency_interval = `"$($signInFreq.frequencyInterval)`""
                    }
                }
            }

            if ($Policy.sessionControls.applicationEnforcedRestrictions) {
                $isEnabled = $Policy.sessionControls.applicationEnforcedRestrictions.isEnabled.ToString().ToLower()
                $sessionControlsBlock += "`n    application_enforced_restrictions_enabled = $isEnabled"
            }

            # Ensure proper closing of session_controls
            $sessionControlsBlock += "`n  }"
        }

        # Add controls blocks with proper spacing
        if ($grantControlsBlock) {
            $terraform = Add-BlockWithSpacing -ExistingContent $terraform -NewBlock $grantControlsBlock
        }
        if ($sessionControlsBlock) {
            $terraform = Add-BlockWithSpacing -ExistingContent $terraform -NewBlock $sessionControlsBlock
        }

        # Close main resource block
        $terraform += "`n}"

        return $terraform
    }
    catch {
        Write-Error "Error converting policy $Filename : $_"
        return $null
    }
}

# Configure paths
$scriptPath = $PSScriptRoot
$sourcePath = Join-Path -Path $scriptPath -ChildPath "Policies"
$destPath = Join-Path -Path $scriptPath -ChildPath "PoliciesTF2"

# Create destination directory if it doesn't exist
if (-not (Test-Path -Path $destPath)) {
    Write-Host "Creating destination directory: $destPath"
    New-Item -ItemType Directory -Path $destPath -Force | Out-Null
}

# Process JSON files
Write-Host "Looking for JSON files in: $sourcePath"
$jsonFiles = Get-ChildItem -Path "$sourcePath\*.json"

foreach ($file in $jsonFiles) {
    try {
        $tfFile = Join-Path -Path $destPath -ChildPath "$($file.BaseName).tf"
        
        # Check if file already exists
        if (Test-Path -Path $tfFile) {
            Write-Host "File $($file.BaseName).tf already exists. Skipping."
            continue
        }

        $policy = Get-Content $file.FullName | ConvertFrom-Json
        $tfContent = Convert-PolicyToTerraform -Policy $policy -Filename $file.BaseName
        
        if ($tfContent) {
            $tfContent | Out-File -FilePath $tfFile -Encoding UTF8 -Force
            Write-Host "Created Terraform file: $tfFile"
        }
    }
    catch {
        Write-Error "Error processing file $($file.Name): $_"
    }
}

Write-Host "Processing complete"