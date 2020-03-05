-------------------------------------------------------------------------------
-- Title      : CC top
-- Project    : Column Controller CPV
-------------------------------------------------------------------------------
-- File       : cc_top.vhd
-- Author     : Clive Seguna  <clive.seguna@cern.ch>
-- Company    : University of Malta
-- Created    : 2018-01-01
-- Last update: 2020-03-04
-- Platform   : Quartus Prime 18.1.0
-- Target     : Cyclone V GX
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Top level entity of the Column controller design
--              Provides buffering of all I/O.
--              Clock generator contains PLL for 10 MHz clock.
--              Main control entity contains all logic.
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CERN
-------------------------------------------------------------------------------
--  Revisions  :
--  Date          Version   Author    Description
--  2019-01-01    1.0       cseguna   Created as main_ctrl
--  2020-03-02    1.20.4    ashangar  Main_ctrl moved to the next level entity.
-------------------------------------------------------------------------------

Library IEEE;
use IEEE.std_logic_1164.all;

Library altera;
use altera.altera_primitives_components.all;

entity cc_top is
  port (
    ------ Clocks ------
    REF_156MHZ      : in std_logic_vector (0 downto 0);
    PLL_50MHZ_CLK   : in std_logic;

    --xcvr data
--    gtx_rx0         : in std_logic_vector (0 downto 0);
    gtx_tx0         : out std_logic_vector(0 downto 0);

    ------ LVDS pins ------
    lvds_rx_in      : in  std_logic_vector (0 downto 0);
    clk_rx_in       : in  std_logic;

    ------ Dilogic connections ------
    SUB_COMP        : out std_logic_vector(3 downto 0);
    DIL_GX          : out std_logic_vector(3 downto 0);
    DIL_CLR         : out std_logic_vector(3 downto 0);
    DIL_RST         : out std_logic_vector(3 downto 0);
    STRIN           : out std_logic_vector(3 downto 0);
    TRG_N           : out std_logic_vector(3 downto 0);
    MACK            : in  std_logic_vector(3 downto 0);
    ALMFULL         : in  std_logic_vector(3 downto 0);
    EMPTY_N         : in  std_logic_vector(3 downto 0);
    NO_ADATA_N      : in  std_logic_vector(3 downto 0);
    CLK_ADC_N       : out std_logic_vector(3 downto 0);
    CLKD_N          : out std_logic_vector(3 downto 0);
    ENIN_N          : out std_logic_vector(3 downto 0);
    ENOUT_N         : in  std_logic_vector(19 downto 0);
    
    FCODE_C1        : out std_logic_vector(3 downto 0);
    FCODE_C2        : out std_logic_vector(3 downto 0);
    
    CH_ADDR_D1_N    : out std_logic_vector(5 downto 0);
    CH_ADDR_D2_N    : out std_logic_vector(5 downto 0);
    CH_ADDR_D3_N    : out std_logic_vector(5 downto 0);
    CH_ADDR_D4_N    : out std_logic_vector(5 downto 0);
    
    DATA_BUS_D1     : inout std_logic_vector(17 downto 0);
    DATA_BUS_D2     : inout std_logic_vector(17 downto 0);
    DATA_BUS_D3     : inout std_logic_vector(17 downto 0);
    DATA_BUS_D4     : inout std_logic_vector(17 downto 0);
    
    ------ Gassiplex Pins ------
    CLK_G         : out std_logic_vector(1 downto 0);
    CLR_G         : out std_logic_vector(1 downto 0);
    T_H           : out std_logic_vector(1 downto 0);

    ------ Others ------
    TEST_PIN        : out std_logic
    
    ---- SI532 pins > Not assigned! ------
--    CLK_125         : in std_logic;
--    CLK_50_A        : in std_logic;
--    CLK_50_B        : in std_logic;
--    I2C_SCL         : out std_logic;
--    I2C_SDA         : inout std_logic
  );
