# Technical Specification Document (TSD)
## Employee Leave Tracker — RAP Managed Business Object

---

| Attribute        | Value                                      |
|------------------|--------------------------------------------|
| **Document ID**  | TSD-ZLVTRK-001                             |
| **Version**      | 1.0                                        |
| **Status**       | Draft                                      |
| **Date**         | April 2026                                 |
| **Author**       | Development Team                           |
| **Reviewer**     | Solution Architect / Tech Lead             |
| **Based On FSD** | FSD-ZLVTRK-001 v2.0                        |
| **Target System**| SAP BTP ABAP Cloud Trial (Cloud Essentials)|
| **Technology**   | ABAP Cloud, RAP Managed BO, CDS View Entity, Fiori Elements V4, OData V4 |

---

## Table of Contents

1. [Solution Architecture Overview](#1-solution-architecture-overview)
2. [Technical Stack & Constraints](#2-technical-stack--constraints)
3. [Naming Conventions](#3-naming-conventions)
4. [Data Model Design](#4-data-model-design)
5. [CDS View Layer](#5-cds-view-layer)
6. [RAP Business Object Design](#6-rap-business-object-design)
7. [Behavior Implementation Class](#7-behavior-implementation-class)
8. [OData Service Layer](#8-odata-service-layer)
9. [UI — Fiori Elements Annotations](#9-ui--fiori-elements-annotations)
10. [Authorization Concept](#10-authorization-concept)
11. [SAP HANA Performance Design](#11-sap-hana-performance-design)
12. [Draft Handling Design](#12-draft-handling-design)
13. [Error Handling & Validation Design](#13-error-handling--validation-design)
14. [Transport & Deployment](#14-transport--deployment)
15. [Testing Strategy](#15-testing-strategy)
16. [Activation Sequence](#16-activation-sequence)
17. [Open Items & Constraints](#17-open-items--constraints)

---

## 1. Solution Architecture Overview

### 1.1 Purpose

This document provides the complete technical specification for the **Employee Leave Tracker** application. The application enables employees to create, edit, and manage leave requests through a Fiori Elements List Report + Object Page UI. It is implemented using the **SAP RESTful Application Programming Model (RAP)** on SAP BTP ABAP Cloud.

### 1.2 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Fiori Elements V4 UI                         │
│              List Report + Object Page (OData V4 client)            │
└───────────────────────────────┬─────────────────────────────────────┘
                                │ OData V4
┌───────────────────────────────▼─────────────────────────────────────┐
│              Service Binding: ZLVTRK_SB_LEAVE_V4  (OData V4)        │
│              Service Definition: ZLVTRK_SD_LEAVE                    │
└───────────────────────────────┬─────────────────────────────────────┘
                                │ exposes
┌───────────────────────────────▼─────────────────────────────────────┐
│  Consumption Layer (Projection)                                     │
│  ├── CDS Projection View:  ZLVTRK_C_Leave  (transactional_query)    │
│  ├── Projection BDEF:      ZLVTRK_C_Leave  (use create/update/...)  │
│  └── Metadata Extension:  ZLVTRK_C_Leave  (@UI annotations, DDLX)  │
└───────────────────────────────┬─────────────────────────────────────┘
                                │ projection on
┌───────────────────────────────▼─────────────────────────────────────┐
│  Interface (BO) Layer                                               │
│  ├── CDS Interface View:  ZLVTRK_I_Leave  (root view entity)        │
│  └── Interface BDEF:      ZLVTRK_I_Leave  (managed, with draft)     │
└───────────────────────────────┬─────────────────────────────────────┘
                                │ select from / maps to
┌───────────────────────────────▼─────────────────────────────────────┐
│  Persistence Layer (SAP HANA)                                       │
│  ├── Active Table:  ZLVTRK_D_LEAVE    (transparent, APPL0)          │
│  └── Draft Table:   ZLVTRK_D_LEAVE_D  (transparent, SYCH_BDL_DRAFT) │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.3 RAP BO Layer Responsibilities

| Layer | Artifact | Responsibility |
|-------|----------|----------------|
| Persistence | `ZLVTRK_D_LEAVE` | Stores active (committed) leave records |
| Persistence | `ZLVTRK_D_LEAVE_D` | Stores draft (in-progress) leave records |
| Interface | `ZLVTRK_I_Leave` (DDLS) | BO data model; field aliases, computed fields, `@Semantics` admin annotations |
| Interface | `ZLVTRK_I_Leave` (BDEF) | BO behaviour: managed CRUD, draft actions, field controls, DB mapping |
| Consumption | `ZLVTRK_C_Leave` (DDLS) | Consumer-facing projection; `@Metadata.allowExtensions`, search enablement |
| Consumption | `ZLVTRK_C_Leave` (BDEF) | Projection behaviour: delegates operations to interface BDEF via `use` |
| Presentation | `ZLVTRK_C_Leave` (DDLX) | All `@UI` annotations: list items, selection fields, facets, criticality |
| Service | `ZLVTRK_SD_LEAVE` | Service definition: exposes projection entity |
| Service | `ZLVTRK_SB_LEAVE_V4` | OData V4 service binding; publishable endpoint |

---

## 2. Technical Stack & Constraints

### 2.1 Platform

| Item | Value |
|------|-------|
| Platform | SAP Business Technology Platform (BTP) |
| ABAP Environment | SAP BTP ABAP Cloud Trial |
| ABAP Language Version | ABAP Cloud (version 5 — `ABAP_LANGU_VERSION = 5`) |
| OData Protocol | OData V4 |
| UI Framework | SAP Fiori Elements V4 (List Report + Object Page) |
| RAP Flavour | Managed BO with Draft |
| Strict Mode | `strict ( 2 )` |

### 2.2 Hard Constraints

| # | Constraint | Rationale |
|---|-----------|-----------|
| C1 | No standard SAP tables (MARA, VBAK, PA0001, etc.) | BTP Cloud Trial: no ERP system connected |
| C2 | No released CDS views as associations (I_BusinessPartner, I_Currency) | Same as C1 — no S/4 backend |
| C3 | No custom domains or fixed-value sets | Kept self-contained; LeaveType is free text |
| C4 | No value help pointing to external entities | Same as C1/C2 |
| C5 | ABAP Cloud syntax only — no deprecated ABAP statements | `strict(2)` enforces this at compile time |
| C6 | All custom objects use prefix `ZLVTRK_` | Namespace isolation per customer namespace convention |

### 2.3 ABAP Cloud Compliance

The implementation follows **ABAP Cloud** development model rules:
- All released APIs only (ABAP Language Version 5)
- No direct SELECT on standard tables
- CDS view entity syntax (`define root view entity`) — not classic `define view`
- `managed` RAP with `strict(2)` — no implicit behaviour
- `@AccessControl.authorizationCheck: #NOT_REQUIRED` during development; upgrade to `#CHECK` with IAM app in production (see Section 10)

---

## 3. Naming Conventions

### 3.1 Object Prefix

All objects in this development use prefix **`ZLVTRK_`** (Z = custom, LVTRK = Leave Tracker abbreviation).

### 3.2 Object Name Registry

| Object Type | Technical Name | Description |
|-------------|---------------|-------------|
| Database Table (Active) | `ZLVTRK_D_LEAVE` | Persistent active data |
| Database Table (Draft) | `ZLVTRK_D_LEAVE_D` | RAP draft data |
| CDS Interface View | `ZLVTRK_I_Leave` | Interface BO layer |
| CDS Projection View | `ZLVTRK_C_Leave` | Consumption layer |
| Metadata Extension | `ZLVTRK_C_Leave` | UI annotations (DDLX) |
| Interface BDEF | `ZLVTRK_I_Leave` | Interface behaviour definition |
| Projection BDEF | `ZLVTRK_C_Leave` | Projection behaviour definition |
| Behaviour Impl. Class | `ZBP_ZLVTRK_I_Leave` | ABAP class (RAP handler) |
| Service Definition | `ZLVTRK_SD_Leave` | OData service definition |
| Service Binding | `ZLVTRK_SB_Leave_V4` | OData V4 service binding |

### 3.3 CDS Field Naming

CDS field aliases use **UpperCamelCase** (PascalCase). Database column names use **snake_case** with underscore separators. The BDEF `mapping` block bridges the two naming conventions explicitly.

### 3.4 File Extension Conventions (abapGit)

| Artifact Type | XML Companion | Source File |
|---------------|--------------|-------------|
| DB Table | `.tabl.xml` | — (DDL only in XML) |
| CDS View Entity | `.ddls.xml` | `.ddls.asddls` |
| Behaviour Definition | `.bdef.xml` | `.bdef.asbdef` |
| Metadata Extension | `.ddlx.xml` | `.ddlx.asddlxs` |
| Service Definition | `.srvd.xml` | `.srvd.srvdsrv` |
| Service Binding | `.srvb.xml` | — (no separate source) |

---

## 4. Data Model Design

### 4.1 Entity-Relationship Overview

```
┌────────────────────────────────────────┐
│           ZLVTRK_D_LEAVE               │
│  (Single root entity — no children)   │
│                                        │
│  PK  MANDT       CLNT                  │
│  PK  LEAVE_ID    CHAR(10)              │
│      EMPLOYEE_NAME  CHAR(60)           │
│      LEAVE_TYPE     CHAR(20)           │
│      START_DATE     DATS               │
│      END_DATE       DATS               │
│      NUM_DAYS       INT4               │
│      REASON         CHAR(255)          │
│      STATUS         CHAR(1)            │
│      CREATED_BY     SYUNAME            │
│      CREATED_AT     TIMESTAMPL         │
│      LAST_CHANGED_BY  SYUNAME          │
│      LAST_CHANGED_AT  TIMESTAMPL       │
└────────────────────────────────────────┘
```

This is a **single-entity BO** with no parent-child composition. All leave data resides in one table row per leave request.

### 4.2 Active Table: `ZLVTRK_D_LEAVE`

| # | Column Name | CDS Alias | ABAP Type | DB Type | Length | Key | Null | Description |
|---|-------------|-----------|-----------|---------|--------|-----|------|-------------|
| 1 | `MANDT` | — | `MANDT` (rollname) | CLNT | 3 | PK | NOT NULL | Client (framework-managed) |
| 2 | `LEAVE_ID` | `LeaveId` | CHAR | CHAR | 10 | PK | NOT NULL | Unique leave request identifier |
| 3 | `EMPLOYEE_NAME` | `EmployeeName` | CHAR | CHAR | 60 | — | NULL | Full name of the requesting employee |
| 4 | `LEAVE_TYPE` | `LeaveType` | CHAR | CHAR | 20 | — | NULL | Category: Annual / Sick / Personal / Other |
| 5 | `START_DATE` | `StartDate` | DATS | DATS | 8 | — | NULL | First day of leave (YYYYMMDD) |
| 6 | `END_DATE` | `EndDate` | DATS | DATS | 8 | — | NULL | Last day of leave (YYYYMMDD) |
| 7 | `NUM_DAYS` | `NumDays` | INT4 | INT4 | 10 | — | NULL | Total calendar/working days |
| 8 | `REASON` | `Reason` | CHAR | CHAR | 255 | — | NULL | Free-text reason for leave |
| 9 | `STATUS` | `Status` | CHAR | CHAR | 1 | — | NULL | N=New, A=Approved, R=Rejected |
| 10 | `CREATED_BY` | `CreatedBy` | `SYUNAME` (rollname) | CHAR | 12 | — | NULL | SAP user ID — auto-populated by RAP |
| 11 | `CREATED_AT` | `CreatedAt` | `TIMESTAMPL` (rollname) | DEC | 21 | — | NULL | UTC timestamp — auto-populated by RAP |
| 12 | `LAST_CHANGED_BY` | `LastChangedBy` | `SYUNAME` (rollname) | CHAR | 12 | — | NULL | SAP user ID — auto-populated by RAP |
| 13 | `LAST_CHANGED_AT` | `LastChangedAt` | `TIMESTAMPL` (rollname) | DEC | 21 | — | NULL | UTC timestamp — used as ETag |

**Table Class:** TRANSP (transparent table)
**Data Class:** APPL0 (master and transaction data)
**Buffering:** Not buffered (`BUFALLOW = N`) — transactional table, buffering inappropriate
**Client-Dependent:** Yes (`CLIDEP = X`)
**Content Flag:** A (application content)
**Delivery Class:** C (Customer: not delivered with SAP transport)

#### 4.2.1 SAP HANA Physical Storage Notes

- Transparent tables in SAP HANA are stored as **column-store tables** by default.
- The primary key `(MANDT, LEAVE_ID)` creates a unique index automatically.
- `TIMESTAMPL` is stored as a 21-digit decimal (`DEC(21,0)`). All timestamps are in **UTC**; conversion to display timezone is handled by the UI layer.
- `DATS` fields are stored as 8-character strings (`YYYYMMDD`) in HANA. Date arithmetic should use ABAP Date arithmetic or CDS `$session.system_date` — not raw string comparison.
- `INT4` is mapped to a 4-byte signed integer in HANA (`INTEGER` type).

#### 4.2.2 Status Field Value Domain

| Value | Meaning | UI Criticality | Colour |
|-------|---------|---------------|--------|
| `N` | New (initial) | 0 | Grey (neutral) |
| `A` | Approved | 3 | Green (positive) |
| `R` | Rejected | 1 | Red (negative) |
| _(blank)_ | Not set | 0 | Grey (fallback) |

> **Note:** No ABAP domain or fixed-value set is used for `STATUS` — validation of allowed values should be added in a future `validation` implementation (see Section 13). The criticality mapping is implemented as a `CASE` expression in the CDS interface view, not as a stored column.

### 4.3 Draft Table: `ZLVTRK_D_LEAVE_D`

The draft table mirrors all columns of the active table **plus** the RAP draft administration include.

| Additional Element | Type | Purpose |
|-------------------|------|---------|
| `.INCLUDE SYCH_BDL_DRAFT_ADMIN_INC` | Structure include | Provides RAP draft administration fields: `%IS_DRAFT`, `%ADMIN` group (`DRAFTENTITYCREATIONDATETIME`, `DRAFTENTITYLASTCHANGEDATETIME`, `DRAFTADMINISTRATIVEDATAUUID`, `DRAFTENTITYOPERATIONCODE`, `LOCALDRAFTINDICATOR`, `DRAFTFIELDCHANGES`) |

**LANGDEP:** `X` (language-dependent) — required for draft tables.
**EXCLASS:** 4 (Exception Class for draft — SAP internal classification).
**Buffering:** Not buffered.

> The draft table is managed entirely by the RAP framework. Application code must never directly SELECT, INSERT, UPDATE, or DELETE from `ZLVTRK_D_LEAVE_D`.

### 4.4 Key Design — `LEAVE_ID`

`LEAVE_ID` is a `CHAR(10)` key managed by application logic. In the current implementation it is declared as `field ( readonly )` in the BDEF, meaning the framework expects the consuming application (or a future `determination`) to supply it.

**Recommended future enhancement:** Implement a `determination setLeaveId on modify { create; }` that generates a zero-padded sequential ID (e.g. `LV0000001`) using a number range object or a UUID-based approach via `cl_system_uuid`.

---

## 5. CDS View Layer

### 5.1 Interface View: `ZLVTRK_I_Leave`

**File:** `zlvtrk_i_leave.ddls.asddls`
**Type:** `define root view entity` (CDS View Entity — ABAP Cloud syntax)
**Base Table:** `zlvtrk_d_leave`

#### 5.1.1 View Annotations

| Annotation | Value | Rationale |
|-----------|-------|-----------|
| `@AccessControl.authorizationCheck` | `#NOT_REQUIRED` | Development phase; replace with `#CHECK` for production and bind an IAM Business Catalog |
| `@EndUserText.label` | `'Leave Tracker - Interface (Root BO) View'` | Displayed in ADT and transport descriptions |
| `@ObjectModel.usageType.serviceQuality` | `#A` | Quality A: stable API contract; suitable for RAP BO root |
| `@ObjectModel.usageType.sizeCategory` | `#S` | Small dataset expected (single-user leave requests) |
| `@ObjectModel.usageType.dataClass` | `#TRANSACTIONAL` | Transactional data — records are frequently created/updated/deleted |

#### 5.1.2 Field-Level Annotations

| CDS Element | Annotation | Purpose |
|-------------|-----------|---------|
| `CreatedBy` | `@Semantics.user.createdBy: true` | RAP framework auto-populates with `sy-uname` on CREATE |
| `CreatedAt` | `@Semantics.systemDateTime.createdAt: true` | RAP framework auto-populates with UTC timestamp on CREATE |
| `LastChangedBy` | `@Semantics.user.lastChangedBy: true` | RAP framework auto-populates with `sy-uname` on every MODIFY |
| `LastChangedAt` | `@Semantics.systemDateTime.lastChangedAt: true` | RAP framework auto-populates UTC timestamp; used as **ETag** for optimistic locking |

#### 5.1.3 Computed Field: `StatusCriticality`

```cds
case status
  when 'A' then 3   -- positive / green
  when 'R' then 1   -- negative / red
  else          0   -- neutral  / grey
end                 as StatusCriticality
```

This is a **virtual computed column** evaluated at query time by SAP HANA. It is never persisted to the database. The field is declared `field ( readonly )` in the BDEF to prevent any write attempt. The values follow the SAP Fiori criticality standard:

| Value | SAP Fiori Meaning |
|-------|------------------|
| 0 | Neutral (grey) |
| 1 | Negative (red) |
| 2 | Critical (orange/yellow) |
| 3 | Positive (green) |

> **HANA optimisation note:** The `CASE` expression is pushed down to the HANA column engine. No ABAP-side processing occurs. This is the recommended pattern for criticality — never compute it in a handler class.

### 5.2 Projection View: `ZLVTRK_C_Leave`

**File:** `zlvtrk_c_leave.ddls.asddls`
**Type:** `define root view entity ... provider contract transactional_query`
**Base:** `as projection on ZLVTRK_I_Leave`

#### 5.2.1 View Annotations

| Annotation | Value | Rationale |
|-----------|-------|-----------|
| `@AccessControl.authorizationCheck` | `#NOT_REQUIRED` | Inherited from interface view; access control to be added at interface layer |
| `@Metadata.allowExtensions` | `true` | **Required** to allow the DDLX metadata extension to be applied to this view |
| `@Search.searchable` | `true` | Enables the Fiori Elements search bar on the List Report |

#### 5.2.2 Field: `@Search.defaultSearchElement: true`

Applied to `EmployeeName`. This makes the employee name the default target when a user types in the List Report search bar (free-text search). Only one field should carry this annotation.

#### 5.2.3 Provider Contract

`provider contract transactional_query` declares this view as the **UI-facing projection** for a draft-enabled transactional Fiori Elements application. This is mandatory for the List Report + Object Page floorplan with draft. It generates the correct OData EDM annotations for draft handling (`HasActiveEntity`, `IsActiveEntity`, `HasDraftEntity` virtual properties) automatically.

---

## 6. RAP Business Object Design

### 6.1 BO Node Structure

This is a **single-node BO** (root only, no child compositions):

```
Root: ZLVTRK_I_Leave  (alias: Leave)
  persistent table: zlvtrk_d_leave
  draft table:      zlvtrk_d_leave_d
```

### 6.2 Interface BDEF: `ZLVTRK_I_Leave`

**File:** `zlvtrk_i_leave.bdef.asbdef`

#### 6.2.1 BO Declaration Keywords

| Keyword | Value | Description |
|---------|-------|-------------|
| `managed` | — | RAP framework generates all CRUD SQL; no custom `save_modified` needed |
| `implementation in class` | `zbp_zlvtrk_i_leave unique` | Handler class for future custom logic (determinations, validations, actions) |
| `strict ( 2 )` | — | Strict mode level 2: all operations must be declared; no implicit behaviour |
| `with draft` | — | Enables the draft framework for this BO |

#### 6.2.2 Entity-Level Clauses

| Clause | Value | Description |
|--------|-------|-------------|
| `persistent table` | `zlvtrk_d_leave` | Active data storage |
| `draft table` | `zlvtrk_d_leave_d` | Draft data storage |
| `lock master` | `total etag LastChangedAt` | Optimistic lock using `LastChangedAt` as total ETag |
| `authorization master` | `( global )` | Global authorization check (no instance-level check in this phase) |
| `etag master` | `LastChangedAt` | HTTP ETag for OData concurrency control — maps to `LAST_CHANGED_AT` column |

#### 6.2.3 Field Controls

| Field | Control | Reason |
|-------|---------|--------|
| `LeaveId` | `readonly` | Key; to be set by number range determination on create |
| `StatusCriticality` | `readonly` | Computed in CDS; has no corresponding DB column to write to |
| `CreatedBy` | `readonly` | Set by `@Semantics.user.createdBy` framework automation |
| `CreatedAt` | `readonly` | Set by `@Semantics.systemDateTime.createdAt` framework automation |
| `LastChangedBy` | `readonly` | Set by `@Semantics.user.lastChangedBy` framework automation |
| `LastChangedAt` | `readonly` | Set by `@Semantics.systemDateTime.lastChangedAt` + used as ETag |
| `EmployeeName` | `mandatory : create` | Must be provided at create time |
| `LeaveType` | `mandatory : create` | Must be provided at create time |
| `StartDate` | `mandatory : create` | Must be provided at create time |

#### 6.2.4 CRUD Operations

| Operation | Enabled | Notes |
|-----------|---------|-------|
| `create` | Yes | Creates new draft; becomes active on Activate |
| `update` | Yes | Applies to both active and draft instances |
| `delete` | Yes | Deletes active record (and associated draft if any) |

#### 6.2.5 Draft Actions

| Draft Action | Description |
|-------------|-------------|
| `Edit` | Creates a draft copy of an active record for editing |
| `Activate optimized` | Commits draft to active table; `optimized` skips unchanged fields |
| `Discard` | Deletes the draft without saving |
| `Resume` | Re-opens an existing draft for further editing |
| `Prepare` (determine action) | Executes validations before Activate; hook point for future validations |

#### 6.2.6 Field-to-DB Mapping

The `mapping for zlvtrk_d_leave corresponding` block explicitly maps every CDS element name (PascalCase) to its database column name (snake_case):

| CDS Element | DB Column |
|-------------|-----------|
| `LeaveId` | `leave_id` |
| `EmployeeName` | `employee_name` |
| `LeaveType` | `leave_type` |
| `StartDate` | `start_date` |
| `EndDate` | `end_date` |
| `NumDays` | `num_days` |
| `Reason` | `reason` |
| `Status` | `status` |
| `CreatedBy` | `created_by` |
| `CreatedAt` | `created_at` |
| `LastChangedBy` | `last_changed_by` |
| `LastChangedAt` | `last_changed_at` |

> **Note:** `StatusCriticality` is not included in the mapping as it is a computed CDS expression with no corresponding DB column.

### 6.3 Projection BDEF: `ZLVTRK_C_Leave`

**File:** `zlvtrk_c_leave.bdef.asbdef`

| Keyword | Value |
|---------|-------|
| `projection` | Delegates all behaviour to interface BDEF |
| `strict ( 2 )` | Strict mode |
| `use draft` | Enables draft at projection layer |

All CRUD and draft operations are delegated via `use` statements. No additional operations, actions, or associations are declared at the projection layer — keeping the surface minimal and the interface BDEF as the single source of truth for behaviour.

---

## 7. Behavior Implementation Class

### 7.1 Class Skeleton

The BDEF declares `implementation in class zbp_zlvtrk_i_leave unique`. The class must be created in ADT as a **Behaviour Pool** (ABAP object type CLAS with pool sub-type).

```abap
CLASS zbp_zlvtrk_i_leave DEFINITION
  PUBLIC
  ABSTRACT
  FINAL
  FOR BEHAVIOR OF zlvtrk_i_leave.
ENDCLASS.

CLASS zbp_zlvtrk_i_leave IMPLEMENTATION.
ENDCLASS.
```

### 7.2 Current Implementation State

In the current v1.0 scope, the class body is **empty** (no custom methods). All behaviour is handled by the RAP managed framework:

- **CRUD persistence:** Auto-generated by framework (INSERT/UPDATE/DELETE on `zlvtrk_d_leave`)
- **Admin field population:** Driven by `@Semantics` annotations in the CDS view
- **Draft table management:** Fully handled by framework (SYCH_BDL layer)
- **ETag management:** Framework reads/writes `last_changed_at`

### 7.3 Planned Enhancements (Future Scope)

| # | Extension Point | Implementation Class Method | Trigger |
|---|----------------|-----------------------------|---------|
| F1 | Set initial `Status = 'N'` on create | `determination setInitialStatus` | `on modify { create; }` |
| F2 | Generate `LeaveId` from number range | `determination setLeaveId` | `on modify { create; }` |
| F3 | Validate `EndDate >= StartDate` | `validation validateDates` | `on save { create; update; field EndDate; field StartDate; }` |
| F4 | Validate `NumDays > 0` | `validation validateNumDays` | `on save { create; update; field NumDays; }` |
| F5 | Validate Status allowed values (N/A/R) | `validation validateStatus` | `on save { create; update; field Status; }` |
| F6 | Action: Approve — set Status = 'A' | `action approveLeave result [1] $self` | User-triggered on Object Page |
| F7 | Action: Reject — set Status = 'R' | `action rejectLeave result [1] $self` | User-triggered on Object Page |

---

## 8. OData Service Layer

### 8.1 Service Definition: `ZLVTRK_SD_Leave`

**File:** `zlvtrk_sd_leave.srvd.srvdsrv`

```cds
@EndUserText.label: 'Leave Tracker Service Definition'
define service ZLVTRK_SD_Leave {
  expose ZLVTRK_C_Leave as Leave;
}
```

| Property | Value |
|----------|-------|
| Exposed Entity | `ZLVTRK_C_Leave` |
| OData Entity Set Name | `Leave` |
| Entity Type Name | `LeaveType` (auto-generated by framework) |
| Draft Entity Set | `Leave_drafts` (auto-generated by framework) |

The service definition generates the following OData V4 entity sets automatically:
- `Leave` — active instances
- `Leave_drafts` — draft instances
- `$batch` endpoint — supported
- `$metadata` — EDM metadata document

### 8.2 Service Binding: `ZLVTRK_SB_Leave_V4`

**File:** `zlvtrk_sb_leave_v4.srvb.xml`

| Property | Value |
|----------|-------|
| Binding Type | `ODATA` |
| Binding Version | `V4` |
| Service Version | `0001` |
| Release State | `NOT_RELEASED` (development) |
| Published | `true` (binding is published upon activation) |

### 8.3 OData V4 Service URL Pattern

After binding publication in ADT, the service is accessible at:

```
/sap/opu/odata4/sap/zlvtrk_sb_leave_v4/srvd/sap/zlvtrk_sd_leave/0001/
```

### 8.4 Key OData V4 Operations Generated

| HTTP Method | URL Pattern | RAP Operation |
|------------|-------------|--------------|
| `GET` | `/Leave` | Read collection (List Report) |
| `GET` | `/Leave('key')` | Read single instance (Object Page) |
| `POST` | `/Leave` | `create` |
| `PATCH` | `/Leave('key')` | `update` |
| `DELETE` | `/Leave('key')` | `delete` |
| `POST` | `/Leave/com.sap.vocabularies.Common.v1.Edit` | Draft `Edit` action |
| `POST` | `/Leave/com.sap.vocabularies.Common.v1.Activate` | Draft `Activate` action |
| `DELETE` | `/Leave_drafts('key')` | Draft `Discard` |
| `POST` | `/Leave/com.sap.vocabularies.Common.v1.Prepare` | Draft `Prepare` action |

---

## 9. UI — Fiori Elements Annotations

### 9.1 Metadata Extension: `ZLVTRK_C_Leave`

**File:** `zlvtrk_c_leave.ddlx.asddlxs`
**Layer:** `@Metadata.layer: #CORE`

The DDLX is the exclusive location for all `@UI` annotations. The CDS projection view (`ZLVTRK_C_Leave`) carries no UI annotations — this separation follows VDM (Virtual Data Model) best practices and allows UI annotations to be overridden per layer.

### 9.2 Header Info

```
typeName:       'Leave Request'
typeNamePlural: 'Leave Requests'
title:          LeaveId        (displayed in Object Page header)
description:    EmployeeName   (displayed as sub-title in Object Page header)
```

### 9.3 Presentation Variant

Default sort order for the List Report:

| Property | Value |
|----------|-------|
| Sort Field | `StartDate` |
| Direction | Descending (`#DESC`) |
| Visualization | `#AS_LINEITEM` |

### 9.4 List Report — Line Item Columns

| Position | Field | Label | Criticality |
|----------|-------|-------|-------------|
| 10 | `LeaveId` | Leave ID | — |
| 20 | `EmployeeName` | Employee Name | — |
| 30 | `LeaveType` | Leave Type | — |
| 40 | `StartDate` | Start Date | — |
| 50 | `EndDate` | End Date | — |
| 60 | `NumDays` | Days | — |
| 70 | `Status` | Status | `StatusCriticality` with `#WITH_ICON` |

### 9.5 List Report — Selection / Filter Fields

| Position | Field | Filter Type |
|----------|-------|-------------|
| 10 | `EmployeeName` | Input field (free text) |
| 20 | `LeaveType` | Input field (free text) |
| 30 | `StartDate` | Date picker |
| 40 | `Status` | Input field (single char) |

### 9.6 Object Page — Facet Layout

| Position | Facet ID | Type | Qualifier | Label |
|----------|----------|------|-----------|-------|
| 10 | `GeneralInfo` | `#FIELDGROUP_REFERENCE` | `GeneralInfo` | General Information |
| 20 | `AdminData` | `#FIELDGROUP_REFERENCE` | `AdminData` | Administrative Data |

### 9.7 Object Page — General Information Facet Fields

| Position | Field | Editable |
|----------|-------|---------|
| 10 | `EmployeeName` | Yes (mandatory on create) |
| 20 | `LeaveType` | Yes (mandatory on create) |
| 30 | `StartDate` | Yes (mandatory on create) |
| 40 | `EndDate` | Yes |
| 50 | `NumDays` | Yes |
| 60 | `Reason` | Yes |

### 9.8 Object Page — Identification Section

Rendered in the Object Page header section alongside the headerInfo title/description:

| Position | Field | Criticality |
|----------|-------|-------------|
| 10 | `LeaveId` | — |
| 20 | `EmployeeName` | — |
| 30 | `LeaveType` | — |
| 40 | `StartDate` | — |
| 50 | `EndDate` | — |
| 60 | `NumDays` | — |
| 70 | `Reason` | — |
| 80 | `Status` | `StatusCriticality` with `#WITH_ICON` |

### 9.9 Object Page — Administrative Data Facet (Read-Only)

| Position | Field | Label |
|----------|-------|-------|
| 10 | `CreatedBy` | Created By |
| 20 | `CreatedAt` | Created At |
| 30 | `LastChangedBy` | Last Changed By |
| 40 | `LastChangedAt` | Last Changed At |

> Admin fields are `field ( readonly )` in the BDEF, so Fiori Elements will render them as display-only regardless of UI mode (create/edit).

### 9.10 Status Criticality — Data Point

A `@UI.dataPoint` annotation is applied to `Status`:

```
{ title: 'Status', criticality: 'StatusCriticality' }
```

This enables the KPI/data-point rendering in Object Page headers and enables micro chart and header badge scenarios in future Fiori Elements versions.

---

## 10. Authorization Concept

### 10.1 Current State (Development)

`@AccessControl.authorizationCheck: #NOT_REQUIRED` is set on the interface CDS view. This disables all CDS access control checks and is acceptable only during development and demo phases.

### 10.2 Production Readiness — Required Steps

| Step | Action |
|------|--------|
| 1 | Create an **Access Control** (DCLS) object `ZLVTRK_I_Leave` with `define role ZLVTRK_I_Leave` |
| 2 | Add a condition: `where ( LeaveId ) = aspect pfcg_auth ( ... )` or basic `#USER` check |
| 3 | Change annotation to `@AccessControl.authorizationCheck: #CHECK` |
| 4 | Create an **IAM App** in ADT and assign it a **Business Catalog** |
| 5 | Assign Business Catalog to a **Business Role** in the BTP Cockpit |
| 6 | Assign Business Role to target users |

### 10.3 BDEF Authorization Mode

The interface BDEF uses `authorization master ( global )`. This means:
- A single global authorization check applies to the whole entity.
- The framework calls `GET_GLOBAL_AUTHORIZATIONS` in the behaviour implementation class.
- Currently the method is not implemented (no-op = all authorized).
- For production, implement `GET_GLOBAL_AUTHORIZATIONS` to check `AUTHORITY-CHECK OBJECT 'S_TABU_DIS'` or a custom authorization object.

---

## 11. SAP HANA Performance Design

### 11.1 Column Store Alignment

All transparent tables in BTP ABAP Cloud are stored in **HANA column store** automatically. This provides:
- Columnar compression for `STATUS` (CHAR 1, high repetition)
- Efficient aggregation for `NUM_DAYS` (INT4) if reporting is added later
- Dictionary encoding for `EMPLOYEE_NAME`, `LEAVE_TYPE`

### 11.2 Primary Key Index

The primary key `(MANDT, LEAVE_ID)` creates an automatic **primary key index** in HANA. All `WHERE LEAVE_ID = ...` queries use this index without additional secondary indexes.

### 11.3 Secondary Index Recommendations

For current single-entity scope, no secondary indexes are required. If query volumes grow, the following secondary indexes are recommended:

| Index Name | Columns | Justification |
|-----------|---------|---------------|
| `ZLVTRK_D_LEAVE~001` | `MANDT, STATUS` | Filter by status (most common List Report filter) |
| `ZLVTRK_D_LEAVE~002` | `MANDT, START_DATE` | Date-range queries and sort by StartDate DESC |
| `ZLVTRK_D_LEAVE~003` | `MANDT, EMPLOYEE_NAME` | Employee-name search filter |

### 11.4 CDS Push-Down

All field transformations are expressed as **CDS CASE expressions** and computed at the HANA layer:
- `StatusCriticality` — CASE expression, evaluated in HANA column engine
- No ABAP-side post-processing of query results
- The RAP managed runtime uses **`SELECT` with `client handling`** via the CDS framework — no raw ABAP `SELECT` is written

### 11.5 ETag and Concurrency

`LastChangedAt` (`TIMESTAMPL` = 21-digit UTC decimal) is used as both the **ETag** and the **total ETag** for optimistic locking. The precision of `TIMESTAMPL` (microseconds) makes collision probability negligible for single-user leave tracking.

### 11.6 Draft Data Footprint

The draft table `ZLVTRK_D_LEAVE_D` holds temporary rows. Orphaned drafts (user navigates away without discarding) are purged by the **RAP draft garbage collection** job. In BTP Cloud, this is managed by the platform automatically. No custom archiving is needed for draft data.

### 11.7 Query Patterns and OData Server-Side Paging

The List Report uses OData V4 `$top` / `$skip` (server-side paging). The default page size in Fiori Elements is 30 rows. For large datasets, implement `@ObjectModel.usageType.sizeCategory: #XL` and add secondary indexes accordingly. Current setting is `#S` (small, < 1,000 rows typical).

---

## 12. Draft Handling Design

### 12.1 Draft Lifecycle

```
User opens app
      │
      ▼
 [List Report]
      │  Click "Create"
      ▼
 [Draft created in ZLVTRK_D_LEAVE_D]
      │
      ├── User fills fields ──► PATCH requests update draft
      │
      ├── "Save" (Activate) ──► Draft validated ──► Copied to ZLVTRK_D_LEAVE ──► Draft deleted
      │
      ├── "Discard" ──────────► Draft deleted from ZLVTRK_D_LEAVE_D
      │
      └── Navigate away ──────► Draft remains (Resume on re-open)

User clicks existing record
      │
      ▼
 [Object Page — display mode]
      │  Click "Edit"
      ▼
 [Draft Edit action] ──► Draft copy created in ZLVTRK_D_LEAVE_D
      │
      └── Same save/discard/resume flow as above
```

### 12.2 Draft Table Technical Details

The `SYCH_BDL_DRAFT_ADMIN_INC` include adds the following HANA columns to `ZLVTRK_D_LEAVE_D`:

| Column | Type | Description |
|--------|------|-------------|
| `DRAFTENTITYCREATIONDATETIME` | TIMESTAMPL | When draft was first created |
| `DRAFTENTITYLASTCHANGEDATETIME` | TIMESTAMPL | When draft was last modified |
| `DRAFTADMINISTRATIVEDATAUUID` | RAW(16) | UUID identifying the draft session |
| `DRAFTENTITYOPERATIONCODE` | CHAR(1) | C=Create, U=Update, D=Delete |
| `LOCALDRAFTINDICATOR` | CHAR(1) | Local vs. shared draft indicator |
| `DRAFTFIELDCHANGES` | CLOB | Field change log (JSON) |

### 12.3 Optimistic Locking via ETag

The `lock master total etag LastChangedAt` clause implements **HTTP ETag-based optimistic locking**:
1. Client sends `If-Match: "<etag_value>"` with every PATCH/DELETE
2. Framework compares with current `LAST_CHANGED_AT` in the database
3. If mismatch → `HTTP 412 Precondition Failed` → user sees conflict message
4. If match → operation proceeds and `LAST_CHANGED_AT` is updated

---

## 13. Error Handling & Validation Design

### 13.1 Current Implementation

No custom validations or error handling are implemented in v1.0. The framework provides:
- Mandatory field enforcement (`field ( mandatory : create )`) — returns `422 Unprocessable Entity` if missing
- ETag mismatch detection — returns `412 Precondition Failed`
- Optimistic lock conflicts — returns `409 Conflict`

### 13.2 Planned Validations (Future Scope)

| Validation Name | Condition Checked | Error Message |
|----------------|------------------|---------------|
| `validateDates` | `EndDate >= StartDate` | "End Date must be on or after Start Date" |
| `validateNumDays` | `NumDays > 0` | "Number of days must be greater than zero" |
| `validateStatus` | `Status IN ('N','A','R')` | "Status must be N, A, or R" |
| `validateLeaveType` | `LeaveType IS NOT INITIAL` | "Leave Type must be provided" |

All validations should use `APPEND VALUE #( ... ) TO reported-leave` and `APPEND VALUE #( ... ) TO failed-leave` following the RAP ABAP types for failed/reported results.

### 13.3 Message Handling Pattern

When validations are added, use the RAP-compliant message pattern:

```abap
" Example validation skeleton
METHOD validateDates.
  READ ENTITIES OF zlvtrk_i_leave IN LOCAL MODE
    ENTITY leave
      FIELDS ( StartDate EndDate )
      WITH CORRESPONDING #( keys )
    RESULT DATA(lt_leave).

  LOOP AT lt_leave INTO DATA(ls_leave).
    IF ls_leave-EndDate < ls_leave-StartDate.
      APPEND VALUE #(
        %tky = ls_leave-%tky
      ) TO failed-leave.
      APPEND VALUE #(
        %tky      = ls_leave-%tky
        %msg      = new_message_with_text(
                      severity = if_abap_behv_message=>severity-error
                      text     = 'End Date must be on or after Start Date' )
        %element-EndDate = if_abap_behv=>mk-on
      ) TO reported-leave.
    ENDIF.
  ENDLOOP.
ENDMETHOD.
```

---

## 14. Transport & Deployment

### 14.1 Activation Sequence

Objects must be activated in the following strict order to avoid dependency errors:

| Step | Object | Type | Dependency |
|------|--------|------|-----------|
| 1 | `ZLVTRK_D_LEAVE` | Database Table | None |
| 2 | `ZLVTRK_D_LEAVE_D` | Database Table (Draft) | None |
| 3 | `ZLVTRK_I_Leave` | CDS View Entity (DDLS) | `ZLVTRK_D_LEAVE` |
| 4 | `ZLVTRK_I_Leave` | Behavior Definition (BDEF) | `ZLVTRK_I_Leave` (DDLS) |
| 5 | `ZBP_ZLVTRK_I_Leave` | Behavior Implementation Class | `ZLVTRK_I_Leave` (BDEF) |
| 6 | `ZLVTRK_C_Leave` | CDS View Entity (DDLS) | `ZLVTRK_I_Leave` (DDLS) |
| 7 | `ZLVTRK_C_Leave` | Behavior Definition (BDEF) | `ZLVTRK_C_Leave` (DDLS) + `ZLVTRK_I_Leave` (BDEF) |
| 8 | `ZLVTRK_C_Leave` | Metadata Extension (DDLX) | `ZLVTRK_C_Leave` (DDLS) |
| 9 | `ZLVTRK_SD_Leave` | Service Definition (SRVD) | `ZLVTRK_C_Leave` (DDLS) |
| 10 | `ZLVTRK_SB_Leave_V4` | Service Binding (SRVB) | `ZLVTRK_SD_Leave` (SRVD) |

### 14.2 abapGit Deployment

The objects are structured for **abapGit** deployment with the following file layout under `new_rap_test/`:

```
new_rap_test/
├── FSD_LeaveTracker.md              (functional specification)
├── TSD_LeaveTracker.md              (this document)
├── zlvtrk_d_leave.tabl.xml          (active table)
├── zlvtrk_d_leave_d.tabl.xml        (draft table)
├── zlvtrk_i_leave.ddls.xml          (interface view — abapGit metadata)
├── zlvtrk_i_leave.ddls.asddls       (interface view — CDS source)
├── zlvtrk_i_leave.bdef.xml          (interface BDEF — abapGit metadata)
├── zlvtrk_i_leave.bdef.asbdef       (interface BDEF — source)
├── zlvtrk_c_leave.ddls.xml          (projection view — abapGit metadata)
├── zlvtrk_c_leave.ddls.asddls       (projection view — CDS source)
├── zlvtrk_c_leave.bdef.xml          (projection BDEF — abapGit metadata)
├── zlvtrk_c_leave.bdef.asbdef       (projection BDEF — source)
├── zlvtrk_c_leave.ddlx.xml          (metadata extension — abapGit metadata)
├── zlvtrk_c_leave.ddlx.asddlxs      (metadata extension — source)
├── zlvtrk_sd_leave.srvd.xml         (service definition — abapGit metadata)
├── zlvtrk_sd_leave.srvd.srvdsrv     (service definition — source)
└── zlvtrk_sb_leave_v4.srvb.xml      (service binding — abapGit XML)
```

The behaviour implementation class `ZBP_ZLVTRK_I_Leave` must be created manually in ADT as it is auto-generated by the BDEF framework and is not part of the abapGit package here.

### 14.3 ABAP Package Assignment

All objects should be assigned to a single ABAP package (e.g., `ZLVTRK` or `ZTMP_LVTRK` for trial). The package must be:
- Assigned to a software component
- Set to ABAP language version **ABAP Cloud** (version 5)
- Linked to a transport request (or `$TMP` for trial/local)

---

## 15. Testing Strategy

### 15.1 Unit Testing (ABAP Unit)

For v1.0 (no custom handler methods), unit testing is limited. When validations and determinations are added:
- Use `CL_ABAP_BEHV_TEST` stubs for RAP test doubles
- Test each `validation` method independently with mock entity data
- Test `determination` methods verify correct field population

### 15.2 Integration Testing

| Test Case | Scenario | Expected Result |
|-----------|----------|----------------|
| TC-01 | Create a new leave request with all mandatory fields | Record created in `ZLVTRK_D_LEAVE` after Activate; `CreatedBy` / `CreatedAt` auto-populated |
| TC-02 | Create leave request without `EmployeeName` | Error: mandatory field validation (HTTP 422) |
| TC-03 | Edit an existing leave request | Draft created in `ZLVTRK_D_LEAVE_D`; active record unchanged until Activate |
| TC-04 | Activate draft | Active record updated; draft row deleted |
| TC-05 | Discard draft | Draft row deleted; active record unchanged |
| TC-06 | Delete a leave request | Row removed from `ZLVTRK_D_LEAVE` |
| TC-07 | Concurrent edit (ETag mismatch) | HTTP 412 returned; no data overwritten |
| TC-08 | Status = 'A' | List Report shows green icon in Status column |
| TC-09 | Status = 'R' | List Report shows red icon in Status column |
| TC-10 | Status = 'N' | List Report shows grey icon in Status column |
| TC-11 | Filter by `EmployeeName` in List Report | Returns only matching records |
| TC-12 | Filter by `Status` in List Report | Returns only records with that status |

### 15.3 OData Service Testing

Use the **SAP Business Application Studio (BAS)** HTTP client or **Postman** with the OData V4 service URL to:
1. Fetch `$metadata` and verify all entity properties are present
2. Execute GET `/Leave` and confirm paging works
3. Execute POST `/Leave` to create a draft
4. Execute the Activate action to commit

---

## 16. Activation Sequence

See Section 14.1 for the full ordered activation table.

**Critical notes:**
- Do **not** try to activate the BDEF before the DDLS — it will fail with a syntax error referencing an unresolved entity.
- Do **not** try to activate the Projection BDEF before the Interface BDEF — the `use create/update/delete` statements reference the interface BO operations.
- The service binding can only be **published** (not just activated) after the service definition is active.
- The behaviour implementation class `ZBP_ZLVTRK_I_Leave` can be created as empty ABAP class first, then referenced by the BDEF.

---

## 17. Open Items & Constraints

| # | Item | Priority | Resolution |
|---|------|----------|-----------|
| OI-01 | `LEAVE_ID` key generation — currently `field(readonly)` with no determination; new records need a manually provided ID | High | Implement `determination setLeaveId on modify { create; }` using `cl_system_uuid` or custom number range |
| OI-02 | `STATUS` initial value — not defaulted to `'N'` on create | High | Implement `determination setInitialStatus on modify { create; }` |
| OI-03 | No validations on `STATUS` value domain (only N/A/R allowed) | Medium | Implement `validation validateStatus` |
| OI-04 | No validation that `END_DATE >= START_DATE` | Medium | Implement `validation validateDates` |
| OI-05 | `@AccessControl.authorizationCheck: #NOT_REQUIRED` | High (before go-live) | Create DCLS, IAM App, Business Catalog, Business Role |
| OI-06 | `authorization master ( global )` — no instance check | Medium | Implement `GET_GLOBAL_AUTHORIZATIONS` in behaviour pool |
| OI-07 | `LeaveType` is free text — no controlled vocabulary | Low | Add a fixed-value domain or lookup entity in a later release |
| OI-08 | No Approve / Reject actions on the UI | Medium | Add `action approveLeave` and `action rejectLeave` to BDEF + expose in projection |
| OI-09 | No secondary indexes defined | Low | Add when dataset exceeds ~10,000 rows |
| OI-10 | Behaviour implementation class `ZBP_ZLVTRK_I_Leave` not in abapGit | Low | Create manually in ADT; add to abapGit package once methods are implemented |

---

*End of Technical Specification Document — TSD-ZLVTRK-001 v1.0*
