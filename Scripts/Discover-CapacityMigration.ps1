<#
Discover-CapacityMigration_clean.ps1

Lightweight, self-contained script to:
- Authenticate to Power BI (interactive or service principal)
- Discover capacities, workspaces, items (datasets, reports, dashboards, dataflows, notebooks)
- Retrieve dataset (semantic model) details including size information
- Export results to a single Excel workbook with multiple sheets:
  * Summary - Item type counts and totals
  * Capacities - All discovered capacities
  * Workspaces - All workspaces
  * Items - All items (datasets, reports, dashboards, dataflows)
  * SemanticModels - Dataset details with size information
  * SkippedDatasets - Items that couldn't be accessed (if any)

Requirements:
- PowerShell 5.1+ (or PowerShell 7+)
- MicrosoftPowerBIMgmt module (script will prompt to install if missing)
- ImportExcel module (script will prompt to install if missing)

Usage examples:
    .\Scripts\Discover-CapacityMigration_clean.ps1
    .\Scripts\Discover-CapacityMigration_clean.ps1 -OutputPath .\output

#>

param(
    [string]$OutputPath = "$PSScriptRoot\output",
    [string]$TenantId = $null,
    [string]$ServicePrincipalId = $null,
    [string]$ServicePrincipalSecret = $null
)

Set-StrictMode -Version Latest

function Get-Prop {
    param(
        [Parameter(Mandatory=$true)] $Object,
        [Parameter(Mandatory=$true)] [string] $Name
    )
    if ($null -eq $Object) { return $null }
    if ($Object -is [System.Management.Automation.PSCustomObject] -or $Object -is [System.Management.Automation.PSObject]) {
        if ($Object.PSObject.Properties.Name -contains $Name) { return $Object.$Name }
        return $null
    }
    try { return $Object.$Name } catch { return $null }
}

function Ensure-Module {
    param([string]$Name)
    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Write-Host "Module $Name not found. Installing from PSGallery (requires internet)..." -ForegroundColor Yellow
        Install-Module -Name $Name -Scope CurrentUser -Force -ErrorAction Stop
    }
    Import-Module $Name -ErrorAction Stop
}