end entity;

architecture structural of cc_top is

-------------------------------------------------------------------------------
------ Component declaration --------------------------------------------------
-------------------------------------------------------------------------------
------ Intel IP ---------------------------------------------------------------

  -- Flash loader
  component SerialFlashLoader is
    port (
      noe_in : in std_logic
    );
  end component SerialFlashLoader;

  component ALT_IOBUF
    port (
      i   : in    std_logic;
      oe  : in    std_logic;
      io  : inout std_logic;
      o   : out   std_logic 
    );
  end component;
  
  component ALT_INBUF
    port (
      i   : in  std_logic;
      o   : out std_logic 
    );
  end component;
  
  component ALT_OUTBUF
    port (
      i   : in  std_logic;
      o   : out std_logic 
    );
  end component;
  
-------------------------------------------------------------------------------
------ Signal declaration -----------------------------------------------------

-- Reset
  signal s_rst              : std_logic := '1';
  signal s_ext_rst          : std_logic := '0';

-- Clocks
  signal CLK10              : std_logic := '1';

-- I/O buffered signals
  signal s_dil_clk_adc      : std_logic := '0';
  signal s_dil_clkd         : std_logic := '0';
  signal s_dil_clr          : std_logic := '0';
  signal s_trg_n            : std_logic := '0';
  signal s_sub_cmp          : std_logic := '0';
  signal s_dil_cmd          : std_logic_vector (3 downto 0) := (others => '0');
  signal s_addr_gas_n       : std_logic_vector (5 downto 0) := (others => '0');
  signal s_fcode_dil        : std_logic_vector (3 downto 0) := (others => '0');
  signal s_dil_ena          : std_logic_vector (3 downto 0) := (others => '0');
  signal s_dil_rst          : std_logic_vector (3 downto 0) := (others => '0');
  signal s_strin            : std_logic_vector (3 downto 0) := (others => '0');
  signal s_mack             : std_logic_vector (3 downto 0) := (others => '0');
  signal s_almfull          : std_logic_vector (3 downto 0) := (others => '0');
  signal s_done_dil_rd      : std_logic_vector (3 downto 0) := (others => '0');
  signal s_empty_n          : std_logic_vector (3 downto 0) := (others => '0');
  signal s_no_adata_n       : std_logic_vector (3 downto 0) := (others => '0');
  signal s_enin_n           : std_logic_vector (3 downto 0) := (others => '0');
  signal s_enout_n          : std_logic_vector (19 downto 0) := (others => '0');
  
  signal s_gas_CLR          : std_logic := '0';
  signal s_gas_CLK          : std_logic := '0';
  signal s_gas_T_H          : std_logic := '0';
  
-- Bidirectional buses, 4x18 bit = 72
  signal s_data_from_dil    : std_logic_vector (71 downto 0) := (others => '0');
  signal s_data_to_dil      : std_logic_vector (71 downto 0) := (others => '0');
  signal s_databus_oe       : std_logic_vector (71 downto 0) := (others => '0');

  signal s_test             : std_logic := '0';
-------------------------------------------------------------------------------
------ Architecture begin -----------------------------------------------------

begin

  INST_CLK_RST: entity work.clock_generator
    port map (
      EXT_RST_i => s_ext_rst,
      RST_o     => s_rst,
      CLK_i     => PLL_50MHZ_CLK,
      CLK_o     => CLK10
    );

-------------------------------------------------------------------------------
------ Serial flash loader to write the .jic file to the memory ---------------

  sf_init: SerialFlashLoader
    port map(
      noe_in  => '0'
    );

