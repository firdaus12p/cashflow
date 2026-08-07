# Architecture Decision Records - Flutter Catatan Keuangan

**Status:** ACTIVE & INDEXED  
**Last Updated:** 2026-08-07  
**Indexed in:** codebase-memory-mcp knowledge graph  

---

## Quick Reference

| # | Title | Status | Impact |
|---|-------|--------|--------|
| 1 | Multi-Platform Flutter Architecture | ✅ ACCEPTED | High modularity, good UX consistency |
| 2 | Feature Clusters Organization | ✅ ACCEPTED | Clear ownership, parallelizable development |
| 3 | Centralized Data Loading Pattern | ✅ ACCEPTED | Single source of truth, monitor hotspots |
| 4 | Platform Runner Ownership | ✅ ACCEPTED | Strong modularity, requires platform expertise |
| 5 | Validation & Skills Framework | ✅ ACCEPTED | QA automation, CI/CD ready |

---

## Architecture Overview

### Technology Stack
- **Framework:** Flutter (Dart)
- **Platforms:** Web, iOS, Android, Windows, macOS, Linux
- **Architecture:** Multi-cluster feature model with platform runners
- **Build System:** Gradle (Android), CMake (Windows/Linux), Xcode (iOS/macOS)

### Feature Clusters (High Cohesion)

```
Flutter App (lib/)
├── Dashboard Module (10 nodes, cohesion: 0.68)
│   └─ Main UI, wallet filters, emoji helpers
├── Transactions Module (13 nodes, cohesion: 0.62)
│   └─ CRUD operations, list rendering
├── Saving Goals Module (19 nodes, cohesion: 0.77)
│   └─ Goal tracking, progress management
├── Wishlist Module (11 nodes, cohesion: 0.72)
│   └─ Item management, purchases
└── Analytics Module (10 nodes, cohesion: 0.64)
    └─ Statistics, badges, enhanced charts
```

### Platform Runners (Independent)

```
Platform Support
├── Windows (21 nodes, cohesion: 0.96) ← Strongest cohesion
│   └─ Win32 API, window management
├── macOS (10 nodes)
│   └─ Swift, native widgets
├── Linux (4 nodes)
│   └─ GTK integration
├── iOS/Android
│   └─ Auto-generated platform code
└── Web (index.html)
    └─ Browser-based rendering
```

### Data Flow (Critical Path)

```
App Lifecycle
  ↓
main.dart (_MainScreenState)
  ↓
_loadAllData() [HOTSPOT: 9 callers]
  ├─ _loadTransactions() [4 callers]
  ├─ _loadWallet()
  ├─ _buildSavingGoals()
  ├─ _buildWishlist()
  ├─ _buildDashboard() [4 callers]
  ├─ _buildBadgesAndAnalytics()
  └─ Wallet emoji helpers (_getWalletEmoji)
  ↓
UI Rendering → Feature Modules
```

---

## Key Decisions Explained

### ADR-001: Multi-Platform Flutter
**Why:** Single codebase for ~90% of UI, native performance.  
**Trade-offs:** Build complexity (8 different build systems).  
**Mitigation:** Use Flutter runners to abstract platform details.

### ADR-002: Feature Clusters
**Why:** Leiden algorithm identified 5 natural feature boundaries.  
**Trade-offs:** Requires coordination across clusters.  
**Mitigation:** Document data contracts between modules.

### ADR-003: Centralized Data Loading
**Why:** Single coordinator prevents data inconsistency.  
**Trade-offs:** `_loadAllData()` is a hotspot (9 callers).  
**Mitigation:** Profile performance, consider isolates for parallel loading.

### ADR-004: Platform Runner Ownership
**Why:** Each platform has unique native requirements.  
**Trade-offs:** Requires platform expertise.  
**Mitigation:** Strong separation = easier platform-specific debugging.

### ADR-005: Validation Framework
**Why:** Automate QA & skill consistency.  
**Trade-offs:** Adds CI/CD dependency on Python.  
**Mitigation:** Validate-skills.py is simple and portable.

---

## Hotspots & Risk Analysis

### High-Traffic Functions
| Function | Callers | File | Risk |
|----------|---------|------|------|
| `_loadAllData()` | 9 | lib/main.dart | **HIGH** - Bottleneck |
| `_getWalletEmoji()` | 4 | lib/main.dart | MEDIUM - UI helper |
| `_loadTransactions()` | 4 | lib/main.dart | MEDIUM - Data loading |
| `_buildSavingGoals()` | 3 | lib/main.dart | LOW - Rendering |

**Recommendation:** Profile `_loadAllData()` for async opportunities.

### Platform Complexity
- **Windows:** Highest complexity (21 nodes, 0.96 cohesion) ← Most testable
- **macOS:** Moderate (10 nodes, with plugin registration)
- **Linux:** Simple (4 nodes, GTK integration)
- **Mobile:** Auto-generated, lowest customization

---

## Team Guidelines

### Feature Development
1. Stay within your cluster's module
2. Call `_loadAllData()` to refresh all data
3. Document inter-cluster dependencies
4. Update this ADR when adding new patterns

### Platform Work
1. Platform code is isolated in `/windows`, `/macos`, `/linux`, `/ios`, `/android`
2. Changes to platform runners usually don't affect app logic
3. Test platform-specific code on target platform
4. Use platform runners for native feature integration

### Performance Optimization
1. Profile `_loadAllData()` before refactoring
2. Consider Dart isolates for heavy data processing
3. Monitor UI rendering in `_buildDashboard()` cluster
4. Cache wallet emoji calculations

---

## Maintenance & Evolution

### When to Update This ADR
- Adding new platform support
- Refactoring data loading pattern
- New feature cluster identified
- Significant performance changes

### When to Add New ADRs
- Major architectural change
- New design pattern adoption
- Significant tech stack change
- Cross-cutting concern resolution

### How to Update
```bash
# In Copilot chat, use:
# mcp_codebase-memo_manage_adr
# Project: flutter-catatan-keuangan
# Mode: update
# Content: [New ADR content]
```

---

## Knowledge Graph Integration

This ADR is backed by a **codebase-memory knowledge graph**:
- **Nodes:** 838 (Classes, Functions, Modules, etc)
- **Edges:** 1,277 (Calls, Imports, Definitions, etc)
- **Compressed Size:** 330 KB (86% savings)
- **Persistent:** Stored in `.codebase-memory/graph.db.zst`

**Benefit:** AI agents can query this graph instead of reading source files → 60-90% token savings.

---

## Related Documents

- [CODEBASE_MEMORY_SETUP.md](./CODEBASE_MEMORY_SETUP.md) - MCP setup guide
- `lib/main.dart` - Main app entry point
- `.codebase-memory/artifact.json` - Graph metadata
- Indexed in: `mcp_codebase-memo_manage_adr` (this ADR)

---

**Generated:** 2026-08-07  
**By:** codebase-memory-mcp + AI analysis  
**Reviewed:** [Awaiting team review]  
**Status:** ACTIVE
