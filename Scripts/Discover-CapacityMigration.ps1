<#
.SYNOPSIS
    Discovers Power BI Premium/Fabric capacities and analyzes migration readiness.

.DESCRIPTION
    This script performs comprehensive discovery of Power BI Premium/Embedded capacities
    and identifies potential blockers for migration to Microsoft Fabric capacities.
    
    Outputs include:
    - CSV files for each entity type (Capacities, Workspaces, Items, Semantic Models)
    - Migration blocker analysis report
    - HTML summary report with visualizations
    
.PARAMETER OutputPath
    Path where discovery results will be saved. Defaults to current directory.

.PARAMETER TenantId
    Azure AD Tenant ID (optional for interactive login).

.PARAMETER ServicePrincipalId
    Service Principal (Application) ID for non-interactive authentication.

.PARAMETER ServicePrincipalSecret
    Service Principal secret/password.

.PARAMETER GenerateHtmlReport
    Generate an HTML summary report with charts. Defaults to $true.

.EXAMPLE
    .\Discover-CapacityMigration.ps1 -OutputPath "C:\Reports"
    
    Interactive login with output to C:\Reports folder.

.EXAMPLE
    .\Discover-CapacityMigration.ps1 -TenantId "xxx-xxx" -ServicePrincipalId "yyy-yyy" -ServicePrincipalSecret "zzz"
    
    Non-interactive authentication using service principal.

.NOTES
    Author: Microsoft Fabric Migration Tool
    Version: 1.0.0
    Requires: MicrosoftPowerBIMgmt PowerShell module
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".",
    
    [Parameter(Mandatory=$false)]
    [string]$TenantId,
    
    [Parameter(Mandatory=$false)]
    [string]$ServicePrincipalId,
    
    [Parameter(Mandatory=$false)]
    [string]$ServicePrincipalSecret,
    
    [Parameter(Mandatory=$false)]
    [bool]$GenerateHtmlReport = $true
)

# ============================================================================
# INITIALIZATION
# ============================================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Create timestamped output folder
$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$outputFolder = Join-Path $OutputPath "CapacityMigration_$timestamp"
New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null

Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "FABRIC CAPACITY MIGRATION DISCOVERY TOOL" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "Output folder: $outputFolder" -ForegroundColor Gray
Write-Host ""

# ============================================================================
# MODULE INSTALLATION & IMPORT
# ============================================================================

Write-Host "Checking PowerShell module..." -ForegroundColor Yellow

if (-not (Get-Module -ListAvailable -Name MicrosoftPowerBIMgmt)) {
    Write-Host "  Installing MicrosoftPowerBIMgmt module..." -ForegroundColor Gray
    Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser -Force -AllowClobber
}

Import-Module MicrosoftPowerBIMgmt
Write-Host "✓ Module ready" -ForegroundColor Green
Write-Host ""

# ============================================================================
# AUTHENTICATION
# ============================================================================

Write-Host "Authenticating to Power BI..." -ForegroundColor Yellow