-------------------------------------------------------------------------------
------ Main control -----------------------------------------------------------
  INST_MAIN_CTRL: entity work.main_ctrl
    port map (
      ARST          => s_rst,
      EXT_RST_o     => s_ext_rst,
      ------ LVDS ------
      LVDS_RX_i     => lvds_rx_in,
      LVDS_CLK_i    => clk_rx_in,
      ------ XCVR ------
      XCVR_TX_o     => gtx_tx0,
      XCVR_REF_CLK  => REF_156MHZ,
      ------ CLK ------
      CLK50_PLL     => PLL_50MHZ_CLK,
      CLK10         => CLK10,
      ------ Dilogic ------
      SUB_COMP_o    => s_sub_cmp,
      DIL_CLR_o     => s_dil_clr,
      DIL_RST_o     => s_dil_rst,
      STRIN_o       => s_strin,
      TRG_N_o       => s_trg_n,
      MACK_i        => s_mack,
      ALMFULL_i     => s_almfull,
      EMPTY_N_i     => s_empty_n,
      NO_ADATA_N_i  => s_no_adata_n,
      CLK_ADC_N_o   => s_dil_clk_adc,
      CLKD_N_o      => s_dil_clkd,
      ENIN_N_o      => s_enin_n,
      ENOUT_N_i     => s_enout_n,
      FCODE_o       => s_fcode_dil,
      CH_ADDR_N_o   => s_addr_gas_n,
      DATABUS_o     => s_data_to_dil,
      DATABUS_i     => s_data_from_dil,
      DIL_ENA_o     => s_dil_ena,
      ------ Gassiplex ------
      CLK_G_o       => s_gas_CLK,
      CLR_G_o       => s_gas_CLR,
      T_H_o         => s_gas_T_H,
      ------ Others ------
      TEST_PIN_o    => s_test
    );
    
-------------------------------------------------------------------------------
------ Databus bidirectional buffering ----------------------------------------

  INST_DATABUS_D1: for j in DATA_BUS_D1'range generate
    INST_IOBUF_DATABUSi: ALT_IOBUF
      port map (
        i   => s_data_to_dil(j),
        oe  => s_databus_oe(j),
        io  => DATA_BUS_D1(j),
        o   => s_data_from_dil(j)
      );
  end generate INST_DATABUS_D1;

  INST_DATABUS_D2: for j in DATA_BUS_D1'range generate
    INST_IOBUF_DATABUSi: ALT_IOBUF
      port map (
        i   => s_data_to_dil(18 + j),
        oe  => s_databus_oe(18 + j),
        io  => DATA_BUS_D2(j),
        o   => s_data_from_dil(18 + j)
      );
  end generate INST_DATABUS_D2;

  INST_DATABUS_D3: for j in DATA_BUS_D1'range generate
    INST_IOBUF_DATABUSi: ALT_IOBUF
      port map (
        i   => s_data_to_dil(36 + j),
        oe  => s_databus_oe(36 + j),
        io  => DATA_BUS_D3(j),
        o   => s_data_from_dil(36 + j)
      );
  end generate INST_DATABUS_D3;

  INST_DATABUS_D4: for j in DATA_BUS_D1'range generate
    INST_IOBUF_DATABUSi: ALT_IOBUF
      port map (
        i   => s_data_to_dil(54 + j),
        oe  => s_databus_oe(54 + j),
        io  => DATA_BUS_D4(j),
        o   => s_data_from_dil(54 + j)
      );
  end generate INST_DATABUS_D4;

  INST_DIL_ENA: for i in 0 to 3 generate
    INST_DATABUS_ENA: for j in DATA_BUS_D1'range generate
      s_databus_oe(18*i+j) <= s_dil_ena(i);
    end generate INST_DATABUS_ENA;
  end generate INST_DIL_ENA;

