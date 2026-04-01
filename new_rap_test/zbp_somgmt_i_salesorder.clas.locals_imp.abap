*"* Local class implementations for ZBP_SOMGMT_I_SALESORDER
*"* (CCIMP include — all RAP handler classes live here)

"! ═══════════════════════════════════════════════════════════════════
"! LOCAL HANDLER CLASS — Sales Order Header
"! ═══════════════════════════════════════════════════════════════════
CLASS lhc_salesorder DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    "! ── Validations ───────────────────────────────────────────────
    METHODS validate_customer FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrder~validateCustomer.

    METHODS validate_dates FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrder~validateDates.

    METHODS validate_currency FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrder~validateCurrency.

    "! ── Determinations ────────────────────────────────────────────
    METHODS set_initial_status FOR DETERMINE ON MODIFY
      IMPORTING keys FOR SalesOrder~setInitialStatus.

    METHODS recalculate_header_amounts FOR DETERMINE ON MODIFY
      IMPORTING keys FOR SalesOrder~recalculateHeaderAmounts.

    "! ── Actions ────────────────────────────────────────────────────
    METHODS submit_for_approval FOR MODIFY
      IMPORTING keys FOR ACTION SalesOrder~submitForApproval RESULT result.

    METHODS approve_order FOR MODIFY
      IMPORTING keys FOR ACTION SalesOrder~approveOrder RESULT result.

    METHODS reject_order FOR MODIFY
      IMPORTING keys FOR ACTION SalesOrder~rejectOrder RESULT result.

ENDCLASS.

CLASS lhc_salesorder IMPLEMENTATION.

" ─────────────────────────────────────────────────────────────────────
  METHOD validate_customer.
" ─────────────────────────────────────────────────────────────────────
" V1: CustomerId must be provided and must exist in I_BusinessPartner.
    READ ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      FIELDS ( CustomerId )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_so).

    LOOP AT lt_so INTO DATA(ls_so).

      IF ls_so-CustomerId IS INITIAL.
        APPEND VALUE #( %tky = ls_so-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky              = ls_so-%tky
                        %msg              = new_message_with_text(
                                              severity = if_abap_behv_message=>severity-error
                                              text     = 'Customer ID is mandatory' )
                        %element-CustomerId = if_abap_behv=>mk-on )
          TO reported-salesorder.
        CONTINUE.
      ENDIF.

      " Check existence in Business Partner master (released CDS view)
      SELECT SINGLE BusinessPartner
        FROM i_businesspartner
        WHERE BusinessPartner = @ls_so-CustomerId
        INTO @DATA(lv_bp).

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = ls_so-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky              = ls_so-%tky
                        %msg              = new_message_with_text(
                                              severity = if_abap_behv_message=>severity-error
                                              text     = |Customer '{ ls_so-CustomerId }' does not exist| )
                        %element-CustomerId = if_abap_behv=>mk-on )
          TO reported-salesorder.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


" ─────────────────────────────────────────────────────────────────────
  METHOD validate_dates.
" ─────────────────────────────────────────────────────────────────────
" V2: DeliveryDate must be >= OrderDate.
    READ ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      FIELDS ( OrderDate DeliveryDate )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_so).

    LOOP AT lt_so INTO DATA(ls_so).

      IF ls_so-DeliveryDate IS INITIAL.
        APPEND VALUE #( %tky = ls_so-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky                 = ls_so-%tky
                        %msg                 = new_message_with_text(
                                                 severity = if_abap_behv_message=>severity-error
                                                 text     = 'Delivery Date is mandatory' )
                        %element-DeliveryDate = if_abap_behv=>mk-on )
          TO reported-salesorder.
        CONTINUE.
      ENDIF.

      IF ls_so-DeliveryDate < ls_so-OrderDate.
        APPEND VALUE #( %tky = ls_so-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky                 = ls_so-%tky
                        %msg                 = new_message_with_text(
                                                 severity = if_abap_behv_message=>severity-error
                                                 text     = 'Delivery Date must be on or after Order Date' )
                        %element-DeliveryDate = if_abap_behv=>mk-on )
          TO reported-salesorder.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


