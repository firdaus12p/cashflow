# Team Guide: Using Codebase Memory for Development

**TL;DR:** Use Copilot with mcp_codebase-memo tools. AI understands your codebase → 60-90% token savings. ⚡

---

## 🚀 Quick Start

### 1. **Ask Copilot About Architecture**
```
You: "What's the architecture of this app?"
Copilot uses: mcp_codebase-memo_get_architecture
Result: Instant overview without reading files
Token cost: ~300 tokens (vs ~2000 without)
```

### 2. **Search Code Semantically**
```
You: "Where do we handle wallet updates?"
Copilot uses: mcp_codebase-memo_search_code (pattern: "wallet")
Result: Finds `_loadWallet()`, `_getWalletEmoji()`, etc
Token cost: ~250 tokens
```

### 3. **Understand Dependencies**
```
You: "What calls _loadAllData?"
Copilot uses: mcp_codebase-memo_trace_path (function: "_loadAllData")
Result: Shows 9 callers with full call chain
Token cost: ~200 tokens
```

### 4. **Impact Analysis**
```
You: "What breaks if we change Transaction class?"
Copilot uses: mcp_codebase-memo_trace_path (reverse direction)
Result: Shows all 4 callers + dependent modules
Token cost: ~250 tokens
```

---

## 🎯 Use Cases

### For Feature Development

| Task | Tool | Benefit |
|------|------|---------|
| **Understand UI flow** | `get_architecture` | See feature clusters |
| **Find similar code** | `search_code` | Reuse patterns |
| **Check for conflicts** | `trace_path` | Avoid duplicate logic |
| **Estimate scope** | `detect_changes` | Impact analysis |

### For Debugging

| Task | Tool | Benefit |
|------|------|---------|
| **Trace a bug** | `trace_path` | Find all call sites |
| **Check data flow** | `trace_path` (mode: data_flow) | Follow value propagation |
| **Platform-specific issue** | `get_architecture` (path: "windows") | Isolate platform code |

### For Performance

| Task | Tool | Benefit |
|------|------|---------|
| **Find hotspots** | `get_architecture` (aspects: hotspots) | See high-traffic functions |
| **Detect N+1 queries** | `trace_path` + `search_code` | Identify load redundancy |
| **Optimize data loading** | `trace_path` (_loadAllData) | Understand critical path |

---

## 📊 Architecture at a Glance

### Feature Modules (Clusters)
- **Dashboard** - Main screen, wallet filters
- **Transactions** - CRUD, list, history
- **Saving Goals** - Goals, progress, tracking
- **Wishlist** - Items, purchases, status
- **Analytics** - Stats, badges, charts

### Hotspots (Profile These!)
1. `_loadAllData()` - 9 callers ← **Potential bottleneck**
2. `_loadTransactions()` - 4 callers
3. `_getWalletEmoji()` - 4 callers (UI helper)
4. `_buildDashboard()` - Main rendering

### Platform Complexity
```
Windows (21 nodes)     ← Most complex, most testable
  ├─ Win32 API
  └─ Window management

macOS (10 nodes)       ← Moderate
  └─ Plugin registration

Linux (4 nodes)        ← Simple
  └─ GTK setup

Mobile               ← Auto-generated
  └─ Gradle/Xcode
```

---

## 🔥 Pro Tips

### Tip 1: Get Architecture First
```
New to project? Run this in Copilot:
"Show me the architecture with clusters"
→ Get de facto module structure
→ Understand feature ownership
```

### Tip 2: Trace Before Refactoring
```
Before renaming a function:
"What calls _loadTransactions?"
→ See all 4 impact points
→ Refactor with confidence
```

### Tip 3: Search Semantically
```
Instead of grep for "wallet":
"Find all wallet-related functions"
→ Graph finds semantic matches
→ Saves context tokens
```

### Tip 4: Detect Changes on PRs
```
For code review:
"What changed in _MainScreenState?"
→ Shows impact scope
→ Reviews PR faster
```

### Tip 5: Platform Isolation
```
For platform-specific bug:
"Show architecture for windows/"
→ Only Windows runner code
→ Easier debugging
```

