# Codebase Memory MCP Setup Guide

## ✅ Status: AKTIF

Project ini sudah dikonfigurasi dengan **codebase-memory-mcp** untuk optimasi token dan AI understanding.

**Indexed at:** 2026-08-07
**Graph Size:** 838 nodes, 1,277 edges
**Compressed Size:** 330 KB (86% compression)
**Commit:** 46e42cf266600018114f06d503fa9c3264ff20c8

---

## 📦 Apa itu Codebase Memory?

Codebase Memory adalah MCP server yang:
- ✅ Index seluruh codebase ke graph database
- ✅ Hemat **60-90% token** pada AI requests  
- ✅ Memberikan AI context lengkap tentang architecture
- ✅ Enable cross-file type-aware analysis
- ✅ Support team sharing via persistent artifacts

---

## 🚀 Cara Menggunakan di Copilot

### 1. **Query Architecture**
```
Gunakan tool: mcp_codebase-memo_get_architecture
```
AI akan understand struktur project Anda tanpa membaca ratusan file.

### 2. **Search Code Semantically**
```
Gunakan tool: mcp_codebase-memo_search_code
```
Cari berdasarkan meaning, bukan hanya keyword.

### 3. **Trace Dependencies**
```
Gunakan tool: mcp_codebase-memo_trace_path
```
Understand call chains dan dependencies across files.

### 4. **Detect Changes**
```
Gunakan tool: mcp_codebase-memo_detect_changes
```
Automatic impact analysis saat ada code changes.

---

## 💾 Persistent Artifact

File `.codebase-memory/graph.db.zst` adalah compressed index yang:

- **Tersimpan di git** untuk team sharing
- **Auto-load** saat codebase-memory MCP start
- **Berkala di-update** saat ada changes

Untuk commit team:
```bash
git add .codebase-memory/
git commit -m "chore: update codebase-memory index"
git push
```

---

## 🔄 Maintenance

### Update Index (Jika ada major code changes)
```bash
# Menggunakan tools di Copilot:
# 1. Buka copilot chat
# 2. Gunakan mcp_codebase-memo_index_repository dengan repo_path:
#    /home/fedora-firdaus/Dokumen/projek/flutter-catatan-keuangan
# 3. Set persistence: true
# 4. Set mode: "moderate" atau "full"
```

### Detect Changes
```bash
# Tools: mcp_codebase-memo_detect_changes
# Project: flutter-catatan-keuangan
# Since: <last-commit-sha>
```

### Architecture Decision Records
```bash
# Tools: mcp_codebase-memo_manage_adr
# Mode: create/update untuk document arsitektur decisions
```

---

## 📊 Graph Statistics

| Metric | Value |
|--------|-------|
| Total Nodes | 838 |
| Total Edges | 1,277 |
| Original Size | 2.4 MB |
| Compressed Size | 330 KB |
| Compression Ratio | 86% |

---

## 🎯 Token Savings Example

### Without Codebase Memory:
```
User: "Tell me about the main.dart architecture"
AI: Reads all files, summarizes → ~2,000 tokens per request
```

### With Codebase Memory:
```
User: "Tell me about the main.dart architecture"  
AI: Queries graph → ~200-300 tokens per request
Savings: 80-90% 🎉
```

---

## 🛠️ Troubleshooting

### Graph tidak update?
- Run `mcp_codebase-memo_detect_changes` untuk check
- Re-index jika perlu dengan mode "full"

### Artifact corrupted?
- Delete `.codebase-memory/` folder
- Re-run indexing dari Copilot

### Need fresh index?
```bash
# Tools: mcp_codebase-memo_delete_project
# Project: flutter-catatan-keuangan
# Kemudian re-index
```

---

## 📝 Files

- `.codebase-memory/graph.db.zst` - Compressed graph database
- `.codebase-memory/artifact.json` - Metadata & indexing info
- `.codebase-memory/.gitattributes` - Git LFS config (jika perlu)

---

## ✨ Next Steps

1. ✅ Codebase indexed
2. ✅ Artifact committed to git
3. ✅ **Use in Copilot Chat** - copilot auto-use graph untuk queries
4. ✅ **Create ADR** - Architecture Decision Records documented
5. 🔜 **Team Share** - Push ke repo, teammates di-auto-load index

---

## 📚 Documentation Created

- ✅ [ADR_ARCHITECTURE.md](./ADR_ARCHITECTURE.md) - 5 ADRs covering architecture
- ✅ [CODEBASE_MEMORY_SETUP.md](./CODEBASE_MEMORY_SETUP.md) - This setup guide
- ✅ `.codebase-memory/graph.db.zst` - Persistent knowledge graph
- ✅ `.codebase-memory/artifact.json` - Graph metadata

---

**Setup by:** Copilot + codebase-memory-mcp  
**Last Updated:** 2026-08-07  
**Status:** COMPLETE ✅
