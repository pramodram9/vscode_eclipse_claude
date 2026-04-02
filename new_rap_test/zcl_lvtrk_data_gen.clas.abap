CLASS zcl_lvtrk_data_gen DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    TYPES tt_leave TYPE TABLE OF zlvtrk_d_leave WITH EMPTY KEY.

    METHODS build_records
      RETURNING VALUE(rt_leave) TYPE tt_leave.

    METHODS write_summary
      IMPORTING
        io_out   TYPE REF TO if_oo_adt_classrun_out
        it_leave TYPE tt_leave.

ENDCLASS.


CLASS zcl_lvtrk_data_gen IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    DATA(lv_sep) = repeat( val = '─' occ = 72 ).

    out->write( lv_sep ).
    out->write( ' ZCL_LVTRK_DATA_GEN — Leave Tracker Sample Data Generator' ).
    out->write( lv_sep ).

    "── Step 1: Delete existing LV* records (makes class re-runnable) ────────
    DELETE FROM zlvtrk_d_leave
      WHERE leave_id BETWEEN @( 'LV0000001' ) AND @( 'LV0000008' ).
    DATA(lv_deleted) = sy-dbcnt.
    out->write( |  [1/3] DELETE → { lv_deleted } existing record(s) removed.| ).

    "── Step 2: Build the 8 sample rows ──────────────────────────────────────
    DATA(lt_leave) = build_records( ).
    out->write( |  [2/3] BUILD  → { lines( lt_leave ) } records prepared in memory.| ).

    "── Step 3: Insert all rows in a single bulk statement ───────────────────
    INSERT zlvtrk_d_leave FROM TABLE @lt_leave.
    IF sy-subrc <> 0.
      out->write( |  [3/3] INSERT → FAILED — sy-subrc = { sy-subrc }.| ).
      RETURN.
    ENDIF.
    out->write( |  [3/3] INSERT → { lines( lt_leave ) } record(s) committed to ZLVTRK_D_LEAVE.| ).

    "── Step 4: Print summary ─────────────────────────────────────────────────
    write_summary( io_out = out it_leave = lt_leave ).

  ENDMETHOD.


  METHOD build_records.

    DATA lv_ts   TYPE timestampl.
    DATA lv_user TYPE syuname.

    GET TIME STAMP FIELD lv_ts.
    lv_user = sy-uname.

    rt_leave = VALUE #(

      "── 1 ─ Annual / Approved ──────────────────────────────────────────────
      ( leave_id        = 'LV0000001'
        employee_name   = 'Alice Johnson'
        leave_type      = 'Annual'
        start_date      = '20250601'
        end_date        = '20250614'
        num_days        = 10
        reason          = 'Summer holiday booked 3 months in advance'
        status          = 'A'
        created_by      = lv_user   created_at      = lv_ts
        last_changed_by = lv_user   last_changed_at = lv_ts )

      "── 2 ─ Sick / Approved ────────────────────────────────────────────────
      ( leave_id        = 'LV0000002'
        employee_name   = 'Bob Martinez'
        leave_type      = 'Sick'
        start_date      = '20250715'
        end_date        = '20250718'
        num_days        = 4
        reason          = 'Flu recovery — doctor certificate provided'
        status          = 'A'
        created_by      = lv_user   created_at      = lv_ts
        last_changed_by = lv_user   last_changed_at = lv_ts )

      "── 3 ─ Personal / Rejected ────────────────────────────────────────────
      ( leave_id        = 'LV0000003'
        employee_name   = 'Carol White'
        leave_type      = 'Personal'
        start_date      = '20250901'
        end_date        = '20250903'
        num_days        = 3
        reason          = 'Wedding attendance — clashes with project go-live week'
        status          = 'R'
        created_by      = lv_user   created_at      = lv_ts
        last_changed_by = lv_user   last_changed_at = lv_ts )

      "── 4 ─ Annual / New ───────────────────────────────────────────────────
      ( leave_id        = 'LV0000004'
        employee_name   = 'David Lee'
        leave_type      = 'Annual'
        start_date      = '20251001'
        end_date        = '20251010'
        num_days        = 8
        reason          = 'Autumn break — pending manager approval'
        status          = 'N'
        created_by      = lv_user   created_at      = lv_ts
        last_changed_by = lv_user   last_changed_at = lv_ts )

      "── 5 ─ Other / New ────────────────────────────────────────────────────
      ( leave_id        = 'LV0000005'
        employee_name   = 'Emma Davis'
        leave_type      = 'Other'
        start_date      = '20251120'
        end_date        = '20251121'
        num_days        = 2
        reason          = 'Community volunteer programme — first-time request'
        status          = 'N'
        created_by      = lv_user   created_at      = lv_ts
        last_changed_by = lv_user   last_changed_at = lv_ts )

      "── 6 ─ Sick / Approved ────────────────────────────────────────────────
      ( leave_id        = 'LV0000006'
        employee_name   = 'Frank Wilson'
        leave_type      = 'Sick'
        start_date      = '20260105'
        end_date        = '20260107'
        num_days        = 3
        reason          = 'Post-surgery recovery — medical certificate attached'
        status          = 'A'
        created_by      = lv_user   created_at      = lv_ts
        last_changed_by = lv_user   last_changed_at = lv_ts )

      "── 7 ─ Annual / Rejected ──────────────────────────────────────────────
      ( leave_id        = 'LV0000007'
        employee_name   = 'Grace Taylor'
        leave_type      = 'Annual'
        start_date      = '20260301'
        end_date        = '20260314'
        num_days        = 10
        reason          = 'Extended travel — insufficient leave balance remaining'
        status          = 'R'
        created_by      = lv_user   created_at      = lv_ts
        last_changed_by = lv_user   last_changed_at = lv_ts )

      "── 8 ─ Personal / New ─────────────────────────────────────────────────
      ( leave_id        = 'LV0000008'
        employee_name   = 'Henry Brown'
        leave_type      = 'Personal'
        start_date      = '20260415'
        end_date        = '20260417'
        num_days        = 3
        reason          = 'Home renovation — newly submitted request'
        status          = 'N'
        created_by      = lv_user   created_at      = lv_ts
        last_changed_by = lv_user   last_changed_at = lv_ts )

    ).

  ENDMETHOD.


  METHOD write_summary.

    DATA(lv_sep)     = repeat( val = '─' occ = 72 ).
    DATA(lv_sep_hdr) = repeat( val = '═' occ = 72 ).

    io_out->write( `` ).
    io_out->write( lv_sep_hdr ).
    io_out->write( ' INSERTED RECORDS SUMMARY' ).
    io_out->write( lv_sep_hdr ).
    io_out->write( | { 'ID'          WIDTH = 10 } { 'EMPLOYEE'      WIDTH = 16 } { 'TYPE'     WIDTH = 10 } { 'START'    WIDTH = 10 } { 'END'      WIDTH = 10 } DAYS  STATUS    | ).
    io_out->write( lv_sep ).

    LOOP AT it_leave INTO DATA(ls).

      DATA(lv_status) = SWITCH string( ls-status
        WHEN 'A' THEN 'Approved'
        WHEN 'R' THEN 'Rejected'
        WHEN 'N' THEN 'New'
        ELSE ls-status ).

      DATA(lv_start) = |{ ls-start_date+0(4) }-{ ls-start_date+4(2) }-{ ls-start_date+6(2) }|.
      DATA(lv_end)   = |{ ls-end_date+0(4) }-{ ls-end_date+4(2) }-{ ls-end_date+6(2) }|.

      io_out->write( | { ls-leave_id WIDTH = 10 } { ls-employee_name WIDTH = 16 } { ls-leave_type WIDTH = 10 } { lv_start WIDTH = 10 } { lv_end WIDTH = 10 } { ls-num_days WIDTH = 4 }  { lv_status }| ).

    ENDLOOP.

    io_out->write( lv_sep ).

    "── Totals by status ──────────────────────────────────────────────────────
    DATA(lv_new)      = lines( FILTER #( it_leave WHERE status = 'N' ) ).
    DATA(lv_approved) = lines( FILTER #( it_leave WHERE status = 'A' ) ).
    DATA(lv_rejected) = lines( FILTER #( it_leave WHERE status = 'R' ) ).

    io_out->write( | STATUS TOTALS:  New: { lv_new }   Approved: { lv_approved }   Rejected: { lv_rejected }| ).

    "── Totals by leave type ──────────────────────────────────────────────────
    DATA(lv_annual)   = lines( FILTER #( it_leave WHERE leave_type = 'Annual'   ) ).
    DATA(lv_sick)     = lines( FILTER #( it_leave WHERE leave_type = 'Sick'     ) ).
    DATA(lv_personal) = lines( FILTER #( it_leave WHERE leave_type = 'Personal' ) ).
    DATA(lv_other)    = lines( FILTER #( it_leave WHERE leave_type = 'Other'    ) ).

    io_out->write( | TYPE  TOTALS:   Annual: { lv_annual }   Sick: { lv_sick }   Personal: { lv_personal }   Other: { lv_other }| ).
    io_out->write( lv_sep_hdr ).

  ENDMETHOD.

ENDCLASS.
