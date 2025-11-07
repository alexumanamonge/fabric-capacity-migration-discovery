# Microsoft Fabric Capacity Migration Discovery Tool

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Microsoft Fabric](https://img.shields.io/badge/Microsoft-Fabric-blue)](https://www.microsoft.com/microsoft-fabric)
[![Power BI](https://img.shields.io/badge/Power%20BI-Premium-yellow)](https://powerbi.microsoft.com/)

> **Comprehensive discovery and assessment tool for migrating Power BI Premium/Embedded capacities to Microsoft Fabric**

## 🎯 Overview

The **Fabric Capacity Migration Discovery Tool** is a Jupyter notebook designed to help organizations assess their current Power BI Premium or Embedded environment and identify potential blockers before migrating to Microsoft Fabric capacities.

This tool provides:
- ✅ **Automated Discovery**: Collects all capacities, workspaces, items, and semantic models
- 🔍 **Blocker Analysis**: Identifies compatibility issues and migration blockers
- 📊 **Data Storage**: Saves data in a Fabric Lakehouse for deep analysis
- 📈 **Visual Reports**: Generates interactive Power BI reports
- 📋 **Readiness Assessment**: Provides actionable migration recommendations

---

## 🚀 Quick Start

### Prerequisites

- Microsoft Fabric Tenant Administrator or Capacity Administrator permissions
- Access to a Fabric workspace
- XMLA Read/Write enabled on capacities

### Installation

1. **Clone or download this repository**
   ```bash
   git clone https://github.com/yourusername/fabric-capacity-migration-discovery.git
   ```

2. **Navigate to Microsoft Fabric**
   - Go to [app.fabric.microsoft.com](https://app.fabric.microsoft.com)
   - Select or create a workspace assigned to a Fabric capacity

3. **Import the notebook**
   - Click "+ New item" → "Import notebook"
   - Select `notebooks/Capacity-Migration-Discovery.ipynb`
   - Click "Upload"

4. **Configure parameters** (Cell 4 in the notebook)
   ```python
   semantic_model_name = "Capacity Migration Analysis"
   report_name = "Capacity Migration Report"
   lakehouse = "CapacityMigrationLH"
   ```

5. **Run the notebook**
   - Click "Run all" or execute cells individually
   - Wait 5-15 minutes for completion

📖 **For detailed instructions, see the [Deployment Guide](docs/DEPLOYMENT-GUIDE.md)**

---

## 📋 Features

### 1. Comprehensive Data Collection

Automatically discovers and catalogs:

| Category | What's Collected |
|----------|------------------|
| **Capacities** | SKU, region, state, administrators |
| **Workspaces** | Name, type, capacity assignment, state |
| **Workspace Items** | Reports, datasets, dataflows, dashboards, etc. |
| **Semantic Models** | Storage mode, RLS, size, refresh configuration |

### 2. Migration Blocker Detection

Identifies critical issues across multiple categories:

#### 🛑 Critical Blockers
- **Embedded (EM) SKUs**: Not supported in Fabric
- **Cross-region capacities**: Require special handling
- **Unsupported item types**: Need upgrade or removal

#### ⚠️ Warnings
- **Dataflows Gen1**: Should upgrade to Gen2
- **Paginated reports**: Require workload configuration
- **Large models (>10GB)**: Need capacity planning
- **Inactive workspaces**: Cleanup recommended

#### ℹ️ Informational
- **RLS models**: Test after migration
- **Deployment pipelines**: Verify configuration
- **Premium P-SKUs**: Ready for migration

### 3. Data Storage & Analysis

All data is stored in a **Fabric Lakehouse** with tables:

- `Capacities` - Capacity details and configuration
- `Workspaces` - Workspace metadata and assignments
- `WorkspaceItems` - Complete item inventory
- `SemanticModels` - Dataset details and properties
- `MigrationAnalysis` - Assessment results and findings

### 4. Interactive Reporting

Generates a **Power BI report** with:
- Overview dashboard with key metrics
- Capacity deep-dive analysis
- Item inventory and breakdown
- Migration readiness visualization

---

## 🔍 What Gets Analyzed

### Capacity Compatibility
- ✅ Identifies Premium P-SKUs (ready for migration)
- ❌ Flags Embedded EM-SKUs (not supported)
- ℹ️ Notes Azure A-SKUs (can migrate)

### Storage & Data
- Detects large models requiring special handling
- Identifies DirectQuery vs Import models
- Flags DirectLake opportunities

### Security & Access
- Models with Row-Level Security (RLS)
- Effective identity requirements
- Workspace access patterns

### Artifacts & Features
- Legacy Dataflows Gen1
- Paginated reports (.rdl files)
- Deployment pipeline usage
- Dashboard dependencies

### Workspace Health
- Active vs inactive workspaces
- Capacity assignments
- Multi-region distribution

---

## 📊 Sample Output

```
======================================================================
MIGRATION READINESS ASSESSMENT
======================================================================

🛑 CRITICAL BLOCKERS (Must resolve before migration):
======================================================================
1. Embedded capacity 'Prod-EM3' (SKU: EM3) - EM SKUs not supported 
   in Fabric. Migrate to F-SKUs.

⚠️  WARNINGS (Review and plan accordingly):
======================================================================
1. 45 Dataflow Gen1 artifacts found. Consider upgrading to Dataflow 
   Gen2 or Data Pipelines in Fabric.
2. 12 Paginated Reports found. Ensure Fabric capacity has paginated 
   report workload enabled.
3. 3 Large Models (>10GB) detected. Verify target Fabric capacity 
   size supports these models.

ℹ️  INFORMATIONAL (For your awareness):
======================================================================
1. 5 Premium P-SKU capacities found - Ready for Fabric migration
2. 87 semantic models with Row-Level Security (RLS). Test RLS 
   behavior after migration, especially with DirectLake.

✓ Analysis results saved to Lakehouse (Table: MigrationAnalysis)
======================================================================
```

---

## 📁 Repository Structure

```
Fabric-Capacity-Migration-Discovery/
├── notebooks/
│   └── Capacity-Migration-Discovery.ipynb    # Main discovery notebook
├── docs/
│   └── DEPLOYMENT-GUIDE.md                    # Detailed deployment guide
├── templates/
│   └── (Future: Custom report templates)
└── README.md                                  # This file
```

---

## 🛠️ Technology Stack

- **Microsoft Fabric**: Cloud analytics platform
- **Python**: Notebook execution environment
- **Semantic Link**: Fabric SDK for Python
- **Semantic Link Labs**: Admin operations and utilities
- **Power BI**: Visualization and reporting
- **Delta Lake**: Data storage format

---

## 📖 Documentation

| Document | Description |
|----------|-------------|
| [Deployment Guide](docs/DEPLOYMENT-GUIDE.md) | Complete setup and execution instructions |
| [Notebook](notebooks/Capacity-Migration-Discovery.ipynb) | Main discovery notebook with inline documentation |

---

## 🔧 Troubleshooting

### Common Issues

**"Requires tenant admin permissions"**
- Verify you have Tenant Admin or Capacity Admin role
- Check permissions in the Power BI Admin Portal

**"Error creating Lakehouse"**
- Ensure workspace is on a Fabric capacity
- Verify you have Contributor or Admin permissions

**"Semantic model not found"**
- Wait the full timeout period (5 minutes)
- Check workspace manually for the model
- Re-run the connection update cell

For more troubleshooting help, see the [Deployment Guide](docs/DEPLOYMENT-GUIDE.md#troubleshooting).

---

## 🎓 Best Practices

### Before Migration
1. ✅ Run this discovery tool to understand your landscape
2. ✅ Address all critical blockers
3. ✅ Plan for warnings and info items
4. ✅ Create a phased migration approach
5. ✅ Test with non-production workspaces first

### During Discovery
1. ✅ Run during off-peak hours for large tenants
2. ✅ Monitor each step for errors
3. ✅ Save results for historical comparison
4. ✅ Share findings with stakeholders

### After Discovery
1. ✅ Review the complete analysis output
2. ✅ Create a migration plan based on findings
3. ✅ Schedule regular discovery runs (monthly)
4. ✅ Keep the Lakehouse for tracking over time

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

### How to Contribute
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- Microsoft Fabric team for the Semantic Link SDK
- Power BI community for feedback and testing
- Contributors and users of this tool

---

## 📞 Support

For questions or issues:

- 📧 **Email**: [your-email@domain.com](mailto:your-email@domain.com)
- 🐛 **Issues**: [GitHub Issues](https://github.com/yourusername/fabric-capacity-migration-discovery/issues)
- 💬 **Discussions**: [Microsoft Fabric Community](https://community.fabric.microsoft.com/)

---

## 🗺️ Roadmap

### Current Version (v1.0)
- ✅ Basic discovery and blocker detection
- ✅ Lakehouse storage
- ✅ Power BI report generation

### Planned Features (v1.1+)
- [ ] Enhanced report templates
- [ ] Migration cost estimation
- [ ] Historical trend analysis
- [ ] Export to Excel/PDF
- [ ] Custom blocker rules
- [ ] Migration wave planning
- [ ] Pre-migration validation tests

---

## 📊 Usage Statistics

Help us improve! Consider sharing (anonymized):
- Tenant size (number of capacities/workspaces)
- Migration challenges encountered
- Feature requests

---

## ⚡ Quick Links

- [Microsoft Fabric Documentation](https://learn.microsoft.com/fabric/)
- [Power BI Premium to Fabric Migration](https://learn.microsoft.com/fabric/admin/fabric-adoption-roadmap)
- [Semantic Link Overview](https://learn.microsoft.com/fabric/data-science/semantic-link-overview)
- [Fabric Capacity Management](https://learn.microsoft.com/fabric/enterprise/licenses)

---

<div align="center">

**Made with ❤️ for the Microsoft Fabric Community**

[Report Bug](https://github.com/yourusername/fabric-capacity-migration-discovery/issues) · [Request Feature](https://github.com/yourusername/fabric-capacity-migration-discovery/issues) · [Documentation](docs/DEPLOYMENT-GUIDE.md)

</div>
