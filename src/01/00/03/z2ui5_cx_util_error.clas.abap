CLASS z2ui5_cx_util_error DEFINITION
  PUBLIC
  INHERITING FROM cx_no_check FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    DATA:
      BEGIN OF ms_error,
        x_root      TYPE REF TO cx_root,
        uuid        TYPE string,
        text        TYPE string,
        status_code TYPE i,
      END OF ms_error.

    METHODS constructor
      IMPORTING
        val         TYPE any            OPTIONAL
        status_code TYPE i              OPTIONAL
        !previous   TYPE REF TO cx_root OPTIONAL
          PREFERRED PARAMETER val.

    METHODS if_message~get_text REDEFINITION.

  PROTECTED SECTION.

  PRIVATE SECTION.
ENDCLASS.



CLASS z2ui5_cx_util_error IMPLEMENTATION.


  METHOD constructor ##ADT_SUPPRESS_GENERATION.

    super->constructor( previous = previous ).
    CLEAR textid.

    TRY.
        ms_error-x_root ?= val.
      CATCH cx_root.
        ms_error-text = val.
    ENDTRY.
    ms_error-uuid = z2ui5_cl_util=>uuid_get_c32( ).
    ms_error-status_code = status_code.

  ENDMETHOD.


  METHOD if_message~get_text.

    IF ms_error-x_root IS NOT INITIAL.
      result = ms_error-x_root->get_text( ).
      DATA(error) = abap_true.
    ELSEIF ms_error-text IS NOT INITIAL.
      result = ms_error-text.
      error = abap_true.
    ENDIF.

    result = COND #( WHEN error = abap_true AND result IS INITIAL THEN `unknown error` ELSE result ).

  ENDMETHOD.
ENDCLASS.
