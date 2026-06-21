# SwiftUI Migration — Document Index

## Quick Reference

### For Understanding API → DataManager Flow

| Document | Purpose | Read When |
|----------|---------|-----------|
| `speckit.migration.globalvariables.specify` | **Complete spec** with API integration section | Kickoff + requirements reference |
| `skills.datamanager-api-integration.swift` | **Patterns & code examples** for refactoring | Before starting implementation |
| `api-to-datamanager-mapping.md` | **API endpoints → DataManager mapping** | Implementing specific endpoint |
| `README_DATAMANAGERS.md` | **Navigation & overview** | Confused about where to start |

---

## Document Descriptions

### 1. `speckit.migration.globalvariables.specify`

**Type:** Full Feature Specification  
**Size:** 473 lines  
**Audience:** Tech leads, developers, reviewers  

**Sections:**
- 🧠 Overview — problem statement
- 🔎 Current globals inventory (9 variables catalogued)
- 🎯 Goals (7 goals)
- ❗ Functional Requirements — 10 REQ-DM requirements + **6 NEW REQ-API requirements**
- 🔗 Architecture Constraints
- 📁 Files to Create/Modify (detailed)
- 🔄 Migration Order (5 phases)
- 🌐 **API Integration Pattern (NEW)** — REQ-API-1 through REQ-API-6
- 📊 Success Criteria (13 items)

**Key Addition:** `🌐 API Integration Pattern` section shows:
- Current API access pattern (Task, async-await, JSON parsing)
- How to refactor VC calls to write into DataManager
- How to refactor static fetch functions
- Optional convenience methods on DataManager
- Error handling requirements
- Main-actor safety requirements
- With code examples for each pattern

**When to Use:**
- ✅ During kickoff: read entire spec for context
- ✅ During implementation: REQ-API section defines requirements
- ✅ During code review: verify against success criteria

---

### 2. `skills.datamanager-api-integration.swift`

**Type:** Skill Guide (formatted as Swift comments)  
**Size:** 350+ lines  
**Audience:** Developers implementing the refactoring  

**Patterns Included (9 total):**
1. Basic VC → AppServices → JSON → DataManager flow
2. Static fetch functions refactoring
3. DataManager with optional fetch method (Phase 2+)
4. Observing in UIKit VCs (Combine sink)
5. Observing in SwiftUI (ObservedObject)
6. Error handling best practices
7. Main-thread safety rules
8. Refactoring checklist (8 steps)
9. Integration points summary with diagram

**Code Examples:**
- Before/after for VenuesVC.addLocation()
- Before/after for SeatsData.addData()
- Optional convenience method pattern
- UIKit subscription + cancellable storage
- SwiftUI @ObservedObject injection

**When to Use:**
- ✅ First time refactoring a global: read entire file
- ✅ Stuck on error handling: see pattern #6
- ✅ Need refactoring checklist: jump to section #8
- ✅ Copy-paste code: all syntax is valid Swift (no pseudo-code)

---

### 3. `api-to-datamanager-mapping.md`

**Type:** API Reference Table + Detailed Flows  
**Size:** 400+ lines  
**Audience:** Developers verifying endpoint mappings  

**Contents:**

**Part 1: Overview Table**
- 9 rows (services/endpoints)
- Target DataManager + property
- Response format column

**Part 2: Detailed Endpoint Flows (9 sections)**
Each includes:
- Source API: `appServices.mbooks.locations()`
- Response format: sample JSON
- Parsing & mapping: copy-paste code
- Current call sites: where it's used today
- Post-migration call sites: where it will be used

**Endpoints Documented:**
1. mbooks.locations() → VenuesDataManager.venues
2. mbooks.locations() (filtered) → VenuesDataManager.filteredVenues
3. mbooks.seats() → BasketDataManager.seats
4. mbooks.checkout() → BasketDataManager.tickets
5. mbooks.screens() → AdminDataManager.screenings
6. mbooks.moviesPaging() → MoviesDataManager.movies
7. mbooks.adminScreenings() → MoviesDataManager.adminScreenings
8. User selection → BasketDataManager.items
9. User selection → BasketDataManager.ticketMap

