# Fabric Capacity Migration Discovery

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue)](https://docs.microsoft.com/powershell/)

> **Automated discovery tool for Microsoft Fabric and Power BI capacity migration planning**

---

##  Overview

Lightweight PowerShell script that discovers all Power BI capacities, workspaces, and items in your tenant, providing detailed insights for migration planning.

**What it does:**
-  Discovers capacities, workspaces, and all items (datasets, reports, dashboards, dataflows)
-  Retrieves semantic model details including size information
-  Exports to a single Excel workbook with multiple organized sheets
-  Provides summary statistics and item type breakdowns
-  Handles errors gracefully with detailed logging
-  Supports automation with service principals

---

##  Quick Start

```powershell
# Clone and run
git clone https://github.com/alexumanamonge/fabric-capacity-migration-discovery.git
cd fabric-capacity-migration-discovery/Scripts
.\Discover-CapacityMigration.ps1
```

Script will prompt for Power BI admin login and generate a timestamped Excel report in the `output` folder.

---

##  Requirements

**Permissions:**
- Power BI **Tenant Administrator** OR **Capacity Administrator**

**PowerShell:**
- Windows PowerShell 5.1+ or PowerShell 7+
- `MicrosoftPowerBIMgmt` module (auto-installed on first run)
- `ImportExcel` module (auto-installed on first run)

**For Automation (Optional):**
- Azure AD App Registration
- Service Principal with API permissions: `Tenant.Read.All`, `Capacity.Read.All`, `Workspace.Read.All`

---

##  Usage

### Interactive Login

```powershell
# Use default output path (.\output)
.\Discover-CapacityMigration.ps1

# Specify custom output path
.\Discover-CapacityMigration.ps1 -OutputPath "C:\Reports"
```

### Service Principal (Automation)

```powershell
.\Discover-CapacityMigration.ps1 `
    -TenantId "your-tenant-id" `
    -ServicePrincipalId "your-app-id" `
    -ServicePrincipalSecret "your-secret" `
    -OutputPath "C:\Reports"
```

### Schedule Daily Scans

```powershell
$scriptPath = "C:\Scripts\fabric-capacity-migration-discovery\Scripts\Discover-CapacityMigration.ps1"
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' `
    -Argument "-File `"$scriptPath`" -OutputPath `"C:\Reports`""
$trigger = New-ScheduledTaskTrigger -Daily -At 2am
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "Capacity Discovery" `
    -Description "Daily Fabric capacity discovery scan"
```

---

##  Parameters

| Parameter | Type | Required | Description | Default |
|-----------|------|----------|-------------|---------|
| `OutputPath` | String | No | Report output location | `$PSScriptRoot\output` |
| `TenantId` | String | No | Azure AD Tenant ID (for service principal auth) | - |
| `ServicePrincipalId` | String | No | Application/Client ID (for service principal auth) | - |
| `ServicePrincipalSecret` | String | No | Application secret (for service principal auth) | - |

---

##  Output Files

Each run creates a timestamped Excel workbook in the output folder:

```
output/
  FabricCapacityDiscovery_20251112_220319.xlsx
```

### Excel Workbook Structure

The workbook contains multiple sheets with organized data:

| Sheet Name | Description |
|------------|-------------|
| **Summary** | Overview with item type counts and totals |
| **Capacities** | All discovered capacities with SKU, state, and region |
| **Workspaces** | All workspaces with capacity assignments and metadata |
| **Items** | All items (datasets, reports, dashboards, dataflows) by workspace |
| **SemanticModels** | Detailed dataset information including size (bytes and MB), refresh settings, and security |
| **SkippedDatasets** | Datasets that couldn't be accessed (if any) with error details |

All sheets include:
-  Auto-sized columns for easy reading
-  Filters enabled on header rows
-  Frozen top row for easy scrolling
-  Professional formatting

---

##  Features

 **Comprehensive Discovery**
- Discovers all capacities, workspaces, and items in your tenant
- Retrieves detailed semantic model information
- Captures dataset sizes in bytes and megabytes

 **Smart Error Handling**
- Gracefully handles inaccessible workspaces (e.g., personal workspaces)
- Skips missing or deleted datasets without unnecessary retries
- Logs all skipped items with reasons for transparency

 **Professional Output**
- Single Excel file with multiple organized sheets
- Timestamped filenames for version tracking
- Summary statistics for quick insights
- Easy to share and analyze

 **Automation Ready**
- Supports service principal authentication
- Can be scheduled for regular scans
- Auto-installs required PowerShell modules

---

##  Troubleshooting

**Authentication Failed**
- Verify you have Power BI Tenant Admin or Capacity Admin permissions
- Check if your account has admin access to the Power BI tenant

**Module Installation Issues**
- Ensure you have internet connectivity
- Modules are installed automatically on first run
- Manual installation: 
  ```powershell
  Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser -Force
  Install-Module -Name ImportExcel -Scope CurrentUser -Force
  ```

**Service Principal Authentication Issues**
- Verify API permissions in Azure AD App Registration
- Enable service principals in Power BI Admin Portal (Tenant settings → Developer settings)
- Ensure the service principal has been added as an admin to relevant workspaces/capacities

**Personal Workspaces Skipped**
- This is expected behavior - personal workspaces often have limited admin API access
- These are logged and can be reviewed in the console output

**Some Datasets Show 0 Size**
- Some datasets may not report size information via the API
- This can occur with certain dataset types or configurations
- The dataset is still discovered and listed

---

##  Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

---

##  License

**MIT License** - See [LICENSE](LICENSE)

```
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
```

---

##  Version History

**v2.0** (November 2025)
- Complete rewrite with improved error handling
- Single Excel workbook output with multiple sheets
- Dataset size information (bytes and MB)
- Summary statistics and item counts
- Smart retry logic for API calls
- Timestamped output files

**v1.0** (Initial Release)
- Basic capacity and workspace discovery
- CSV file outputs
- HTML report generation

---

<div align="center">

**Built for the Power BI & Microsoft Fabric Community**

[Report Issue](https://github.com/alexumanamonge/fabric-capacity-migration-discovery/issues) • [View Source](https://github.com/alexumanamonge/fabric-capacity-migration-discovery)

</div>
