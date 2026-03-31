"! <p class="shorttext synchronized" lang="en">Original Commit Date – SD Item BAdI (Clean Core)</p>
"! Embedded Steampunk / Developer Extensibility implementation.
"!
"! Implements BAdI SD_SLS_ITEM_ADD_DATA to auto-populate the Key User
"! extension field YY1_COMMITDATE_SDI (Original Customer Commit Date)
"! on each sales order item from the latest GoodsIssueDate (WADAT) found
"! in the schedule lines of that item.
"!
"! Clean Core compliance:
"!   - No direct SELECT on VBEP/VBAK/VBAP — uses released CDS view only.
"!   - No classic user exits (MV45AFZZ), no append structures.
"!   - Fields defined via Key User Extensions (YY1_ prefix).
"!   - ABAP language scope: ABAP for Cloud (restricted).
"!
"! Prerequisite:
"!   Custom field YY1_COMMITDATE_SDI created in Custom Fields and Logic app
"!   (Business Context: Sales – Sales Document Item, Type: Date).
"!
"! BAdI setup (verify in ADT or SE18 on your system):
"!   Enhancement Spot : SD_SLS_ITEM_ADD_DATA_ES
"!   BAdI             : SD_SLS_ITEM_ADD_DATA
"!   Interface        : IF_SD_SLS_ITEM_ADD_DATA
CLASS zcl_commit_date_determination DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! BAdI interface – released for ABAP Cloud / Embedded Steampunk.
    "! Verify interface name in ADT before activating.
    INTERFACES if_sd_sls_item_add_data.

  PRIVATE SECTION.
    "! Queries the released CDS view I_SalesOrderScheduleLine and returns
    "! the latest GoodsIssueDate (WADAT) across all schedule lines for the
    "! given sales order item.
    "! @parameter iv_sales_order      | Sales document number (VBELN)
    "! @parameter iv_sales_order_item | Sales document item   (POSNR)
    "! @parameter rv_date             | Latest GoodsIssueDate, or initial if none
    CLASS-METHODS get_latest_goods_issue_date
      IMPORTING
        iv_sales_order      TYPE vbeln_va
        iv_sales_order_item TYPE posnr_va
      RETURNING
        VALUE(rv_date)      TYPE dats.

ENDCLASS.


CLASS zcl_commit_date_determination IMPLEMENTATION.

" ─────────────────────────────────────────────────────────────────────────────
  METHOD if_sd_sls_item_add_data~execute.
" ─────────────────────────────────────────────────────────────────────────────
" BAdI entry point – called by the framework during sales order processing
" (pre-save phase) for each changed sales order item.
"
" The framework provides access to item data via the BAdI context object
" (io_item / ct_item depending on the actual interface – verify in ADT).
" The pattern below uses a generic representation; adapt field/parameter
" names to the actual interface method signature in your system.
" ─────────────────────────────────────────────────────────────────────────────

    " Guard: only derive date when field is still initial (preserve 'original').
    " YY1_COMMITDATE_SDI is set once on first save and never overwritten.
    CHECK io_item->get_field( 'YY1_COMMITDATE_SDI' ) IS INITIAL.

    " Resolve the latest schedule line goods-issue date for this item.
    DATA(lv_commit_date) = get_latest_goods_issue_date(
        iv_sales_order      = io_item->get_field( 'VBELN' )
        iv_sales_order_item = io_item->get_field( 'POSNR' )
    ).

    " Write back to the extension field only when a date was found.
    IF lv_commit_date IS NOT INITIAL.
      io_item->set_field( name  = 'YY1_COMMITDATE_SDI'
                          value = lv_commit_date ).
    ENDIF.

  ENDMETHOD.


" ─────────────────────────────────────────────────────────────────────────────
  METHOD get_latest_goods_issue_date.
" ─────────────────────────────────────────────────────────────────────────────
" Reads schedule line data exclusively from the released CDS view
" I_SalesOrderScheduleLine — no direct SELECT on VBEP table.
"
" I_SalesOrderScheduleLine field mapping (verify in ADT CDS editor):
"   SalesOrder          → VBELN
"   SalesOrderItem      → POSNR
"   ScheduleLine        → ETENR
"   GoodsIssueDate      → WADAT  ← used here
"
" MAX aggregate ensures we always get the latest date when multiple
" schedule lines exist (e.g. partial delivery splits).
" ─────────────────────────────────────────────────────────────────────────────

    SELECT MAX( goodsissuedate )
      FROM i_salesorderscheduleline
      WHERE salesorder     = @iv_sales_order
        AND salesorderitem = @iv_sales_order_item
      INTO @rv_date.

  ENDMETHOD.

ENDCLASS.


*----------------------------------------------------------------------*
* BADI REGISTRATION (perform in ADT – Eclipse)                         *
*----------------------------------------------------------------------*
* 1. In ADT, right-click your ABAP Cloud package → New → Other ABAP   *
*    Repository Object → Enhancement Implementation.                   *
*                                                                       *
* 2. Enhancement Spot : SD_SLS_ITEM_ADD_DATA_ES                        *
*    BAdI             : SD_SLS_ITEM_ADD_DATA                           *
*    Implementation   : ZIMPL_COMMIT_DATE_DETERMINATION                *
*    Implementing Class: ZCL_COMMIT_DATE_DETERMINATION                 *
*                                                                       *
* 3. Activate and transport.                                            *
*----------------------------------------------------------------------*
* NOTE ON BADI INTERFACE                                               *
*----------------------------------------------------------------------*
* The BAdI interface name IF_SD_SLS_ITEM_ADD_DATA and its method       *
* signature (parameter io_item / ct_item) must be verified in your     *
* S/4 HANA 2022 system:                                                *
*   ADT → Repository → Open Development Object → IF_SD_SLS_ITEM_ADD_DATA  *
* If the interface uses a different get/set pattern, adapt the         *
* method body accordingly while keeping the static helper              *
* GET_LATEST_GOODS_ISSUE_DATE unchanged.                               *
*----------------------------------------------------------------------*
* CUSTOM FIELDS (Key User Extension – no ABAP required)               *
*----------------------------------------------------------------------*
* YY1_SFDC_ORDER_SDD  (Header):                                        *
*   Fiori → Custom Fields and Logic                                    *
*   Business Context : Sales – Sales Document                          *
*   Type : Text(10), Label: SFDC Order Number                          *
*   → Populated by SFDC-SAP interface via standard OData endpoint      *
*                                                                       *
* YY1_COMMITDATE_SDI  (Item):                                          *
*   Fiori → Custom Fields and Logic                                    *
*   Business Context : Sales – Sales Document Item                     *
*   Type : Date, Label: Original Customer Commit Date                  *
*   UI Property: Read-only (system-populated)                          *
*   → Populated by this class                                          *
*----------------------------------------------------------------------*