try {
    Ensure-Module -Name MicrosoftPowerBIMgmt
    Ensure-Module -Name ImportExcel
}
catch {
    Write-Host "Failed to install/load required modules: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Authentication
Write-Host "Authenticating to Power BI..." -ForegroundColor Cyan
try {
    if ($ServicePrincipalId -and $ServicePrincipalSecret) {
        $secure = ConvertTo-SecureString $ServicePrincipalSecret -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential($ServicePrincipalId, $secure)
        if ($TenantId) {
            Connect-PowerBIServiceAccount -ServicePrincipal -Credential $cred -Tenant $TenantId -ErrorAction Stop
        }
        else {
            Connect-PowerBIServiceAccount -ServicePrincipal -Credential $cred -ErrorAction Stop
        }
        Write-Host "Connected (service principal)" -ForegroundColor Green
    }
    else {
        if ($TenantId) { Connect-PowerBIServiceAccount -Tenant $TenantId -ErrorAction Stop }
        else { Connect-PowerBIServiceAccount -ErrorAction Stop }
        Write-Host "Connected (interactive)" -ForegroundColor Green
    }
}
catch {
    Write-Host "Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Prepare output folder
if (-not (Test-Path -Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }

# Helper to call admin REST endpoints
function Get-AdminEndpoint {
    param(
        [string]$RelativeUrl
    )
    $maxRetries = 3
    $delaySeconds = 1
    for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
        try {
            $resp = Invoke-PowerBIRestMethod -Url $RelativeUrl -Method Get -ErrorAction Stop
            if ($null -eq $resp) { return $null }
            if ($resp -is [string]) {
                return $resp | ConvertFrom-Json
            }
            else {
                return $resp
            }
        }
        catch {
            $ex = $_.Exception
            $msg = $ex.Message
            if ($ex.InnerException) { $msg += " | Inner: " + $ex.InnerException.Message }

            # Try to extract HTTP status code / response if present
            try {
                if ($ex.Response -and $ex.Response.StatusCode) {
                    $msg += " | StatusCode: $($ex.Response.StatusCode)"
                }
            } catch { }

            # expose last error for callers to inspect
            Set-Variable -Scope Script -Name LastGetAdminError -Value $msg -Force

            # Check if this is an error that won't be resolved by retrying
            $shouldNotRetry = ($msg -match 'ItemNotFound') -or ($msg -match 'PowerBIEntityNotFound') -or ($msg -match '404')
            
            if ($shouldNotRetry) {
                Write-Host "Skipping $RelativeUrl - resource not found or inaccessible." -ForegroundColor DarkGray
                return $null
            }

            Write-Host "Failed to call $RelativeUrl : $msg" -ForegroundColor Yellow

            if ($attempt -lt $maxRetries) {
                $sleep = $delaySeconds * [math]::Pow(2, $attempt-1)
                Write-Host "Retrying in $sleep seconds (attempt $attempt of $maxRetries)..." -ForegroundColor DarkYellow
                Start-Sleep -Seconds $sleep
                continue
            }
            else {
                return $null
            }
        }
    }
}

# Structured wrapper that returns success/data/error
function Try-GetAdminEndpoint {
    param([string]$RelativeUrl)
    $data = Get-AdminEndpoint -RelativeUrl $RelativeUrl
    if ($null -eq $data) {
        return [PSCustomObject]@{ Success = $false; Data = $null; Error = $script:LastGetAdminError }
    }
    return [PSCustomObject]@{ Success = $true; Data = $data; Error = $null }
}


# 1) Capacities
Write-Host "Retrieving capacities..." -ForegroundColor Cyan
$capacitiesRaw = Get-AdminEndpoint -RelativeUrl 'admin/capacities'
$capacities = @()
if ($capacitiesRaw) {
    foreach ($c in $capacitiesRaw.value) {
        $capacities += [PSCustomObject]@{
            'Capacity Id' = (Get-Prop -Object $c -Name 'id')
            'Name' = (Get-Prop -Object $c -Name 'displayName')
            'SKU' = (Get-Prop -Object $c -Name 'sku')
            'State' = (Get-Prop -Object $c -Name 'state')
            'Region' = (Get-Prop -Object $c -Name 'region')
        }
    }
}

# 2) Workspaces (admin groups)
Write-Host "Retrieving workspaces (admin/groups)..." -ForegroundColor Cyan
$workspacesRaw = Get-AdminEndpoint -RelativeUrl 'admin/groups?$top=5000'
$workspaces = @()
if ($workspacesRaw) {
    foreach ($ws in $workspacesRaw.value) {
        $workspaces += [PSCustomObject]@{
            'Workspace Id' = (Get-Prop -Object $ws -Name 'id')
            'Name' = (Get-Prop -Object $ws -Name 'name')
            'Type' = (Get-Prop -Object $ws -Name 'type')
            'State' = (Get-Prop -Object $ws -Name 'state')
            'IsOnDedicatedCapacity' = (Get-Prop -Object $ws -Name 'isOnDedicatedCapacity')
            'IsReadOnly' = (Get-Prop -Object $ws -Name 'isReadOnly')
        }
    }
}

# 3) Items: datasets, reports, dashboards, dataflows for each workspace
Write-Host "Collecting workspace items (datasets/reports/dashboards/dataflows)..." -ForegroundColor Cyan
$allItems = @()
foreach ($ws in $workspaces) {
    $gid = $ws.'Workspace Id'
    if (-not $gid) { continue }
    # datasets (use wrapper)
    $dsResult = Try-GetAdminEndpoint -RelativeUrl "admin/groups/$gid/datasets"
    if (-not $dsResult.Success) {
        if ($dsResult.Error -and $dsResult.Error -match 'PowerBIEntityNotFound') {
            Write-Host "Skipping workspace $gid ($($ws.Name)) - admin/entities not found or inaccessible." -ForegroundColor Yellow
            # record skipped workspace
                    if (-not (Get-Variable -Name SkippedWorkspaces -Scope Script -ErrorAction SilentlyContinue)) { Set-Variable -Name SkippedWorkspaces -Scope Script -Value @() -Force }
            $script:SkippedWorkspaces += $gid
            continue
        }
        else {
            Write-Host "Warning: failed to retrieve datasets for workspace $($gid): $($dsResult.Error)" -ForegroundColor Yellow
        }
    }
    else {
        foreach ($d in $dsResult.Data.value) {
            $allItems += [PSCustomObject]@{
                'WorkspaceId' = $gid
                'WorkspaceName' = $ws.Name
                'Id' = (Get-Prop -Object $d -Name 'id')
                'Name' = (Get-Prop -Object $d -Name 'name')
                'Type' = 'Dataset'
                'Details' = ''
            }
        }
    }

    # reports
    $rResult = Try-GetAdminEndpoint -RelativeUrl "admin/groups/$gid/reports"
    if ($rResult.Success) {
        foreach ($rep in $rResult.Data.value) {
            $allItems += [PSCustomObject]@{
                'WorkspaceId' = $gid
                'WorkspaceName' = $ws.Name
                'Id' = (Get-Prop -Object $rep -Name 'id')
                'Name' = (Get-Prop -Object $rep -Name 'name')
                'Type' = 'Report'
                'Details' = (Get-Prop -Object $rep -Name 'webUrl')
            }
        }
    }

    # dashboards
    $dbResult = Try-GetAdminEndpoint -RelativeUrl "admin/groups/$gid/dashboards"
    if ($dbResult.Success) {
        foreach ($dash in $dbResult.Data.value) {
            $allItems += [PSCustomObject]@{
                'WorkspaceId' = $gid
                'WorkspaceName' = $ws.Name
                'Id' = (Get-Prop -Object $dash -Name 'id')
                'Name' = (Get-Prop -Object $dash -Name 'displayName')
                'Type' = 'Dashboard'
                'Details' = ''
            }
        }
    }

    # dataflows
    $dfResult = Try-GetAdminEndpoint -RelativeUrl "admin/groups/$gid/dataflows"
    if ($dfResult.Success) {
        foreach ($flow in $dfResult.Data.value) {
            $allItems += [PSCustomObject]@{
                'WorkspaceId' = $gid
                'WorkspaceName' = $ws.Name
                'Id' = (Get-Prop -Object $flow -Name 'objectId')
                'Name' = (Get-Prop -Object $flow -Name 'name')
                'Type' = 'Dataflow'
                'Details' = ''
            }
        }
    }
}

# 4) Semantic models (basic dataset details)
Write-Host "Retrieving dataset (semantic model) details..." -ForegroundColor Cyan
$semanticModels = @()
$datasets = $allItems | Where-Object { $_.Type -eq 'Dataset' }
$skippedDatasets = @()
foreach ($ds in $datasets) {
    $did = $ds.Id
    $detResult = Try-GetAdminEndpoint -RelativeUrl "admin/datasets/$did"
    if ($detResult.Success) {
        $det = $detResult.Data
        
        $semanticModels += [PSCustomObject]@{
            'DatasetId' = $did
            'Name' = $ds.Name
            'WorkspaceId' = $ds.WorkspaceId
            'WorkspaceName' = $ds.WorkspaceName
            'ConfiguredBy' = Get-Prop -Object $det -Name 'configuredBy'
            'IsRefreshable' = Get-Prop -Object $det -Name 'isRefreshable'
            'IsEffectiveIdentityRequired' = Get-Prop -Object $det -Name 'isEffectiveIdentityRequired'
            'TargetStorageMode' = Get-Prop -Object $det -Name 'targetStorageMode'
            'ContentProviderType' = Get-Prop -Object $det -Name 'contentProviderType'
            'IsOnPremGatewayRequired' = Get-Prop -Object $det -Name 'isOnPremGatewayRequired'
        }
    }
    else {
        # Dataset not accessible - may be orphaned, deleted, or permission issue
        $skippedDatasets += [PSCustomObject]@{
            DatasetId = $did
            Name = $ds.Name
            WorkspaceId = $ds.WorkspaceId
            Reason = $detResult.Error
        }
    }
}

# Prepare Summary Data
Write-Host "Preparing summary data..." -ForegroundColor Cyan

# Count items by type
$itemCounts = $allItems | Group-Object -Property Type | Select-Object @{Name='ItemType';Expression={$_.Name}}, Count
$summaryData = @()

$summaryData += [PSCustomObject]@{ 'Metric' = 'Total Capacities'; 'Count' = $capacities.Count }
$summaryData += [PSCustomObject]@{ 'Metric' = 'Total Workspaces'; 'Count' = $workspaces.Count }
$summaryData += [PSCustomObject]@{ 'Metric' = 'Total Items'; 'Count' = $allItems.Count }

foreach ($itemCount in $itemCounts) {
    $summaryData += [PSCustomObject]@{ 
        'Metric' = "Total $($itemCount.ItemType)s"
        'Count' = $itemCount.Count 
    }
}

$summaryData += [PSCustomObject]@{ 'Metric' = 'Accessible Datasets (with details)'; 'Count' = $semanticModels.Count }
if ($skippedDatasets.Count -gt 0) {
    $summaryData += [PSCustomObject]@{ 'Metric' = 'Skipped Datasets (inaccessible)'; 'Count' = $skippedDatasets.Count }
}

# Export to Excel with multiple sheets
Write-Host "Exporting data to Excel workbook..." -ForegroundColor Cyan
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$excelPath = Join-Path $OutputPath "FabricCapacityDiscovery_$timestamp.xlsx"

# Remove existing file if present
if (Test-Path $excelPath) { Remove-Item $excelPath -Force }

# Export each collection to a separate sheet
$summaryData | Export-Excel -Path $excelPath -WorksheetName 'Summary' -AutoSize -AutoFilter -FreezeTopRow -BoldTopRow
$capacities | Export-Excel -Path $excelPath -WorksheetName 'Capacities' -AutoSize -AutoFilter -FreezeTopRow -BoldTopRow
$workspaces | Export-Excel -Path $excelPath -WorksheetName 'Workspaces' -AutoSize -AutoFilter -FreezeTopRow -BoldTopRow
$allItems | Export-Excel -Path $excelPath -WorksheetName 'Items' -AutoSize -AutoFilter -FreezeTopRow -BoldTopRow
$semanticModels | Export-Excel -Path $excelPath -WorksheetName 'SemanticModels' -AutoSize -AutoFilter -FreezeTopRow -BoldTopRow

if ($skippedDatasets.Count -gt 0) {
    $skippedDatasets | Export-Excel -Path $excelPath -WorksheetName 'SkippedDatasets' -AutoSize -AutoFilter -FreezeTopRow -BoldTopRow
    Write-Host "Note: $($skippedDatasets.Count) dataset(s) could not be accessed. See 'SkippedDatasets' sheet for details." -ForegroundColor Yellow
}

Write-Host "Excel export complete: $excelPath" -ForegroundColor Green
Write-Host "Done. Open the Excel file to view the complete discovery report." -ForegroundColor Cyan
