CLASS z2ui5_cl_core_app DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_serializable_object.

    DATA mt_attri TYPE REF TO z2ui5_if_core_types=>ty_t_attri.
    DATA mo_app   TYPE REF TO object.
    DATA ms_draft TYPE z2ui5_if_types=>ty_s_get-s_draft.

    METHODS model_json_stringify
      RETURNING
        VALUE(result) TYPE string.

    METHODS model_json_parse
      IMPORTING
        iv_view  TYPE clike
        io_model TYPE REF TO z2ui5_if_ajson.

    METHODS all_xml_stringify
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS all_xml_parse
      IMPORTING
        !xml          TYPE clike
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_core_app.

    TYPES:
      BEGIN OF ty_s_buffer,
        id   TYPE string,
        app  TYPE REF TO z2ui5_cl_core_app,
        last TYPE i,
      END OF ty_s_buffer.

    CONSTANTS c_max_buffer_size TYPE i VALUE 100.
    CLASS-DATA mt_buffer TYPE SORTED TABLE OF ty_s_buffer WITH UNIQUE KEY id.
    CLASS-DATA mv_lru_counter TYPE i.

    CLASS-METHODS db_load
      IMPORTING
        !id           TYPE clike
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_core_app.

    CLASS-METHODS db_load_by_app
      IMPORTING
        app           TYPE REF TO z2ui5_if_app
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_core_app.

    CLASS-METHODS db_load_buffer_clear.

    METHODS constructor.
    METHODS db_save.

  PROTECTED SECTION.

  PRIVATE SECTION.
    CLASS-METHODS buffer_evict_lru.
    METHODS create_model
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_core_srv_model.
ENDCLASS.


CLASS z2ui5_cl_core_app IMPLEMENTATION.

  METHOD all_xml_parse.

    z2ui5_cl_util=>xml_parse( EXPORTING xml = xml
                              IMPORTING any = result ).

  ENDMETHOD.

  METHOD all_xml_stringify.

    DATA(lo_model) = create_model( ).

    TRY.
        result = z2ui5_cl_util=>xml_stringify( me ).
        RETURN.
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

    TRY.
        lo_model->main_attri_db_save_srtti( ).
        result = z2ui5_cl_util=>xml_stringify( me ).
        lo_model->main_attri_db_load( ).
        RETURN.
      CATCH cx_root INTO DATA(x) ##NO_HANDLER.
    ENDTRY.

    TRY.
        lo_model->main_attri_refresh( ).
        lo_model->main_attri_db_save_srtti( ).
        result = z2ui5_cl_util=>xml_stringify( me ).
        lo_model->main_attri_db_load( ).
        RETURN.
      CATCH cx_root INTO x ##NO_HANDLER.
    ENDTRY.

    RAISE EXCEPTION TYPE z2ui5_cx_util_error
      EXPORTING
        val = |<p>{ x->get_text( ) } or <p> Please check if all generic data references are public attributes of your class|.

  ENDMETHOD.

  METHOD constructor.

    CREATE DATA mt_attri.

  ENDMETHOD.

  METHOD db_load.

    DATA lv_id TYPE string.
    lv_id = id.

    IF line_exists( mt_buffer[ id = lv_id ] ).
      ASSIGN mt_buffer[ id = lv_id ] TO FIELD-SYMBOL(<ls_buffer>).
      mv_lru_counter = mv_lru_counter + 1.
      <ls_buffer>-last = mv_lru_counter.
      result = <ls_buffer>-app.
      RETURN.
    ENDIF.

    DATA(lo_db) = NEW z2ui5_cl_core_srv_draft( ).
    DATA(ls_db) = lo_db->read_draft( id ).
    result = all_xml_parse( ls_db-data ).

    result->create_model( )->main_attri_db_load( ).

    IF lines( mt_buffer ) >= c_max_buffer_size.
      buffer_evict_lru( ).
    ENDIF.

    mv_lru_counter = mv_lru_counter + 1.
    INSERT VALUE #( id = lv_id app = result last = mv_lru_counter ) INTO TABLE mt_buffer.

  ENDMETHOD.

  METHOD db_load_buffer_clear.

    CLEAR mt_buffer.
    CLEAR mv_lru_counter.

  ENDMETHOD.

  METHOD db_load_by_app.

    DATA(lo_db) = NEW z2ui5_cl_core_srv_draft( ).
    DATA(ls_db) = lo_db->read_draft( app->id_draft ).
    result = all_xml_parse( ls_db-data ).

    result->mo_app = app.
    result->create_model( )->main_attri_db_load( ).

  ENDMETHOD.

  METHOD db_save.

    IF mo_app IS BOUND.
      DATA(li_app) = CAST z2ui5_if_app( mo_app ).
      li_app->id_draft = ms_draft-id.
      li_app->check_initialized = abap_true.
    ENDIF.

    DATA(lo_db) = NEW z2ui5_cl_core_srv_draft( ).
    lo_db->create( draft     = ms_draft
                   model_xml = all_xml_stringify( ) ).

  ENDMETHOD.

  METHOD model_json_parse.

    create_model( )->main_json_to_attri(
        view  = iv_view
        model = io_model ).

  ENDMETHOD.

  METHOD model_json_stringify.

    result = create_model( )->main_json_stringify( ).

  ENDMETHOD.

  METHOD buffer_evict_lru.

    DATA lv_lru_id TYPE string.
    DATA lv_min_last TYPE i.

    LOOP AT mt_buffer ASSIGNING FIELD-SYMBOL(<ls_buf>).
      IF lv_lru_id IS INITIAL OR <ls_buf>-last < lv_min_last.
        lv_min_last = <ls_buf>-last.
        lv_lru_id   = <ls_buf>-id.
      ENDIF.
    ENDLOOP.

    DELETE mt_buffer WHERE id = lv_lru_id.

  ENDMETHOD.

  METHOD create_model.

    result = NEW z2ui5_cl_core_srv_model( attri = mt_attri
                                          app   = mo_app ).

  ENDMETHOD.
ENDCLASS.
