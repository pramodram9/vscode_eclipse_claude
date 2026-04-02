# Functional Specification Document (FSD)
## Employee Leave Tracker — RAP Managed BO + Fiori Elements

**Version:** 2.0 | **Date:** April 2026 | **Status:** Demo-Ready
**Target Environment:** SAP BTP ABAP Cloud Trial (no standard tables)
**Technology:** RAP Managed, CDS View Entity, Fiori Elements V4, OData V4

---

## 1. Overview

A simple single-entity RAP application to track employee leave requests. Employees can create, edit, and delete leave entries. Each entry has a status field with Fiori criticality coloring (New=Grey, Approved=Green, Rejected=Red). The application uses a List Report + Object Page floorplan.

**Why this scenario:** Single entity, no compositions, no dependencies on standard SAP tables, no external value helps — fully self-contained for BTP Cloud Trial.

---

## 2. Data Model — Single Entity

### Database Table: `ZLVTRK_D_LEAVE`

| Field | CDS Alias | Type | Key | Description |
|-------|-----------|------|-----|-------------|
| CLIENT | (handled by framework) | CLNT | Yes | Client |
| LEAVE_ID | LeaveId | CHAR(10) | Yes | Unique leave request ID |
| EMPLOYEE_NAME | EmployeeName | CHAR(60) | No | Employee full name |
| LEAVE_TYPE | LeaveType | CHAR(20) | No | Annual / Sick / Personal / Other |
| START_DATE | StartDate | DATS | No | Leave start date |
| END_DATE | EndDate | DATS | No | Leave end date |
| NUM_DAYS | NumDays | INT4 | No | Number of leave days |
| REASON | Reason | CHAR(255) | No | Leave reason text |
| STATUS | Status | CHAR(1) | No | N=New, A=Approved, R=Rejected |
| CREATED_BY | CreatedBy | CHAR(12) | No | Created by user |
| CREATED_AT | CreatedAt | TIMESTAMPL | No | Creation timestamp |
| LAST_CHANGED_BY | LastChangedBy | CHAR(12) | No | Last changed by |
| LAST_CHANGED_AT | LastChangedAt | TIMESTAMPL | No | Last changed timestamp |

---

## 3. Naming Conventions

| Artifact | Name |
|----------|------|
| Database Table | ZLVTRK_D_LEAVE |
| Interface CDS View | ZLVTRK_I_Leave |
| Consumption CDS Projection | ZLVTRK_C_Leave |
| Behavior Definition | ZLVTRK_I_Leave |
| Metadata Extension | ZLVTRK_C_Leave |
| Service Definition | ZLVTRK_SD_Leave |
| Service Binding | ZLVTRK_SB_Leave_V4 |

---

## 4. Artifact List (6 Total)

| # | Artifact | Type | Purpose |
|---|----------|------|---------|
| 1 | ZLVTRK_D_LEAVE | Database Table | Persistence |
| 2 | ZLVTRK_I_Leave | CDS View Entity | Interface layer with all fields |
| 3 | ZLVTRK_I_Leave | Behavior Definition | Managed BO with draft, basic CRUD |
| 4 | ZLVTRK_C_Leave | CDS Projection | Consumption layer for Fiori UI |
| 5 | ZLVTRK_C_Leave | Metadata Extension | @UI annotations for List Report + Object Page |
| 6 | ZLVTRK_SD_Leave + ZLVTRK_SB_Leave_V4 | Service Def + Binding | OData V4 exposure |

---

## 5. Behavior Definition

- **Implementation Type:** managed
- **Persistent Table:** zlvtrk_d_leave
- **Draft:** enabled (with draft table auto-generated)
- **ETag:** field LastChangedAt
- **Operations:** create, update, delete
- **No custom validations, no actions, no determinations** (keep it simple for demo)

---

## 6. Fiori UI Specification

### List Report
- **Filter Fields:** EmployeeName, LeaveType, Status, StartDate
- **Table Columns:** LeaveId, EmployeeName, LeaveType, StartDate, EndDate, NumDays, Status (with criticality)

### Object Page
- **Header:** LeaveId + EmployeeName, Status badge with criticality
- **General Info Facet:** EmployeeName, LeaveType, StartDate, EndDate, NumDays, Reason
- **Admin Facet:** CreatedBy, CreatedAt, LastChangedBy, LastChangedAt (read-only)

### Status Criticality
- N (New) = 0 (Grey)
- A (Approved) = 3 (Green / Positive)
- R (Rejected) = 1 (Red / Negative)

---

## 7. Single-Line Prompts for Claude Code Demo

These are the exact prompts to type during the live demo:

**Prompt 1 — Generate everything:**
```
Read FSD_LeaveTracker.md and generate all 6 RAP artifacts: database table, interface CDS view entity, behavior definition with managed and draft, consumption projection, metadata extension with List Report and Object Page annotations including status criticality, service definition and OData V4 service binding. Use ZLVTRK_ prefix, ABAP Cloud syntax, no standard table dependencies.
```

**Prompt 2 — Refinement (if needed):**
```
Add @UI.selectionField annotations for EmployeeName, LeaveType, Status, and StartDate in the metadata extension.
```

**Prompt 3 — Prepare for deploy:**
```
Run /abap-git-fix for all generated classes and prepare the folder structure for abapGit with FULL folder logic.
```

---

## 8. Key Constraints (BTP Cloud Trial)

- **NO standard tables** (no MARA, VBAK, etc.)
- **NO released CDS views** as associations (no I_BusinessPartner, I_Currency)
- **ALL fields are custom** — fully self-contained
- **NO value helps** pointing to external entities
- LeaveType is a free-text field (no domain/fixed values dependency)
- Status is a simple CHAR(1) with criticality mapped in the metadata extension
