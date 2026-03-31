CLASS zcl_price_reason_code DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! BADI implementation for SD_SLS_FIELDPROP_ITEM.
    "! Controls the read-only state of the custom field ZZ1_PRICEREASONCODE_SDI
    "! based on whether manual price condition ZP02 exists on the sales order item.
    INTERFACES if_sd_sls_fieldprop_item.

  PRIVATE SECTION.

    "! Internal structure to hold pricing condition data from VBAK / PRCD_ELEMENTS.
    TYPES:
      BEGIN OF ty_prcd,
        knumv TYPE knumv,   " Condition document number
        kposn TYPE kposn,   " Condition item (matches VBAP-POSNR)
        kschl TYPE kscha,   " Condition type (e.g. ZP02 = manual price)
      END OF ty_prcd,
      tt_prcd TYPE STANDARD TABLE OF ty_prcd WITH EMPTY KEY.

    "! Fetches pricing conditions for a sales document by joining VBAK and PRCD_ELEMENTS.
    "! @parameter iv_vbeln | Sales document number (VBELN)
    "! @parameter rt_prcd  | Internal table with KNUMV, KPOSN, KSCHL
    CLASS-METHODS table_select
      IMPORTING
        iv_vbeln       TYPE vbeln_va
      RETURNING
        VALUE(rt_prcd) TYPE tt_prcd.

ENDCLASS.


CLASS zcl_price_reason_code IMPLEMENTATION.

" ─────────────────────────────────────────────────────────────────────────────
  METHOD if_sd_sls_fieldprop_item~set_field_prop.
" ─────────────────────────────────────────────────────────────────────────────
" Purpose:
"   Evaluate whether the manual price condition type ZP02 exists on the
"   current sales order item.  If ZP02 is absent, set the custom field
"   ZZ1_PRICEREASONCODE_SDI to read-only so the user cannot enter a reason
"   code for non-manual-price items.
"
" Parameters (provided by BADI framework):
"   IS_SALESDOCUMENT     - importing structure; component SALESDOCUMENT = VBELN
"   IS_SALESDOCUMENTITEM - importing structure; component SALESDOCUMENTITEM = POSNR
"   CT_FIELD_PROPERTIES  - changing table of field property structures
"                          (components: FIELD_NAME, READ_ONLY, ...)
" ─────────────────────────────────────────────────────────────────────────────
    DATA: lt_prcd TYPE tt_prcd.

    FIELD-SYMBOLS: <fs_field_prop> LIKE LINE OF ct_field_properties.

    " Step 1 – Retrieve all pricing conditions for the sales document
    lt_prcd = table_select( is_salesdocument-salesdocument ).

    " Step 2 – Determine if ZP02 exists for the specific sales order item
    IF lt_prcd IS NOT INITIAL.

      " Look for manual price condition ZP02 on this item
      READ TABLE lt_prcd TRANSPORTING NO FIELDS
        WITH KEY kposn = is_salesdocumentitem-salesdocumentitem
                 kschl = 'ZP02'.

      IF sy-subrc <> 0.
        " ZP02 not found for this item: only standard condition types are present.
        " Set the Price Reason Code field to read-only.
        READ TABLE ct_field_properties ASSIGNING <fs_field_prop>
          WITH KEY field_name = 'ZZ1_PRICEREASONCODE_SDI'.
        IF sy-subrc = 0.
          <fs_field_prop>-read_only = abap_true.
        ENDIF.
      ENDIF.

    ELSE.

      " No pricing conditions at all for this document: field must be read-only.
      READ TABLE ct_field_properties ASSIGNING <fs_field_prop>
        WITH KEY field_name = 'ZZ1_PRICEREASONCODE_SDI'.
      IF sy-subrc = 0.
        <fs_field_prop>-read_only = abap_true.
      ENDIF.

    ENDIF.

  ENDMETHOD.


" ─────────────────────────────────────────────────────────────────────────────
  METHOD table_select.
" ─────────────────────────────────────────────────────────────────────────────
" Joins VBAK and PRCD_ELEMENTS to retrieve all pricing condition types for the
" given sales document.  Uses a LEFT OUTER JOIN so that a document with a
" condition document number but no detail lines is still returned (and the
" caller can detect the absence of ZP02 correctly).
"
" PRCD_ELEMENTS is the S/4 HANA successor to table KONV.
" ─────────────────────────────────────────────────────────────────────────────
    SELECT vbak~knumv,
           prcd_elements~kposn,
           prcd_elements~kschl
      INTO TABLE @rt_prcd
      FROM vbak
        LEFT OUTER JOIN prcd_elements
          ON vbak~knumv = prcd_elements~knumv
      WHERE vbak~vbeln = @iv_vbeln.

  ENDMETHOD.

ENDCLASS.


*----------------------------------------------------------------------*
* IMPLICIT ENHANCEMENT: ZEI_PRICE_REASON_CODE                         *
* Location : Include MV45AFZB, User Exit USEREXIT_CHECK_VBAP           *
* Transport: DS4K900129                                                 *
*----------------------------------------------------------------------*
* The code below is NOT part of the class above.  It is placed here    *
* as a reference for the implicit enhancement that must be created in  *
* Include MV45AFZB via the Enhancement Framework (SE80 / ENHANCE).     *
*                                                                       *
* Logic:                                                                *
*   If table XKOMV contains only standard condition types (i.e. ZP02   *
*   is not present in the current item), clear table XVBUV so that     *
*   the incompletion log is suppressed for standard-priced items.       *
*----------------------------------------------------------------------*
*
* ENHANCEMENT ZEI_PRICE_REASON_CODE.                                   *
*                                                                       *
*   DATA: lv_manual_price_found TYPE abap_bool VALUE abap_false.       *
*                                                                       *
*   LOOP AT xkomv WHERE kschl = 'ZP02'                                 *
*                   AND kposn = vbap-posnr.                            *
*     lv_manual_price_found = abap_true.                               *
*     EXIT.                                                             *
*   ENDLOOP.                                                            *
*                                                                       *
*   IF lv_manual_price_found = abap_false.                             *
*     DELETE xvbuv WHERE fieldname = 'ZZ1_PRICEREASONCODE_SDI'.        *
*   ENDIF.                                                              *
*                                                                       *
* ENDENHANCEMENT.                                                       *
