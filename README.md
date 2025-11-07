# Microsoft Fabric Capacity Migration Discovery Tool

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Microsoft Fabric](https://img.shields.io/badge/Microsoft-Fabric-blue)](https://www.microsoft.com/microsoft-fabric)

> **Automated discovery and assessment tool for migrating Power BI Premium/Embedded capacities to Microsoft Fabric**

## 🎯 Overview

Jupyter notebook that analyzes your Power BI environment and identifies migration blockers before moving to Microsoft Fabric capacities.

**What it does:**
- ✅ Discovers all capacities, workspaces, items, and semantic models
- 🔍 Identifies 10+ categories of migration blockers and warnings
- 📊 Saves data to Fabric Lakehouse for analysis
- 📈 Generates interactive Power BI report

---

## 🚀 Quick Start

### Prerequisites

- **Tenant Admin or Capacity Admin** permissions
- **Fabric workspace** (Fabric capacity, Premium Gen2, or **Fabric Trial**)
- XMLA Read/Write enabled on capacities

> 💡 **Fabric Trial**: This notebook works perfectly on a free 60-day Fabric Trial capacity! Start your trial at [app.fabric.microsoft.com](https://app.fabric.microsoft.com)

### Installation

1. **Go to Microsoft Fabric** - [app.fabric.microsoft.com](https://app.fabric.microsoft.com)
2. **Select/create a workspace** on Fabric capacity (or start a Fabric Trial)
3. **Import the notebook**:
   - Click "+ New item" → "Import notebook"
   - Upload `notebooks/Capacity-Migration-Discovery.ipynb`
4. **Run all cells** - Takes 5-12 minutes (collects data to Delta tables)
5. **Create semantic model manually** - Follow Step 10 instructions (2 minutes)
6. **Build Power BI report** - Add relationships and visuals (5-10 minutes)

📖 **For detailed instructions, see the [Deployment Guide](docs/DEPLOYMENT-GUIDE.md)**

---

## � Migration Blockers Detected

The notebook identifies issues across 10 categories:

### 🛑 Critical Blockers
- **Embedded (EM) SKUs** - Not supported in Fabric
- **Incompatible features** - Require upgrade or removal

### ⚠️ Warnings
- **Dataflows Gen1** - Should upgrade to Gen2
- **Paginated reports** - Need workload enabled
- **Large models (>10GB)** - Require capacity planning
- **Cross-region capacities** - Need migration strategy
- **Inactive workspaces** - Cleanup recommended

### ℹ️ Informational
- **Premium P-SKUs** - Ready for migration
- **RLS models** - Test after migration
- **Deployment pipelines** - Verify configuration

---

## 📊 Sample Output

```
======================================================================
MIGRATION READINESS ASSESSMENT
======================================================================

🛑 CRITICAL BLOCKERS (Must resolve before migration):
1. Embedded capacity 'Prod-EM3' (SKU: EM3) - EM SKUs not supported

⚠️  WARNINGS (Review and plan accordingly):
1. 45 Dataflow Gen1 artifacts found
2. 12 Paginated Reports found
3. 3 Large Models (>10GB) detected

ℹ️  INFORMATIONAL (For your awareness):
1. 5 Premium P-SKU capacities - Ready for Fabric migration
2. 87 semantic models with RLS - Test after migration

✓ Analysis saved to Lakehouse
======================================================================
```

---

## 📁 Repository Structure

```
Fabric-Capacity-Migration-Discovery/
├── notebooks/
│   └── Capacity-Migration-Discovery.ipynb    # Main notebook
├── docs/
│   ├── DEPLOYMENT-GUIDE.md                    # Setup instructions
│   └── TROUBLESHOOTING.md                     # Common errors
└── README.md                                  # This file
```

---

## �️ Troubleshooting

**"Requires tenant admin permissions"**
- Verify Tenant Admin or Capacity Admin role

**"Error creating Lakehouse"**
- Ensure workspace is on Fabric capacity (or Trial)
- Check workspace permissions

**"Semantic model not found"**
- Wait full timeout period (5 minutes)
- Check troubleshooting guide: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

---

## 📖 Documentation

- [Deployment Guide](docs/DEPLOYMENT-GUIDE.md) - Complete setup instructions
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md) - Error solutions

---

## 📝 License

MIT License - see [LICENSE](LICENSE) file

---

## 🙏 Acknowledgments

Built with Microsoft Fabric Semantic Link SDK

---

<div align="center">

**Made for the Microsoft Fabric Community**

[Report Issue](https://github.com/alexumanamonge/fabric-capacity-migration-discovery/issues) · [Documentation](docs/DEPLOYMENT-GUIDE.md)

</div>