-------------------------------------------------------------------------------
------ Input and output buffers -----------------------------------------------

  GEN_DIL_ENOUT: for i in ENOUT_N'range generate
    INST_ENOUT: ALT_INBUF
      port map (
        i => ENOUT_N(i),
        o => s_enout_n(i)
      );
  end generate GEN_DIL_ENOUT;
  
  GEN_DIL_INPUT: for i in 0 to 3 generate
    INST_EMPTY: ALT_INBUF
      port map (
        i => EMPTY_N(i),
        o => s_empty_n(i)
      );
    INST_ALMFULL: ALT_INBUF
      port map (
        i => ALMFULL(i),
        o => s_almfull(i)
      );
    INST_NOADATA: ALT_INBUF
      port map (
        i => NO_ADATA_N(i),
        o => s_no_adata_n(i)
      );
    INST_MACK: ALT_INBUF
      port map (
        i => MACK(i),
        o => s_mack(i)
      );
  end generate GEN_DIL_INPUT;
  
  GEN_DIL_OUTPUT: for i in 0 to 3 generate
    INST_TRG: ALT_OUTBUF
      port map (
        i => s_trg_n,
        o => TRG_N(i)
      );
    INST_CLK_ADC: ALT_OUTBUF
      port map (
        i => s_dil_clk_adc,
        o => CLK_ADC_N(i)
      );
    INST_CLKD: ALT_OUTBUF
      port map (
        i => s_dil_clkd,
        o => CLKD_N(i)
      );
    INST_CLR: ALT_OUTBUF
      port map (
        i => s_dil_clr,
        o => DIL_CLR(i)
      );
    INST_SUBCOMP: ALT_OUTBUF
      port map (
        i => s_sub_cmp,
        o => SUB_COMP(i)
      );
    INST_FCODE_C1: ALT_OUTBUF
      port map (
        i => s_fcode_dil(i),
        o => FCODE_C1(i)
      );
    INST_FCODE_C2: ALT_OUTBUF
      port map (
        i => s_fcode_dil(i),
        o => FCODE_C2(i)
      );
    INST_ENIN: ALT_OUTBUF
      port map (
        i => s_enin_n(i),
        o => ENIN_N(i)
      );
    INST_STRIN: ALT_OUTBUF
      port map (
        i => s_strin(i),
        o => STRIN(i)
      );
    INST_DIL_RST: ALT_OUTBUF
      port map (
        i => s_dil_rst(i),
        o => DIL_RST(i)
      );
  end generate GEN_DIL_OUTPUT;
    
  GEN_DIL_ADDR: for i in 0 to 5 generate
    INST_ADDR_D1: ALT_OUTBUF
      port map (
        i => s_addr_gas_n(i),
        o => CH_ADDR_D1_N(i)
      );
    INST_ADDR_D2: ALT_OUTBUF
      port map (
        i => s_addr_gas_n(i),
        o => CH_ADDR_D2_N(i)
      );
    INST_ADDR_D3: ALT_OUTBUF
      port map (
        i => s_addr_gas_n(i),
        o => CH_ADDR_D3_N(i)
      );
    INST_ADDR_D4: ALT_OUTBUF
      port map (
        i => s_addr_gas_n(i),
        o => CH_ADDR_D4_N(i)
      );
  end generate GEN_DIL_ADDR;
  
  -- "10" means 3 Gassiplex per one Dilogic chip, 48 channels.
  DIL_GX        <= b"1010"; -- "10" for D1 & D2; "10" for D3 & D4

-------------------------------------------------------------------------------
------ 3-Gassiplex signals ----------------------------------------------------
  
  GEN_GAS_SIG: for i in 0 to 1 generate
    INST_CLKG: ALT_OUTBUF
    port map (
      i => s_gas_CLK,
      o => CLK_G(i)
    );
    INST_CLRG: ALT_OUTBUF
    port map (
      i => s_gas_CLR,
      o => CLR_G(i)
    );
    INST_T_H: ALT_OUTBUF
    port map (
      i => s_gas_T_H,
      o => T_H(i)
    );
  end generate GEN_GAS_SIG;

-------------------------------------------------------------------------------
------ Other signals ----------------------------------------------------------
  
  INST_TEST: ALT_OUTBUF
    port map (
      i => s_test,
      o => TEST_PIN
    );

end architecture;