" ─────────────────────────────────────────────────────────────────────
  METHOD validate_currency.
" ─────────────────────────────────────────────────────────────────────
" V4: Currency must exist in the currency master (I_Currency).
    READ ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      FIELDS ( Currency )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_so).

    LOOP AT lt_so INTO DATA(ls_so).

      IF ls_so-Currency IS INITIAL.
        APPEND VALUE #( %tky = ls_so-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky             = ls_so-%tky
                        %msg             = new_message_with_text(
                                             severity = if_abap_behv_message=>severity-error
                                             text     = 'Currency is mandatory' )
                        %element-Currency = if_abap_behv=>mk-on )
          TO reported-salesorder.
        CONTINUE.
      ENDIF.

      SELECT SINGLE Currency
        FROM i_currency
        WHERE Currency = @ls_so-Currency
        INTO @DATA(lv_curr).

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = ls_so-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky             = ls_so-%tky
                        %msg             = new_message_with_text(
                                             severity = if_abap_behv_message=>severity-error
                                             text     = |Currency '{ ls_so-Currency }' is not valid| )
                        %element-Currency = if_abap_behv=>mk-on )
          TO reported-salesorder.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


" ─────────────────────────────────────────────────────────────────────
  METHOD set_initial_status.
" ─────────────────────────────────────────────────────────────────────
" On CREATE: set OverallStatus = 'N' (New) and seed OrderDate if empty.
    READ ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      FIELDS ( OverallStatus OrderDate )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_so).

    MODIFY ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      UPDATE FIELDS ( OverallStatus OrderDate )
      WITH VALUE #(
        FOR ls IN lt_so WHERE ( OverallStatus IS INITIAL )
        ( %tky         = ls-%tky
          OverallStatus = 'N'
          OrderDate     = COND #( WHEN ls-OrderDate IS INITIAL
                                  THEN cl_abap_context_info=>get_system_date( )
                                  ELSE ls-OrderDate ) ) )
      REPORTED DATA(ls_rep).

    reported = CORRESPONDING #( DEEP ls_rep ).

  ENDMETHOD.


" ─────────────────────────────────────────────────────────────────────
  METHOD recalculate_header_amounts.
" ─────────────────────────────────────────────────────────────────────
" On item delete: re-sum all remaining item NetAmounts for the header.
" On item create/update the calculation is triggered from the item
" determination calculateItemNetAmount which also updates the header.
    LOOP AT keys INTO DATA(ls_key).

      " Read all items for this sales order
      READ ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
        ENTITY SalesOrder BY \_Item
        FIELDS ( NetAmount )
        WITH VALUE #( ( %tky = ls_key-%tky ) )
        RESULT DATA(lt_items).

      DATA(lv_net)   = REDUCE decfloat16(
                         INIT s = CONV decfloat16( 0 )
                         FOR  i IN lt_items
                         NEXT s = s + i-NetAmount ).
      DATA(lv_tax)   = lv_net * gc_tax_rate.
      DATA(lv_gross) = lv_net + lv_tax.

      MODIFY ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
        ENTITY SalesOrder
        UPDATE FIELDS ( NetAmount TaxAmount GrossAmount )
        WITH VALUE #( ( %tky        = ls_key-%tky
                        NetAmount   = lv_net
                        TaxAmount   = lv_tax
                        GrossAmount = lv_gross ) )
        REPORTED DATA(ls_rep).

      reported = CORRESPONDING #( DEEP ls_rep ).

    ENDLOOP.

  ENDMETHOD.


" ─────────────────────────────────────────────────────────────────────
  METHOD submit_for_approval.
