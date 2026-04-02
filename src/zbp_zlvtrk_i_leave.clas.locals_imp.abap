*"* Local class implementations for ZBP_ZLVTRK_I_LEAVE
*"* (CCIMP include — all RAP handler classes live here)

"! ═══════════════════════════════════════════════════════════════════
"! LOCAL HANDLER CLASS — Leave Request
"! ═══════════════════════════════════════════════════════════════════
CLASS lhc_leave DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    "! ── Early Numbering ───────────────────────────────────────────
    "! Called by the RAP framework BEFORE the new entity enters the
    "! transactional buffer. This is the correct hook to assign a
    "! CHAR key — earlier than any determination, no MODIFY needed.
    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE Leave.

    "! ── Determinations ────────────────────────────────────────────
    METHODS set_initial_status FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Leave~setInitialStatus.

ENDCLASS.


CLASS lhc_leave IMPLEMENTATION.

" ─────────────────────────────────────────────────────────────────────
  METHOD earlynumbering_create.
" ─────────────────────────────────────────────────────────────────────
" RAP early-numbering method — called by the framework immediately
" when CREATE is triggered, before the entity enters the buffer.
"
" Contract: populate the implicit 'mapped-leave' table by mapping
" each incoming %cid to the assigned LeaveId. The framework uses
" this to build the entity identity in the transactional buffer.
" No MODIFY ENTITIES call is needed or allowed here.
"
" Key format:  LV + 8-digit zero-padded number
" Examples:    LV00000001, LV00000002, … LV00000099
"
" Sequence strategy:
"   1. Read MAX( leave_id ) from the active persist table.
"   2. Parse the numeric suffix (chars 3-10, offset 2 length 8).
"   3. Start at MAX + 1; increment per entity in this batch.
"
" Zero-Error Rule 2 compliance:
"   VALUE #( FOR ... WHERE ... ) used for filtering — never FILTER.

    "── Determine starting sequence number from the active table ─────
    SELECT SINGLE MAX( leave_id )
      FROM zlvtrk_d_leave
      INTO @DATA(lv_max_id).

    DATA(lv_next) = COND i(
      WHEN lv_max_id IS INITIAL THEN 1
      ELSE CONV i( lv_max_id+2(8) ) + 1 ).

    "── Assign a sequential ID to each entity in this CREATE batch ───
    LOOP AT entities INTO DATA(entity).

      "── Pass through any key the caller already pre-assigned ────────
      IF entity-LeaveId IS NOT INITIAL.
        APPEND VALUE #(
          %cid      = entity-%cid
          %is_draft = entity-%is_draft
          LeaveId   = entity-LeaveId
        ) TO mapped-leave.
        CONTINUE.
      ENDIF.

      "── Generate next ID and register it in the mapped table ────────
      APPEND VALUE #(
        %cid      = entity-%cid
        %is_draft = entity-%is_draft
        LeaveId   = |LV{ lv_next WIDTH = 8
                             ALIGN = RIGHT
                             PAD   = '0' }|
      ) TO mapped-leave.

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
