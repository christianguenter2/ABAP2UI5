CLASS ltcl_test DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS first_test FOR TESTING RAISING cx_static_check.
ENDCLASS.

CLASS ltcl_test_buffer DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS test_evict_lru FOR TESTING.
    METHODS test_clear_resets_counter FOR TESTING.
ENDCLASS.

CLASS z2ui5_cl_core_app DEFINITION LOCAL FRIENDS ltcl_test.
CLASS z2ui5_cl_core_app DEFINITION LOCAL FRIENDS ltcl_test_buffer.

CLASS ltcl_test IMPLEMENTATION.
  METHOD first_test.

    DATA(lo_action) = NEW z2ui5_cl_core_app( ) ##NEEDED.

  ENDMETHOD.
ENDCLASS.


CLASS ltcl_test_db DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION LONG.

  PUBLIC SECTION.

    DATA mv_value TYPE string.

    INTERFACES z2ui5_if_app.

    METHODS constructor.

    METHODS test_db_save FOR TESTING.

  PROTECTED SECTION.

  PRIVATE SECTION.
ENDCLASS.


CLASS ltcl_test_db IMPLEMENTATION.
  METHOD constructor.

  ENDMETHOD.

  METHOD test_db_save.

    IF sy-sysid = `ABC`.
      RETURN.
    ENDIF.

    DATA(lo_app_user) = NEW ltcl_test_db( ).
    lo_app_user->mv_value = `my value`.

    DATA(lo_app) = NEW z2ui5_cl_core_app( ).
    lo_app->ms_draft-id = `TEST_ID`.
    lo_app->mo_app = lo_app_user.

    lo_app->db_save( ).

    DATA(lo_app_db) = z2ui5_cl_core_app=>db_load( `TEST_ID` ).
    DATA(lo_app_user_db) = CAST ltcl_test_db( lo_app_db->mo_app ).

    cl_abap_unit_assert=>assert_equals( exp = lo_app_user->mv_value
                                        act = lo_app_user_db->mv_value ).

  ENDMETHOD.

  METHOD z2ui5_if_app~main.

  ENDMETHOD.
ENDCLASS.


CLASS ltcl_test_buffer IMPLEMENTATION.

  METHOD test_evict_lru.

    z2ui5_cl_core_app=>db_load_buffer_clear( ).

    INSERT VALUE #( id = `A` app = NEW z2ui5_cl_core_app( ) last = 1 ) INTO TABLE z2ui5_cl_core_app=>mt_buffer.
    INSERT VALUE #( id = `B` app = NEW z2ui5_cl_core_app( ) last = 3 ) INTO TABLE z2ui5_cl_core_app=>mt_buffer.
    INSERT VALUE #( id = `C` app = NEW z2ui5_cl_core_app( ) last = 2 ) INTO TABLE z2ui5_cl_core_app=>mt_buffer.

    z2ui5_cl_core_app=>buffer_evict_lru( ).

    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( z2ui5_cl_core_app=>mt_buffer ) ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( z2ui5_cl_core_app=>mt_buffer[ id = `A` ] ) ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( z2ui5_cl_core_app=>mt_buffer[ id = `B` ] ) ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( z2ui5_cl_core_app=>mt_buffer[ id = `C` ] ) ) ).

  ENDMETHOD.

  METHOD test_clear_resets_counter.

    z2ui5_cl_core_app=>mv_lru_counter = 42.
    INSERT VALUE #( id = `X` app = NEW z2ui5_cl_core_app( ) last = 42 ) INTO TABLE z2ui5_cl_core_app=>mt_buffer.

    z2ui5_cl_core_app=>db_load_buffer_clear( ).

    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = z2ui5_cl_core_app=>mv_lru_counter ).
    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = lines( z2ui5_cl_core_app=>mt_buffer ) ).

  ENDMETHOD.

ENDCLASS.