" ─────────────────────────────────────────────────────────────────────
" A3: Change OverallStatus from 'N' → 'P'.  Only valid when status = N.
    READ ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      FIELDS ( OverallStatus CustomerId DeliveryDate )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_so).

    LOOP AT lt_so INTO DATA(ls_so).

      IF ls_so-OverallStatus <> 'N'.
        APPEND VALUE #( %tky = ls_so-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky = ls_so-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Only orders with status New can be submitted for approval' ) )
          TO reported-salesorder.
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
        ENTITY SalesOrder
        UPDATE FIELDS ( OverallStatus )
        WITH VALUE #( ( %tky = ls_so-%tky  OverallStatus = 'P' ) )
        REPORTED DATA(ls_rep).

      reported = CORRESPONDING #( DEEP ls_rep ).

    ENDLOOP.

    " Read updated entities for action result
    READ ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls IN lt_result ( %tky = ls-%tky %param = ls ) ).

  ENDMETHOD.


" ─────────────────────────────────────────────────────────────────────
  METHOD approve_order.
" ─────────────────────────────────────────────────────────────────────
" A1: Change OverallStatus 'P' → 'A'.  Only valid when status = P.
    READ ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      FIELDS ( OverallStatus )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_so).

    LOOP AT lt_so INTO DATA(ls_so).

      IF ls_so-OverallStatus <> 'P'.
        APPEND VALUE #( %tky = ls_so-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky = ls_so-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Only orders with status In Process can be approved' ) )
          TO reported-salesorder.
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
        ENTITY SalesOrder
        UPDATE FIELDS ( OverallStatus )
        WITH VALUE #( ( %tky = ls_so-%tky  OverallStatus = 'A' ) )
        REPORTED DATA(ls_rep).

      reported = CORRESPONDING #( DEEP ls_rep ).

    ENDLOOP.

    READ ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls IN lt_result ( %tky = ls-%tky %param = ls ) ).

  ENDMETHOD.


" ─────────────────────────────────────────────────────────────────────
  METHOD reject_order.
" ─────────────────────────────────────────────────────────────────────
" A2: Change OverallStatus 'P' → 'X'.  Rejection reason from parameter.
    READ ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      FIELDS ( OverallStatus )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_so).

    LOOP AT lt_so INTO DATA(ls_so).

      " Locate action parameter for this key instance
      READ TABLE keys INTO DATA(ls_key) WITH KEY %tky = ls_so-%tky.
      DATA(lv_reason) = ls_key-%param-RejectionReason.

      IF ls_so-OverallStatus <> 'P'.
        APPEND VALUE #( %tky = ls_so-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky = ls_so-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Only orders with status In Process can be rejected' ) )
          TO reported-salesorder.
        CONTINUE.
      ENDIF.

      IF lv_reason IS INITIAL.
        APPEND VALUE #( %tky = ls_so-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky = ls_so-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Rejection reason is mandatory' ) )
          TO reported-salesorder.
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
        ENTITY SalesOrder
        UPDATE FIELDS ( OverallStatus Description )
        WITH VALUE #( ( %tky          = ls_so-%tky
                        OverallStatus = 'X'
                        Description   = |Rejected: { lv_reason }| ) )
        REPORTED DATA(ls_rep).

      reported = CORRESPONDING #( DEEP ls_rep ).

    ENDLOOP.

    READ ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
      ENTITY SalesOrder
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls IN lt_result ( %tky = ls-%tky %param = ls ) ).

  ENDMETHOD.

ENDCLASS.


"! ═══════════════════════════════════════════════════════════════════
"! LOCAL HANDLER CLASS — Sales Order Item
"! ═══════════════════════════════════════════════════════════════════
CLASS lhc_salesorderitem DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS calculate_item_net_amount FOR DETERMINE ON MODIFY
      IMPORTING keys FOR SalesOrderItem~calculateItemNetAmount.

    METHODS validate_quantity FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrderItem~validateQuantity.

    METHODS validate_item_product FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrderItem~validateItemProduct.

ENDCLASS.

CLASS lhc_salesorderitem IMPLEMENTATION.

" ─────────────────────────────────────────────────────────────────────
  METHOD calculate_item_net_amount.
