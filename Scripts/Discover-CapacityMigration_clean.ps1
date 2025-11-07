<#
Discover-CapacityMigration_clean.ps1

Lightweight, self-contained script to:
- Authenticate to Power BI (interactive or service principal)
- Discover capacities, workspaces, items (datasets, reports, dashboards, dataflows)
- Retrieve basic dataset (semantic model) details
- Export results to CSV files
- Produce a small HTML summary with links to CSVs

Requirements:
- PowerShell 5.1+ (or PowerShell 7+)
- MicrosoftPowerBIMgmt module (script will prompt to install if missing)

Usage example:
.
    .\Scripts\Discover-CapacityMigration_clean.ps1 -OutputPath .\output -GenerateHtmlReport

#>

param(
    [string]$OutputPath = "$PSScriptRoot\output",
    [string]$TenantId = $null,
    [string]$ServicePrincipalId = $null,
    [string]$ServicePrincipalSecret = $null,
    [switch]$GenerateHtmlReport
)

Set-StrictMode -Version Latest

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
}
catch {
    Write-Host "Failed to install/load MicrosoftPowerBIMgmt: $($_.Exception.Message)" -ForegroundColor Red
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
    try {
        $resp = Invoke-PowerBIRestMethod -Url $RelativeUrl -Method Get -ErrorAction Stop
        return $resp | ConvertFrom-Json
    }
    catch {
        Write-Host "Failed to call $RelativeUrl : $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

# 1) Capacities
Write-Host "Retrieving capacities..." -ForegroundColor Cyan
$capacitiesRaw = Get-AdminEndpoint -RelativeUrl 'admin/capacities'
$capacities = @()
if ($capacitiesRaw) {
    foreach ($c in $capacitiesRaw.value) {
        $capacities += [PSCustomObject]@{
            'Capacity Id' = $c.id
            'Name' = $c.displayName
            'SKU' = $c.sku
            'State' = $c.state
            'Region' = $c.location
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
            'Workspace Id' = $ws.id
            'Name' = $ws.name
            'State' = $ws.state
            'Capacity Id' = $ws.capacityId
            'IsReadOnly' = $ws.isReadOnly
            'CreatedDate' = $ws.createdDateTime
        }
    }
}

# 3) Items: datasets, reports, dashboards, dataflows for each workspace
Write-Host "Collecting workspace items (datasets/reports/dashboards/dataflows)..." -ForegroundColor Cyan
$allItems = @()
foreach ($ws in $workspaces) {
    $gid = $ws.'Workspace Id'
    if (-not $gid) { continue }

    # datasets
    $ds = Get-AdminEndpoint -RelativeUrl "admin/groups/$gid/datasets"
    if ($ds -and $ds.value) {
        foreach ($d in $ds.value) {
            $allItems += [PSCustomObject]@{
                'WorkspaceId' = $gid
                'WorkspaceName' = $ws.Name
                'Id' = $d.id
                'Name' = $d.name
                'Type' = 'Dataset'
                'Details' = ''
            }
        }
    }

    # reports
    $r = Get-AdminEndpoint -RelativeUrl "admin/groups/$gid/reports"
    if ($r -and $r.value) {
        foreach ($rep in $r.value) {
            $allItems += [PSCustomObject]@{
                'WorkspaceId' = $gid
                'WorkspaceName' = $ws.Name
                'Id' = $rep.id
                'Name' = $rep.name
                'Type' = 'Report'
                'Details' = $rep.webUrl
            }
        }
    }

    # dashboards
    $db = Get-AdminEndpoint -RelativeUrl "admin/groups/$gid/dashboards"
    if ($db -and $db.value) {
        foreach ($dash in $db.value) {
            $allItems += [PSCustomObject]@{
                'WorkspaceId' = $gid
                'WorkspaceName' = $ws.Name
                'Id' = $dash.id
                'Name' = $dash.displayName
                'Type' = 'Dashboard'
                'Details' = ''
            }
        }
    }

    # dataflows
    $df = Get-AdminEndpoint -RelativeUrl "admin/groups/$gid/dataflows"
    if ($df -and $df.value) {
        foreach ($flow in $df.value) {
            $allItems += [PSCustomObject]@{
                'WorkspaceId' = $gid
                'WorkspaceName' = $ws.Name
                'Id' = $flow.objectId
                'Name' = $flow.name
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
foreach ($ds in $datasets) {
    $did = $ds.Id
    $det = Get-AdminEndpoint -RelativeUrl "admin/datasets/$did"
    if ($det) {
        $semanticModels += [PSCustomObject]@{
            'DatasetId' = $did
            'Name' = $ds.Name
            'WorkspaceId' = $ds.WorkspaceId
            'WorkspaceName' = $ds.WorkspaceName
            'IsRefreshable' = $det.isRefreshable
            'IsEffectiveIdentityRequired' = $det.isEffectiveIdentityRequired
            'TargetStorageMode' = if ($det.tables) { ($det.tables | Select-Object -First 1).storageMode } else { '' }
            'ModelSize' = if ($det.size) { $det.size } else { '' }
        }
    }
}

# Export CSVs
Write-Host "Exporting CSV files to $OutputPath" -ForegroundColor Cyan
$capacities | Export-Csv -Path (Join-Path $OutputPath 'Capacities.csv') -NoTypeInformation -Force
$workspaces | Export-Csv -Path (Join-Path $OutputPath 'Workspaces.csv') -NoTypeInformation -Force
$allItems | Export-Csv -Path (Join-Path $OutputPath 'Items.csv') -NoTypeInformation -Force
$semanticModels | Export-Csv -Path (Join-Path $OutputPath 'SemanticModels.csv') -NoTypeInformation -Force

Write-Host "CSV export complete." -ForegroundColor Green

# Small summary
$summary = [PSCustomObject]@{
    'Date' = Get-Date -Format 'u'
    'Capacities' = $capacities.Count
    'Workspaces' = $workspaces.Count
    'Items' = $allItems.Count
    'Datasets' = $semanticModels.Count
}

if ($GenerateHtmlReport) {
    Write-Host "Generating HTML summary..." -ForegroundColor Cyan

    $htmlPath = Join-Path $OutputPath 'MigrationSummary.html'

$html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Fabric Capacity Migration - Summary</title>
  <style>
    body { font-family: Arial, Helvetica, sans-serif; margin: 24px; }
    .summary { display:flex; gap:16px; margin-bottom:18px }
    .card { padding:12px; border:1px solid #ddd; border-radius:6px; min-width:140px }
    table { border-collapse: collapse; width:100% }
    th, td { border:1px solid #ccc; padding:6px }
    th { background:#0078D4; color:white }
  </style>
</head>
<body>
  <h1>Fabric Capacity Migration — Summary</h1>
  <div class="summary">
    <div class="card"><strong>Capacities</strong><div>$($summary.Capacities)</div></div>
    <div class="card"><strong>Workspaces</strong><div>$($summary.Workspaces)</div></div>
    <div class="card"><strong>Items</strong><div>$($summary.Items)</div></div>
    <div class="card"><strong>Datasets</strong><div>$($summary.Datasets)</div></div>
  </div>

  <h2>Downloads</h2>
  <ul>
    <li><a href="Capacities.csv">Capacities.csv</a></li>
    <li><a href="Workspaces.csv">Workspaces.csv</a></li>
    <li><a href="Items.csv">Items.csv</a></li>
    <li><a href="SemanticModels.csv">SemanticModels.csv</a></li>
  </ul>

  <h2>Notes</h2>
  <p>This is a lightweight discovery report. For full migration analysis, run the script with appropriate service principal credentials and review the exported CSVs in Power BI or Excel.</p>

  <script>
    // Simple client-side table preview (load CSVs) - optional
    async function loadCsv(name, containerId) {
      try {
        const res = await fetch(name);
        const txt = await res.text();
        const rows = txt.split('\n').slice(0,6).map(r => r.split(','));
        const table = document.createElement('table');
        rows.forEach((cols, ri) => {
          const tr = document.createElement('tr');
          cols.forEach(c => { const cell = document.createElement(ri===0? 'th':'td'); cell.textContent = c; tr.appendChild(cell) });
          table.appendChild(tr)
        });
        document.getElementById(containerId).appendChild(table);
      } catch(e) { console.warn('Unable to load', name, e) }
    }
  </script>

</body>
</html>
"@

    $html | Out-File -FilePath $htmlPath -Encoding UTF8 -Force
    Write-Host "HTML summary written to $htmlPath" -ForegroundColor Green
}

Write-Host "Done." -ForegroundColor Cyan
