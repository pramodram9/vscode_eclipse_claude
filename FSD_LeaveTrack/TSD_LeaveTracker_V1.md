# Technical Specification Document (TSD)
## Employee Leave Tracker — RAP Application V1

**Version:** 1.0 | **Date:** April 2026 | **Status:** Draft
**Author:** Capgemini SAP Practice
**Target Environment:** SAP BTP ABAP Cloud Trial

---

## 1. Solution Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        FIORI ELEMENTS V4                            │
│            List Report + Object Page (OData V4 consumer)           │
└────────────────────────────┬────────────────────────────────────────┘
                             │ OData V4
┌────────────────────────────▼────────────────────────────────────────┐
│                      OData V4 Service Layer                         │
│  ZLVTRK_SB_LEAVE_V1_V4  →  ZLVTRK_SD_Leave_V1                     │
└────────────────────────────┬────────────────────────────────────────┘
                             │ exposes
┌────────────────────────────▼────────────────────────────────────────┐
│                   Consumption Projection Layer                       │
│  ZLVTRK_C_Leave_V1  (provider contract transactional_query)         │
│  ZLVTRK_C_Leave_V1  (Projection BDEF — use create/update/delete)    │
│  ZLVTRK_C_Leave_V1  (Metadata Extension — @UI annotations)          │
└────────────────────────────┬────────────────────────────────────────┘
                             │ projection on
┌────────────────────────────▼────────────────────────────────────────┐
│                     Interface / BO Layer                             │
│  ZLVTRK_I_Leave_V1  (Interface CDS View Entity)                     │
│  ZLVTRK_I_Leave_V1  (Interface BDEF — managed, draft, early num.)   │
│  ZBP_ZLVTRK_I_LEAVE_V1  (Behavior Pool — earlynumbering, status)    │
└────────────────────────────┬────────────────────────────────────────┘
                             │ select from / persistent table
┌────────────────────────────▼────────────────────────────────────────┐
│                       Persistence Layer                              │
│  ZLVTRK_D_LEAVE_V1   (Active Table — 13 fields, snake_case)         │
│  ZLVTRK_D_LEAVE_V1_D (Draft Table  — CDS alias names, %admin inc.)  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Technical Stack & Constraints

| Item | Value |
|------|-------|
| ABAP Release | ABAP Cloud (BTP Trial) — ABAP language version: ABAP for Cloud Development |
| BDEF Strict Mode | strict ( 2 ) |
| Draft Framework | RAP Managed Draft (sych_bdl_draft_admin_inc) |
| OData Version | V4 |
| UI Technology | Fiori Elements V4 — List Report + Object Page |
| No Standard Tables | All fields are custom; no I_BusinessPartner, MARA, VBAK etc. |
| No Released CDS Views | Fully self-contained for BTP Cloud Trial |
| No Value Helps | LeaveCategory is free-text; Status is CHAR(1) |
| ABAP Cloud Rules | No WRITE, no MESSAGE, no SELECT *, no sy-datum/sy-uzeit |

---

## 3. Naming Conventions — Full Object Registry

| # | Object Type | Object Name | File(s) | Description |
|---|-------------|-------------|---------|-------------|
| 1 | Active DB Table | ZLVTRK_D_LEAVE_V1 | zlvtrk_d_leave_v1.tabl.xml | Active persistence table |
| 2 | Draft DB Table | ZLVTRK_D_LEAVE_V1_D | zlvtrk_d_leave_v1_d.tabl.xml | Draft persistence table (CDS alias names) |
| 3 | Interface CDS View | ZLVTRK_I_Leave_V1 | zlvtrk_i_leave_v1.ddls.asddls/xml | BO root interface view |
| 4 | Interface BDEF | ZLVTRK_I_Leave_V1 | zlvtrk_i_leave_v1.bdef.asbdef/xml | Managed BO behavior definition |
| 5 | Behavior Pool | ZBP_ZLVTRK_I_LEAVE_V1 | zbp_zlvtrk_i_leave_v1.clas.abap/locals_imp.abap/xml | ABAP behavior pool class |
| 6 | Consumption CDS | ZLVTRK_C_Leave_V1 | zlvtrk_c_leave_v1.ddls.asddls/xml | Projection view for UI |
| 7 | Projection BDEF | ZLVTRK_C_Leave_V1 | zlvtrk_c_leave_v1.bdef.asbdef/xml | Projection behavior definition |
| 8 | Metadata Extension | ZLVTRK_C_Leave_V1 | zlvtrk_c_leave_v1.ddlx.asddlxs/xml | Fiori UI annotations |
| 9 | Service Definition | ZLVTRK_SD_Leave_V1 | zlvtrk_sd_leave_v1.srvd.srvdsrv/xml | OData service definition |
| 10 | Service Binding | ZLVTRK_SB_LEAVE_V1_V4 | zlvtrk_sb_leave_v1_v4.srvb.xml | OData V4 service binding |
| 11 | Data Generator | ZCL_LVTRK_DATA_GEN_V1 | zcl_lvtrk_data_gen_v1.clas.abap/xml | Test data generator |