" ─────────────────────────────────────────────────────────────────────
" D2: NetAmount = Quantity × UnitPrice per item.
" After updating item NetAmount, recalculate header totals.
    READ ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
      FIELDS ( SalesOrderId Quantity UnitPrice Currency )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    " Update item NetAmount
    MODIFY ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
      UPDATE FIELDS ( NetAmount )
      WITH VALUE #(
        FOR ls IN lt_items
        WHERE ( Quantity IS NOT INITIAL AND UnitPrice IS NOT INITIAL )
        ( %tky     = ls-%tky
          NetAmount = ls-Quantity * ls-UnitPrice ) )
      REPORTED DATA(ls_rep_item).

    reported = CORRESPONDING #( DEEP ls_rep_item ).

    " Re-read items (including newly set NetAmount) and roll up to header
    READ ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
      FIELDS ( SalesOrderId NetAmount )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_updated_items).

    " Collect unique parent orders to update
    DATA lt_so_keys TYPE TABLE OF STRUCTURE zsomgmt_i_salesorder WITH EMPTY KEY.
    lt_so_keys = VALUE #( FOR ls IN lt_updated_items
                          ( SalesOrderId = ls-SalesOrderId ) ).
    DELETE ADJACENT DUPLICATES FROM lt_so_keys COMPARING SalesOrderId.

    LOOP AT lt_so_keys INTO DATA(ls_parent).

      " Read ALL items for this parent (not just the changed ones)
      READ ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
        ENTITY SalesOrder
        FIELDS ( SalesOrderId )
        WITH VALUE #( ( SalesOrderId = ls_parent-SalesOrderId ) )
        RESULT DATA(lt_hdr).

      READ ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
        ENTITY SalesOrder BY \_Item
        FIELDS ( NetAmount )
        WITH CORRESPONDING #( lt_hdr )
        RESULT DATA(lt_all_items).

      DATA(lv_net)   = REDUCE decfloat16(
                         INIT s = CONV decfloat16( 0 )
                         FOR  i IN lt_all_items
                         NEXT s = s + i-NetAmount ).
      DATA(lv_tax)   = lv_net * gc_tax_rate.
      DATA(lv_gross) = lv_net + lv_tax.

      MODIFY ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
        ENTITY SalesOrder
        UPDATE FIELDS ( NetAmount TaxAmount GrossAmount )
        WITH VALUE #( FOR lh IN lt_hdr
                      ( %tky        = lh-%tky
                        NetAmount   = lv_net
                        TaxAmount   = lv_tax
                        GrossAmount = lv_gross ) )
        REPORTED DATA(ls_rep_hdr).

      reported = CORRESPONDING #( DEEP ls_rep_hdr ).

    ENDLOOP.

  ENDMETHOD.


" ─────────────────────────────────────────────────────────────────────
  METHOD validate_quantity.
" ─────────────────────────────────────────────────────────────────────
" V3: Quantity must be > 0.
    READ ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
      FIELDS ( Quantity )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    LOOP AT lt_items INTO DATA(ls_item).

      IF ls_item-Quantity <= 0.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-salesorderitem.
        APPEND VALUE #( %tky             = ls_item-%tky
                        %msg             = new_message_with_text(
                                             severity = if_abap_behv_message=>severity-error
                                             text     = 'Quantity must be greater than zero' )
                        %element-Quantity = if_abap_behv=>mk-on )
          TO reported-salesorderitem.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


" ─────────────────────────────────────────────────────────────────────
  METHOD validate_item_product.
" ─────────────────────────────────────────────────────────────────────
" V5: ProductId must be provided.
" Extend with I_Product lookup once product master CDS is available.
    READ ENTITIES OF zsomgmt_i_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
      FIELDS ( ProductId )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    LOOP AT lt_items INTO DATA(ls_item).

      IF ls_item-ProductId IS INITIAL.
        APPEND VALUE #( %tky = ls_item-%tky ) TO failed-salesorderitem.
        APPEND VALUE #( %tky              = ls_item-%tky
                        %msg              = new_message_with_text(
                                              severity = if_abap_behv_message=>severity-error
                                              text     = 'Product ID is mandatory' )
                        %element-ProductId = if_abap_behv=>mk-on )
          TO reported-salesorderitem.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