try {
    if ($ServicePrincipalId -and $ServicePrincipalSecret) {
        # Service Principal authentication
        $securePassword = ConvertTo-SecureString $ServicePrincipalSecret -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($ServicePrincipalId, $securePassword)
        
        Connect-PowerBIServiceAccount -ServicePrincipal -Credential $credential -TenantId $TenantId
        Write-Host "✓ Connected using Service Principal" -ForegroundColor Green
    }
    else {
        # Interactive authentication
        if ($TenantId) {
            Connect-PowerBIServiceAccount -Tenant $TenantId
        }
        else {
            Connect-PowerBIServiceAccount
        }
        Write-Host "✓ Connected interactively" -ForegroundColor Green
    }
}
catch {
    Write-Host "✗ Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ============================================================================
# DATA COLLECTION - CAPACITIES
# ============================================================================

Write-Host "Collecting capacity data..." -ForegroundColor Yellow

try {
    $capacities = @()
    
    # Get all capacities using Admin API
    $capacitiesResponse = Invoke-PowerBIRestMethod -Url "admin/capacities" -Method Get | ConvertFrom-Json
    
    foreach ($cap in $capacitiesResponse.value) {
        $capacities += [PSCustomObject]@{
            'Capacity Id' = $cap.id
            'Capacity Name' = $cap.displayName
            'SKU' = $cap.sku
            'State' = $cap.state
            'Region' = $cap.region
            'Admins' = ($cap.admins.emailAddress -join '; ')
        }
    }
    
    # Add placeholder for shared capacity
    $capacities += [PSCustomObject]@{
        'Capacity Id' = '-1'
        'Capacity Name' = 'Non Premium (Shared)'
        'SKU' = 'Shared'
        'State' = 'Active'
        'Region' = 'N/A'
        'Admins' = 'N/A'
    }
    
    Write-Host "  ✓ Found $($capacities.Count - 1) Premium/Fabric capacities" -ForegroundColor Green
    
    # Group by SKU
    $skuSummary = $capacities | Where-Object { $_.'Capacity Id' -ne '-1' } | Group-Object -Property SKU
    foreach ($sku in $skuSummary) {
        Write-Host "    • $($sku.Name): $($sku.Count)" -ForegroundColor Gray
    }
    
    # Export to CSV
    $capacitiesPath = Join-Path $outputFolder "Capacities.csv"
    $capacities | Export-Csv -Path $capacitiesPath -NoTypeInformation
    Write-Host "  ✓ Saved to Capacities.csv" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    throw
}

Write-Host ""

# ============================================================================
# DATA COLLECTION - WORKSPACES
# ============================================================================

Write-Host "Collecting workspace data..." -ForegroundColor Yellow

try {
    $workspaces = @()
    
    # Get all workspaces
    $workspacesResponse = Invoke-PowerBIRestMethod -Url "admin/groups?`$top=5000" -Method Get | ConvertFrom-Json
    
    foreach ($ws in $workspacesResponse.value) {
        $workspaces += [PSCustomObject]@{
            'Workspace Id' = $ws.id
            'Workspace Name' = $ws.name
            'State' = $ws.state
            'Type' = $ws.type
            'Capacity Id' = if ($ws.capacityId) { $ws.capacityId } else { '-1' }
            'Is Read Only' = $ws.isReadOnly
            'Is On Dedicated Capacity' = $ws.isOnDedicatedCapacity
        }
    }
    
    Write-Host "  ✓ Found $($workspaces.Count) workspaces" -ForegroundColor Green
    
    $premiumCount = ($workspaces | Where-Object { $_.'Capacity Id' -ne '-1' }).Count
    $sharedCount = ($workspaces | Where-Object { $_.'Capacity Id' -eq '-1' }).Count
    
    Write-Host "    • Premium/Fabric: $premiumCount" -ForegroundColor Gray
    Write-Host "    • Shared: $sharedCount" -ForegroundColor Gray
    
    # Export to CSV
    $workspacesPath = Join-Path $outputFolder "Workspaces.csv"
    $workspaces | Export-Csv -Path $workspacesPath -NoTypeInformation
    Write-Host "  ✓ Saved to Workspaces.csv" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    throw
}

Write-Host ""

# ============================================================================
# DATA COLLECTION - WORKSPACE ITEMS
# ============================================================================

Write-Host "Collecting workspace items (this may take a few minutes)..." -ForegroundColor Yellow

try {
    $allItems = @()
    $processedWorkspaces = 0
    
    foreach ($ws in $workspaces) {
        $processedWorkspaces++
        if ($processedWorkspaces % 50 -eq 0) {
            Write-Host "  • Processing workspace $processedWorkspaces of $($workspaces.Count)..." -ForegroundColor Gray
        }
        
        try {
            # Get all items in workspace (reports, datasets, dashboards, dataflows, etc.)
            $itemsResponse = Invoke-PowerBIRestMethod -Url "admin/groups/$($ws.'Workspace Id')/datasets" -Method Get | ConvertFrom-Json
            
            foreach ($item in $itemsResponse.value) {
                $allItems += [PSCustomObject]@{
                    'Workspace Id' = $ws.'Workspace Id'
                    'Workspace Name' = $ws.'Workspace Name'
                    'Item Id' = $item.id
                    'Item Name' = $item.name
                    'Type' = 'Dataset'
                    'Configured By' = $item.configuredBy
                    'Is Refreshable' = $item.isRefreshable
                }
            }
            
            # Get reports
            $reportsResponse = Invoke-PowerBIRestMethod -Url "admin/groups/$($ws.'Workspace Id')/reports" -Method Get | ConvertFrom-Json
            
            foreach ($report in $reportsResponse.value) {
                $allItems += [PSCustomObject]@{
                    'Workspace Id' = $ws.'Workspace Id'
                    'Workspace Name' = $ws.'Workspace Name'
                    'Item Id' = $report.id
                    'Item Name' = $report.name
                    'Type' = 'Report'
                    'Dataset Id' = $report.datasetId
                    'Report Type' = $report.reportType
                }
            }
            
            # Get dashboards
            $dashboardsResponse = Invoke-PowerBIRestMethod -Url "admin/groups/$($ws.'Workspace Id')/dashboards" -Method Get | ConvertFrom-Json
            
            foreach ($dashboard in $dashboardsResponse.value) {
                $allItems += [PSCustomObject]@{
                    'Workspace Id' = $ws.'Workspace Id'
                    'Workspace Name' = $ws.'Workspace Name'
                    'Item Id' = $dashboard.id
                    'Item Name' = $dashboard.displayName
                    'Type' = 'Dashboard'
                }
            }
            
            # Get dataflows
            $dataflowsResponse = Invoke-PowerBIRestMethod -Url "admin/groups/$($ws.'Workspace Id')/dataflows" -Method Get | ConvertFrom-Json
            
            foreach ($dataflow in $dataflowsResponse.value) {
                $allItems += [PSCustomObject]@{
                    'Workspace Id' = $ws.'Workspace Id'
                    'Workspace Name' = $ws.'Workspace Name'
                    'Item Id' = $dataflow.objectId
                    'Item Name' = $dataflow.name
                    'Type' = 'Dataflow'
                }
            }
        }
        catch {
            # Skip workspaces we can't access
            continue
        }
    }
    
    Write-Host "  ✓ Found $($allItems.Count) items across all workspaces" -ForegroundColor Green
    
    $itemTypeSummary = $allItems | Group-Object -Property Type
    foreach ($type in $itemTypeSummary) {
        Write-Host "    • $($type.Name): $($type.Count)" -ForegroundColor Gray
    }
    
    # Export to CSV
    $itemsPath = Join-Path $outputFolder "WorkspaceItems.csv"
    $allItems | Export-Csv -Path $itemsPath -NoTypeInformation
    Write-Host "  ✓ Saved to WorkspaceItems.csv" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    throw
}

Write-Host ""

# ============================================================================
# DATA COLLECTION - SEMANTIC MODELS (Detailed)
# ============================================================================

Write-Host "Collecting detailed semantic model information..." -ForegroundColor Yellow

try {
    $semanticModels = @()
    $datasets = $allItems | Where-Object { $_.Type -eq 'Dataset' }
    
    Write-Host "  • Analyzing $($datasets.Count) semantic models..." -ForegroundColor Gray
    
    $processedDatasets = 0
    foreach ($dataset in $datasets) {
        $processedDatasets++
        
        try {
            # Get dataset details
            $datasetDetails = Invoke-PowerBIRestMethod -Url "admin/datasets/$($dataset.'Item Id')" -Method Get | ConvertFrom-Json
            
            $semanticModels += [PSCustomObject]@{
                'Dataset Id' = $dataset.'Item Id'
                'Dataset Name' = $dataset.'Item Name'
                'Workspace Id' = $dataset.'Workspace Id'
                'Workspace Name' = $dataset.'Workspace Name'
                'Configured By' = $dataset.'Configured By'
                'Is Refreshable' = $dataset.'Is Refreshable'
                'Target Storage Mode' = $datasetDetails.targetStorageMode
                'Is Effective Identity Required' = $datasetDetails.isEffectiveIdentityRequired
                'Is Effective Identity Roles Required' = $datasetDetails.isEffectiveIdentityRolesRequired
                'Created Date' = $datasetDetails.createdDate
            }
        }
        catch {
            # Add basic info if we can't get details
            $semanticModels += [PSCustomObject]@{
                'Dataset Id' = $dataset.'Item Id'
                'Dataset Name' = $dataset.'Item Name'
                'Workspace Id' = $dataset.'Workspace Id'
                'Workspace Name' = $dataset.'Workspace Name'
                'Configured By' = $dataset.'Configured By'
                'Is Refreshable' = $dataset.'Is Refreshable'
                'Target Storage Mode' = 'Unknown'
            }
        }
    }
    
    Write-Host "  ✓ Collected details for $($semanticModels.Count) semantic models" -ForegroundColor Green
    
    # Storage mode summary
    $storageModes = $semanticModels | Group-Object -Property 'Target Storage Mode'
    foreach ($mode in $storageModes) {
        Write-Host "    • $($mode.Name): $($mode.Count)" -ForegroundColor Gray
    }
    
    # Export to CSV
    $semanticModelsPath = Join-Path $outputFolder "SemanticModels.csv"
    $semanticModels | Export-Csv -Path $semanticModelsPath -NoTypeInformation
    Write-Host "  ✓ Saved to SemanticModels.csv" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    throw
}

Write-Host ""

# ============================================================================
# MIGRATION BLOCKER ANALYSIS
# ============================================================================

Write-Host "Analyzing migration blockers..." -ForegroundColor Yellow
Write-Host ""

$blockers = @()
$warnings = @()
$infoItems = @()

# 1. Check for Embedded (EM) SKUs
$emSkus = $capacities | Where-Object { $_.'SKU' -like 'EM*' -or $_.'SKU' -like 'A*' }
foreach ($cap in $emSkus) {
    if ($cap.SKU -like 'EM*') {
        $blockers += "Embedded capacity '$($cap.'Capacity Name')' (SKU: $($cap.SKU)) - EM SKUs not supported in Fabric. Migrate to F-SKUs."
    }
    elseif ($cap.SKU -like 'A*') {
        $infoItems += "Azure capacity '$($cap.'Capacity Name')' (SKU: $($cap.SKU)) - Azure Embedded can migrate to Fabric F-SKUs."
    }
}

# 2. Check for Premium P SKUs (ready for migration)
$pSkus = $capacities | Where-Object { $_.'SKU' -like 'P*' -and $_.'Capacity Id' -ne '-1' }
if ($pSkus.Count -gt 0) {
    $infoItems += "$($pSkus.Count) Premium P-SKU capacities found - Ready for Fabric migration"
}

# 3. Check for cross-region capacities
$regions = ($capacities | Where-Object { $_.Region -ne 'N/A' } | Select-Object -ExpandProperty Region -Unique)
if ($regions.Count -gt 1) {
    $warnings += "Multiple regions detected: $($regions -join ', '). Fabric capacities are region-specific. Plan migrations within same region."
}

# 4. Check for Dataflows Gen1
$dataflowsGen1 = $allItems | Where-Object { $_.Type -eq 'Dataflow' }
if ($dataflowsGen1.Count -gt 0) {
    $warnings += "$($dataflowsGen1.Count) Dataflow Gen1 artifacts found. Consider upgrading to Dataflow Gen2 or Data Pipelines in Fabric."
}

# 5. Check for Paginated Reports
$paginatedReports = $allItems | Where-Object { $_.'Report Type' -eq 'PaginatedReport' }
if ($paginatedReports.Count -gt 0) {
    $warnings += "$($paginatedReports.Count) Paginated Reports found. Ensure Fabric capacity has paginated report workload enabled."
}

# 6. Check for Large Models (Premium Files)
$largeModels = $semanticModels | Where-Object { $_.'Target Storage Mode' -eq 'PremiumFiles' }
if ($largeModels.Count -gt 0) {
    $warnings += "$($largeModels.Count) Large Models (>10GB) detected. Verify target Fabric capacity size supports these models."
}

# 7. Check for Inactive Workspaces
$inactiveWorkspaces = $workspaces | Where-Object { $_.State -ne 'Active' }
if ($inactiveWorkspaces.Count -gt 0) {
    $warnings += "$($inactiveWorkspaces.Count) inactive workspaces found. Review and clean up before migration."
}

# 8. Check for Models with RLS
$rlsModels = $semanticModels | Where-Object { $_.'Is Effective Identity Required' -eq 'True' }
if ($rlsModels.Count -gt 0) {
    $infoItems += "$($rlsModels.Count) semantic models with Row-Level Security (RLS). Test RLS behavior after migration, especially with DirectLake."
}

# 9. Check for Dashboards
$dashboards = $allItems | Where-Object { $_.Type -eq 'Dashboard' }
if ($dashboards.Count -gt 0) {
    $infoItems += "$($dashboards.Count) Dashboards found. Dashboards migrate with their tiles and data sources."
}

# Display results
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "MIGRATION READINESS ASSESSMENT" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""

if ($blockers.Count -gt 0) {
    Write-Host "🛑 CRITICAL BLOCKERS (Must resolve before migration):" -ForegroundColor Red
    Write-Host "=" * 70 -ForegroundColor Red
    for ($i = 0; $i -lt $blockers.Count; $i++) {
        Write-Host "$($i + 1). $($blockers[$i])" -ForegroundColor Red
    }
    Write-Host ""
}

if ($warnings.Count -gt 0) {
    Write-Host "⚠️  WARNINGS (Review and plan accordingly):" -ForegroundColor Yellow
    Write-Host "=" * 70 -ForegroundColor Yellow
    for ($i = 0; $i -lt $warnings.Count; $i++) {
        Write-Host "$($i + 1). $($warnings[$i])" -ForegroundColor Yellow
    }
    Write-Host ""
}

if ($infoItems.Count -gt 0) {
    Write-Host "ℹ️  INFORMATIONAL (For your awareness):" -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
    for ($i = 0; $i -lt $infoItems.Count; $i++) {
        Write-Host "$($i + 1). $($infoItems[$i])" -ForegroundColor Cyan
    }
    Write-Host ""
}

if ($blockers.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "✅ MIGRATION READY" -ForegroundColor Green
    Write-Host "=" * 70 -ForegroundColor Green
    Write-Host "No critical blockers or warnings detected." -ForegroundColor Green
    Write-Host "Your environment appears ready for Fabric migration." -ForegroundColor Green
    Write-Host ""
}

# Save analysis to CSV
$analysisResults = [PSCustomObject]@{
    'Analysis Date' = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    'Total Capacities' = $capacities.Count - 1
    'Total Workspaces' = $workspaces.Count
    'Total Items' = $allItems.Count
    'Total Semantic Models' = $semanticModels.Count
    'Blocker Count' = $blockers.Count
    'Warning Count' = $warnings.Count
    'Info Count' = $infoItems.Count
    'Blockers' = ($blockers -join ' | ')
    'Warnings' = ($warnings -join ' | ')
    'Info' = ($infoItems -join ' | ')
}

$analysisPath = Join-Path $outputFolder "MigrationAnalysis.csv"
$analysisResults | Export-Csv -Path $analysisPath -NoTypeInformation
Write-Host "✓ Analysis saved to MigrationAnalysis.csv" -ForegroundColor Green
Write-Host ""

# ============================================================================
# GENERATE HTML REPORT
# ============================================================================

if ($GenerateHtmlReport) {
    Write-Host "Generating HTML summary report..." -ForegroundColor Yellow
    
    $htmlPath = Join-Path $outputFolder "MigrationSummary.html"
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Fabric Capacity Migration Discovery Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #0078D4; border-bottom: 3px solid #0078D4; padding-bottom: 10px; }
        h2 { color: #005A9E; margin-top: 30px; }
        .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .summary-card { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; text-align: center; }
        .summary-card h3 { margin: 0; font-size: 36px; font-weight: bold; }
        .summary-card p { margin: 5px 0 0 0; font-size: 14px; opacity: 0.9; }
        .blocker { background-color: #fff4f4; border-left: 4px solid #d13438; padding: 15px; margin: 10px 0; border-radius: 4px; }
        .warning { background-color: #fffbf0; border-left: 4px solid #ff8c00; padding: 15px; margin: 10px 0; border-radius: 4px; }
        .info { background-color: #f0f7ff; border-left: 4px solid #0078D4; padding: 15px; margin: 10px 0; border-radius: 4px; }
        .success { background-color: #f0fff4; border-left: 4px solid #107c10; padding: 15px; margin: 10px 0; border-radius: 4px; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th { background-color: #0078D4; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:hover { background-color: #f5f5f5; }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; text-align: center; color: #666; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔍 Fabric Capacity Migration Discovery Report</h1>
        <p><strong>Generated:</strong> $(Get-Date -Format "MMMM dd, yyyy HH:mm:ss")</p>
        
        <div class="summary-grid">
            <div class="summary-card" style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);">
                <h3>$($capacities.Count - 1)</h3>
                <p>Capacities</p>
            </div>
            <div class="summary-card" style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);">
                <h3>$($workspaces.Count)</h3>
                <p>Workspaces</p>
            </div>
            <div class="summary-card" style="background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);">
                <h3>$($allItems.Count)</h3>
                <p>Items</p>
            </div>
            <div class="summary-card" style="background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%);">
                <h3>$($semanticModels.Count)</h3>
                <p>Semantic Models</p>
            </div>
        </div>
        
        <h2>📊 Migration Readiness Assessment</h2>
        
"@

    if ($blockers.Count -eq 0 -and $warnings.Count -eq 0) {
        $html += @"
        <div class="success">
            <strong>✅ MIGRATION READY</strong><br>
            No critical blockers or warnings detected. Your environment appears ready for Fabric migration.
        </div>
"@
    }
    
    if ($blockers.Count -gt 0) {
        $html += "<h3>🛑 Critical Blockers ($($blockers.Count))</h3>"
        foreach ($blocker in $blockers) {
            $html += "<div class='blocker'>$blocker</div>"
        }
    }
    
    if ($warnings.Count -gt 0) {
        $html += "<h3>⚠️ Warnings ($($warnings.Count))</h3>"
        foreach ($warning in $warnings) {
            $html += "<div class='warning'>$warning</div>"
        }
    }
    
    if ($infoItems.Count -gt 0) {
        $html += "<h3>ℹ️ Informational ($($infoItems.Count))</h3>"
        foreach ($info in $infoItems) {
            $html += "<div class='info'>$info</div>"
        }
    }
    
    $html += @"
        
        <h2>📁 Capacity Summary</h2>
        <table>
            <tr>
                <th>Capacity Name</th>
                <th>SKU</th>
                <th>Region</th>
                <th>State</th>
            </tr>
"@

    foreach ($cap in ($capacities | Where-Object { $_.'Capacity Id' -ne '-1' })) {
        $html += @"
            <tr>
                <td>$($cap.'Capacity Name')</td>
                <td>$($cap.SKU)</td>
                <td>$($cap.Region)</td>
                <td>$($cap.State)</td>
            </tr>
"@
    }
    
    $html += @"
        </table>
        
        <h2>📂 Export Files</h2>
        <p>Detailed data has been exported to the following CSV files:</p>
        <ul>
            <li><strong>Capacities.csv</strong> - All capacity details</li>
            <li><strong>Workspaces.csv</strong> - All workspace information</li>
            <li><strong>WorkspaceItems.csv</strong> - All items (reports, datasets, dashboards, dataflows)</li>
            <li><strong>SemanticModels.csv</strong> - Detailed semantic model information</li>
            <li><strong>MigrationAnalysis.csv</strong> - Migration blocker analysis summary</li>
        </ul>
        
        <div class="footer">
            Microsoft Fabric Capacity Migration Discovery Tool v1.0.0<br>
            Report Location: $outputFolder
        </div>
    </div>
</body>
</html>
"@

    $html | Out-File -FilePath $htmlPath -Encoding UTF8
    Write-Host "  ✓ HTML report saved to MigrationSummary.html" -ForegroundColor Green
    Write-Host ""
}

# ============================================================================
# COMPLETION
# ============================================================================

Write-Host "=" * 70 -ForegroundColor Green
Write-Host "✅ DISCOVERY COMPLETE" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Green
Write-Host ""
Write-Host "Output location: $outputFolder" -ForegroundColor Cyan
Write-Host ""
Write-Host "Files generated:" -ForegroundColor White
Write-Host "  • Capacities.csv" -ForegroundColor Gray
Write-Host "  • Workspaces.csv" -ForegroundColor Gray
Write-Host "  • WorkspaceItems.csv" -ForegroundColor Gray
Write-Host "  • SemanticModels.csv" -ForegroundColor Gray
Write-Host "  • MigrationAnalysis.csv" -ForegroundColor Gray
if ($GenerateHtmlReport) {
    Write-Host "  • MigrationSummary.html" -ForegroundColor Gray
}
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Review the MigrationSummary.html report" -ForegroundColor White
Write-Host "  2. Address any critical blockers identified" -ForegroundColor White
Write-Host "  3. Plan your migration strategy based on findings" -ForegroundColor White
Write-Host "  4. Import CSVs into Power BI for detailed analysis (optional)" -ForegroundColor White
Write-Host ""

# Open HTML report if generated
if ($GenerateHtmlReport) {
    $openReport = Read-Host "Open HTML report now? (Y/N)"
    if ($openReport -eq 'Y' -or $openReport -eq 'y') {
        Start-Process $htmlPath
    }
}
