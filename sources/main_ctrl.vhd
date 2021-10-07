-------------------------------------------------------------------------------
-- Title      : Main control
-- Project    : Column Controller CPV
-------------------------------------------------------------------------------
-- File       : main_ctrl.vhd
-- Author     : Clive Seguna  <clive.seguna@cern.ch>
-- Company    : University of Malta
-- Author     : Artem Shangaraev <artem.shangaraev@cern.ch>
-- Company    : NRC "Kurchatov institute" - IHEP
-- Created    : 2018-01-01
-- Last update: 2021-04-07
-- Platform   : Quartus Prime 18.1.0
-- Target     : Cyclone V GX
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Main structural entity of the Column controller design.
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CERN
-------------------------------------------------------------------------------

Library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


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
    CLK40_o         : out std_logic;
    CLK_SLOW        : in  std_logic;
    LVDS_RDY_o      : out std_logic;
    
    ------ Dilogic connections ------
    SUB_COMP_o      : out std_logic;
    DIL_CLR_o       : out std_logic;
    TRG_N_o         : out std_logic;
    CLK_A_N_o       : out std_logic;
    CLK_D_N_o       : out std_logic;
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
    TEST_PIN_o      : out std_logic
  );
end entity MAIN_CTRL;

architecture structural of MAIN_CTRL is

-------------------------------------------------------------------------------
------ Component declaration --------------------------------------------------

-------------------------------------------------------------------------------
------ Signal declaration -----------------------------------------------------

-- Reset
  signal s_rst              : std_logic := '1';

-- Control commands
  signal s_realign          : std_logic := '0';
  signal s_check_status     : std_logic := '0';

-- Clocks
  signal CLK40_LVDS         : std_logic := '1';

-- Transceivers interface
  signal s_xcvr_clk         : std_logic_vector (0 downto 0)   := "0";
  signal s_data_tx          : std_logic_vector (31 downto 0)  := (others => '0');
  signal s_data_valid       : std_logic_vector (3 downto 0)   := x"0";
  signal s_data_to_xcvr     : std_logic_vector (127 downto 0) := (others => '0');
  signal s_ctrl             : std_logic_vector (31 downto 0)  := (others => '0');

-- Readout control signals, same for 4 boards (parallel synchronous)
  signal s_analog_rd        : std_logic := '0';
  signal s_data_ready       : std_logic := '0';
  signal s_accept_data      : std_logic := '0';
  signal s_reject_data      : std_logic := '0';
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

  EXT_RST_o   <= s_realign;
  TEST_PIN_o  <= s_analog_rd;
  CLK40_o     <= CLK40_LVDS;

-------------------------------------------------------------------------------
------ LVDS RX wrapper --------------------------------------------------------

  INST_lvds_wrapper: entity work.lvds_wrapper
    port map (
      arst        => ARST,
      lvds_data_i => LVDS_RX_i,
      lvds_clk_i  => LVDS_CLK_i,
      lvds_data_o => s_lvds_word,
      lvds_clk_o  => CLK40_LVDS,
      aligned_o   => LVDS_RDY_o
    );

-------------------------------------------------------------------------------
------ Trigger_generator ------------------------------------------------------

  INST_trigger_generator: entity work.trigger_generator
    port map (
      CLK       => CLK_SLOW,
      ARST      => ARST,

--      TRIGGER_o => open
      TRIGGER_o => s_analog_rd
    );

-------------------------------------------------------------------------------
------ System control, decodes commands and transfer it to other blocks -------

  INST_sys_ctrl : entity work.sys_ctrl 
    port map (
      arst            => ARST,
      CLK_FAST        => CLK40_LVDS,
      lvds_cmd_i      => s_lvds_word,
      realign_o       => s_realign,
      ram_addr_o      => s_ram_addr,
      ram_data_o      => s_ram_data,
      ram_wren_o      => s_ram_wren,
      ram_select_o    => s_ram_select,
      CLK_SLOW        => CLK_SLOW,
      sub_cmp_o       => SUB_COMP_o,
--      trigger_o       => s_analog_rd, -- trigger from LVDS
      trigger_o       => open,        -- internal trigger
      stop_read_o     => open,
      accept_data_o   => s_accept_data,
      reject_data_o   => s_reject_data,
      read_conf_o     => s_read_conf,
      load_conf_o     => s_write_conf,
      check_status_o  => s_check_status
    );

-------------------------------------------------------------------------------
------ Analog readout to Dilogic internal FIFO --------------------------------

  INST_analog_read: entity work.analog_read
    port map (
      arst          => ARST,
      CLK           => CLK_SLOW,
      start_i       => s_analog_rd,
      done_o        => s_data_ready,
      CLK_A_o       => CLK_A_N_o,
      CLK_D_o       => CLK_D_N_o,
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
      CLK_FAST        => CLK40_LVDS,
      ram_addr_i      => s_ram_addr,
      ram_data_i      => s_ram_data,
      ram_wren_i      => s_ram_wren,
      ram_select_i    => s_ram_select,
      CLK_SLOW        => CLK_SLOW,
      trigger_i       => s_analog_rd,
      data_ready_i    => s_data_ready,
      accept_data_i   => s_data_ready, -- s_accept_data,
      reject_data_i   => s_reject_data,
      read_conf_i     => s_read_conf,
      write_conf_i    => s_write_conf,
      check_status_i  => s_check_status,
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
      DATA_RDY_o      => s_data_valid,
      DATAOUT_o       => s_data_to_xcvr,
      CTRL_o          => s_ctrl
    );

---------------------------------------------------------------------------------
-------- Dilogic data generator -------------------------------------------------
--
--    INST_DIL_DATA_GEN: entity work.dilogic_data_generator
--      port map (
--        arst            => ARST,
--        
--        -- 10M clock domain
--        CLK10           => CLK10,
--        trigger_i       => s_analog_rd,
--        data_ready_i    => s_analog_rdy,
--  --      accept_data_i     => s_accept_data, -- send on external accept
--        accept_data_i   => s_analog_rdy,    -- send data immediately 
--        reject_data_i   => '0', --s_reject_data,
--        check_status_i  => s_check_status,
--        
--        -- XCVR connection
--        DATA_RDY_o      => s_data_valid,
--        DATAOUT_o       => s_data_to_xcvr,
--        CTRL_o          => s_ctrl
--      );
    
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
  
  INST_xcvr_packager: entity work.data_packager
    port map (
      arst        => ARST,
      CLK_DIL     => CLK_SLOW,
      data_i      => s_data_to_xcvr,
      data_rdy_i  => s_data_valid, --x"0", --
      CTRL_i      => s_ctrl,
      clk_xcvr    => s_xcvr_clk(0),
      data_o      => s_data_tx
    );
    
end architecture;
