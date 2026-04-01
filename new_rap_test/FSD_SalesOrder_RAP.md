# Functional Specification Document (FSD)
## Sales Order Management — RAP Managed BO + Fiori Elements

**Version:** 1.0 | **Date:** April 2026 | **Author:** AI-Assisted (Claude Code)
**Status:** Draft — For Review
**Technology:** RAP Managed, CDS View Entities, Fiori Elements V4, OData V4

---

## 1. Introduction

### 1.1 Purpose
This FSD defines the functional and technical requirements for building a Sales Order Management application using the RESTful ABAP Programming (RAP) Model with a Fiori Elements front-end. The application supports the complete lifecycle of a sales order: creation, editing, submission for approval, approval/rejection, and status tracking.

This document is designed to be fed directly into Claude Code to auto-generate the complete set of RAP artifacts including CDS View Entities, Behavior Definitions, Projections, Metadata Extensions, Service Definitions, and Behavior Implementation classes.

### 1.2 Scope
- Sales Order Header and Item management (CRUD operations)
- Draft-enabled editing with Fiori Elements draft handling
- Multi-step status workflow: New → In Process → Approved / Rejected
- Automatic amount calculation (determination on item changes)
- Fiori Elements List Report with filters and Object Page with facets
- OData V4 Service Binding for UI consumption
- Value Helps for Customer, Product, Currency

