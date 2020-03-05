## Timing constraints for the CPV Column Controller
## Both Gassiplex and Dilogic are working at 10 MHz
## Author:      Artem Shangaraev <artem.shangaraev@cern.ch>
## Last update: 2020-03-04
## Notes:
## False path from CLK50 to ...txpmalocal clock is not 
## completely correst. It should be from "reset" to this clock,
## but I didn't find proper reset cell/port.

##
## DEVICE  "5CGXFC5C6F27C7"
##

#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3

#**************************************************************
# Create Clock
#**************************************************************

create_clock -name CLK50 -period 20.00 -waveform { 0.00 10.00 } [get_ports PLL_50MHZ_CLK]
create_clock -name CLK_REF -period 6.40 -waveform { 0.00 3.20 } [get_ports REF_156MHZ[0]]
create_clock -name CLK200 -period 5.00 -waveform { 0.00 2.50 } [get_ports clk_rx_in]

#**************************************************************
# Create Generated Clock
#**************************************************************

derive_pll_clocks -use_net_name
derive_clock_uncertainty
create_generated_clock -name CLK10 -source {clock_generator:INST_CLK_RST|main_PLL:INST_MAIN_PLL|main_PLL_0002:main_pll_inst|altera_pll:altera_pll_i|outclk_wire[0]~CLKENA0}

#**************************************************************
# Set Clock Latency
#**************************************************************

#**************************************************************
# Set Clock Uncertainty
#**************************************************************

set_clock_uncertainty -from [get_clocks {altera_reserved_tck}] -to [get_clocks {altera_reserved_tck}] 0.270 

#**************************************************************
# Set Input Delay
#**************************************************************

set_input_delay -add_delay -clock [get_clocks CLK10] -max 2.5 [get_ports {ENOUT_N[*]}]
set_input_delay -add_delay -clock [get_clocks CLK10] -min 0.0 [get_ports {ENOUT_N[*]}]

set_input_delay -add_delay -clock [get_clocks CLK200] -min 0.0 [get_ports {lvds_rx_in[0]}]
set_input_delay -add_delay -clock [get_clocks CLK200] -max 1.0 [get_ports {lvds_rx_in[0]}]

set_input_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {DATA_BUS_D1[*]}]
set_input_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {DATA_BUS_D1[*]}]
set_input_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {DATA_BUS_D2[*]}]
set_input_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {DATA_BUS_D2[*]}]
set_input_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {DATA_BUS_D3[*]}]
set_input_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {DATA_BUS_D3[*]}]
set_input_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {DATA_BUS_D4[*]}]
set_input_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {DATA_BUS_D4[*]}]

set_input_delay -add_delay -clock {altera_reserved_tck} -max  0.5 [get_ports {altera_reserved_tdi}]
set_input_delay -add_delay -clock {altera_reserved_tck} -min -0.5 [get_ports {altera_reserved_tdi}]
set_input_delay -add_delay -clock {altera_reserved_tck} -max  0.5 [get_ports {altera_reserved_tms}]
set_input_delay -add_delay -clock {altera_reserved_tck} -min -0.5 [get_ports {altera_reserved_tms}]

#**************************************************************
# Set Output Delay
#**************************************************************

set_output_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {ENIN_N[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {ENIN_N[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {STRIN[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {STRIN[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {TRG_N[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {TRG_N[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {DIL_CLR[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {DIL_CLR[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {DIL_RST[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {DIL_RST[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {CLK_ADC_N[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {CLK_ADC_N[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {CLKD_N[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {CLKD_N[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {SUB_COMP[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {SUB_COMP[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {FCODE_C1[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {FCODE_C1[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {FCODE_C2[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {FCODE_C2[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {CH_ADDR_D1_N[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {CH_ADDR_D1_N[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {CH_ADDR_D2_N[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {CH_ADDR_D2_N[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {CH_ADDR_D3_N[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {CH_ADDR_D3_N[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {CH_ADDR_D4_N[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {CH_ADDR_D4_N[*]}]

set_output_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {CLK_G[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {CLK_G[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {CLR_G[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {CLR_G[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -max  0.5 [get_ports {T_H[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {T_H[*]}]

set_output_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {DATA_BUS_D1[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {DATA_BUS_D1[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {DATA_BUS_D2[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {DATA_BUS_D2[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {DATA_BUS_D3[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {DATA_BUS_D3[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {DATA_BUS_D4[*]}]
set_output_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {DATA_BUS_D4[*]}]

set_output_delay -add_delay -clock [get_clocks CLK10] -max  2.5 [get_ports {TEST_PIN}]
set_output_delay -add_delay -clock [get_clocks CLK10] -min -2.5 [get_ports {TEST_PIN}]

set_output_delay -add_delay -clock {altera_reserved_tck} -max  0.5 [get_ports {altera_reserved_tdo}]
set_output_delay -add_delay -clock {altera_reserved_tck} -min -0.5 [get_ports {altera_reserved_tdo}]

#**************************************************************
# Set Clock Groups
#**************************************************************

set_clock_groups -exclusive -group [get_clocks {alt_cal_av_edge_detect_clk}] 
set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}] 

set_clock_groups -asynchronous -group {CLK50} -group {CLK200}
set_clock_groups -asynchronous -group {CLK50} -group {CLK_REF}
set_clock_groups -asynchronous -group {CLK200} -group {CLK_REF}

#**************************************************************
# Set False Path
#**************************************************************

set_false_path -to [get_registers {*alt_xcvr_resync*sync_r[0]}]

set_false_path -from [get_clocks CLK50] -to [get_clocks *xcvr_tx_inst*_xcvr_native*|ch[0]*tx_pcs|wys|txpmalocalclk]

set_false_path -from {altera_reserved_tck} -to {CLK50}
set_false_path -from {altera_reserved_tck} -to {CLK200}
set_false_path -from {altera_reserved_tck} -to {CLK_REF}
set_false_path -from {CLK50} -to {altera_reserved_tck}
set_false_path -from {CLK200} -to {altera_reserved_tck}
set_false_path -from {CLK_REF} -to {altera_reserved_tck}

set_false_path -to [get_ports DIL_GX[*]]

#**************************************************************
# Set Multicycle Path
#**************************************************************

#**************************************************************
# Set Maximum Delay
#**************************************************************

#**************************************************************
# Set Minimum Delay
#**************************************************************

#**************************************************************
# Set Input Transition
#**************************************************************

#**************************************************************
# Set Disable Timing
#**************************************************************

set_disable_timing -from * -to q [get_cells -compatibility_mode {*|alt_cal_channel[*]}]
set_disable_timing -from * -to q [get_cells -compatibility_mode {*|alt_cal_busy}]
