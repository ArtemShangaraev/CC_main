set_global_assignment -entity "xcvr_rst_ctrl" -library "lib_xcvr_rst_ctrl" -name IP_TOOL_NAME "altera_xcvr_reset_control"
set_global_assignment -entity "xcvr_rst_ctrl" -library "lib_xcvr_rst_ctrl" -name IP_TOOL_VERSION "18.1"
set_global_assignment -entity "xcvr_rst_ctrl" -library "lib_xcvr_rst_ctrl" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_xcvr_rst_ctrl" -name SPD_FILE [file join $::quartus(sip_path) "xcvr_rst_ctrl.spd"]

set_global_assignment -library "lib_xcvr_rst_ctrl" -name MISC_FILE [file join $::quartus(sip_path) "xcvr_rst_ctrl_sim/xcvr_rst_ctrl.vhd"]
set_global_assignment -library "lib_xcvr_rst_ctrl" -name MISC_FILE [file join $::quartus(sip_path) "xcvr_rst_ctrl_sim/altera_xcvr_reset_control/altera_xcvr_functions.sv"]
set_global_assignment -library "lib_xcvr_rst_ctrl" -name MISC_FILE [file join $::quartus(sip_path) "xcvr_rst_ctrl_sim/altera_xcvr_reset_control/mentor/altera_xcvr_functions.sv"]
set_global_assignment -library "lib_xcvr_rst_ctrl" -name MISC_FILE [file join $::quartus(sip_path) "xcvr_rst_ctrl_sim/altera_xcvr_reset_control/alt_xcvr_resync.sv"]
set_global_assignment -library "lib_xcvr_rst_ctrl" -name MISC_FILE [file join $::quartus(sip_path) "xcvr_rst_ctrl_sim/altera_xcvr_reset_control/mentor/alt_xcvr_resync.sv"]
set_global_assignment -library "lib_xcvr_rst_ctrl" -name MISC_FILE [file join $::quartus(sip_path) "xcvr_rst_ctrl_sim/altera_xcvr_reset_control/altera_xcvr_reset_control.sv"]
set_global_assignment -library "lib_xcvr_rst_ctrl" -name MISC_FILE [file join $::quartus(sip_path) "xcvr_rst_ctrl_sim/altera_xcvr_reset_control/alt_xcvr_reset_counter.sv"]
set_global_assignment -library "lib_xcvr_rst_ctrl" -name MISC_FILE [file join $::quartus(sip_path) "xcvr_rst_ctrl_sim/altera_xcvr_reset_control/mentor/altera_xcvr_reset_control.sv"]
set_global_assignment -library "lib_xcvr_rst_ctrl" -name MISC_FILE [file join $::quartus(sip_path) "xcvr_rst_ctrl_sim/altera_xcvr_reset_control/mentor/alt_xcvr_reset_counter.sv"]
set_global_assignment -library "lib_xcvr_rst_ctrl" -name MISC_FILE [file join $::quartus(sip_path) "xcvr_rst_ctrl_sim/altera_xcvr_reset_control/plain_files.txt"]
set_global_assignment -library "lib_xcvr_rst_ctrl" -name MISC_FILE [file join $::quartus(sip_path) "xcvr_rst_ctrl_sim/altera_xcvr_reset_control/mentor_files.txt"]
set_global_assignment -library "lib_xcvr_rst_ctrl" -name MISC_FILE [file join $::quartus(sip_path) "xcvr_rst_ctrl_sim/altera_xcvr_reset_control/cadence_files.txt"]
set_global_assignment -library "lib_xcvr_rst_ctrl" -name MISC_FILE [file join $::quartus(sip_path) "xcvr_rst_ctrl_sim/altera_xcvr_reset_control/synopsys_files.txt"]
set_global_assignment -library "lib_xcvr_rst_ctrl" -name MISC_FILE [file join $::quartus(sip_path) "xcvr_rst_ctrl_sim/altera_xcvr_reset_control/aldec_files.txt"]
