set_global_assignment -entity "SerialFlashLoader" -library "lib_SerialFlashLoader" -name IP_TOOL_NAME "Qsys"
set_global_assignment -entity "SerialFlashLoader" -library "lib_SerialFlashLoader" -name IP_TOOL_VERSION "18.1"
set_global_assignment -entity "SerialFlashLoader" -library "lib_SerialFlashLoader" -name IP_TOOL_ENV "Qsys"
set_global_assignment -library "lib_SerialFlashLoader" -name SPD_FILE [file join $::quartus(sip_path) "../SerialFlashLoader.spd"]
set_global_assignment -library "lib_SerialFlashLoader" -name MISC_FILE [file join $::quartus(sip_path) "../../SerialFlashLoader.qsys"]

set_global_assignment -library "lib_SerialFlashLoader" -name MISC_FILE [file join $::quartus(sip_path) "SerialFlashLoader.vhd"]
set_global_assignment -library "lib_SerialFlashLoader" -name MISC_FILE [file join $::quartus(sip_path) "submodules/altera_serial_flash_loader.v"]