**Naming rules:**
- Prefix: `ZLVTRK_` for all custom objects
- Suffix: `_V1` appended to all artifact names
- Behavior pool prefix: `ZBP_` + interface view name
- Draft table: active table name + `_D`

---

## 4. Data Model — Field-by-Field Specification

### Active Table: ZLVTRK_D_LEAVE_V1

| # | DB Column | CDS Alias | ABAP Type | Length | Key | Description | Notes |
|---|-----------|-----------|-----------|--------|-----|-------------|-------|
| 1 | CLIENT | (framework) | CLNT | 3 | ✓ | SAP client | Handled by ABAP Cloud framework |
| 2 | LEAVE_ID | LeaveId | CHAR | 10 | ✓ | Unique leave request ID | Format: LV00000001—LV99999999 |
| 3 | EMPLOYEE_NAME | EmployeeName | CHAR | 60 | | Employee full name | Free text |
| 4 | LEAVE_TYPE | LeaveCategory | CHAR | 20 | | Leave category | Alias renamed per Rule 1 — see §5 |
| 5 | START_DATE | StartDate | DATS | 8 | | Leave start date | YYYYMMDD |
| 6 | END_DATE | EndDate | DATS | 8 | | Leave end date | YYYYMMDD |
| 7 | NUM_DAYS | NumDays | INT4 | 10 | | Number of leave days | User-entered |
| 8 | REASON | Reason | CHAR | 255 | | Leave reason | Free text |
| 9 | STATUS | Status | CHAR | 1 | | Leave status | N=New, A=Approved, R=Rejected |
| 10 | CREATED_BY | CreatedBy | CHAR | 12 | | Created by user | Set by @Semantics.user.createdBy |
| 11 | CREATED_AT | CreatedAt | TIMESTAMPL | 21,7 | | Creation timestamp | Set by @Semantics.systemDateTime.createdAt |
| 12 | LAST_CHANGED_BY | LastChangedBy | CHAR | 12 | | Last changed by user | Set by @Semantics.user.lastChangedBy |
| 13 | LAST_CHANGED_AT | LastChangedAt | TIMESTAMPL | 21,7 | | Last changed timestamp | Used as ETag master |

**HANA Storage Notes:**
- Table class TRANSP (transparent), storage category APPL0
- Column store is default for SAP HANA
- TIMESTAMPL stored as DEC(21,7) in HANA — microsecond precision
- No buffering (BUFALLOW=N) — RAP draft framework requires direct DB access

### Draft Table: ZLVTRK_D_LEAVE_V1_D

Mirrors the interface CDS view field names (PascalCase, no underscores). Includes:
- All active-table fields mapped via CDS aliases (LEAVEID, EMPLOYEENAME, LEAVECATEGORY, etc.)
- `STATUSCRITICALITY` INT4 — computed field must be physically stored for draft
- `.INCLUDE SYCH_BDL_DRAFT_ADMIN_INC` — RAP draft administration fields (%tky, %admin columns)

---

## 5. CDS View Layer

### Interface View: ZLVTRK_I_Leave_V1

