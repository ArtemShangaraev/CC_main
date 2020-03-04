-------------------------------------------------------------------------------
-- Title      : Main control
-- Project    :
-------------------------------------------------------------------------------
-- File       : main_ctrl.vhd
-- Author     : Clive Seguna  <clive.seguna@cern.ch>
-- Company    : University of Malta
-- Created    : 2018-01-01
-- Last update: 2020-02-14
-- Platform   : Cyclone V GX
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Top level entity of the Column controller design
--              Provides control of Dilogic cards and FIFO for data taking.
--              Receives commands and data by LVDS. TX is also available.
--              Sends out data using GX transceivers. GX-RX is also available.
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CERN
-------------------------------------------------------------------------------
--  Revisions  :
--  Date          Version   Author    Description
--  2018-01-01    1.0       cseguna   Created
--  2020-02-14    1.20.1    ashangar  Added FIFO to provide XCVR TX
--                                    Removed unused signals
--                                    Cosmetics
--  2020-02-14    1.20.1    ashangar  LVDSCtrl replaced by lvds_wrapper
--  2020-02-16    1.20.1    ashangar  SYSCtrl replaced by sys_ctrl
--                                    Reworked command decoding
--  2020-02-19    1.20.2    ashangar  Complete rearrangement of structure
--                                    New analog readout block.
--                                    New Dilogic FIFO readout block.
--                                    Temporary missing thresholds operations.
--  2020-02-20    1.20.2    ashangar  Assignment change!
--                                    Pin_B9 - Pin_K25 for C2_GX[1]
--  2020-02-23    1.20.3    ashangar  XCVR wrapper recreated with native
--                                    Transceiver Reset and Recongig IP.
--  2020-03-02    1.20.4    ashangar  Added buffers for all i/o
-------------------------------------------------------------------------------

Library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

Library altera;
use altera.altera_primitives_components.all;

entity MAIN_CTRL is
  port (
    ARST            : in  std_logic;
    EXT_RST_o       : out std_logic;
    
    ------ LVDS pins ------
    LVDS_RX_i       : in  std_logic_vector (0 downto 0);
    LVDS_CLK_i      : in  std_logic;
    
    --xcvr data
    XCVR_TX_o       : out std_logic_vector(0 downto 0);
    
    ------ Clocks ------
    XCVR_REF_CLK    : in  std_logic_vector (0 downto 0);
    CLK50_PLL       : in  std_logic;
    CLK10           : in  std_logic;
    
    ------ Dilogic connections ------
    SUB_COMP_o      : out std_logic;
    DIL_CLR_o       : out std_logic;
    TRG_N_o         : out std_logic;
    CLK_ADC_N_o     : out std_logic;
    CLKD_N_o        : out std_logic;
    DIL_RST_o       : out std_logic_vector(3 downto 0);
    STRIN_o         : out std_logic_vector(3 downto 0);
    ENIN_N_o        : out std_logic_vector(3 downto 0);
    MACK_i          : in  std_logic_vector(3 downto 0);
    ALMFULL_i       : in  std_logic_vector(3 downto 0);
    EMPTY_N_i       : in  std_logic_vector(3 downto 0);
    NO_ADATA_N_i    : in  std_logic_vector(3 downto 0);
    ENOUT_N_i       : in  std_logic_vector(19 downto 0);
    
    FCODE_o         : out std_logic_vector(3 downto 0);
    CH_ADDR_N_o     : out std_logic_vector(5 downto 0);
    
    DATABUS_i       : in  std_logic_vector(71 downto 0);
    DATABUS_o       : out std_logic_vector(71 downto 0);
    DIL_ENA_o       : out std_logic_vector(3 downto 0);
    
    ------ Gassiplex Pins ------
    CLK_G_o         : out std_logic;
    CLR_G_o         : out std_logic;
    T_H_o           : out std_logic;

    ------ Others ------
    TEST_PIN_o        : out std_logic
  );
end entity MAIN_CTRL;

architecture structural of MAIN_CTRL is

-------------------------------------------------------------------------------
------ Component declaration --------------------------------------------------

-------------------------------------------------------------------------------
------ Signal declaration -----------------------------------------------------

-- Reset
  signal s_rst              : std_logic := '1';
  signal s_realign          : std_logic := '0';

-- Clocks
  signal CLK50_LVDS         : std_logic := '1';

-- Transceivers interface
  signal s_xcvr_clk         : std_logic_vector (0 downto 0) := "0";
  signal s_data_tx          : std_logic_vector (31 downto 0) := (others => '0');
  signal s_data_rdy         : std_logic_vector (3 downto 0) := x"0";
  signal s_data_to_xcvr     : std_logic_vector (127 downto 0) := (others => '0');

-- Readout control signals, same for 4 boards (parallel synchronous)
  signal s_start_rd         : std_logic := '0';
  signal s_done_analog_rd   : std_logic := '0';
  signal s_stop_rd          : std_logic := '0';
  signal s_read_conf        : std_logic := '0';
  signal s_write_conf       : std_logic := '0';
  