### 1.3 Technology Stack
- SAP S/4HANA Cloud or SAP BTP ABAP Environment
- ABAP Cloud 7.54+ (Modern Syntax: VALUE #, NEW #, inline declarations)
- RAP Managed Business Object with Draft
- CDS View Entities (Interface + Consumption layers)
- Fiori Elements V4 (List Report + Object Page floorplan)
- OData V4 protocol

---

## 2. Business Process Overview

### 2.1 Process Description
A Sales Representative creates a new Sales Order by entering customer details, delivery date, and one or more line items with product and quantity information. The system automatically calculates the net amount per line item and aggregates the totals at the header level. Once all details are complete, the representative submits the order for approval. A Sales Manager reviews the order and either approves or rejects it with a reason. Approved orders are ready for downstream processing (delivery, billing).

### 2.2 Process Flow
1. Sales Representative opens the Fiori app and clicks "Create" to start a new Sales Order (Draft is created).
2. Representative enters header data: Customer, Order Date, Delivery Date, Description.
3. Representative adds line items: Product, Quantity, Unit Price. Net amounts are calculated automatically.
4. Representative saves the draft. System validates mandatory fields and business rules.
5. Representative clicks "Submit for Approval" action. Status changes from N (New) to P (In Process).
6. Sales Manager opens the order from the List Report, reviews details on the Object Page.
7. Manager clicks "Approve" (status → A) or "Reject" with reason (status → X).

### 2.3 Status Flow
`N (New)` → `P (In Process)` → `A (Approved)` or `X (Rejected)`

| Status | Code | Description | Allowed Operations |
|--------|------|-------------|-------------------|
| New | N | Default on creation | Full CRUD, Submit for Approval |
| In Process | P | Submitted for approval | Approve, Reject (read-only otherwise) |
| Approved | A | Final approved state | Read-only |
| Rejected | X | Final rejected state | Read-only, can copy to new order |

---

## 3. Data Model

### 3.1 Entity Relationship
- Sales Order Header (1) → (0..*) Sales Order Item (composition)
- Composition is managed by RAP framework (cascade delete, draft consistency)
- Both entities support draft handling via managed implementation type

### 3.2 Sales Order Header — Database Table: `ZSOMGMT_D_SO_HDR`

| Field Name | CDS Element | Data Type | Key | Description |
|-----------|-------------|-----------|-----|-------------|
| SalesOrderID | SalesOrderId | CHAR(10) | Yes | Unique Sales Order Number |
| Description | Description | CHAR(80) | No | Order description text |
| CustomerID | CustomerId | CHAR(10) | No | Customer business partner ID |
| CustomerName | CustomerName | CHAR(60) | No | Customer full name |
| OrderDate | OrderDate | DATS | No | Date order was created |
| DeliveryDate | DeliveryDate | DATS | No | Requested delivery date |
| OverallStatus | OverallStatus | CHAR(1) | No | N=New, P=In Process, A=Approved, X=Rejected |
| Currency | Currency | CUKY(5) | No | Order currency code (ISO) |
| GrossAmount | GrossAmount | CURR(15,2) | No | Total gross amount |
| NetAmount | NetAmount | CURR(15,2) | No | Total net amount |
| TaxAmount | TaxAmount | CURR(15,2) | No | Total tax amount |
| CreatedBy | CreatedBy | CHAR(12) | No | User who created the order |
| CreatedAt | CreatedAt | TIMESTAMPL | No | Creation timestamp |
| LastChangedBy | LastChangedBy | CHAR(12) | No | Last modifier user ID |
| LastChangedAt | LastChangedAt | TIMESTAMPL | No | Last change timestamp |

### 3.3 Sales Order Item — Database Table: `ZSOMGMT_D_SO_ITM`

| Field Name | CDS Element | Data Type | Key | Description |
|-----------|-------------|-----------|-----|-------------|
| SalesOrderID | SalesOrderId | CHAR(10) | Yes | Parent Sales Order ID |
| ItemNumber | ItemNumber | NUMC(6) | Yes | Line item sequence number |
| ProductID | ProductId | CHAR(18) | No | Material / product number |
| ProductDescription | ProductDescription | CHAR(40) | No | Product description text |
| Quantity | Quantity | QUAN(13,3) | No | Ordered quantity |
| UoM | QuantityUnit | UNIT(3) | No | Unit of measure |
| UnitPrice | UnitPrice | CURR(15,2) | No | Price per unit |
| NetAmount | NetAmount | CURR(15,2) | No | Line net amount |
| Currency | Currency | CUKY(5) | No | Item currency |
| ItemStatus | ItemStatus | CHAR(1) | No | N=New, D=Delivered, C=Cancelled |

---

## 4. Naming Conventions (VDM Standard)

All artifacts follow the SAP Virtual Data Model (VDM) naming conventions and Clean ABAP principles. The prefix `ZSOMGMT` identifies the Sales Order Management application namespace.

| Artifact Type | Naming Pattern | Example |
|--------------|---------------|---------|
| Database Table | Z\<app\>_D_\<entity\> | ZSOMGMT_D_SO_HDR |
| Interface CDS View | Z\<app\>_I_\<entity\> | ZSOMGMT_I_SalesOrder |
| Consumption CDS View | Z\<app\>_C_\<entity\> | ZSOMGMT_C_SalesOrder |
| Metadata Extension | Z\<app\>_C_\<entity\> | ZSOMGMT_C_SalesOrder (MDEV) |
| Behavior Definition | Z\<app\>_I_\<entity\> | ZSOMGMT_I_SalesOrder (BDEF) |
| Behavior Projection | Z\<app\>_C_\<entity\> | ZSOMGMT_C_SalesOrder (BDEF) |
| Behavior Implementation | ZBP_\<app\>_I_\<entity\> | ZBP_SOMGMT_I_SalesOrder |
| Service Definition | Z\<app\>_SD_\<service\> | ZSOMGMT_SD_SalesOrder |
| Service Binding | Z\<app\>_SB_\<service\>_V4 | ZSOMGMT_SB_SalesOrder_V4 |
| Custom Entity (VH) | Z\<app\>_I_\<vh_name\>VH | ZSOMGMT_I_CustomerVH |

---

## 5. Artifact Inventory

| # | Artifact Name | Type | Purpose |
|---|--------------|------|---------|
| 1 | ZSOMGMT_D_SO_HDR | Database Table | Sales Order header persistence |
| 2 | ZSOMGMT_D_SO_ITM | Database Table | Sales Order item persistence |
| 3 | ZSOMGMT_I_SalesOrder | Interface CDS View Entity | Root BO entity with associations |
| 4 | ZSOMGMT_I_SalesOrderItem | Interface CDS View Entity | Child BO entity (composition) |
| 5 | ZSOMGMT_C_SalesOrder | Consumption CDS Projection | Root projection for Fiori UI |
| 6 | ZSOMGMT_C_SalesOrderItem | Consumption CDS Projection | Item projection for Fiori UI |
| 7 | ZSOMGMT_I_SalesOrder | Behavior Definition | Managed BO with draft, validations, actions |
| 8 | ZSOMGMT_C_SalesOrder | Behavior Projection | Projection BDEF exposing actions to UI |
| 9 | ZSOMGMT_C_SalesOrder (MDEV) | Metadata Extension | UI annotations for List Report & Object Page |
| 10 | ZSOMGMT_C_SalesOrderItem (MDEV) | Metadata Extension | UI annotations for Item sub-page |
| 11 | ZBP_SOMGMT_I_SalesOrder | ABAP Class | Behavior implementation (validations, determinations, actions) |
| 12 | ZSOMGMT_SD_SalesOrder | Service Definition | Exposes projections as OData service |
| 13 | ZSOMGMT_SB_SalesOrder_V4 | Service Binding | OData V4 UI binding for Fiori Elements |

---

## 6. Behavior Definition Specification

### 6.1 Root Entity Behavior — `ZSOMGMT_I_SalesOrder`
- **Implementation Type:** managed
- **Persistent Table:** zsomgmt_d_so_hdr
- **Draft Table:** zsomgmt_d_so_d_h (auto-generated)
- **Lock Master:** total ETag (LastChangedAt)
- **Authorization Master:** instance
- **ETag Master:** field LastChangedAt
- **Standard Operations:** create, update, delete
- **Draft Actions:** Edit, Activate, Discard, Resume

### 6.2 Child Entity Behavior — `ZSOMGMT_I_SalesOrderItem`
- **Implementation Type:** managed
- **Persistent Table:** zsomgmt_d_so_itm
- **Draft Table:** zsomgmt_d_so_d_i (auto-generated)
- **Lock Dependent**
- **Standard Operations:** create, update, delete (by association)

### 6.3 Validations

| # | Validation Name | Trigger | Business Rule |
|---|----------------|---------|---------------|
| V1 | validateCustomer | CREATE, UPDATE (CustomerId) | CustomerId must exist in I_BusinessPartner |
| V2 | validateDates | CREATE, UPDATE (DeliveryDate) | DeliveryDate must be >= OrderDate |
| V3 | validateQuantity | CREATE, UPDATE (Quantity) | Quantity must be > 0 for all items |
| V4 | validateCurrency | CREATE, UPDATE (Currency) | Currency must be a valid ISO currency code |
| V5 | validateItemProduct | CREATE, UPDATE (ProductId) | ProductId must exist in the product master |

### 6.4 Determinations
- **setInitialStatus:** On CREATE, set OverallStatus = 'N' and populate CreatedBy, CreatedAt.
- **calculateItemNetAmount:** On item CREATE/UPDATE of Quantity or UnitPrice, compute NetAmount = Quantity × UnitPrice.
- **recalculateHeaderAmounts:** On item CREATE/UPDATE/DELETE, sum all item NetAmounts, compute Tax (10%), compute GrossAmount = NetAmount + TaxAmount.

### 6.5 Actions

| # | Action Name | Type | Business Logic |
|---|------------|------|----------------|
| A1 | approveOrder | Instance Action | Set OverallStatus = 'A'. Only allowed when status = 'P'. Set all item statuses accordingly. |
| A2 | rejectOrder | Instance Action | Set OverallStatus = 'X'. Only allowed when status = 'P'. Requires rejection reason (parameter). |
| A3 | submitForApproval | Instance Action | Set OverallStatus from 'N' to 'P'. Validates all mandatory fields are populated. |
| A4 | recalculateAmounts | Internal Action (Determination) | Triggered on item CREATE/UPDATE. Sums item NetAmounts. Calculates TaxAmount (10%). Calculates GrossAmount. |

---

## 7. Fiori Elements UI Specification

### 7.1 Floorplan
- **Floorplan Type:** List Report + Object Page (standard Fiori Elements template)
- **OData Version:** V4
- **Navigation:** List Report row click → Object Page
- **Draft Handling:** Enabled (Edit button, Activate/Discard)

### 7.2 List Report Page

#### Filter Bar Fields
- SalesOrderId (single value input)
- CustomerId (value help with typeahead)
- OrderDate (date range)
- OverallStatus (dropdown with criticality coloring)

#### Table Columns
- Sales Order ID (hyperlink to Object Page)
- Description
- Customer ID & Customer Name
- Order Date & Delivery Date
- Overall Status (criticality: Green=Approved, Yellow=In Process, Red=Rejected, Grey=New)
- Gross Amount & Net Amount (with currency)

### 7.3 Object Page

#### Header Area
- **Title:** Sales Order ID + Description
- **Status Badge:** OverallStatus with criticality coloring
- **Key figures:** GrossAmount, NetAmount displayed as KPI cards

#### Facets (Sections)
1. **General Information:** CustomerId (Value Help), CustomerName (read-only), OrderDate, DeliveryDate, Currency
2. **Financial Summary:** NetAmount, TaxAmount, GrossAmount (all read-only, calculated)
3. **Line Items:** Embedded table of SalesOrderItem with inline editing — Columns: ItemNumber, ProductId (Value Help), ProductDescription, Quantity, UoM, UnitPrice, NetAmount, ItemStatus
4. **Administrative Data:** CreatedBy, CreatedAt, LastChangedBy, LastChangedAt (all read-only)

#### Actions on Object Page
- **Edit** (standard draft edit)
- **Submit for Approval** (visible when status = N)
- **Approve** (visible when status = P, role = Manager)
- **Reject** (visible when status = P, role = Manager) — opens dialog for rejection reason
- **Delete** (visible when status = N)

### 7.4 UI Annotation Summary

| Field | List Report | Object Page | Notes |
|-------|------------|-------------|-------|
| SalesOrderId | lineItem, selectionField | Header Facet | Primary key, hyperlink navigation |
| Description | lineItem | Header Title | Editable on Object Page |
| CustomerId | lineItem, selectionField | General Info Facet | Value Help from Customer entity |
| CustomerName | lineItem | General Info Facet | Read-only, derived from CustomerId |
| OrderDate | lineItem, selectionField | General Info Facet | Date picker |
| DeliveryDate | lineItem | General Info Facet | Date picker, must be >= OrderDate |
| OverallStatus | lineItem, selectionField | Header Facet (Criticality) | Color-coded status badge |
| GrossAmount | lineItem | Amounts Facet | Read-only, calculated |
| NetAmount | lineItem | Amounts Facet | Read-only, calculated |

---

## 8. Value Helps
- **Customer Value Help:** Source entity I_BusinessPartner. Display: BusinessPartner, BusinessPartnerName. Filter: BusinessPartnerName. Bound to CustomerId field.
- **Product Value Help:** Source entity I_Product or custom CDS. Display: ProductID, ProductDescription. Filter: ProductDescription. Bound to ProductId field.
- **Currency Value Help:** Source entity I_Currency. Display: Currency, CurrencyName. Bound to Currency field.

---

## 9. Authorization Concept

| Role | Create/Edit | Approve/Reject | View |
|------|------------|----------------|------|
| Sales Representative | Yes | No | Own orders only |
| Sales Manager | Yes | Yes | All orders in org unit |
| Administrator | Yes | Yes | All orders |

---

## 10. Non-Functional Requirements
- **Performance:** List Report must load within 2 seconds for up to 10,000 records with standard pagination.
- **Draft Consistency:** Draft locks must prevent concurrent editing by multiple users.
- **Extensibility:** The BO must support custom fields via released extension include structures.
- **Localization:** All UI labels must use text elements / data element descriptions for multi-language support.
- **Error Handling:** All validation messages must use the message class with appropriate severity (Error, Warning, Information).
- **Testing:** Unit test class must cover all validations, determinations, and actions with positive and negative test cases.

---

## 11. Appendix: Claude Code Generation Instructions

When feeding this FSD to Claude Code, use the following prompt structure to generate all artifacts in sequence:

1. Generate the database tables (ZSOMGMT_D_SO_HDR, ZSOMGMT_D_SO_ITM) with all fields as specified in Section 3.
2. Generate the Interface CDS View Entities (ZSOMGMT_I_SalesOrder, ZSOMGMT_I_SalesOrderItem) with proper associations and compositions.
3. Generate the Behavior Definition for ZSOMGMT_I_SalesOrder (managed, with draft) including all validations, determinations, and actions from Section 6.
4. Generate the Consumption CDS Projections (ZSOMGMT_C_SalesOrder, ZSOMGMT_C_SalesOrderItem) with value helps and search annotations.
5. Generate the Behavior Projection for ZSOMGMT_C_SalesOrder exposing all actions.
6. Generate the Metadata Extensions for both projections with all UI annotations from Section 7.
7. Generate the Behavior Implementation class ZBP_SOMGMT_I_SalesOrder with all validation, determination, and action methods.
8. Generate the Service Definition (ZSOMGMT_SD_SalesOrder) and Service Binding (ZSOMGMT_SB_SalesOrder_V4).

**Tip:** Use the `/cds-gen`, `/rap-action`, and `/fiori-ui` slash commands if SAP Skills plugins are installed for accelerated generation.
