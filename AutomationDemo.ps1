# This script calls the Power BI API to programmatically create workspace and assign capacity
$workspaceName = "YOURWORKSPACENAMETOCREATE"
$serverLocation = "westeurope"

Add-Type -AssemblyName System.Net.Http

$appSecret = "YOURAPPSECRET"
$appId = "YOURAPPID"
$tenantId = "YOURTENANTID"

$tokenEndpoint = {https://login.windows.net/{0}/oauth2/token} -f $tenantId 
$resourceAppIdURI = "https://analysis.windows.net/powerbi/api";
$body = @{
        'resource'= $resourceAppIdURI
        'client_id' = $appId
        'grant_type' = 'client_credentials'
        'client_secret' = $appSecret
}
$params = @{
    ContentType = 'application/x-www-form-urlencoded'
    Headers = @{'accept'='application/json'}
    Body = $body
    Method = 'Post'
    URI = $tokenEndpoint
}

# Get the Access token to be able to call the Power BI API
try {
$response = Invoke-RestMethod @params
$accessToken = $response.access_token
} catch { 
    Write-Error "Failed call to get accesstoken"
    Write-Error "StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Error "StatusDescription:" $_.Exception.Response.StatusDescription
}

Write-Host "AccessToken: $accessToken"

if ($accessToken -eq $null) {
    Write-Error "No AccessToken acquired"
}

# Building Rest API header with authorization token
$auth_header = @{
   'Content-Type'='application/json'
   'Authorization'= '' 
}

$auth_header.Authorization = "Bearer $accessToken"

# Try create the choosen group name
try {
    $uri = "https://api.powerbi.com/v1.0/myorg/groups"
    $body = "{`"name`":`"$workspaceName`"}"
    $response = Invoke-RestMethod -Uri $uri -Headers $auth_header -Method "POST" -Body $body
    $target_group_id = $response.id
    Write-Host "Created new workspace: $target_group_id"
} catch { 
    Write-Error "Could not create a group with that name. Please try again and make sure the name is not already taken"
    Write-Error "More details: "
    Write-Error "StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Error "StatusDescription:" $_.Exception.Response.StatusDescription
}

# Add user to the target workspace 
$workspaceAdminAccount= "YOURUSERTOADDTOWORKSPACE"
try {
    $uri = "https://api.powerbi.com/v1.0/myorg/groups/$target_group_id/users"
    $body = "{`"emailAddress`":`"$workspaceAdminAccount`", `"groupUserAccessRight`":`"Admin`"}"
    $response = Invoke-RestMethod -Uri $uri -Headers $auth_header -Method POST -Body $body
    Write-Host "Added admin account: " $workspaceAdminAccount
} catch { 
    Write-Error "Could not add admin user"
    Write-Error "More details: "
    Write-Error "StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Error "StatusDescription:" $_.Exception.Response.StatusDescription
}

Write-Host "Adding PowerBI Embedd capacity"

$uri = "https://api.powerbi.com/v1.0/myorg/capacities"
$response = Invoke-RestMethod -Uri $uri -Headers $auth_header -Method GET

$capacities = $response.value

# Map the Serverlocation of customer to PowerBI Embedded region
switch ($serverLocation){
    "eastus" { 
        $ServerLocation = "centralus";
        break
     }
    "eastus2" { 
        $ServerLocation = "centralus";
        break
     }
    "westus" { 
        $ServerLocation = "centralus";
        break
     }
    "westeurope" { 
        $ServerLocation = "northeurope";
        break
     }
    "ukwest" { 
        $ServerLocation = "uksouth";
        break
     }
    "canadaeast" { 
        $ServerLocation = "canadacentral";
        break
     }
}

Foreach ($capacity in $capacities) {

    $region = $capacity.region -replace '\s',''
    $region = $region.ToLower() 

    if ($region -eq $ServerLocation) {
        $capacityId = $capacity.id
    }
}

if ($null -eq $capacityId) {
    Write-Error "No capacity found for the ServerLocation!"
}

$uri = "https://api.powerbi.com/v1.0/myorg/groups/$target_group_id/AssignToCapacity"

$body = @{
    "capacityId" = $capacityId
}

$jsonBody = $body | ConvertTo-Json

try {
    Invoke-RestMethod -Uri $uri -Headers $auth_header -Method POST -Body($jsonBody)
    Write-Host "Capacity: $capacity.id set for workspace: $target_group_id"
} 
catch { 
       Write-Error "The deployment went through, but the call to set Power BI Embedded dedicated instance for the workgroup $target_group_id failed. Please check that the Embedded instance is running in the specified or mapped region"
}

