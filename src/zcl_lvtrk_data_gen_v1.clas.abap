CLASS zcl_lvtrk_data_gen_v1 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    "-- Builds the 8 test records
    METHODS build_records
      RETURNING VALUE(rt_records) TYPE TABLE OF zlvtrk_d_leave_v1.

    "-- Writes status summary to console
    METHODS write_summary
      IMPORTING
        io_out     TYPE REF TO if_oo_adt_classrun_out
        it_records TYPE TABLE OF zlvtrk_d_leave_v1.

ENDCLASS.


CLASS zcl_lvtrk_data_gen_v1 IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    DATA(lt_records) = build_records( ).

    "-- Delete existing test data range before re-inserting
    DELETE FROM zlvtrk_d_leave_v1
      WHERE leave_id BETWEEN 'LV00000001' AND 'LV00000008'.

    "-- Single bulk insert
    INSERT zlvtrk_d_leave_v1 FROM TABLE @lt_records.

    write_summary( io_out = out it_records = lt_records ).
  ENDMETHOD.


  METHOD build_records.
    DATA lv_ts TYPE timestampl.
    GET TIME STAMP FIELD lv_ts.

    "-- 8 rows covering all status values (N=3, A=3, R=2) and all categories
    "-- Key format: LV + 8 zero-padded digits → CHAR(10) e.g. LV00000001
    rt_records = VALUE #(
      (
        leave_id        = 'LV00000001'
        employee_name   = 'Alice Johnson'
        leave_type      = 'Annual'
        start_date      = '20260401'
        end_date        = '20260405'
        num_days        = 5
        reason          = 'Family vacation to the coast'
        status          = 'A'
        created_by      = sy-uname
        created_at      = lv_ts
        last_changed_by = sy-uname
        last_changed_at = lv_ts
      )
      (
        leave_id        = 'LV00000002'
        employee_name   = 'Bob Smith'
        leave_type      = 'Sick'
        start_date      = '20260402'
        end_date        = '20260402'
        num_days        = 1
        reason          = 'Not feeling well — fever'
        status          = 'N'
        created_by      = sy-uname
        created_at      = lv_ts
        last_changed_by = sy-uname
        last_changed_at = lv_ts
      )
      (
        leave_id        = 'LV00000003'
        employee_name   = 'Carol White'
        leave_type      = 'Personal'
        start_date      = '20260410'
        end_date        = '20260411'
        num_days        = 2
        reason          = 'Personal appointment'
        status          = 'R'
        created_by      = sy-uname
        created_at      = lv_ts
        last_changed_by = sy-uname
        last_changed_at = lv_ts
      )
      (
        leave_id        = 'LV00000004'
        employee_name   = 'David Brown'
        leave_type      = 'Annual'
        start_date      = '20260415'
        end_date        = '20260419'
        num_days        = 5
        reason          = 'Holiday trip abroad'
        status          = 'N'
        created_by      = sy-uname
        created_at      = lv_ts
        last_changed_by = sy-uname
        last_changed_at = lv_ts
      )
      (
        leave_id        = 'LV00000005'
        employee_name   = 'Eve Martinez'
        leave_type      = 'Other'
        start_date      = '20260420'
        end_date        = '20260420'
        num_days        = 1
        reason          = 'Moving house — removal day'
        status          = 'A'
        created_by      = sy-uname
        created_at      = lv_ts
        last_changed_by = sy-uname
        last_changed_at = lv_ts
      )
      (
        leave_id        = 'LV00000006'
        employee_name   = 'Frank Lee'
        leave_type      = 'Sick'
        start_date      = '20260403'
        end_date        = '20260404'
        num_days        = 2
        reason          = 'Flu symptoms — doctor advised rest'
        status          = 'R'
        created_by      = sy-uname
        created_at      = lv_ts
        last_changed_by = sy-uname
        last_changed_at = lv_ts
      )
      (
        leave_id        = 'LV00000007'
        employee_name   = 'Grace Kim'
        leave_type      = 'Annual'
        start_date      = '20260501'
        end_date        = '20260510'
        num_days        = 10
        reason          = 'Extended annual leave — planned in advance'
        status          = 'N'
        created_by      = sy-uname
        created_at      = lv_ts
        last_changed_by = sy-uname
        last_changed_at = lv_ts
      )
      (
        leave_id        = 'LV00000008'
        employee_name   = 'Henry Wilson'
        leave_type      = 'Personal'
        start_date      = '20260425'
        end_date        = '20260425'
        num_days        = 1
        reason          = 'Medical appointment — follow-up'
        status          = 'A'
        created_by      = sy-uname
        created_at      = lv_ts
        last_changed_by = sy-uname
        last_changed_at = lv_ts
      )
    ).
  ENDMETHOD.


  METHOD write_summary.
    io_out->write( |============================================| ).
    io_out->write( |  ZCL_LVTRK_DATA_GEN_V1 — Run Complete     | ).
    io_out->write( |============================================| ).
    io_out->write( |  Records inserted: { lines( it_records ) }| ).

    "-- REDUCE for counts per Rule 4 — never FILTER on standard table with empty key
    DATA(lv_count_n) = REDUCE i(
      INIT c = 0
      FOR ls IN it_records
      WHERE ( status = 'N' )
      NEXT c = c + 1
    ).
    DATA(lv_count_a) = REDUCE i(
      INIT c = 0
      FOR ls IN it_records
      WHERE ( status = 'A' )
      NEXT c = c + 1
    ).
    DATA(lv_count_r) = REDUCE i(
      INIT c = 0
      FOR ls IN it_records
      WHERE ( status = 'R' )
      NEXT c = c + 1
    ).

    io_out->write( |  Status breakdown:| ).
    io_out->write( |    N (New)      = { lv_count_n }| ).
    io_out->write( |    A (Approved) = { lv_count_a }| ).
    io_out->write( |    R (Rejected) = { lv_count_r }| ).
    io_out->write( |  Key range: LV00000001 — LV00000008| ).
    io_out->write( |  Active table: ZLVTRK_D_LEAVE_V1| ).
    io_out->write( |============================================| ).
  ENDMETHOD.

ENDCLASS.
