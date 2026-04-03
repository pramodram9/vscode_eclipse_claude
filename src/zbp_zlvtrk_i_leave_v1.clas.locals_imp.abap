CLASS lhc_leave DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE Leave.

    METHODS set_initial_status FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Leave~setInitialStatus.

ENDCLASS.


CLASS lhc_leave IMPLEMENTATION.

  METHOD earlynumbering_create.
    "-- Read all existing keys from the active table
    SELECT leave_id
      FROM zlvtrk_d_leave_v1
      INTO TABLE @DATA(lt_existing).

    "-- Find the maximum numeric suffix using REDUCE (Rule 4 — never FILTER)
    DATA(lv_max_n) = REDUCE i(
      INIT n = 0
      FOR ls IN lt_existing
      LET s = CONV i( ls-leave_id+2(8) )
      NEXT n = COND i( WHEN s > n THEN s ELSE n )
    ).

    "-- Assign key to each new entity that has no LeaveId yet
    LOOP AT entities ASSIGNING FIELD-SYMBOL(<ls_entity>).
      IF <ls_entity>-%key-leaveid IS INITIAL.
        lv_max_n += 1.
        <ls_entity>-%key-leaveid =
          |LV{ lv_max_n WIDTH = 8 ALIGN = RIGHT PAD = '0' }|.
      ENDIF.

      INSERT VALUE #(
        %cid      = <ls_entity>-%cid
        %key      = <ls_entity>-%key
        %is_draft = <ls_entity>-%is_draft
      ) INTO TABLE mapped-leave.
    ENDLOOP.
  ENDMETHOD.


  METHOD set_initial_status.
    "-- Read current Status for all incoming keys
    READ ENTITIES OF zlvtrk_i_leave_v1 IN LOCAL MODE
      ENTITY Leave
        FIELDS ( status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_leave).

    "-- Set Status = 'N' (New) for any record where it is still initial
    MODIFY ENTITIES OF zlvtrk_i_leave_v1 IN LOCAL MODE
      ENTITY Leave
        UPDATE FIELDS ( status )
        WITH VALUE #(
          FOR ls IN lt_leave
          WHERE ( status IS INITIAL )
          ( %key   = ls-%key
            status = 'N' )
        ).
  ENDMETHOD.

ENDCLASS.
