*"* Local class implementations for ZBP_ZLVTRK_I_LEAVE
*"* (CCIMP include — all RAP handler classes live here)

"! ═══════════════════════════════════════════════════════════════════
"! LOCAL HANDLER CLASS — Leave Request
"! ═══════════════════════════════════════════════════════════════════
CLASS lhc_leave DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    "! ── Determinations ────────────────────────────────────────────
    METHODS set_leave_id       FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Leave~setLeaveId.

    METHODS set_initial_status FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Leave~setInitialStatus.

ENDCLASS.


CLASS lhc_leave IMPLEMENTATION.

" ─────────────────────────────────────────────────────────────────────
  METHOD set_leave_id.
" ─────────────────────────────────────────────────────────────────────
" Early-numbering determination: fires on CREATE (draft or active).
" Generates a sequential CHAR(10) key: LV + 8-digit zero-padded number.
" e.g. LV00000001, LV00000002, …
"
" This is what suppresses the Fiori 'New Object' popup: as long as
" LeaveId is populated before Fiori tries to compose the Object Page
" URL, the popup is bypassed automatically.
"
" Rule 2 compliance: VALUE #( FOR ... WHERE ... ) used instead of
" FILTER to avoid Key Requirement errors on standard tables.

    "── Read candidate records ──────────────────────────────────────
    READ ENTITIES OF zlvtrk_i_leave IN LOCAL MODE
      ENTITY leave
      FIELDS ( LeaveId )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_leave).

    "── Only process rows that still have no key assigned ───────────
    DATA(lt_need_id) = VALUE #(
      FOR ls IN lt_leave WHERE ( LeaveId IS INITIAL ) ( ls ) ).

    CHECK lt_need_id IS NOT INITIAL.

    "── Get highest existing ID to determine next sequence number ───
    SELECT SINGLE MAX( leave_id )
      FROM zlvtrk_d_leave
      INTO @DATA(lv_max_id).

    DATA(lv_next) = COND i(
      WHEN lv_max_id IS INITIAL THEN 1
      ELSE CONV i( lv_max_id+2(8) ) + 1 ).

    "── Assign sequential IDs — one per new draft ───────────────────
    LOOP AT lt_need_id INTO DATA(ls_leave).

      MODIFY ENTITIES OF zlvtrk_i_leave IN LOCAL MODE
        ENTITY leave
        UPDATE FIELDS ( LeaveId )
        WITH VALUE #( ( %tky    = ls_leave-%tky
                        LeaveId = |LV{ lv_next WIDTH = 8
                                          ALIGN = RIGHT
                                          PAD   = '0' }| ) )
        REPORTED DATA(lt_rep).

      reported = CORRESPONDING #( DEEP lt_rep ).
      lv_next += 1.

    ENDLOOP.

  ENDMETHOD.


" ─────────────────────────────────────────────────────────────────────
  METHOD set_initial_status.
" ─────────────────────────────────────────────────────────────────────
" Default-value determination: fires on CREATE.
" Sets Status = 'N' (New) for any record where Status is still blank.
" Ensures every leave request enters the workflow with a defined state.

    READ ENTITIES OF zlvtrk_i_leave IN LOCAL MODE
      ENTITY leave
      FIELDS ( Status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_leave).

    MODIFY ENTITIES OF zlvtrk_i_leave IN LOCAL MODE
      ENTITY leave
      UPDATE FIELDS ( Status )
      WITH VALUE #(
        FOR ls IN lt_leave WHERE ( Status IS INITIAL )
        ( %tky   = ls-%tky
          Status = 'N' ) )
      REPORTED DATA(lt_rep).

    reported = CORRESPONDING #( DEEP lt_rep ).

  ENDMETHOD.

ENDCLASS.