**Part 3: Best Practices**
- Always reset before fetch
- Collect in temp array before publish
- Always log errors
- Main thread only

**When to Use:**
- ✅ Working on a specific API endpoint: find its section
- ✅ Need response format: check JSON examples
- ✅ Need parsing code: copy from "Parsing & mapping" subsection
- ✅ Verifying you're writing to the right property: check target column

---

### 4. `README_DATAMANAGERS.md`

**Type:** Navigation & Overview  
**Size:** 280+ lines  
**Audience:** Anyone confused about where to start  

**Sections:**
- Quick reference table (which file for what)
- How to use (dev → impl, code review, arch)
- Key concepts explained
- 4 DataManagers overview table
- Phased migration order (5 phases)
- Files to create/modify summary
- Success metrics checklist
- References (Apple docs links)
- Questions? → refer to skill guide

**When to Use:**
- ✅ First time contributor: read flow in "For Developers Implementing"
- ✅ Starting code review: jump to "For Code Review" section
- ✅ Lost in the specs: use "Files" section table to navigate
- ✅ Want quick overview: read first 3 sections

---

## Decision Tree

### "I'm implementing this feature. Where do I start?"
→ Read `README_DATAMANAGERS.md` → Follow "For Developers" flow  
→ Start with `speckit.migration.globalvariables.specify`  
→ Study `skills.datamanager-api-integration.swift` for patterns  
→ Use `api-to-datamanager-mapping.md` while coding

### "I need to refactor VenuesVC.addLocation(). What do I do?"
→ Find endpoint in `api-to-datamanager-mapping.md` (mbooks.locations)  
→ Copy response format + parsing code  
→ Reference pattern #1 in `skills.datamanager-api-integration.swift`  
→ Apply to your VC

### "I'm reviewing a DataManager refactoring. What should I check?"
→ Open `speckit.migration.globalvariables.specify`  
→ Check against REQ-DM-* and REQ-API-* sections  
→ Verify against success criteria checklist  
→ Spot-check code against `skills.datamanager-api-integration.swift` patterns

### "What's the overall migration strategy?"
→ Read `speckit.migration.globalvariables.specify` (Overview + Goals)  
→ Review 5-phase plan in README_DATAMANAGERS.md  
→ Check architecture constraints in spec

### "I'm stuck on a specific pattern (e.g., error handling)"
→ Search `skills.datamanager-api-integration.swift` for pattern name  
→ Copy example code  
→ Apply to your situation

---

## Document Characteristics

| Document | Audience | Format | Length | Readability |
|----------|----------|--------|--------|-------------|
| speckit.migration.globalvariables.specify | Tech leads, devs | Markdown-style spec | 473 lines | Very detailed |
| skills.datamanager-api-integration.swift | Developers | Swift file w/ comments | 350 lines | Runnable code |
| api-to-datamanager-mapping.md | Developers | Markdown table + detail | 400 lines | Very structured |
| README_DATAMANAGERS.md | Everyone | Markdown guide | 280 lines | Quick reference |

---

## Total Documentation

- **4 documents** (1 spec update, 3 new)
- **~1,500 lines** total
- **9 API endpoints** documented
- **9 refactoring patterns** with code
- **4 DataManagers** defined
- **13+ files** identified for modification
- **5-phase migration** strategy
- **100% code examples** valid Swift syntax

---

## Print/Export

All documents are in plain markdown + Swift comments for easy sharing:
- Markdown files: use any markdown viewer or GitHub
- Swift file: open in Xcode or any text editor
- Spec file: use any markdown viewer

---

## Questions?

Refer to the document that matches your role/need from the "Decision Tree" section above.

Most common next step: **Read README_DATAMANAGERS.md → then speckit.migration.globalvariables.specify**

