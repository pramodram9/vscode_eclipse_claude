# Technical Specification — Sales Order Management
## RAP Managed BO · Fiori Elements V4 · OData V4

| Attribute | Value |
|-----------|-------|
| **Document Version** | 1.0 |
| **Date** | April 2026 |
| **Author** | AI-Assisted (Claude Code) |
| **Status** | Ready for Development Review |
| **SAP Version** | S/4 HANA 2022 / BTP ABAP Environment |
| **Technology** | RAP Managed BO · CDS View Entities · Fiori Elements V4 |
| **Namespace Prefix** | `ZSOMGMT` |
| **Package** | `ZSD_SOMGMT` *(create before importing)* |
| **GitHub Repo** | `pramodram9/vscode_eclipse_claude` — folder `new_rap_test/` |

---

## Table of Contents

1. [Business Overview](#1-business-overview)
2. [Architecture & Technology Stack](#2-architecture--technology-stack)
3. [Data Model](#3-data-model)
4. [Artifact Inventory](#4-artifact-inventory)
5. [CDS View Layer](#5-cds-view-layer)
6. [Behavior Definition](#6-behavior-definition)
7. [Behavior Implementation](#7-behavior-implementation)
8. [Fiori Elements UI](#8-fiori-elements-ui)
9. [Status & Workflow Logic](#9-status--workflow-logic)
10. [Security & Authorization](#10-security--authorization)
11. [Step-by-Step Deployment Guide](#11-step-by-step-deployment-guide)
12. [Testing Guide](#12-testing-guide)
13. [Troubleshooting](#13-troubleshooting)
14. [Appendix — File Reference](#14-appendix--file-reference)

---

## 1. Business Overview

### 1.1 Purpose

The Sales Order Management application enables Sales Representatives to create, edit, and submit sales orders for approval, and allows Sales Managers to approve or reject submitted orders. The application is built on SAP's **RESTful Application Programming (RAP) Model** with a **Fiori Elements V4** front end, deployed as an OData V4 service on S/4 HANA 2022.

### 1.2 Business Process

```
Sales Rep                              Sales Manager
   │                                        │
   ├─ Open Fiori App (List Report)          │
   ├─ Click "Create" → Draft created        │
   ├─ Enter Header: Customer, Dates         │
   ├─ Add Line Items: Product, Qty, Price   │
   │     └─ System calculates NetAmount     │
   │         per item + Header totals       │
   ├─ Save Draft (validations run)          │
   ├─ Click "Submit for Approval"           │
   │     └─ Status: N → P                  │
   │                                        ├─ Open order in List Report
   │                                        ├─ Review Object Page details
   │                                        ├─ Click "Approve" → Status: P → A
   │                                        │   OR
   │                                        └─ Click "Reject" (enter reason)
   │                                              └─ Status: P → X
   └─ Approved orders ready for
      downstream (delivery, billing)
```

### 1.3 Status Lifecycle

| Status Code | Label | Description | Allowed Operations |
|-------------|-------|-------------|-------------------|
| `N` | New | Default on creation | Full CRUD, Submit for Approval |
| `P` | In Process | Submitted, awaiting decision | Approve, Reject (read-only otherwise) |
| `A` | Approved | Final approved state | Read-only |
| `X` | Rejected | Final rejected state | Read-only |

### 1.4 Key Business Rules

| # | Rule | Enforcement Point |
|---|------|-------------------|
| BR-01 | Customer ID must exist in Business Partner master | Validation `validateCustomer` |
| BR-02 | Delivery Date ≥ Order Date | Validation `validateDates` |
| BR-03 | Quantity must be > 0 on every line item | Validation `validateQuantity` |
| BR-04 | Currency must be a valid ISO code | Validation `validateCurrency` |
| BR-05 | Product ID is mandatory on every line item | Validation `validateItemProduct` |
| BR-06 | NetAmount per item = Quantity × UnitPrice | Determination `calculateItemNetAmount` |
| BR-07 | TaxAmount = 10% of total NetAmount | Determination `calculateItemNetAmount` |
| BR-08 | GrossAmount = NetAmount + TaxAmount | Determination `calculateItemNetAmount` |
| BR-09 | Only orders in status N can be submitted | Action guard `submitForApproval` |
| BR-10 | Only orders in status P can be approved/rejected | Action guard `approveOrder` / `rejectOrder` |
| BR-11 | Rejection reason is mandatory when rejecting | Action guard `rejectOrder` |
| BR-12 | OverallStatus is system-controlled, never user-editable | `field (readonly)` in BDEF |

---

## 2. Architecture & Technology Stack

### 2.1 Layered Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER                                          │
│  Fiori Elements V4 · List Report + Object Page floorplan    │
│  OData V4 protocol · Service Binding ZSOMGMT_SB_SALESORDER  │
└──────────────────────────┬──────────────────────────────────┘
                           │ OData V4
┌──────────────────────────▼──────────────────────────────────┐
│  SERVICE LAYER                                               │
│  Service Definition: ZSOMGMT_SD_SalesOrder                  │
│  Consumption Projections: ZSOMGMT_C_SalesOrder / _Item      │
│  Consumption BDEFs: ZSOMGMT_C_SalesOrder (projection)       │
│  Metadata Extensions: ZSOMGMT_C_SalesOrder / _Item (DDLX)  │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│  BUSINESS OBJECT LAYER                                       │
│  Interface CDS Views: ZSOMGMT_I_SalesOrder / _SalesOrderItem│
│  Interface BDEF: ZSOMGMT_I_SalesOrder (managed, with draft) │
│  Behavior Impl: ZBP_SOMGMT_I_SalesOrder                     │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│  PERSISTENCE LAYER                                           │
│  Active Tables: ZSOMGMT_D_SO_HDR · ZSOMGMT_D_SO_ITM         │
│  Draft Tables:  ZSOMGMT_D_SO_D_H · ZSOMGMT_D_SO_D_I         │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Technology Stack

| Component | Technology |
|-----------|-----------|
| Programming Model | SAP RAP (RESTful ABAP Programming) — Managed BO |
| ABAP Language | ABAP Cloud / Modern ABAP 7.54+ |
| CDS Layer | CDS View Entities (not classic CDS views) |
| Draft Handling | RAP Framework Draft (with draft tables) |
| Protocol | OData V4 |
| Front End | SAP Fiori Elements — List Report + Object Page |
| IDE | Eclipse ADT (ABAP Development Tools) |
| Source Control | abapGit → GitHub |
| SAP Platform | S/4 HANA 2022 on-premise or BTP ABAP Environment |

---

## 3. Data Model

### 3.1 Entity Relationship

```
ZSOMGMT_D_SO_HDR (1)
  │  SalesOrderId (PK)
  │  Description
  │  CustomerId / CustomerName
  │  OrderDate / DeliveryDate
  │  OverallStatus
  │  Currency
  │  GrossAmount / NetAmount / TaxAmount
  │  CreatedBy / CreatedAt / LastChangedBy / LastChangedAt
  │
  └──── (0..*) ZSOMGMT_D_SO_ITM
                 SalesOrderId (PK, FK)
                 ItemNumber   (PK)
                 ProductId / ProductDescription
                 Quantity / UoM
                 UnitPrice / NetAmount / Currency
                 ItemStatus
```

### 3.2 Header Table — `ZSOMGMT_D_SO_HDR`

| Field Name | ABAP Type | Key | Length | Description |
|------------|-----------|-----|--------|-------------|
| `MANDT` | MANDT | ✓ | 3 | Client |
| `SALESORDERID` | CHAR | ✓ | 10 | Sales Order Number (user-assigned) |
| `DESCRIPTION` | CHAR | | 80 | Order description |
| `CUSTOMERID` | CHAR | | 10 | Customer business partner ID |
| `CUSTOMERNAME` | CHAR | | 60 | Customer full name (cached) |
| `ORDERDATE` | DATS | | 8 | Date order was placed |
| `DELIVERYDATE` | DATS | | 8 | Requested delivery date |
| `OVERALLSTATUS` | CHAR | | 1 | `N` / `P` / `A` / `X` |
| `CURRENCY` | CUKY | | 5 | ISO currency key |
| `GROSSAMOUNT` | CURR(15,2) | | 15.2 | Gross Amount (ref: CURRENCY) |
| `NETAMOUNT` | CURR(15,2) | | 15.2 | Net Amount (ref: CURRENCY) |
| `TAXAMOUNT` | CURR(15,2) | | 15.2 | Tax Amount (ref: CURRENCY) |
| `CREATEDBY` | SYUNAME | | 12 | Admin: created by |
| `CREATEDAT` | TIMESTAMPL | | — | Admin: creation timestamp |
| `LASTCHANGEDBY` | SYUNAME | | 12 | Admin: last changed by |
| `LASTCHANGEDAT` | TIMESTAMPL | | — | Admin: last change timestamp |

### 3.3 Item Table — `ZSOMGMT_D_SO_ITM`

| Field Name | ABAP Type | Key | Length | Description |
|------------|-----------|-----|--------|-------------|
| `MANDT` | MANDT | ✓ | 3 | Client |
| `SALESORDERID` | CHAR | ✓ | 10 | Parent order (FK to HDR) |
| `ITEMNUMBER` | NUMC | ✓ | 6 | Sequential item number |
| `PRODUCTID` | CHAR | | 18 | Material / product key |
| `PRODUCTDESCRIPTION` | CHAR | | 40 | Product description text |
| `UOM` | UNIT | | 3 | Unit of measure (ref for QUANTITY) |
| `QUANTITY` | QUAN(13,3) | | 13.3 | Ordered quantity (ref: UOM) |
| `CURRENCY` | CUKY | | 5 | ISO currency key |
| `UNITPRICE` | CURR(15,2) | | 15.2 | Price per unit (ref: CURRENCY) |
| `NETAMOUNT` | CURR(15,2) | | 15.2 | Line net amount (ref: CURRENCY) |
| `ITEMSTATUS` | CHAR | | 1 | `N`=New · `D`=Delivered · `C`=Cancelled |

### 3.4 Draft Tables

| Table | Mirrors | Extra Field |
|-------|---------|-------------|
| `ZSOMGMT_D_SO_D_H` | `ZSOMGMT_D_SO_HDR` | `DRAFTENTITYOPERATIONCODE CHAR(1)` |
| `ZSOMGMT_D_SO_D_I` | `ZSOMGMT_D_SO_ITM` | `DRAFTENTITYOPERATIONCODE CHAR(1)` |

> Draft tables must mirror the exact field structure of their active counterparts. The RAP framework uses them to buffer uncommitted changes during draft sessions. `DRAFTENTITYOPERATIONCODE` values: `I` = Insert (new draft), `U` = Update (edit of existing active entity).

---

## 4. Artifact Inventory

| # | Object Name | abapGit File | Object Type | Description |
|---|------------|--------------|-------------|-------------|
| 1 | `ZSOMGMT_D_SO_HDR` | `.tabl.xml` | TABL | Sales Order header active table |
| 2 | `ZSOMGMT_D_SO_ITM` | `.tabl.xml` | TABL | Sales Order item active table |
| 3 | `ZSOMGMT_D_SO_D_H` | `.tabl.xml` | TABL | Header draft table |
| 4 | `ZSOMGMT_D_SO_D_I` | `.tabl.xml` | TABL | Item draft table |
| 5 | `ZSOMGMT_A_RejectParam` | `.ddls.asddls` | DDLS (abstract) | Action parameter entity for rejectOrder |
| 6 | `ZSOMGMT_I_SalesOrder` | `.ddls.asddls` | DDLS (root) | Interface BO view — header |
| 7 | `ZSOMGMT_I_SalesOrderItem` | `.ddls.asddls` | DDLS (child) | Interface BO view — items |
| 8 | `ZSOMGMT_C_SalesOrder` | `.ddls.asddls` | DDLS (root projection) | Consumption view — header |
| 9 | `ZSOMGMT_C_SalesOrderItem` | `.ddls.asddls` | DDLS (child projection) | Consumption view — items |
| 10 | `ZSOMGMT_I_SalesOrder` | `.bdef.asbdls` | BDEF | Interface behavior definition |
| 11 | `ZSOMGMT_C_SalesOrder` | `.bdef.asbdls` | BDEF | Projection behavior definition |
| 12 | `ZSOMGMT_C_SalesOrder` | `.ddlx.asddlxs` | DDLX | Header metadata extension (UI annotations) |
| 13 | `ZSOMGMT_C_SalesOrderItem` | `.ddlx.asddlxs` | DDLX | Item metadata extension (UI annotations) |
| 14 | `ZBP_SOMGMT_I_SalesOrder` | `.clas.abap` | CLAS | Behavior implementation — global shell |
| 15 | `ZBP_SOMGMT_I_SalesOrder` | `.clas.locals_def.abap` | CLAS (CCDEF) | Local constant definitions |
| 16 | `ZBP_SOMGMT_I_SalesOrder` | `.clas.locals_imp.abap` | CLAS (CCIMP) | All handler class implementations |
| 17 | `ZBP_SOMGMT_I_SalesOrder` | `.clas.testclasses.abap` | CLAS (CCAU) | Unit test classes |
| 18 | `ZBP_SOMGMT_I_SalesOrder` | `.clas.xml` | CLAS descriptor | abapGit class metadata |
| 19 | `ZSOMGMT_SD_SalesOrder` | `.srvd.asddls` | SRVD | Service definition |
| — | `ZSOMGMT_SB_SalesOrder_V4` | *(created in ADT)* | SRVB | Service binding — OData V4 UI |

---

## 5. CDS View Layer

### 5.1 Interface View — `ZSOMGMT_I_SalesOrder` (Root)

**Purpose:** Lowest-level BO view. Reads from `ZSOMGMT_D_SO_HDR`. Defines the composition to `ZSOMGMT_I_SalesOrderItem`. Admin field annotations drive automatic population by the RAP managed framework.

**Key annotations:**

| Annotation | Field | Effect |
|-----------|-------|--------|
| `@Semantics.user.createdBy` | `CreatedBy` | Auto-set on CREATE by framework |
| `@Semantics.systemDateTime.createdAt` | `CreatedAt` | Auto-set on CREATE by framework |
| `@Semantics.user.lastChangedBy` | `LastChangedBy` | Auto-updated on every MODIFY |
| `@Semantics.systemDateTime.lastChangedAt` | `LastChangedAt` | Auto-updated, used as ETag |

**Computed field `OverallStatusCriticality`:**
```cds
case overallstatus
  when 'A' then 3   -- success / green
  when 'P' then 2   -- warning / yellow
  when 'X' then 1   -- error   / red
  else          0   -- neutral / grey
end as OverallStatusCriticality
```
This field is consumed by `@UI.lineItem: [{ criticality: 'OverallStatusCriticality' }]` in the metadata extension to colour-code the status badge in the Fiori List Report and Object Page.

### 5.2 Interface View — `ZSOMGMT_I_SalesOrderItem` (Child)

**Purpose:** Reads from `ZSOMGMT_D_SO_ITM`. Declares `association to parent ZSOMGMT_I_SalesOrder` for composition back-navigation.

**Key annotations:**

| Annotation | Field | Effect |
|-----------|-------|--------|
| `@Semantics.quantity.unitOfMeasure: 'QuantityUnit'` | `Quantity` | Links quantity to UoM for OData quantity type |
| `@Semantics.amount.currencyCode: 'Currency'` | `UnitPrice`, `NetAmount` | Links amounts to currency key |

### 5.3 Consumption Views

| View | `provider contract` | Draft | Value Helps Defined |
|------|---------------------|-------|---------------------|
| `ZSOMGMT_C_SalesOrder` | `transactional_query` | ✓ | Customer (`I_BusinessPartner`), Currency (`I_Currency`) |
| `ZSOMGMT_C_SalesOrderItem` | *(inherits from root)* | ✓ | Product (`I_Product`), UoM (`I_UnitOfMeasure`) |

**Composition redirection** (mandatory for draft-enabled projection):
```cds
-- In ZSOMGMT_C_SalesOrder:
_Item : redirected to composition child ZSOMGMT_C_SalesOrderItem

-- In ZSOMGMT_C_SalesOrderItem:
_SalesOrder : redirected to parent ZSOMGMT_C_SalesOrder
```

---

## 6. Behavior Definition

### 6.1 Interface BDEF — `ZSOMGMT_I_SalesOrder`

```
managed implementation in class zbp_somgmt_i_salesorder unique;
strict ( 2 );
with draft;
```

#### Header Entity (`SalesOrder`) — Field Controls

| Field | Control | Reason |
|-------|---------|--------|
| `SalesOrderId` | `readonly` | Assigned externally / by system |
| `OverallStatus` | `readonly` | Controlled exclusively by workflow actions |
| `GrossAmount`, `NetAmount`, `TaxAmount` | `readonly` | Computed by determinations |
| `CustomerName` | `readonly` | Derived via value help binding from `CustomerId` |
| `CreatedBy`, `CreatedAt`, `LastChangedBy`, `LastChangedAt` | `readonly` | Admin fields — managed by framework |
| `CustomerId`, `OrderDate`, `Currency` | `mandatory` | Required for save |

#### Standard Operations

| Operation | Scope | Notes |
|-----------|-------|-------|
| `create` | Header | Creates new draft; sets initial status N |
| `update` | Header | Updates draft fields; triggers determinations |
| `delete` | Header | Only allowed in status N; cascades to items |

#### Draft Actions (auto-generated)

| Action | Trigger | Description |
|--------|---------|-------------|
| `Edit` | User clicks Edit | Creates draft copy of active entity |
| `Activate` | User clicks Save | Runs validations, persists draft to active table |
| `Discard` | User clicks Cancel | Deletes draft without touching active entity |
| `Resume` | User reopens draft | Restores in-progress edit session |
| `Prepare` | Before Activate | Runs `validateCustomer`, `validateDates`, `validateCurrency` |

#### Business Actions

| Action | Type | Input | Status Guard | Result |
|--------|------|-------|-------------|--------|
| `submitForApproval` | Instance | None | Status = `N` | Status → `P` |
| `approveOrder` | Instance | None | Status = `P` | Status → `A` |
| `rejectOrder` | Instance | `ZSOMGMT_A_RejectParam` (RejectionReason) | Status = `P` | Status → `X` |

#### Determinations

| Name | Trigger | Logic |
|------|---------|-------|
| `setInitialStatus` | On modify → create | Sets `OverallStatus = 'N'`, seeds `OrderDate` with system date if empty |
| `recalculateHeaderAmounts` | On modify → delete | Re-sums remaining items and updates `NetAmount`, `TaxAmount`, `GrossAmount` on header |

#### Validations

| Name | Trigger | Check | Message on Failure |
|------|---------|-------|-------------------|
| `validateCustomer` | Save: create, update(CustomerId) | `CustomerId` not initial AND exists in `I_BusinessPartner` | *"Customer 'XXX' does not exist"* |
| `validateDates` | Save: create, update(DeliveryDate, OrderDate) | `DeliveryDate` ≥ `OrderDate` | *"Delivery Date must be on or after Order Date"* |
| `validateCurrency` | Save: create, update(Currency) | Currency exists in `I_Currency` | *"Currency 'XXX' is not valid"* |

#### Item Entity (`SalesOrderItem`) — Determination

| Name | Trigger | Logic |
|------|---------|-------|
| `calculateItemNetAmount` | On modify → create, update(Quantity, UnitPrice) | `NetAmount = Quantity × UnitPrice`; then re-reads all items of parent and updates header `NetAmount`, `TaxAmount` (10%), `GrossAmount` |

#### Item Validations

| Name | Trigger | Check |
|------|---------|-------|
| `validateQuantity` | Save: create, update(Quantity) | `Quantity > 0` |
| `validateItemProduct` | Save: create, update(ProductId) | `ProductId` not initial |

### 6.2 Projection BDEF — `ZSOMGMT_C_SalesOrder`

```
projection;
strict ( 2 );
use draft;
```

Exposes: `create`, `update`, `delete`, `Edit`, `Activate`, `Discard`, `Resume`, `Prepare`, `submitForApproval`, `approveOrder`, `rejectOrder`, `_Item { create; with draft; }`.

---

## 7. Behavior Implementation

### 7.1 Class Structure

```
ZBP_SOMGMT_I_SALESORDER (global ABSTRACT FINAL class — shell only)
│
├── CCDEF (locals_def)
│     └── CONSTANT gc_tax_rate TYPE decfloat16 VALUE '0.10'
│
├── CCIMP (locals_imp)
│     ├── CLASS lhc_salesorder    INHERITING FROM cl_abap_behavior_handler
│     │     ├── validate_customer        → FOR VALIDATE ON SAVE
│     │     ├── validate_dates           → FOR VALIDATE ON SAVE
│     │     ├── validate_currency        → FOR VALIDATE ON SAVE
│     │     ├── set_initial_status       → FOR DETERMINE ON MODIFY
│     │     ├── recalculate_header_amounts → FOR DETERMINE ON MODIFY
│     │     ├── submit_for_approval      → FOR MODIFY (ACTION)
│     │     ├── approve_order            → FOR MODIFY (ACTION)
│     │     └── reject_order             → FOR MODIFY (ACTION)
│     │
│     └── CLASS lhc_salesorderitem INHERITING FROM cl_abap_behavior_handler
│           ├── calculate_item_net_amount → FOR DETERMINE ON MODIFY
│           ├── validate_quantity         → FOR VALIDATE ON SAVE
│           └── validate_item_product     → FOR VALIDATE ON SAVE
│
└── CCAU (testclasses)
      ├── CLASS ltcl_salesorder_test (validate_dates, currency, status guards)
      └── CLASS ltcl_item_test       (net amount calc, quantity validation)
```

### 7.2 EML Pattern Used

All database access uses **Entity Manipulation Language (EML)** — no direct `SELECT FROM zsomgmt_d_so_hdr` in handler classes:

```abap
" Reading entity data (IN LOCAL MODE = bypasses auth check for internal use)
READ ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
  ENTITY SalesOrder
  FIELDS ( CustomerId OverallStatus )
  WITH CORRESPONDING #( keys )
  RESULT DATA(lt_so).

" Reading child entities via association
READ ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
  ENTITY SalesOrder BY \_Item
  FIELDS ( NetAmount )
  WITH CORRESPONDING #( keys )
  RESULT DATA(lt_items).

" Modifying entity data
MODIFY ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
  ENTITY SalesOrder
  UPDATE FIELDS ( OverallStatus )
  WITH VALUE #( ( %tky = ls_so-%tky  OverallStatus = 'P' ) )
  REPORTED DATA(ls_rep).
```

### 7.3 Amount Calculation Flow

```
User changes Quantity or UnitPrice on Item
        │
        ▼
calculateItemNetAmount determination fires
        │
        ├─► UPDATE item NetAmount = Quantity × UnitPrice
        │
        ├─► READ all items for parent order (BY \_Item)
        │
        ├─► SUM all item NetAmounts → lv_net
        │
        ├─► lv_tax   = lv_net × 0.10   (10% tax)
        │
        ├─► lv_gross = lv_net + lv_tax
        │
        └─► UPDATE header NetAmount, TaxAmount, GrossAmount
```

### 7.4 Action Flow — Submit for Approval

```
User clicks "Submit for Approval"
        │
        ▼
submit_for_approval method called
        │
        ├─ READ OverallStatus for each key
        │
        ├─ IF OverallStatus ≠ 'N'
        │     └─► APPEND to failed-salesorder + ERROR message
        │
        └─ IF OverallStatus = 'N'
              ├─► MODIFY OverallStatus = 'P'
              ├─► READ updated entity (ALL FIELDS)
              └─► RETURN as action result (result = ...)
```

---

## 8. Fiori Elements UI

### 8.1 Floorplan

- **Template:** List Report Object Page (LROP)
- **OData Version:** V4
- **Draft Handling:** Enabled — Edit / Save / Cancel / Discard buttons auto-generated
- **Navigation:** Clicking a row in the List Report opens the Object Page for that order

### 8.2 List Report — Filter Bar

| Field | Filter Type | Source |
|-------|-------------|--------|
| Sales Order ID | Single-value input | `SalesOrderId` |
| Customer ID | Value help (typeahead) | `CustomerId` → `I_BusinessPartner` |
| Order Date | Date range picker | `OrderDate` |
| Overall Status | Dropdown | `OverallStatus` (values: N / P / A / X) |

### 8.3 List Report — Table Columns

| Position | Column | Annotation | Notes |
|----------|--------|-----------|-------|
| 10 | Sales Order | `@UI.lineItem: [{ position: 10 }]` | Hyperlink to Object Page |
| 20 | Description | `@UI.lineItem: [{ position: 20 }]` | |
| 30 | Customer ID | `@UI.lineItem: [{ position: 30 }]` | |
| 40 | Customer Name | `@UI.lineItem: [{ position: 40 }]` | |
| 50 | Order Date | `@UI.lineItem: [{ position: 50 }]` | |
| 60 | Delivery Date | `@UI.lineItem: [{ position: 60 }]` | |
| 70 | Status | `criticality: 'OverallStatusCriticality'` | Colour-coded badge |
| 80 | Gross Amount | `@UI.lineItem: [{ position: 80 }]` | Currency formatted |
| 90 | Net Amount | `@UI.lineItem: [{ position: 90 }]` | Currency formatted |

**Inline action buttons on List Report table rows:**

| Button Label | Action | Visibility |
|---|---|---|
| Submit | `submitForApproval` | When Status = N |
| Approve | `approveOrder` | When Status = P |
| Reject | `rejectOrder` | When Status = P (opens dialog) |

### 8.4 Object Page — Header

| Element | Source | Notes |
|---------|--------|-------|
| Title | `SalesOrderId` | `@UI.headerInfo.title` |
| Description | `Description` | `@UI.headerInfo.description` |
| Status Badge | `OverallStatus` with criticality | `@UI.dataPoint` |
| KPI — Gross Amount | `GrossAmount` | `@UI.dataPoint` |
| KPI — Net Amount | `NetAmount` | `@UI.dataPoint` |

### 8.5 Object Page — Facets (Sections)

| Position | Facet ID | Type | Content |
|----------|----------|------|---------|
| 10 | `GeneralInfo` | `#IDENTIFICATION_REFERENCE` | CustomerId, CustomerName, OrderDate, DeliveryDate, Currency |
| 20 | `FinancialSummary` | `#FIELDGROUP_REFERENCE` | NetAmount, TaxAmount, GrossAmount (all read-only) |
| 30 | `LineItems` | `#LINEITEM_REFERENCE` | Embedded items table → `_Item` (inline editable in draft) |
| 40 | `AdminData` | `#FIELDGROUP_REFERENCE` | CreatedBy, CreatedAt, LastChangedBy, LastChangedAt |

### 8.6 Status Criticality — Colour Mapping

| Status | Code | `OverallStatusCriticality` | Fiori Colour |
|--------|------|---------------------------|-------------|
| New | `N` | `0` | Grey (neutral) |
| In Process | `P` | `2` | Yellow (warning) |
| Approved | `A` | `3` | Green (success) |
| Rejected | `X` | `1` | Red (error) |

---

## 9. Status & Workflow Logic

### 9.1 Allowed Transitions

```
          submitForApproval
   New ──────────────────► In Process
    │                           │
    │ delete                    ├─── approveOrder ──► Approved (read-only)
    ▼                           │
  (deleted)                     └─── rejectOrder ──► Rejected (read-only)
```

### 9.2 Field Editability by Status

| Field | New (N) | In Process (P) | Approved (A) | Rejected (X) |
|-------|---------|---------------|-------------|-------------|
| Description | ✏️ Editable | 🔒 Read-only | 🔒 Read-only | 🔒 Read-only |
| CustomerId | ✏️ Editable | 🔒 Read-only | 🔒 Read-only | 🔒 Read-only |
| Dates | ✏️ Editable | 🔒 Read-only | 🔒 Read-only | 🔒 Read-only |
| Line Items | ✏️ Editable | 🔒 Read-only | 🔒 Read-only | 🔒 Read-only |
| OverallStatus | 🚫 System-only | 🚫 System-only | 🚫 System-only | 🚫 System-only |
| Amounts | 🔢 Computed | 🔢 Computed | 🔢 Computed | 🔢 Computed |

> Note: Full field-level locking by status requires feature control implementation in the BDEF/handler. The current implementation marks `OverallStatus` as `readonly` at the BDEF level. Full status-based locking can be added via `PROVIDE FIELDS LOCKED` in the action handler or via dynamic feature control.

---

## 10. Security & Authorization

### 10.1 Role Concept

| Role | Create/Edit Orders | Submit | Approve/Reject | View |
|------|-------------------|--------|---------------|------|
| Sales Representative (`ZSO_REP`) | ✓ Own orders | ✓ | ✗ | Own orders |
| Sales Manager (`ZSO_MGR`) | ✓ All orders | ✓ | ✓ | All orders |
| Administrator (`ZSO_ADMIN`) | ✓ All orders | ✓ | ✓ | All orders |

### 10.2 Access Control (Current State)

The current implementation uses `@AccessControl.authorizationCheck: #NOT_REQUIRED` on all CDS views to simplify initial development and testing. For production:

1. **Create DCL objects** (`.dcls` files) for `ZSOMGMT_I_SalesOrder` and `ZSOMGMT_I_SalesOrderItem` using `define role`.
2. **Switch** `#NOT_REQUIRED` → `#CHECK` on both interface views.
3. **Implement** `authorization master (instance)` in the handler class by adding a `GET_INSTANCE_AUTHORIZATIONS` method.

### 10.3 Recommended Authorization Object

```abap
" Authorization object: Z_SO_AUTH
" Fields:
"   ACTVT  (Activity: 01=Create, 02=Change, 03=Display, 06=Delete, Z1=Submit, Z2=Approve)
"   ZSOCUST (Customer ID — for row-level filter on Sales Rep role)
```

---

## 11. Step-by-Step Deployment Guide

### Prerequisites

| Requirement | Detail |
|------------|--------|
| SAP System | S/4 HANA 2022 (on-prem) or BTP ABAP Environment |
| Eclipse Version | Eclipse 2023-09 or later |
| ADT Plugin | ABAP Development Tools for Eclipse (latest) |
| abapGit Plugin | abapGit Eclipse plugin installed |
| GitHub Access | Read access to `pramodram9/vscode_eclipse_claude` |
| ABAP Package | `ZSD_SOMGMT` created in the target system |
| Transport | Workbench transport request created |

---

### Step 1 — Create the ABAP Package in Eclipse ADT

1. Open Eclipse → connect to your S/4 HANA system.
2. In **Project Explorer**, right-click your project → **New → ABAP Package**.
3. Fill in:
   - **Name:** `ZSD_SOMGMT`
   - **Description:** `Sales Order Management — RAP`
   - **Package Type:** Development
   - **Software Component:** `HOME` (or your Z component)
4. Assign to a **Workbench transport request** (create one if needed via SE09).
5. Click **Finish**.

---

### Step 2 — Configure abapGit in Eclipse

1. In Eclipse menu → **Window → Perspective → Open Perspective → abapGit Repositories**.
2. Click **New Repository (Clone)** button (green `+` icon).
3. Enter:
   - **URL:** `https://github.com/pramodram9/vscode_eclipse_claude.git`
   - **Branch:** `main`
   - **Package:** `ZSD_SOMGMT`
4. Click **Next** → authenticate with your GitHub credentials if prompted.
5. On the **Folder** step, set the folder to `new_rap_test` (the subfolder containing the RAP artifacts).
6. Click **Finish**. abapGit will clone the repository and map it to your package.

> **Tip:** If your abapGit version does not support subfolder cloning, clone the full repo and use the **Ignore** feature to exclude `src/` content, or move `new_rap_test/` contents to the repo root.

---

### Step 3 — Pull Objects from GitHub via abapGit

1. In the **abapGit Repositories** perspective, select your repository entry.
2. Click **Pull** (down-arrow icon).
3. abapGit will show a list of all 19 objects to be imported. Verify the list matches the [Artifact Inventory](#4-artifact-inventory).
4. Click **Execute Pull**.
5. abapGit imports all objects into the `ZSD_SOMGMT` package. Objects appear in **Project Explorer** under the package.

---

### Step 4 — Activate All Objects (Correct Order)

**Critical:** Activate in dependency order. ABAP objects cannot be activated if their dependencies are inactive.

#### 4a — Activate Database Tables

In ADT **Project Explorer**, navigate to `ZSD_SOMGMT → Dictionary → Database Tables`.

Activate in this order (select each, press `Ctrl+F3`):

```
1. ZSOMGMT_D_SO_HDR    (header active table)
2. ZSOMGMT_D_SO_ITM    (item active table)
3. ZSOMGMT_D_SO_D_H    (header draft table)
4. ZSOMGMT_D_SO_D_I    (item draft table)
```

> ✅ **Verify:** Right-click each table → **Open With → ABAP Dictionary**. All fields should be visible with correct types. Run `SE11 → Display` to confirm.

#### 4b — Activate Abstract Entity

```
5. ZSOMGMT_A_RejectParam    (action parameter)
```

#### 4c — Activate Interface CDS View Entities

```
6. ZSOMGMT_I_SalesOrder       (root interface view)
7. ZSOMGMT_I_SalesOrderItem   (child interface view)
```

> ✅ **Verify:** Right-click → **Run As → Data Preview**. For `ZSOMGMT_I_SalesOrder`, the preview should show columns with correct data types (empty table at this point is fine).

#### 4d — Activate Interface Behavior Definition

```
8. ZSOMGMT_I_SalesOrder   (BDEF — interface layer)
```

> ✅ **Verify:** No syntax errors in the BDEF editor. Hover over the `implementation in class` reference — it should resolve to `ZBP_SOMGMT_I_SALESORDER`.

#### 4e — Activate Consumption CDS View Entities

```
9.  ZSOMGMT_C_SalesOrder       (root consumption view)
10. ZSOMGMT_C_SalesOrderItem   (child consumption view)
```

#### 4f — Activate Projection Behavior Definition

```
11. ZSOMGMT_C_SalesOrder   (BDEF — projection layer)
```

#### 4g — Activate Behavior Implementation Class

```
12. ZBP_SOMGMT_I_SalesOrder   (all includes: .abap, locals_def, locals_imp, testclasses)
```

> ✅ **Verify:** Select the class, press `Ctrl+F3`. Activate all includes together. Check the **Problems** view — there should be no errors. Warnings about unused variables in stub methods are acceptable.

#### 4h — Activate Metadata Extensions

```
13. ZSOMGMT_C_SalesOrder      (header DDLX)
14. ZSOMGMT_C_SalesOrderItem  (item DDLX)
```

#### 4i — Activate Service Definition

```
15. ZSOMGMT_SD_SalesOrder
```

> ✅ **Verify:** Open the service definition. Both entity exposures (`SalesOrder`, `SalesOrderItem`) should resolve without errors.

---

### Step 5 — Create the Service Binding

The service binding cannot be stored in abapGit as a deployable file and must be created manually in ADT.

1. In **Project Explorer**, right-click `ZSD_SOMGMT` → **New → Other ABAP Repository Object**.
2. Navigate to **Business Services → Service Binding**.
3. Fill in:
   - **Name:** `ZSOMGMT_SB_SALESORDER_V4`
   - **Description:** `Sales Order Management - OData V4 UI`
   - **Binding Type:** `OData V4 - UI`
   - **Service Definition:** `ZSOMGMT_SD_SalesOrder`
4. Click **Finish**.
5. In the service binding editor that opens, click **Publish**.
6. After publishing, the **Service URL** is displayed:
   ```
   /sap/opu/odata4/sap/zsomgmt_sd_salesorder/srvd/sap/zsomgmt_sd_salesorder/0001/
   ```
   Copy this URL — you will need it in Step 7.

> ✅ **Verify:** The binding shows status **Published** and both entity sets (`SalesOrder`, `SalesOrderItem`) are listed under **Entity Sets and Associations**.

---

### Step 6 — Run Unit Tests

1. In ADT, open `ZBP_SOMGMT_I_SALESORDER`.
2. Navigate to the **Test Classes** include (`Ctrl+Shift+T`).
3. Right-click anywhere in the test class source → **Run As → ABAP Unit Test**.
4. The **ABAP Unit** view opens. All 8 test methods should show **green**.

| Test Class | Method | Expected Result |
|-----------|--------|----------------|
| `ltcl_salesorder_test` | `validate_dates_pass` | ✅ Pass |
| `ltcl_salesorder_test` | `validate_dates_fail` | ✅ Pass |
| `ltcl_salesorder_test` | `validate_currency_pass` | ✅ Pass |
| `ltcl_salesorder_test` | `validate_currency_fail` | ✅ Pass |
| `ltcl_salesorder_test` | `submit_status_must_be_new` | ✅ Pass |
| `ltcl_salesorder_test` | `approve_status_must_be_p` | ✅ Pass |
| `ltcl_item_test` | `net_amount_calculation` | ✅ Pass |
| `ltcl_item_test` | `quantity_zero_is_invalid` | ✅ Pass |

---

### Step 7 — Test the OData Service with Postman

Use the service URL from Step 5.

#### 7a — Read Sales Orders (GET)

```
GET /sap/opu/odata4/sap/zsomgmt_sd_salesorder/srvd/sap/zsomgmt_sd_salesorder/0001/SalesOrder
Authorization: Basic <user:password>
```

Expected response: HTTP 200 with JSON array of sales orders.

#### 7b — Create a Sales Order (POST)

```http
POST /sap/opu/odata4/.../SalesOrder
Content-Type: application/json

{
  "SalesOrderId": "SO0000001",
  "CustomerId": "1000000001",
  "Description": "Test Order",
  "OrderDate": "2026-04-01",
  "DeliveryDate": "2026-04-30",
  "Currency": "USD"
}
```

Expected: HTTP 201 Created. `OverallStatus` = `N`.

#### 7c — Submit for Approval (POST action)

```http
POST /sap/opu/odata4/.../SalesOrder('SO0000001')/com.sap.gateway.srvd.zsomgmt_sd_salesorder.v0001.submitForApproval
Content-Type: application/json
{}
```

Expected: HTTP 200. `OverallStatus` changes to `P`.

#### 7d — Approve (POST action)

```http
POST /sap/opu/odata4/.../SalesOrder('SO0000001')/com.sap.gateway.srvd.zsomgmt_sd_salesorder.v0001.approveOrder
Content-Type: application/json
{}
```

Expected: HTTP 200. `OverallStatus` changes to `A`.

---

### Step 8 — Launch the Fiori Elements App (Launchpad / BAS)

**Option A — Preview directly from ADT:**

1. Open the service binding `ZSOMGMT_SB_SALESORDER_V4`.
2. Select entity `SalesOrder` in the entity set list.
3. Click **Preview** button in the binding editor.
4. Eclipse opens a browser with the Fiori Elements List Report app automatically generated from your CDS annotations.

**Option B — SAP Business Application Studio (BAS):**

1. Open BAS → **New Project from Template**.
2. Select **SAP Fiori application → List Report Object Page**.
3. Connect to your system → select service `ZSOMGMT_SD_SalesOrder`.
4. Choose main entity `SalesOrder`, navigation entity `SalesOrderItem`.
5. Generate the app. BAS scaffolds a full Fiori app using your metadata extension annotations.
6. Deploy to SAP Fiori Launchpad.

---

### Step 9 — Push Changes Back to GitHub (Future Updates)

After any changes in ADT (new validations, UI annotation changes, etc.):

1. In Eclipse → **abapGit Repositories** perspective.
2. Select your repository → click **Stage** (shows changed objects).
3. Review the diff for each changed object.
4. Enter a commit message and click **Push**.
5. Changes are pushed to `pramodram9/vscode_eclipse_claude` on the `main` branch.
6. In VS Code (local), run `git pull` to sync.

---

## 12. Testing Guide

### 12.1 Functional Test Scenarios

#### Scenario 1 — Happy Path: Create and Approve Order

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Open Fiori app → Click Create | New order draft created, Status = N |
| 2 | Enter CustomerId = `1000000001` | CustomerName auto-populated |
| 3 | Set OrderDate = today, DeliveryDate = +30 days | Dates accepted |
| 4 | Set Currency = `USD` | Currency accepted |
| 5 | Add item: ProductId=`PROD001`, Qty=5, Price=100 | NetAmount = 500.00 auto-calculated |
| 6 | Click Save | Draft activated, order persisted. Header Net=500, Tax=50, Gross=550 |
| 7 | Click Submit for Approval | Status changes to P |
| 8 | Log in as Manager → Open order → Click Approve | Status changes to A. Order read-only |

#### Scenario 2 — Reject Order

| Step | Action | Expected Result |
|------|--------|----------------|
| 1–7 | Same as Scenario 1 steps 1–7 | Order in status P |
| 8 | Click Reject → Enter "Price too high" → Confirm | Status = X, Description updated with rejection reason |

#### Scenario 3 — Validation Errors

| Scenario | Action | Expected Error |
|----------|--------|---------------|
| Missing Customer | Save with empty CustomerId | *"Customer ID is mandatory"* |
| Invalid Customer | CustomerId = `ZZZZZZ` (non-existent) | *"Customer 'ZZZZZZ' does not exist"* |
| Bad Dates | DeliveryDate < OrderDate | *"Delivery Date must be on or after Order Date"* |
| Zero Quantity | Item with Qty = 0 | *"Quantity must be greater than zero"* |
| Empty Product | Item with blank ProductId | *"Product ID is mandatory"* |

#### Scenario 4 — Draft Handling

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Create order → enter partial data → close browser | Draft saved |
| 2 | Reopen app → order shows in list with draft indicator | Draft indicator visible |
| 3 | Click Resume | Edit session restored with partial data |
| 4 | Click Discard | Draft deleted, no active record created |

### 12.2 Amount Calculation Verification

| Input | Expected Output |
|-------|----------------|
| Item 1: Qty=5, Price=100 | NetAmount(item)=500 |
| Item 2: Qty=2, Price=50 | NetAmount(item)=100 |
| Header totals | NetAmount=600, TaxAmount=60, GrossAmount=660 |
| Delete Item 2 | NetAmount=500, TaxAmount=50, GrossAmount=550 |

---

## 13. Troubleshooting

### 13.1 Common Activation Errors

| Error | Cause | Resolution |
|-------|-------|-----------|
| *"ZSOMGMT_D_SO_HDR not found"* | Table not activated | Activate table first (Step 4a) |
| *"ZBP_SOMGMT_I_SALESORDER not found"* | Class not activated | Activate class before BDEF (Step 4g) |
| *"Composition type mismatch"* | Projection view not redirected | Ensure `redirected to composition child` in `ZSOMGMT_C_SalesOrder` |
| *"Draft table field mismatch"* | Draft table missing field | Compare draft table fields with active table |
| *"BDEF: action parameter not found"* | `ZSOMGMT_A_RejectParam` not activated | Activate abstract entity first (Step 4b) |

### 13.2 Runtime Errors

| Error | Cause | Resolution |
|-------|-------|-----------|
| HTTP 401 on OData call | Auth not configured | Use Basic Auth with a valid system user |
| HTTP 404 on entity set | Service binding not published | Click Publish in service binding editor |
| Amount not calculated | Item determination not triggering | Check BDEF `on modify { create; update(...) }` trigger fields |
| Status not changing | Action guard failing silently | Check `failed-salesorder` and `reported-salesorder` in action handler |
| Draft not visible | Draft table not activated | Check `ZSOMGMT_D_SO_D_H` / `_D_I` are active and accessible |

### 13.3 abapGit Pull Issues

| Issue | Resolution |
|-------|-----------|
| *"Object already exists with different type"* | Check for naming conflicts in the system; rename or delete conflicting object |
| *"Package does not exist"* | Create `ZSD_SOMGMT` package before pulling |
| *"Inactive objects found"* | Mass-activate all pulled objects: ADT → **Source Library → Activate All** |
| Subfolder not found | Clone full repo; manually map `new_rap_test/` folder in abapGit settings |

---

## 14. Appendix — File Reference

### 14.1 Complete File List in `new_rap_test/`

```
new_rap_test/
├── FSD_SalesOrder_RAP.md                          ← Original Functional Spec
├── TECHSPEC_SalesOrder_RAP.md                     ← This document
│
├── ── DB Tables ─────────────────────────────────────
├── zsomgmt_d_so_hdr.tabl.xml                      ← Header active table
├── zsomgmt_d_so_itm.tabl.xml                      ← Item active table
├── zsomgmt_d_so_d_h.tabl.xml                      ← Header draft table
├── zsomgmt_d_so_d_i.tabl.xml                      ← Item draft table
│
├── ── CDS DDL Sources ───────────────────────────────
├── zsomgmt_a_rejectparam.ddls.asddls              ← Abstract entity (action param)
├── zsomgmt_i_salesorder.ddls.asddls               ← Interface root view
├── zsomgmt_i_salesorderitem.ddls.asddls           ← Interface child view
├── zsomgmt_c_salesorder.ddls.asddls               ← Consumption root projection
├── zsomgmt_c_salesorderitem.ddls.asddls           ← Consumption child projection
│
├── ── Behavior Definitions ──────────────────────────
├── zsomgmt_i_salesorder.bdef.asbdls               ← Interface BDEF (managed+draft)
├── zsomgmt_c_salesorder.bdef.asbdls               ← Projection BDEF
│
├── ── Metadata Extensions (UI Annotations) ──────────
├── zsomgmt_c_salesorder.ddlx.asddlxs              ← Header LR+OP annotations
├── zsomgmt_c_salesorderitem.ddlx.asddlxs          ← Item table annotations
│
├── ── Behavior Implementation Class ─────────────────
├── zbp_somgmt_i_salesorder.clas.abap              ← Global class shell
├── zbp_somgmt_i_salesorder.clas.locals_def.abap   ← CCDEF (constants)
├── zbp_somgmt_i_salesorder.clas.locals_imp.abap   ← CCIMP (all handlers)
├── zbp_somgmt_i_salesorder.clas.testclasses.abap  ← CCAU (unit tests)
├── zbp_somgmt_i_salesorder.clas.xml               ← Class descriptor
│
└── ── Service Definition ────────────────────────────
    zsomgmt_sd_salesorder.srvd.asddls              ← Service definition
    (ZSOMGMT_SB_SALESORDER_V4 — created manually in ADT, Step 5)
```

### 14.2 abapGit File Extension Reference

| SAP Object Type | abapGit Extension | Content Format |
|----------------|-------------------|----------------|
| Database Table (TABL) | `.tabl.xml` | abapGit XML (DDIC structure) |
| CDS Data Definition (DDLS) | `.ddls.asddls` | CDS DDL source text |
| CDS Metadata Extension (DDLX) | `.ddlx.asddlxs` | CDS DDL extension text |
| Behavior Definition (BDEF) | `.bdef.asbdls` | Behavior definition source text |
| Service Definition (SRVD) | `.srvd.asddls` | Service definition DDL |
| ABAP Class — main | `.clas.abap` | ABAP source |
| ABAP Class — CCDEF | `.clas.locals_def.abap` | ABAP source |
| ABAP Class — CCIMP | `.clas.locals_imp.abap` | ABAP source |
| ABAP Class — CCAU | `.clas.testclasses.abap` | ABAP source |
| ABAP Class — descriptor | `.clas.xml` | abapGit XML |

### 14.3 Key SAP Transactions

| Transaction | Purpose |
|-------------|---------|
| `SE11` | ABAP Dictionary — verify table structure |
| `SE18` | BAdI Builder — verify BAdI definitions |
| `SE09` | Transport Organizer — manage transport requests |
| `/n/IWFND/MAINT_SERVICE` | Activate and maintain OData services (classic gateway) |
| `/n/IWFND/ERROR_LOG` | OData error log — troubleshoot runtime errors |
| `SAML2` / `SU01` | User management — assign roles for authorization |

---

*This document was generated by Claude Code (Sonnet 4.6) on 2026-04-01 from `FSD_SalesOrder_RAP.md`.*
*All artifacts are stored in `pramodram9/vscode_eclipse_claude/new_rap_test/`.*