---

## 💡 Token Savings Breakdown

### Without Codebase Memory

```
Query: "What's the call chain for _loadAllData?"

Copilot approach:
1. Read main.dart (~500 lines)
2. Read all imported files (~2000 lines total)
3. Analyze dependencies (~1000 tokens)
4. Generate response (~500 tokens)
= ~2000 tokens per query ❌
```

### With Codebase Memory (YOUR SETUP)

```
Query: "What's the call chain for _loadAllData?"

Copilot + Graph approach:
1. Query graph (9 callers, instant)
2. Return call chain (~200 tokens)
= ~200 tokens per query ✅

Savings: 10x reduction! 🎉
```

---

## 🔄 Maintenance

### When Index Gets Stale
```bash
# In Copilot chat, after big refactoring:
# Use: mcp_codebase-memo_index_repository
# Project: flutter-catatan-keuangan
# Mode: "moderate" (balanced speed/accuracy)
# Persistence: true
```

### Detect What Changed
```bash
# After merging a big PR:
# Use: mcp_codebase-memo_detect_changes
# Project: flutter-catatan-keuangan
# Since: <last-index-commit>
```

---

## 📋 Commands Reference

### In Copilot Chat

```
Query Architecture:
→ "Get architecture with all aspects"
→ Tool: mcp_codebase-memo_get_architecture

Search Code:
→ "Search for [pattern]"
→ Tool: mcp_codebase-memo_search_code

Trace Dependencies:
→ "What calls [function]?"
→ Tool: mcp_codebase-memo_trace_path

Impact Analysis:
→ "What breaks if we change [class]?"
→ Tool: mcp_codebase-memo_trace_path (reverse)

Detect Changes:
→ "What changed since [commit]?"
→ Tool: mcp_codebase-memo_detect_changes

Update Index:
→ "Reindex the codebase"
→ Tool: mcp_codebase-memo_index_repository
```

---

## ⚠️ Troubleshooting

### "Copilot doesn't use the graph"
**Fix:** Graph loads automatically on startup. Restart Copilot window.

### "Results seem outdated"
**Fix:** After major refactoring, re-index:
- Use: `mcp_codebase-memo_index_repository` with mode "full"

### "Query is too slow"
**Fix:** Narrow your scope:
- Use `path` parameter to limit to specific directory
- Use `search_code` with file_pattern instead of searching all files

### "Graph is too big"
**Info:** Graph is already compressed 86% (2.4MB → 330KB)
- Further optimization: Use mode "moderate" instead of "full"

---

## 🎓 Learning Resources

- [ADR_ARCHITECTURE.md](./ADR_ARCHITECTURE.md) - 5 architectural decisions
- [CODEBASE_MEMORY_SETUP.md](./CODEBASE_MEMORY_SETUP.md) - Technical setup
- Graph Statistics: `.codebase-memory/artifact.json`
- Knowledge Graph: `.codebase-memory/graph.db.zst` (persistent)

---

## 🚀 Next Steps for Your Team

1. **Install MCP integration** (if not done)
   - Copilot auto-loads `.codebase-memory/` index
   - No manual setup needed

2. **Share with team**
   ```bash
   git push  # Graph shared via .codebase-memory/graph.db.zst
   ```

3. **Start querying**
   - Use tools in Copilot chat
   - Watch token savings 📊

4. **Maintain the index**
   - After major changes: reindex
   - After PRs: detect changes
   - Document decisions: update ADR

---

## 📞 Questions?

| Question | Answer |
|----------|--------|
| How often to reindex? | After major features (~100+ line refactors) |
| Is graph safe to commit? | Yes! It's already compressed & stable |
| Can I delete the graph? | Yes, but you'll lose token savings. Reindex anytime. |
| Does it work on Windows? | Yes, cross-platform support included |
| Cost to maintain? | Zero - it's all offline & cached |

---

**Last Updated:** 2026-08-07  
**For Project:** flutter-catatan-keuangan  
**Status:** Ready for team use ✅
