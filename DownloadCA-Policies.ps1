# Get all conditional access policies
$policies = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies"

# Create a directory to store the JSON files in the script's directory
$directory = "$PSScriptRoot/Policies"
if (-Not (Test-Path -Path $directory)) {
    New-Item -ItemType Directory -Path $directory
}

Write-Output "Directory created at: $directory"

# Save each policy as a separate JSON file
foreach ($policy in $policies.value) {
    $fileName = "$directory\$($policy.id).json"
    $policy | ConvertTo-Json -Depth 10 | Out-File -FilePath $fileName -Encoding utf8
}