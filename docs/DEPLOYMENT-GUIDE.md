# Fabric Capacity Migration Discovery - Deployment Guide

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Setup Instructions](#setup-instructions)
- [Running the Notebook](#running-the-notebook)
- [Understanding the Results](#understanding-the-results)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

---

## Overview

The **Fabric Capacity Migration Discovery** notebook is designed to help organizations assess their current Power BI Premium or Embedded environment and identify potential blockers before migrating to Microsoft Fabric capacities.

### What This Tool Does

1. **Discovers** all capacities, workspaces, items, and semantic models in your tenant
2. **Analyzes** compatibility issues and migration blockers
3. **Stores** data in a Fabric Lakehouse for analysis
4. **Creates** an interactive Power BI report for visualization
5. **Generates** a comprehensive migration readiness assessment

---

## Prerequisites

### Required Permissions

You must have **one of the following** permissions:

- ✅ **Microsoft Fabric Tenant Administrator**
- ✅ **Power BI Capacity Administrator** (for the capacities you want to analyze)

### Fabric Environment Requirements

1. **Microsoft Fabric Workspace**
   - You need access to a Fabric workspace where you can create items
   - The workspace should be assigned to a Fabric capacity (F2 or higher recommended)

2. **Capacity Settings**
   - **XMLA Read/Write** must be enabled on the capacities you want to analyze
   - This is typically enabled by default on Premium capacities
   - Check: Capacity Settings → Power BI workloads → XMLA Endpoint = Read/Write

3. **Python Kernel**
   - Fabric notebooks run on Python by default
   - No additional configuration needed

### Knowledge Requirements

- Basic understanding of Power BI workspaces and capacities
- Familiarity with Jupyter notebooks
- Understanding of your organization's Fabric/Premium landscape

---

## Setup Instructions

### Step 1: Access Microsoft Fabric

1. Navigate to [Microsoft Fabric](https://app.fabric.microsoft.com)
2. Sign in with your tenant administrator credentials
3. Select or create a workspace for running the discovery tool

### Step 2: Create or Select a Workspace

**Option A: Use an Existing Workspace**
```
1. Navigate to your target workspace
2. Ensure it's assigned to a Fabric capacity
3. Verify you have Contributor or Admin permissions
```

**Option B: Create a New Workspace**
```
1. Click "Workspaces" in the left navigation
2. Click "+ New workspace"
3. Name it (e.g., "Capacity Migration Analysis")
4. Under "Advanced", assign it to a Fabric capacity
5. Click "Apply"
```

### Step 3: Upload the Notebook

1. **Download the Notebook**
   - Get `Capacity-Migration-Discovery.ipynb` from the repository

2. **Import to Fabric**
   ```
   • In your Fabric workspace, click "+ New item"
   • Select "Import notebook"
   • Browse and select the .ipynb file
   • Click "Upload"
   ```

3. **Open the Notebook**
   - Once uploaded, click on the notebook to open it
   - The notebook will open in the Fabric notebook editor

### Step 4: Configure Parameters

Locate **Cell 4** in the notebook and update the parameters:

```python
# Configuration Parameters
semantic_model_name = "Capacity Migration Analysis"  # Name for your semantic model
report_name = "Capacity Migration Report"            # Name for your Power BI report
lakehouse = "CapacityMigrationLH"                    # Name for your Lakehouse
```

**Customization Tips:**
- Use descriptive names that indicate the discovery date (e.g., `"Migration Analysis 2025-11"`)
- Avoid special characters in names
- Keep names under 100 characters

### **🔴 CRITICAL: Attach Lakehouse to Notebook**

Before running any cells, you **must** attach the lakehouse to the notebook:

1. **Look at the left panel** of the notebook interface
2. **Click "Add lakehouse"** (if no lakehouse is attached)
3. **Select "Existing lakehouse"**
4. **Choose `CapacityMigrationLakehouse`** (or your custom name from Step 3)
5. **Click "Add"**

You should see the lakehouse appear in the left panel with the **Tables** and **Files** folders.

**Why this matters:** The notebook writes Delta tables to the attached lakehouse. Without this connection, you'll get "Bad Request" errors when saving data.

---

## Running the Notebook

### Execution Options

**Option 1: Run All Cells (Recommended for First Run)**
```
1. Ensure lakehouse is attached (see above)
2. Click "Run all" in the top menu
3. Monitor progress as each cell executes
4. Total execution time: 5-12 minutes (depending on tenant size)
```

**Option 2: Run Cell by Cell**
```
1. Click on the first cell
2. Press Shift + Enter to execute and move to next cell
3. Review output before proceeding
4. Useful for troubleshooting or understanding each step
```

### Expected Execution Timeline

| Step | Description | Typical Duration |
|------|-------------|------------------|
| 1-3  | Library installation & setup | 30-60 seconds |
| 4-5  | Configuration & validation | 10 seconds |
| 6    | Capacity data collection | 20-30 seconds |
| 7    | Workspace data collection | 1-3 minutes |
| 8    | Workspace items collection | 2-5 minutes |
| 9    | Semantic models collection | 1-3 minutes |
| 10   | Data verification | 10 seconds |

**Total Notebook Execution:** 5-12 minutes (varies by tenant size)

**Manual Steps After Notebook:**
- Create DirectLake semantic model (2 minutes) - see instructions in Step 10 output
- Add relationships and measures in model (3-5 minutes)
- Create Power BI report (5-10 minutes)

**Complete End-to-End:** 15-30 minutes

### Monitoring Progress

Each cell displays progress indicators:
- ✅ Success messages in green
- ⚠️ Warning messages in yellow
- ❌ Error messages in red
- 📊 Data summaries showing counts and breakdowns

---

## Understanding the Results

### Migration Blocker Analysis Output

The notebook generates a comprehensive assessment with three severity levels:

#### 🛑 **CRITICAL BLOCKERS**

These **must be resolved** before migration:

| Blocker Type | Description | Resolution |
|--------------|-------------|------------|
| **EM SKU Capacities** | Embedded (EM1-EM3) SKUs detected | Migrate to Fabric F-SKUs |
| **Cross-Region Issues** | Workspaces in different regions | Plan region-specific migrations |
| **Unsupported Items** | Items not compatible with Fabric | Remove or upgrade before migration |

**Example Output:**
```
🛑 CRITICAL BLOCKERS (Must resolve before migration):
==================================================================
1. Embedded capacity 'EM-Production' (SKU: EM3) - EM SKUs not 
   supported in Fabric. Migrate to F-SKUs.
```

#### ⚠️ **WARNINGS**

These should be **reviewed and planned for**:

| Warning Type | Description | Action Required |
|--------------|-------------|-----------------|
| **Dataflows Gen1** | Legacy dataflows detected | Consider upgrading to Gen2 |
| **Paginated Reports** | RDL reports found | Verify Fabric capacity workload enabled |
| **Large Models** | Models >10GB detected | Ensure target capacity size adequate |
| **Inactive Workspaces** | Non-active workspaces found | Clean up before migration |

**Example Output:**
```
⚠️  WARNINGS (Review and plan accordingly):
==================================================================
1. 45 Dataflow Gen1 artifacts found. Consider upgrading to 
   Dataflow Gen2 or Data Pipelines in Fabric.
2. 12 Paginated Reports found. Ensure Fabric capacity has 
   paginated report workload enabled.
```

#### ℹ️ **INFORMATIONAL**

For your **awareness and planning**:

| Info Type | Description | Note |
|-----------|-------------|------|
| **RLS Models** | Models with Row-Level Security | Test RLS after migration |
| **Deployment Pipelines** | Pipeline usage detected | Verify configuration post-migration |
| **Premium P-SKUs** | Premium capacities ready for migration | These can migrate directly |

### Data Storage

All collected data is stored in the Lakehouse:

| Table Name | Contents | Use Case |
|------------|----------|----------|
| `Capacities` | All capacity details (SKU, region, state) | Capacity planning |
| `Workspaces` | Workspace metadata and capacity assignments | Workspace migration planning |
| `WorkspaceItems` | All items (reports, datasets, dataflows, etc.) | Item inventory |
| `SemanticModels` | Dataset details (storage mode, RLS, etc.) | Model migration planning |
| `MigrationAnalysis` | Analysis results and blocker details | Historical tracking |

### Power BI Report

The generated report includes:

- **Overview Dashboard**: High-level metrics (capacities, workspaces, items)
- **Capacity Details**: Drill-down into each capacity
- **Item Inventory**: Breakdown by type and workspace
- **Migration Readiness**: Visual representation of blockers and warnings

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: "Requires tenant/capacity admin permissions"

**Cause:** Insufficient permissions to access tenant-wide data

**Solution:**
```
1. Verify you have Tenant Admin or Capacity Admin role
2. Check in: https://app.powerbi.com/admin-portal
3. If you're a Capacity Admin, ensure you're analyzing only your capacities
4. Contact your Fabric administrator if permissions are needed
```

#### Issue 2: "Error creating Lakehouse"

**Cause:** Workspace not on Fabric capacity or insufficient permissions

**Solution:**
```
1. Verify the workspace is assigned to a Fabric capacity:
   • Workspace Settings → License info → Fabric capacity
2. Ensure you have Contributor or Admin role in the workspace
3. Try creating the lakehouse manually first to test permissions
```

#### Issue 3: "Semantic model not found after creation"

**Cause:** Model creation is slow or failed

**Solution:**
```
1. Wait the full 5 minutes (max_retries timeout)
2. Check the workspace for the semantic model manually
3. If it exists, run cell 12 again to update the connection
4. If it doesn't exist, check for error messages in cell 11
```

#### Issue 4: "No capacities found"

**Cause:** No Premium/Fabric capacities in tenant, or permissions issue

**Solution:**
```
1. Verify you have Premium or Fabric capacities:
   • Admin Portal → Capacity settings
2. Ensure XMLA Read/Write is enabled
3. Check if you're running in the correct tenant
```

#### Issue 5: Library Installation Fails

**Cause:** Network issues or package conflicts

**Solution:**
```python
# Try installing with specific version
%pip install semantic-link-labs==0.7.0 --force-reinstall

# Clear cache and reinstall
%pip cache purge
%pip install semantic-link-labs
```

### Getting Help

If issues persist:

1. **Check the Error Message**: Most errors include specific details
2. **Review Prerequisites**: Ensure all requirements are met
3. **Check Fabric Status**: Visit [Microsoft 365 Status](https://status.office.com/)
4. **Community Support**: Post in [Microsoft Fabric Community](https://community.fabric.microsoft.com/)
5. **Microsoft Support**: Open a support ticket if you have a support plan

---

## Best Practices

### Before Running the Notebook

✅ **DO:**
- Review and understand your current capacity landscape
- Ensure you have the required permissions
- Run during off-peak hours for large tenants
- Back up critical workspaces before any migration
- Communicate with stakeholders about the discovery process

❌ **DON'T:**
- Run without proper permissions (can cause errors)
- Modify the notebook without understanding the impact
- Skip the blocker analysis (critical for planning)
- Delete the Lakehouse before reviewing all data

### During Execution

✅ **DO:**
- Monitor each cell's output for errors or warnings
- Take note of blocker and warning counts
- Review data summaries to ensure completeness
- Save the notebook periodically

❌ **DON'T:**
- Interrupt the execution mid-way (data may be incomplete)
- Skip cells (they build on each other)
- Ignore error messages (they indicate issues)

### After Execution

✅ **DO:**
- Review the complete migration analysis output
- Export the blocker list for planning
- Share the Power BI report with stakeholders
- Keep the Lakehouse for historical comparison
- Schedule regular discovery runs (monthly/quarterly)
- Document your migration plan based on findings

❌ **DON'T:**
- Proceed with migration without addressing blockers
- Delete the Lakehouse (you'll lose historical data)
- Ignore warnings (they can cause post-migration issues)

### Migration Planning

Based on the analysis results:

1. **Address Critical Blockers First**
   - Resolve EM SKU issues
   - Plan cross-region migrations separately
   - Remove or upgrade unsupported items

2. **Plan for Warnings**
   - Schedule Dataflow Gen1 upgrades
   - Configure Fabric capacity workloads
   - Size capacities for large models

3. **Create Migration Waves**
   - Group workspaces by capacity
   - Prioritize based on business criticality
   - Test with non-production workspaces first

4. **Test Thoroughly**
   - Validate reports and datasets post-migration
   - Test RLS and security
   - Verify scheduled refreshes
   - Check performance

---

## Next Steps

After running the discovery:

1. **Review Results**: Analyze the migration readiness assessment
2. **Create Migration Plan**: Based on blockers and warnings identified
3. **Stakeholder Communication**: Share findings with business owners
4. **Address Blockers**: Resolve critical issues before migration
5. **Pilot Migration**: Test with a small workspace first
6. **Full Migration**: Execute your planned migration waves
7. **Post-Migration Validation**: Run the notebook again to verify

---

## Additional Resources

- [Microsoft Fabric Documentation](https://learn.microsoft.com/fabric/)
- [Power BI Premium to Fabric Migration Guide](https://learn.microsoft.com/fabric/admin/fabric-adoption-roadmap)
- [Fabric Capacity Management](https://learn.microsoft.com/fabric/enterprise/licenses)
- [Semantic Link Documentation](https://learn.microsoft.com/fabric/data-science/semantic-link-overview)

---

## Support and Feedback

For questions, issues, or feedback:
- Create an issue in the GitHub repository
- Contact your Microsoft account team
- Visit the Microsoft Fabric Community forums

---

**Last Updated:** November 2025  
**Version:** 1.0
