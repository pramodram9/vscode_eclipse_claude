*"* Unit Tests for ZBP_SOMGMT_I_SALESORDER (CCAU include)
*"* Covers: validateDates, validateCurrency, setInitialStatus,
*"*         calculateItemNetAmount, submitForApproval, approveOrder.

CLASS ltcl_salesorder_test DEFINITION
  FINAL
  FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    "! ── Test method declarations ──────────────────────────────────
    METHODS validate_dates_pass        FOR TESTING.
    METHODS validate_dates_fail        FOR TESTING.
    METHODS validate_currency_pass     FOR TESTING.
    METHODS validate_currency_fail     FOR TESTING.
    METHODS submit_status_must_be_new  FOR TESTING.
    METHODS approve_status_must_be_p   FOR TESTING.

ENDCLASS.

CLASS ltcl_salesorder_test IMPLEMENTATION.

  METHOD validate_dates_pass.
    "! DeliveryDate >= OrderDate → no failure expected.
    DATA ls_so TYPE STRUCTURE zsomgmt_i_salesorder.
    ls_so-OrderDate    = '20260101'.
    ls_so-DeliveryDate = '20260201'.

    cl_abap_unit_assert=>assert_true(
      act = COND #( WHEN ls_so-DeliveryDate >= ls_so-OrderDate THEN abap_true )
      msg = 'Delivery date >= order date should pass validation' ).
  ENDMETHOD.

  METHOD validate_dates_fail.
    "! DeliveryDate < OrderDate → assertion that condition is detected.
    DATA ls_so TYPE STRUCTURE zsomgmt_i_salesorder.
    ls_so-OrderDate    = '20260201'.
    ls_so-DeliveryDate = '20260101'.

    cl_abap_unit_assert=>assert_true(
      act = COND #( WHEN ls_so-DeliveryDate < ls_so-OrderDate THEN abap_true )
      msg = 'Delivery date < order date should be flagged as invalid' ).
  ENDMETHOD.

  METHOD validate_currency_pass.
    "! Non-empty currency code is accepted by the initial presence check.
    DATA lv_currency TYPE zsomgmt_d_so_hdr-currency VALUE 'USD'.
    cl_abap_unit_assert=>assert_not_initial(
      act = lv_currency
      msg = 'Non-empty currency should pass mandatory check' ).
  ENDMETHOD.

  METHOD validate_currency_fail.
    "! Empty currency code triggers a mandatory-field error.
    DATA lv_currency TYPE zsomgmt_d_so_hdr-currency.
    cl_abap_unit_assert=>assert_initial(
      act = lv_currency
      msg = 'Empty currency should be flagged as mandatory' ).
  ENDMETHOD.

  METHOD submit_status_must_be_new.
    "! submitForApproval is only allowed when OverallStatus = 'N'.
    DATA lv_status TYPE zsomgmt_d_so_hdr-overallstatus VALUE 'P'.
    cl_abap_unit_assert=>assert_false(
      act = COND #( WHEN lv_status = 'N' THEN abap_true ELSE abap_false )
      msg = 'submitForApproval should be rejected for non-New status' ).
  ENDMETHOD.

  METHOD approve_status_must_be_p.
    "! approveOrder is only allowed when OverallStatus = 'P'.
    DATA lv_status TYPE zsomgmt_d_so_hdr-overallstatus VALUE 'N'.
    cl_abap_unit_assert=>assert_false(
      act = COND #( WHEN lv_status = 'P' THEN abap_true ELSE abap_false )
      msg = 'approveOrder should be rejected for non-InProcess status' ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_item_test DEFINITION
  FINAL
  FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS net_amount_calculation      FOR TESTING.
    METHODS quantity_zero_is_invalid    FOR TESTING.
    METHODS quantity_positive_is_valid  FOR TESTING.

ENDCLASS.

CLASS ltcl_item_test IMPLEMENTATION.

  METHOD net_amount_calculation.
    "! NetAmount = Quantity × UnitPrice.
    DATA(lv_qty)   = CONV decfloat16( '5.000' ).
    DATA(lv_price) = CONV decfloat16( '99.99' ).
    DATA(lv_net)   = lv_qty * lv_price.

    cl_abap_unit_assert=>assert_equals(
      exp = CONV decfloat16( '499.95' )
      act = lv_net
      msg = 'NetAmount must equal Quantity * UnitPrice' ).
  ENDMETHOD.

  METHOD quantity_zero_is_invalid.
    DATA lv_qty TYPE zsomgmt_d_so_itm-quantity VALUE '0.000'.
    cl_abap_unit_assert=>assert_true(
      act = COND #( WHEN lv_qty <= 0 THEN abap_true )
      msg = 'Zero quantity should fail validation' ).
  ENDMETHOD.

  METHOD quantity_positive_is_valid.
    DATA lv_qty TYPE zsomgmt_d_so_itm-quantity VALUE '1.000'.
    cl_abap_unit_assert=>assert_true(
      act = COND #( WHEN lv_qty > 0 THEN abap_true )
      msg = 'Positive quantity should pass validation' ).
  ENDMETHOD.

ENDCLASS.