-- RAM interface for Dilogic thresholds memory
  signal s_ram_addr         : std_logic_vector (8 downto 0) := (others => '0');
  signal s_ram_data         : std_logic_vector (8 downto 0) := (others => '0');
  signal s_ram_wren         : std_logic := '0';
  signal s_ram_select       : unsigned (1 downto 0) := "00";
  
  signal s_lvds_word        : std_logic_vector(3 downto 0) := x"0";

-------------------------------------------------------------------------------
------ Architecture begin -----------------------------------------------------

begin

  EXT_RST_o <= s_realign;

-------------------------------------------------------------------------------
------ LVDS RX wrapper --------------------------------------------------------

  INST_lvds_wrapper: entity work.lvds_wrapper
    port map (
      arst        => ARST,
      realign_i   => s_realign,
      lvds_data_i => LVDS_RX_i,
      lvds_clk_i  => LVDS_CLK_i,
      lvds_data_o => s_lvds_word,
      lvds_clk_o  => CLK50_LVDS
    );

-------------------------------------------------------------------------------
------ System control, decodes commands and transfer it to other blocks -------

  INST_sys_ctrl : entity work.sys_ctrl 
    port map (
      arst          => ARST,
      CLK50         => CLK50_LVDS,
      lvds_cmd_i    => s_lvds_word,
      realign_o     => s_realign,
      ram_addr_o    => s_ram_addr,
      ram_data_o    => s_ram_data,
      ram_wren_o    => s_ram_wren,
      ram_select_o  => s_ram_select,
      CLK10         => CLK10,
      sub_cmp_o     => SUB_COMP_o,
      trigger_o     => s_start_rd,
      stop_read_o   => s_stop_rd,
      read_conf_o   => s_read_conf,
      write_conf_o  => s_write_conf
    );

-------------------------------------------------------------------------------
------ Analog readout to Dilogic internal FIFO --------------------------------

  INST_analog_read: entity work.analog_read
    port map (
      arst          => ARST,
      CLK           => CLK10,
      start_i       => s_start_rd,
      done_o        => s_done_analog_rd,
      stop_i        => s_stop_rd,
      CLK_ADC_o     => CLK_ADC_N_o,
      CLKD_o        => CLKD_N_o,
      CLR_D_o       => DIL_CLR_o,
      ADDR_GAS_N_o  => CH_ADDR_N_o,
      TRG_N_o       => TRG_N_o,
      CLK_G_o       => CLK_G_o,
      CLR_G_o       => CLR_G_o,
      T_H_o         => T_H_o
    );

-------------------------------------------------------------------------------
------ Dilogic control --------------------------------------------------------

  INST_DIL_CTRL_TOP: entity work.dilogic_ctrl_top
    port map (
      arst            => ARST,
      CLK50           => CLK50_LVDS,
      ram_addr_i      => s_ram_addr,
      ram_data_i      => s_ram_data,
      ram_wren_i      => s_ram_wren,
      ram_select_i    => s_ram_select,
      CLK10           => CLK10,
      trigger_i       => s_start_rd,
      started_rd_i    => s_done_analog_rd,
      read_conf_i     => s_read_conf,
      write_conf_i    => s_write_conf,
      RST_o           => DIL_RST_o,
      MACK_i          => MACK_i,
      ALMFULL_i       => ALMFULL_i,
      EMPTY_N_i       => EMPTY_N_i,
      STRIN_o         => STRIN_o,
      ENIN_N_o        => ENIN_N_o,
      ENOUT_N_i       => ENOUT_N_i,
      NO_ADATA_N_i    => NO_ADATA_N_i,
      FCODE_o         => FCODE_o,
      DATA_FROM_DIL_i => DATABUS_i,
      DATA_TO_DIL_o   => DATABUS_o,
      DIL_ENA_o       => DIL_ENA_o,
      DATA_RDY_o      => s_data_rdy,
      DATAOUT_o       => s_data_to_xcvr
    );

-------------------------------------------------------------------------------
------ TRANSCEIVER SERDES - Trasnfer of Event Data ----------------------------

  INST_XCVR_WRAPPER : entity work.XCVR_WRAPPER
    port map(
      ARST                    => ARST,
      MGMT_CLK                => CLK50_PLL,
      REF_CLK                 => XCVR_REF_CLK,
      XCVR_TX_serial_data_o   => XCVR_TX_o,
      XCVR_TX_parallel_data_i => s_data_tx,
      XCVR_TX_parallel_clk_o  => s_xcvr_clk
    );
  
  INST_xcvr_packer: entity work.data_packer
    port map (
      arst        => ARST,
      CLK_DIL     => CLK10,
      data_i      => s_data_to_xcvr,
      data_rdy_i  => s_data_rdy,
      clk_xcvr    => s_xcvr_clk(0),
      data_o      => s_data_tx
    );
    
  TEST_PIN_o      <= CLK10;

end architecture;