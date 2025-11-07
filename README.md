# Power BI Capacity Migration Discovery

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue)](https://docs.microsoft.com/powershell/)

> **Automated discovery and migration readiness analysis for Power BI Premium/Embedded capacities**

---

##  Overview

PowerShell script that discovers all Power BI capacities, workspaces, items, and semantic models in your tenant, then analyzes migration readiness with actionable insights.

**What it does:**
-  Discovers capacities, workspaces, items, and semantic models
-  Identifies migration blockers across 10 categories
-  Exports to CSV files + interactive HTML report
-  Runs anywhere with PowerShell (no workspace setup)
-  Supports automation with service principals

---

##  Quick Start

```powershell
# Clone and run
git clone https://github.com/alexumanamonge/fabric-capacity-migration-discovery.git
cd fabric-capacity-migration-discovery/Scripts
.\Discover-CapacityMigration.ps1 -OutputPath "C:\Reports"
```

Script will prompt for Power BI admin login and generate a timestamped report folder.

---

##  Requirements

**Permissions:**
- Power BI **Tenant Administrator** OR **Capacity Administrator**

**PowerShell:**
- Windows PowerShell 5.1+ or PowerShell 7+
- MicrosoftPowerBIMgmt module (auto-installed)

**For Automation (Optional):**
- Azure AD App Registration
- API permissions: Tenant.Read.All, Capacity.Read.All, Workspace.Read.All

---

##  Usage

### Interactive Login

```powershell
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
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' `
    -Argument '-File "C:\Scripts\Discover-CapacityMigration.ps1" -OutputPath "C:\Reports"'
$trigger = New-ScheduledTaskTrigger -Daily -At 2am
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "Capacity Discovery"
```

---

##  Output Files

Each run creates a timestamped folder with:

```
CapacityMigration_2025-11-07_143022/
 Capacities.csv              # All capacity details
 Workspaces.csv              # Workspace assignments
 WorkspaceItems.csv          # Reports, datasets, dashboards, dataflows
 SemanticModels.csv          # Model details (storage mode, RLS)
 MigrationAnalysis.csv       # Blocker summary
 MigrationSummary.html       # Interactive report
```

---

##  Migration Analysis

The script identifies issues across **10 categories**:

** Critical Blockers**
- Embedded (EM) SKUs not supported
- Unsupported features requiring updates

** Warnings**
- Dataflows Gen1 (upgrade to Gen2 recommended)
- Paginated reports (workload verification needed)
- Large models >10GB (capacity planning required)
- Cross-region capacities (migration planning needed)
- Inactive workspaces (cleanup recommended)

**ℹ Informational**
- Premium P-SKUs ready for migration
- Models with Row-Level Security (testing recommended)
- Dashboards and deployment pipelines

---

##  Documentation

Detailed documentation available in the Scripts folder:

- **[Scripts/README.md](Scripts/README.md)** - Complete usage guide
- **[Scripts/config.example.json](Scripts/config.example.json)** - Configuration template

---

##  Troubleshooting

**Authentication Failed**
- Verify Tenant Admin or Capacity Admin permissions

**Module Not Found**
- Run: Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser

**Service Principal Issues**
- Verify API permissions in Azure AD App Registration
- Enable service principals in Power BI Admin Portal

---

##  License

**MIT License** - See [LICENSE](LICENSE)

```
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
```

---

<div align="center">

**Built for the Power BI & Microsoft Fabric Community**

[Documentation](Scripts/README.md)  [Report Issue](https://github.com/alexumanamonge/fabric-capacity-migration-discovery/issues)

</div>
