"! <p class="shorttext synchronized">ABAP-PRC Demo: Initialize common master data</p>
"!
"! Classrun: deletes and recreates the master data all demo scenarios use -
"! business partners, equipment categories, materials, 10,000 equipments and
"! 20 service contracts with 9 items each. Items 1-8 carry equipments 1-160;
"! item 9 of every contract stays free for scenario Local RAP Event, which
"! assigns new equipments to the first free item of an open or in-process contract.
CLASS zcl_prc_demo_common_init DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_prc_demo_common_init IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    TRY.
        DELETE FROM zprc_demo_bupa.
        DELETE FROM zprc_demo_equi.
        DELETE FROM zprc_demo_eq_cat.
        DELETE FROM zprc_demo_mat.
        DELETE FROM zprc_demo_srvctr.
        DELETE FROM zprc_demo_sc_itm.

        DATA lt_bupa_data TYPE STANDARD TABLE OF zprc_demo_bupa WITH DEFAULT KEY.

        lt_bupa_data = VALUE #( ( id = '1000000001' description = 'Northern Peak Machinery Ltd.' )
                                ( id = '1000000002' description = 'Blueforge Industrial Systems Inc.' )
                                ( id = '1000000003' description = 'Ironbridge Manufacturing Group' )
                                ( id = '1000000004' description = 'Precision Dynamics Engineering Ltd.' )
                                ( id = '1000000005' description = 'Titancore Manufacturing Inc.' )
                                ( id = '1000000006' description = 'Greenfield Industrial Solutions Ltd.' )
                                ( id = '1000000007' description = 'Atlas Heavy Equipment Corp.' )
                                ( id = '1000000008' description = 'Silverline Production Systems Ltd.' )
                                ( id = '1000000009' description = 'Redrock Mechanical Industries Inc.' )
                                ( id = '1000000010' description = 'Primesteel Fabrication Ltd.' )
                                ( id = '1000000011' description = 'Nextgen Machinery Solutions Inc.' )
                                ( id = '1000000012' description = 'Vertex Industrial Manufacturing Ltd.' )
                                ( id = '1000000013' description = 'Summit Precision Engineering Corp.' )
                                ( id = '1000000014' description = 'Ironwave Industrial Technologies Ltd.' )
                                ( id = '1000000015' description = 'Coreaxis Manufacturing Group' ) ).
        INSERT zprc_demo_bupa FROM TABLE @lt_bupa_data.

        DATA lt_eq_category TYPE STANDARD TABLE OF zprc_demo_eq_cat WITH DEFAULT KEY.
        lt_eq_category = VALUE #( ( id = 'EQC0000001' description = 'Conveyor System' )
                                  ( id = 'EQC0000002' description = 'Shuttle System' )
                                  ( id = 'EQC0000003' description = 'Warehouse Robot' ) ).
        INSERT zprc_demo_eq_cat FROM TABLE @lt_eq_category.

        DATA lt_materials TYPE STANDARD TABLE OF zprc_demo_mat WITH DEFAULT KEY.
        lt_materials = VALUE #( " --- for all equipment categories ---
                                ( id = 'MAT0000001' description = 'Maintenance Service' )
                                ( id = 'MAT0000002' description = 'Repair Service' )

                                " --- category specific ---
                                ( id = 'MAT0000003' description = 'Conveyor Belt Adjustment' )
                                ( id = 'MAT0000004' description = 'Shuttle Calibration' )
                                ( id = 'MAT0000005' description = 'Robot Software Update' ) ).
        INSERT zprc_demo_mat FROM TABLE @lt_materials.

        DATA lt_equipments TYPE STANDARD TABLE OF zprc_demo_equi WITH DEFAULT KEY.

        DO 10000 TIMES.
          DATA(idx) = sy-index.
          DATA(lv_category) = idx MOD 3 + 1.

          APPEND VALUE #( id                    = |{ idx WIDTH = 10 ALIGN = RIGHT PAD = '0' }|
                          equipment_category_id = |EQC000000{ lv_category }| )
                 TO lt_equipments.
        ENDDO.

        INSERT zprc_demo_equi FROM TABLE @lt_equipments.

        DATA lt_service_contracts TYPE STANDARD TABLE OF zprc_demo_srvctr WITH DEFAULT KEY.
        DATA lt_srv_ctr_item      TYPE STANDARD TABLE OF zprc_demo_sc_itm WITH DEFAULT KEY.
        DATA(lv_equipment_id) = 0.

        DO 20 TIMES.
          idx = sy-index.

          DATA(lv_srv_ctr_uuid) = cl_system_uuid=>create_uuid_x16_static( ).

          CASE idx MOD 4.
            WHEN 0.
              DATA(lv_lifecycle_status) = 'A'.
            WHEN 1.
              lv_lifecycle_status = 'B'.
            WHEN 2.
              lv_lifecycle_status = 'C'.
            WHEN 3.
              lv_lifecycle_status = 'D'.
          ENDCASE.

          CASE idx MOD 12.
            WHEN 0.
              DATA(lv_error_status) = 'E'.
            WHEN 1.
              lv_error_status = 'N'.
          ENDCASE.

          APPEND VALUE #( uuid                = lv_srv_ctr_uuid
                          service_contract_id = |3{ idx WIDTH = 9 ALIGN = RIGHT PAD = '0' }|
                          error_status        = lv_error_status
                          description         = |Test Contract { idx }|
                          sold_to_party_id    = |100000000{ idx MOD 10 + 1 } |
                          ship_to_party_id    = |100000000{ idx MOD 10 + 1 } |
                          lifecycle_status    = lv_lifecycle_status )
                 TO lt_service_contracts.

          DO 9 TIMES.
            DATA(idx_item) = sy-index.
            " The last item stays free: scenario Local RAP Event assigns new equipments there
            DATA(lv_item_equipment) = ``.
            IF idx_item < 9.
              lv_equipment_id += 1.
              lv_item_equipment = |{ lv_equipment_id WIDTH = 10 ALIGN = RIGHT PAD = '0' }|.
            ENDIF.
            APPEND VALUE #( uuid             = cl_system_uuid=>create_uuid_x16_static( )
                            parent_uuid      = lv_srv_ctr_uuid
                            item_number      = |000{ idx_item }00|
                            product_id       = |MAT000000{ idx_item MOD 5 + 1 }|
                            quantity         = 1
                            quantity_uom     = 'Stk'
                            currency         = 'EUR'
                            net_price        = idx_item * idx
                            discount_percent = 0
                            equipment_id     = lv_item_equipment )
                   TO lt_srv_ctr_item.
          ENDDO.
        ENDDO.

        INSERT zprc_demo_srvctr FROM TABLE @lt_service_contracts.
        INSERT zprc_demo_sc_itm FROM TABLE @lt_srv_ctr_item.

        COMMIT WORK.

        out->write( 'Demo data initialized' ).
      CATCH cx_uuid_error INTO DATA(lx_uuid_error).
        out->write( |Error generating UUID: { lx_uuid_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
