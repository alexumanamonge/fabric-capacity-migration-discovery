# 🔍 Power BI Capacity Migration Discovery

**Automated discovery and migration readiness analysis for Power BI Premium/Embedded capacities.**

---

## ✨ What It Does

- **Discovers** all capacities, workspaces, items, and semantic models in your tenant
- **Analyzes** migration readiness across 10 blocker categories
- **Exports** results to CSV files and interactive HTML report
- **Identifies** critical blockers, warnings, and recommendations

---

## 🚀 Quick Start

```powershell
.\Discover-CapacityMigration.ps1 -OutputPath "C:\Reports"
```

Prompts for Power BI admin credentials and generates a timestamped report folder.

---

## 📋 Requirements

**Permissions:**
- Power BI Tenant Administrator **OR** Capacity Administrator

**PowerShell Module:**
- `MicrosoftPowerBIMgmt` (auto-installed if missing)

**For Automation (Optional):**
- Azure AD App Registration with API permissions:
  - `Tenant.Read.All`
  - `Capacity.Read.All`
  - `Workspace.Read.All`
- Service principals enabled in Power BI Admin Portal

---

## 💻 Deployment

### Interactive Login

```powershell
# Run with current credentials
.\Discover-CapacityMigration.ps1 -OutputPath "C:\Reports"
```

### Service Principal (Automation)

```powershell
# Non-interactive authentication
.\Discover-CapacityMigration.ps1 `
    -TenantId "your-tenant-id" `
    -ServicePrincipalId "your-app-id" `
    -ServicePrincipalSecret "your-secret" `
    -OutputPath "C:\Reports"
```

### Schedule Daily Scans

```powershell
# Create Windows scheduled task
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' `
    -Argument '-File "C:\Scripts\Discover-CapacityMigration.ps1" -OutputPath "C:\Reports"'
$trigger = New-ScheduledTaskTrigger -Daily -At 2am
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "Capacity Discovery"
```

---

## 📊 Output Files

Each run creates a timestamped folder with:

```
CapacityMigration_2025-11-07_143022/
├── Capacities.csv              # All capacity details
├── Workspaces.csv              # Workspace assignments
├── WorkspaceItems.csv          # Reports, datasets, dashboards, dataflows
├── SemanticModels.csv          # Model details (storage mode, RLS)
├── MigrationAnalysis.csv       # Blocker summary
└── MigrationSummary.html       # Interactive report
```

---

## 🎯 Migration Analysis

The tool identifies issues across 10 categories:

**🛑 Critical Blockers**
- Embedded (EM) SKUs not supported
- Unsupported features requiring updates

**⚠️ Warnings**
- Dataflows Gen1 (recommend upgrade to Gen2)
- Paginated reports (workload verification needed)
- Large models >10GB (capacity planning required)
- Cross-region capacities (migration planning needed)
- Inactive workspaces (cleanup recommended)

**ℹ️ Informational**
- Premium P-SKUs ready for migration
- Models with Row-Level Security (testing recommended)
- Dashboards and deployment pipelines

---

## ⚙️ Parameters

| Parameter | Type | Required | Description | Default |
|-----------|------|----------|-------------|---------|
| `OutputPath` | String | No | Report output location | Current directory |
| `TenantId` | String | No | Azure AD Tenant ID | - |
| `ServicePrincipalId` | String | No | Application ID | - |
| `ServicePrincipalSecret` | String | No | Application secret | - |
| `GenerateHtmlReport` | Boolean | No | Create HTML summary | `$true` |

---

## 📄 License

**MIT License** - See [LICENSE](../LICENSE)

```
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
DEALINGS IN THE SOFTWARE.
```

---

**Version:** 1.0.0 | **Last Updated:** November 2025
