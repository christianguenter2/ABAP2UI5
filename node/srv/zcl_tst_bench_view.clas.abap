CLASS zcl_tst_bench_view DEFINITION PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_s_row,
        id       TYPE i,
        name     TYPE string,
        city     TYPE string,
        quantity TYPE i,
        note     TYPE string,
      END OF ty_s_row.
    TYPES ty_t_row TYPE STANDARD TABLE OF ty_s_row WITH DEFAULT KEY.

    DATA t_row    TYPE ty_t_row.
    DATA counter  TYPE i.
    DATA field_01 TYPE string.
    DATA field_02 TYPE string.
    DATA field_03 TYPE string.
    DATA field_04 TYPE string.
    DATA field_05 TYPE string.
    DATA field_06 TYPE string.
    DATA field_07 TYPE string.
    DATA field_08 TYPE string.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.
    METHODS view_display.
  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_tst_bench_view IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.

    " bench fixture for keeping an unchanged view (actions/Slots canKeep):
    " a view of a typical size (a form of eight inputs, a table of 50 rows
    " with inputs) and three events that change the same value - REDISPLAY
    " renders the view again with the same XML (kept), REBUILD destroys it
    " first (built anew - what every redisplay cost before), DATA only
    " changes the bound value.
    IF client->check_on_init( ).
      DO 50 TIMES.
        APPEND VALUE #( id       = sy-index
                        name     = |Name { sy-index }|
                        city     = |City { sy-index }|
                        quantity = sy-index * 3
                        note     = |Note { sy-index }| ) TO t_row.
      ENDDO.
      view_display( ).
      RETURN.
    ENDIF.

    counter = counter + 1.
    CASE client->get( )-event.
      WHEN `REDISPLAY`.
        view_display( ).
      WHEN `REBUILD`.
        client->view_destroy( ).
        view_display( ).
      WHEN `DATA`.
        " the roundtrip alone - the counter above is the change
        RETURN.
    ENDCASE.

  ENDMETHOD.


  METHOD view_display.
    DATA view TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA page TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA form TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA tab  TYPE REF TO z2ui5_cl_ui5_view_builder.
    DATA cells TYPE REF TO z2ui5_cl_ui5_view_builder.

    view = z2ui5_cl_ui5_view_builder=>factory( ).
    page = view->ele( n = `View` ns = `mvc`
        )->a( n = `xmlns`        v = `sap.m`
        )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
        )->a( n = `xmlns:f`      v = `sap.ui.layout.form`
        )->a( n = `displayBlock` v = `true`
        )->a( n = `height`       v = `100%`
        )->ele( `Shell`
            )->ele( `Page`
                )->a( n = `title` v = `BENCH VIEW` ).

    page->ele( `headerContent`
        )->tag( `Button`
            )->a( n = `id`    v = `btnRedisplay`
            )->a( n = `text`  v = `Redisplay`
            )->a( n = `press` v = client->_event( `REDISPLAY` )
        )->tag( `Button`
            )->a( n = `id`    v = `btnRebuild`
            )->a( n = `text`  v = `Rebuild`
            )->a( n = `press` v = client->_event( `REBUILD` )
        )->tag( `Button`
            )->a( n = `id`    v = `btnData`
            )->a( n = `text`  v = `Data`
            )->a( n = `press` v = client->_event( `DATA` ) ).

    page->tag( `Text`
        )->a( n = `id`   v = `txtCounter`
        )->a( n = `text` v = client->_bind( counter ) ).

    form = page->ele( n = `SimpleForm` ns = `f`
        )->a( n = `editable` v = `true`
        )->ele( n = `content` ns = `f` ).
    form->tag( `Label`
        )->a( n = `text` v = `Field 1`
        )->tag( `Input`
            )->a( n = `value` v = client->_bind( field_01 )
        )->tag( `Label`
            )->a( n = `text` v = `Field 2`
        )->tag( `Input`
            )->a( n = `value` v = client->_bind( field_02 )
        )->tag( `Label`
            )->a( n = `text` v = `Field 3`
        )->tag( `Input`
            )->a( n = `value` v = client->_bind( field_03 )
        )->tag( `Label`
            )->a( n = `text` v = `Field 4`
        )->tag( `Input`
            )->a( n = `value` v = client->_bind( field_04 )
        )->tag( `Label`
            )->a( n = `text` v = `Field 5`
        )->tag( `Input`
            )->a( n = `value` v = client->_bind( field_05 )
        )->tag( `Label`
            )->a( n = `text` v = `Field 6`
        )->tag( `Input`
            )->a( n = `value` v = client->_bind( field_06 )
        )->tag( `Label`
            )->a( n = `text` v = `Field 7`
        )->tag( `Input`
            )->a( n = `value` v = client->_bind( field_07 )
        )->tag( `Label`
            )->a( n = `text` v = `Field 8`
        )->tag( `Input`
            )->a( n = `value` v = client->_bind( field_08 ) ).

    tab = page->ele( `Table`
        )->a( n = `id`    v = `tabRows`
        )->a( n = `items` v = client->_bind( t_row ) ).
    tab->ele( `columns`
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Id`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Name`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `City`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Quantity`
        )->end(
        )->ele( `Column`
            )->tag( `Text`
                )->a( n = `text` v = `Note` ).
    cells = tab->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{ID}`
        )->tag( `Input`
            )->a( n = `value` v = `{NAME}`
        )->tag( `Input`
            )->a( n = `value` v = `{CITY}`
        )->tag( `Input`
            )->a( n = `value` v = `{QUANTITY}`
        )->tag( `Input`
            )->a( n = `value` v = `{NOTE}` ).

    client->view_display( view->stringify( ) ).
  ENDMETHOD.

ENDCLASS.
