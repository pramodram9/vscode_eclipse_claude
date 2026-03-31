CLASS zcl_mulesoft_integration_v1 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    " Structure matching the Mulesoft JSON response payload
    TYPES:
      BEGIN OF ty_mulesoft_response,
        field1 TYPE string,   " Maps to Purchase Order Number (PURCH_NO_C)
        field2 TYPE string,   " Maps to Customer Group       (CUST_GROUP)
        field3 TYPE string,   " Maps to Order Reason         (REASON_ORD)
      END OF ty_mulesoft_response.

    "! Fetches data from a Mulesoft REST API and updates the given Sales Order.
    "! @parameter iv_sales_order | 10-digit Sales Order number (VBELN)
    "! @parameter iv_api_url     | Full URL of the Mulesoft endpoint
    "! @parameter et_return      | BAPI return messages (E/A = error, S = success)
    METHODS fetch_and_update
      IMPORTING
        iv_sales_order TYPE vbeln
        iv_api_url     TYPE string
      EXPORTING
        et_return      TYPE bapiret2_t.

  PRIVATE SECTION.

    "! Performs the HTTP POST to Mulesoft and returns the raw JSON body.
    METHODS call_mulesoft_api
      IMPORTING
        iv_url         TYPE string
        iv_sales_order TYPE vbeln
      EXPORTING
        ev_json        TYPE string
        ev_success     TYPE abap_bool.

    "! Deserializes a flat JSON object into ty_mulesoft_response using /ui2/cl_json.
    METHODS deserialize_response
      IMPORTING
        iv_json            TYPE string
      RETURNING
        VALUE(rs_response) TYPE ty_mulesoft_response.

    "! Calls BAPI_SALESORDER_CHANGE with the three mapped fields.
    METHODS update_sales_order
      IMPORTING
        iv_sales_order TYPE vbeln
        is_response    TYPE ty_mulesoft_response
      EXPORTING
        et_return      TYPE bapiret2_t.

ENDCLASS.


CLASS zcl_mulesoft_integration_v1 IMPLEMENTATION.

" ─────────────────────────────────────────────────────────────────────────────
  METHOD fetch_and_update.
" ─────────────────────────────────────────────────────────────────────────────
    DATA: lv_json      TYPE string,
          lv_api_ok    TYPE abap_bool,
          ls_response  TYPE ty_mulesoft_response,
          lt_return    TYPE bapiret2_t,
          ls_err       TYPE bapiret2.

    " Step 1 – Call Mulesoft REST API
    call_mulesoft_api(
      EXPORTING
        iv_url         = iv_api_url
        iv_sales_order = iv_sales_order
      IMPORTING
        ev_json        = lv_json
        ev_success     = lv_api_ok
    ).

    IF lv_api_ok = abap_false.
      ls_err-type    = 'E'.
      ls_err-id      = 'ZMF'.
      ls_err-number  = '001'.
      ls_err-message = 'Mulesoft API call failed – check URL or connectivity'.
      APPEND ls_err TO et_return.
      RETURN.
    ENDIF.

    " Step 2 – Deserialize JSON → ABAP structure
    ls_response = deserialize_response( lv_json ).

    " Step 3 – Update Sales Order via BAPI
    update_sales_order(
      EXPORTING
        iv_sales_order = iv_sales_order
        is_response    = ls_response
      IMPORTING
        et_return      = lt_return
    ).

    et_return = lt_return.

  ENDMETHOD.


" ─────────────────────────────────────────────────────────────────────────────
  METHOD call_mulesoft_api.
" ─────────────────────────────────────────────────────────────────────────────
    DATA: lo_client      TYPE REF TO if_http_client,
          lv_status_code TYPE i,
          lv_reason      TYPE string,
          lv_request     TYPE string.

    ev_success = abap_false.

    " Build a minimal JSON request body containing the Sales Order key
    lv_request = |{"salesOrder":"{ iv_sales_order }"}|.

    " Create HTTP client for the given URL
    cl_http_client=>create_by_url(
      EXPORTING
        url                = iv_url
      IMPORTING
        client             = lo_client
      EXCEPTIONS
        argument_not_found = 1
        plugin_not_active  = 2
        internal_error     = 3
        OTHERS             = 4
    ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " Configure request: POST with JSON content
    lo_client->request->set_method( if_http_request=>co_request_method_post ).
    lo_client->request->set_header_field( name = 'Content-Type' value = 'application/json' ).
    lo_client->request->set_header_field( name = 'Accept'       value = 'application/json' ).
    lo_client->request->set_cdata( lv_request ).

    " Send
    lo_client->send(
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        OTHERS                     = 3
    ).
    IF sy-subrc <> 0.
      lo_client->close( ).
      RETURN.
    ENDIF.

    " Receive
    lo_client->receive(
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        OTHERS                     = 4
    ).
    IF sy-subrc <> 0.
      lo_client->close( ).
      RETURN.
    ENDIF.

    " Validate HTTP 200 OK
    lo_client->response->get_status(
      IMPORTING
        code   = lv_status_code
        reason = lv_reason
    ).
    IF lv_status_code <> 200.
      lo_client->close( ).
      RETURN.
    ENDIF.

    ev_json    = lo_client->response->get_cdata( ).
    ev_success = abap_true.
    lo_client->close( ).

  ENDMETHOD.


" ─────────────────────────────────────────────────────────────────────────────
  METHOD deserialize_response.
" ─────────────────────────────────────────────────────────────────────────────
    " /ui2/cl_json maps camelCase JSON keys ("field1"/"Field1") to ABAP
    " component names automatically via pretty_mode-camel_case.
    /ui2/cl_json=>deserialize(
      EXPORTING
        json        = iv_json
        pretty_name = /ui2/cl_json=>pretty_mode-camel_case
      CHANGING
        data        = rs_response
    ).
  ENDMETHOD.


" ─────────────────────────────────────────────────────────────────────────────
  METHOD update_sales_order.
" ─────────────────────────────────────────────────────────────────────────────
    DATA: ls_header     TYPE bapisdh1,
          ls_header_inx TYPE bapisdh1x,
          lt_return     TYPE bapiret2_t.

    " ── Map response fields to Sales Order header fields ─────────────────────
    "   Field1 → PURCH_NO_C  (Customer Purchase Order Number, max 35 chars)
    "   Field2 → CUST_GROUP  (Customer Group, 2 chars)
    "   Field3 → REASON_ORD  (Order Reason code, 3 chars)
    ls_header-purch_no_c = CONV bstnk_vf( is_response-field1 ).
    ls_header-cust_group = CONV kdgrp(    is_response-field2 ).
    ls_header-reason_ord = CONV augru(    is_response-field3 ).

    " ── Mark only the three changed fields (update flag = 'U') ───────────────
    ls_header_inx-updateflag  = 'U'.
    ls_header_inx-purch_no_c  = abap_true.
    ls_header_inx-cust_group  = abap_true.
    ls_header_inx-reason_ord  = abap_true.

    " ── Call BAPI ─────────────────────────────────────────────────────────────
    CALL FUNCTION 'BAPI_SALESORDER_CHANGE'
      EXPORTING
        salesdocument    = iv_sales_order
        order_header_in  = ls_header
        order_header_inx = ls_header_inx
      TABLES
        return           = lt_return.

    et_return = lt_return.

    " ── Commit only if no errors / aborts in the return table ─────────────────
    IF NOT line_exists( lt_return[ type = 'E' ] ) AND
       NOT line_exists( lt_return[ type = 'A' ] ).
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = abap_true.
    ELSE.
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