| Annotation | Value | Purpose |
|------------|-------|---------|
| @AbapCatalog.viewEnhancementCategory | [#NONE] | No extensions expected |
| @AccessControl.authorizationCheck | #NOT_REQUIRED | BTP demo — harden for production |
| @ObjectModel.usageType.serviceQuality | #A | Application data |
| @ObjectModel.usageType.sizeCategory | #S | Small data volume |
| @ObjectModel.usageType.dataClass | #TRANSACTIONAL | Transactional entity |
| @ObjectModel.semanticKey | ['LeaveId'] | Business key for OData |
| @Semantics.user.createdBy | CreatedBy | Auto-populated by RAP framework |
| @Semantics.systemDateTime.createdAt | CreatedAt | Auto-populated by RAP framework |
| @Semantics.user.lastChangedBy | LastChangedBy | Auto-populated by RAP framework |
| @Semantics.systemDateTime.lastChangedAt | LastChangedAt | Auto-populated, used as ETag |

**Rule 1 — EDM Name Conflict Prevention:**
The OData service exposes `ZLVTRK_C_Leave_V1 as Leave`, making the OData entity type `LeaveType`.
The DB field `LEAVE_TYPE` would naturally get alias `LeaveType` — a direct collision.
**Fix:** alias renamed to `LeaveCategory` throughout (CDS view, draft table column, BDEF mapping).

**StatusCriticality CASE expression:**
```abap
case status
  when 'A' then cast( 3 as abap.int4 )  -- Green / Positive
  when 'R' then cast( 1 as abap.int4 )  -- Red / Negative
  else          cast( 0 as abap.int4 )  -- Grey / New (default)
end as StatusCriticality
```
This is a computed field — no active-table column, omitted from BDEF mapping.

### Consumption Projection: ZLVTRK_C_Leave_V1

| Annotation | Purpose |
|------------|---------|
| `provider contract transactional_query` | Marks this as the BO projection for Fiori Elements |
| `@Metadata.allowExtensions: true` | Allows the metadata extension to apply annotations |
| `@Search.searchable: true` | Enables search bar in List Report |
| `@Search.defaultSearchElement: true` on EmployeeName | Default search field |

---

## 6. RAP BO Design

### BDEF Keywords

| Keyword | Value | Explanation |
|---------|-------|-------------|
| `managed` | — | Framework handles CRUD persistence automatically |
| `strict ( 2 )` | — | Latest strictness mode; enforces ABAP Cloud discipline |
| `with draft` | — | Enables draft save / discard lifecycle |
| `early numbering` | — | Key assigned in behavior pool before DB insert |
| `persistent table` | zlvtrk_d_leave_v1 | Active table for committed records |
| `draft table` | zlvtrk_d_leave_v1_d | Draft table for in-progress edits |
| `etag master` | LastChangedAt | Optimistic locking via last-changed timestamp |
| `lock master total etag` | LastChangedAt | Total ETag covers all fields |
| `authorization master (global)` | — | Global authorization check (extend for production) |

### Field Controls

| Field(s) | Control | Reason |
|----------|---------|--------|
| LeaveId | readonly | Key field — assigned by early numbering |
| StatusCriticality | readonly | Computed CDS field — no persistent column |
| CreatedBy, CreatedAt | readonly | Set once on creation via @Semantics |
| LastChangedBy, LastChangedAt | readonly | Maintained by framework via @Semantics |
| EmployeeName, LeaveCategory, StartDate, EndDate, NumDays, Reason, Status | (editable) | User-maintained fields |

**Rule 3:** No `field ( mandatory : create )` used anywhere — avoids Fiori Elements V4 popup interception. Mandatory validation is enforcement via BDEF `determination` instead.

### BDEF Mapping Table

| CDS Alias (draft side) | Active Table Column | Notes |
|------------------------|---------------------|-------|
| LeaveId | leave_id | Primary key |
| EmployeeName | employee_name | |
| LeaveCategory | leave_type | Renamed alias per Rule 1 |
| StartDate | start_date | |
| EndDate | end_date | |
| NumDays | num_days | |
| Reason | reason | |
| Status | status | |
| CreatedBy | created_by | |
| CreatedAt | created_at | |
| LastChangedBy | last_changed_by | |
| LastChangedAt | last_changed_at | |
| StatusCriticality | *(omitted)* | Computed — no active column |

---

## 7. Behavior Pool Class

**Class:** `ZBP_ZLVTRK_I_LEAVE_V1`
**Type:** `PUBLIC ABSTRACT FINAL FOR BEHAVIOR OF zlvtrk_i_leave_v1`

### Local Handler: lhc_leave

| Method | Type | Signature | Purpose |
|--------|------|-----------|---------|
| `earlynumbering_create` | FOR NUMBERING | `IMPORTING entities FOR CREATE Leave` | Assigns LeaveId = LV + 8-digit zero-padded counter |
| `set_initial_status` | FOR DETERMINE ON MODIFY | `IMPORTING keys FOR Leave~setInitialStatus` | Sets Status = 'N' on create if still initial |

### Early Numbering Algorithm

```
1. SELECT leave_id FROM zlvtrk_d_leave_v1 INTO TABLE lt_existing
2. lv_max_n = REDUCE i( INIT n=0 FOR ls IN lt_existing
               LET s = CONV i( ls-leave_id+2(8) )
               NEXT n = COND i( WHEN s>n THEN s ELSE n ) )
3. LOOP AT entities: IF leaveid IS INITIAL → lv_max_n += 1
                      leaveid = |LV{ lv_max_n WIDTH=8 ALIGN=RIGHT PAD='0' }|
4. INSERT into mapped-leave
```

Rule 4 compliance: REDUCE used for max calculation (never FILTER on standard table with empty key).

### Planned Enhancements

| Enhancement | Priority | Description |
|-------------|----------|-------------|
| Validation: validateDates | Medium | EndDate must be >= StartDate |
| Validation: validateMandatoryFields | High | EmployeeName, StartDate, EndDate must be filled |
| Action: approveLeave | Low | Change Status from N → A |
| Action: rejectLeave | Low | Change Status from N → R |
| Feature Control | Medium | Approve/Reject only when Status = 'N' |

---

## 8. OData Service Layer

**Service Definition:** `ZLVTRK_SD_Leave_V1`
**Service Binding:** `ZLVTRK_SB_LEAVE_V1_V4` (OData V4, Category: ODATA, Protocol: V4)

### URL Pattern

```
/sap/opu/odata4/sap/zlvtrk_sb_leave_v1_v4/srvd/sap/zlvtrk_sd_leave_v1/0001/
```

### HTTP Verb → RAP Operation Mapping

| HTTP Verb | URL Pattern | RAP Operation | Description |
|-----------|-------------|---------------|-------------|
| GET | /Leave | cds_view read (list) | List all leave requests |
| GET | /Leave('LV00000001') | cds_view read (single) | Read one leave request |
| POST | /Leave | create | Create new draft |
| PATCH | /Leave('LV00000001') | update | Edit draft fields |
| DELETE | /Leave('LV00000001') | delete | Delete draft or active |
| POST | /Leave('LV00000001')/Edit | edit action | Lock record for edit |
| POST | /Leave('LV00000001')/Activate | activate action | Commit draft → active |
| POST | /Leave('LV00000001')/Discard | discard action | Discard draft |

---

## 9. Fiori Elements Annotations

### List Report

| Column | Position | Field | Criticality |
|--------|----------|-------|-------------|
| Leave ID | 10 | LeaveId | — |
| Employee Name | 20 | EmployeeName | — |
| Leave Category | 30 | LeaveCategory | — |
| Start Date | 40 | StartDate | — |
| End Date | 50 | EndDate | — |
| Days | 60 | NumDays | — |
| Status | 70 | Status | StatusCriticality + icon |

**Filter Bar:** EmployeeName, LeaveCategory, StartDate (position 10–30), Status (position 40)

### Object Page

**Header:**
- Title: LeaveId
- Description: EmployeeName
- DataPoint (StatusDP): Status with criticality icon (purpose: #HEADER)

**Facets:**

| Facet | Type | Target | Fields |
|-------|------|--------|--------|
| General Information | FIELDGROUP_REFERENCE | GeneralInfo | EmployeeName, LeaveCategory, StartDate, EndDate, NumDays, Reason |
| Administrative Data | FIELDGROUP_REFERENCE | AdminInfo | CreatedBy, CreatedAt, LastChangedBy, LastChangedAt |

**Sort order:** StartDate descending (presentationVariant)

---

## 10. Authorization Concept

**Current State (Demo):** `@AccessControl.authorizationCheck: #NOT_REQUIRED` — no access control objects (ACOs) activated.

**Production Hardening Checklist:**

| Step | Action |
|------|--------|
| 1 | Create authorization object ZLVTRK_AUTH with activity field ACTVT (01/02/06) |
| 2 | Create access control (DCLS) for ZLVTRK_I_Leave_V1 referencing auth object |
| 3 | Change @AccessControl.authorizationCheck to #CHECK |
| 4 | Assign authorization profile to roles in SU21/PFCG |
| 5 | Test with restricted user — verify list-level and instance-level filtering |

---

## 11. SAP HANA Performance Design

| Design Decision | Rationale |
|----------------|-----------|
| Column store (default HANA) | Optimized for analytical scans on Status, StartDate, EmployeeName |
| No secondary indexes (demo) | Low data volume; add INDEX on STATUS, START_DATE for production |
| ETAG via LAST_CHANGED_AT | Avoids full-record comparison for optimistic locking |
| REDUCE instead of FILTER | Rule 4 compliance; FILTER on empty-key standard table would fail at runtime |
| No SELECT * | All SELECTs use explicit field list per ABAP Cloud rule |
| Draft buffering OFF | BUFALLOW=N on draft table; RAP framework accesses draft directly |

---

## 12. Draft Lifecycle

```
User clicks "Create"
       │
       ▼
earlynumbering_create assigns LeaveId
       │
       ▼
setInitialStatus sets Status = 'N'
       │
       ▼
Draft saved (ZLVTRK_D_LEAVE_V1_D)
       │
   ┌───┴────────────────────┐
   │ Edit / Save Draft       │ Discard
   │                         ▼
   │                 Draft deleted
   ▼
User clicks "Save" → Activate action
       │
       ▼
Draft → Active (ZLVTRK_D_LEAVE_V1)
Draft row deleted
```

### Draft %ADMIN Column Reference

| %ADMIN Column | Type | Description |
|--------------|------|-------------|
| %TKY | — | Technical key (includes MANDT + entity key) |
| LASTCHANGEDDATETIME | TIMESTAMPL | Last change in draft |
| LOCALINSTANCELASTCHANGEDDATETIME | TIMESTAMPL | Local instance change |
| DRAFTENTITYCREATIONDATETIME | TIMESTAMPL | Draft creation time |
| DRAFTENTITYLASTCHANGEDDATETIME | TIMESTAMPL | Draft last change time |
| DRAFTADMINISTRATIVEDDATAISVALID | CHAR(1) | Draft validity flag |
| DRAFTISPROCESSED | CHAR(1) | Whether draft is being activated |
| DRAFTISLOCKEDBYANOTHERWSER | CHAR(1) | Lock indicator |

---

## 13. Error Handling & Validation Design

**Current State:** No custom validations — determination `setInitialStatus` only.

**Planned Validations:**

| Validation Name | Trigger | Rule | Error Message |
|-----------------|---------|------|---------------|
| validateEmployeeName | on modify { field EmployeeName; } | EmployeeName must not be initial | 'Employee name is required' |
| validateDateRange | on modify { field StartDate; field EndDate; } | EndDate >= StartDate | 'End date must be on or after start date' |
| validateNumDays | on modify { field NumDays; } | NumDays >= 1 | 'Number of days must be at least 1' |
| validateStatusTransition | on modify { field Status; } | Only N→A or N→R (future actions) | 'Invalid status transition' |

**Implementation pattern (ABAP Cloud compliant):**
```abap
APPEND VALUE #(
  %key     = ls-%key
  %msg     = new_message_with_text( severity = 'E' text = 'Error msg' )
  %element = VALUE #( employee_name = if_abap_behv=>mk-on )
) TO reported-leave.
APPEND VALUE #( %key = ls-%key ) TO failed-leave.
```

---

## 14. Transport & Deployment

### Activation Sequence

| Step | Object | Action | Notes |
|------|--------|--------|-------|
| 1 | ZLVTRK_D_LEAVE_V1 | Activate + create table | Must exist before CDS view activation |
| 2 | ZLVTRK_D_LEAVE_V1_D | Activate + create table | Must exist before BDEF activation |
| 3 | ZLVTRK_I_Leave_V1 (CDS) | Activate | Interface view |
| 4 | ZBP_ZLVTRK_I_LEAVE_V1 | Activate class | Behavior pool — after CDS |
| 5 | ZLVTRK_I_Leave_V1 (BDEF) | Activate | References CDS + behavior pool |
| 6 | ZLVTRK_C_Leave_V1 (CDS) | Activate | Projection — after interface BDEF |
| 7 | ZLVTRK_C_Leave_V1 (BDEF) | Activate | Projection BDEF |
| 8 | ZLVTRK_C_Leave_V1 (DDLX) | Activate | Metadata extension |
| 9 | ZLVTRK_SD_Leave_V1 | Activate | Service definition |
| 10 | ZLVTRK_SB_LEAVE_V1_V4 | Activate + Publish | Service binding — last step |

**abapGit Pull Sequence:** Pull objects in dependency order (tables → CDS → BDEF → service).

---

## 15. Testing Strategy

### Integration Test Cases

| TC# | Scenario | Steps | Expected Result |
|-----|----------|-------|-----------------|
| TC01 | Create leave request | Open List Report → Create → Fill fields → Save | New record LV0000000x created with Status=N |
| TC02 | Edit leave request | Open existing record → Edit → Change EmployeeName → Save | Record updated, LastChangedAt refreshed |
| TC03 | Delete leave request | Select record → Delete → Confirm | Record removed from list |
| TC04 | Status criticality | View list with N/A/R records | Grey/Green/Red icons displayed correctly |
| TC05 | Filter by Status | Set Status filter = 'A' | Only approved leaves shown |
| TC06 | Discard draft | Create → Fill partial data → Discard | Draft deleted, no active record created |
| TC07 | Sort by StartDate | Default presentationVariant | List sorted StartDate DESC |
| TC08 | Search by EmployeeName | Type name in search bar | Matching records returned |

### Data Generator

Class `ZCL_LVTRK_DATA_GEN_V1` (implements `IF_OO_ADT_CLASSRUN`):
- Inserts 8 records: LV00000001 to LV00000008
- Covers all 3 status values: N (3 records), A (3 records), R (2 records)
- Covers all leave categories: Annual, Sick, Personal, Other
- Run via ADT → right-click class → Run As → ABAP Application (Console)

---

## 16. Open Items & Constraints

| # | Priority | Item | Description | Resolution Plan |
|---|----------|------|-------------|-----------------|
| OI-01 | HIGH | No mandatory field validation | No validation for EmployeeName/dates on create | Add BDEF validations in V2 |
| OI-02 | HIGH | No access control | authorizationCheck = #NOT_REQUIRED | Add DCLS in V2 for production |
| OI-03 | MEDIUM | No status transitions | Status can be freely edited | Add approve/reject actions in V2 |
| OI-04 | MEDIUM | NumDays not calculated | User must enter number manually | Add determination to auto-calc from date range in V2 |
| OI-05 | LOW | LeaveCategory is free text | No controlled vocabulary | Add value help with fixed values in V2 |
| OI-06 | LOW | No approval workflow | No notification to manager | Out of scope for BTP trial demo |

---

## 17. Document Change Log

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | April 2026 | Capgemini (Claude Sonnet 4.6) | Initial version — generated from FSD_LeaveTracker.md with suffix _v1 |

---

*Generated by Claude Code (Claude Sonnet 4.6) — Lead SAP Technical Architect, Capgemini*
