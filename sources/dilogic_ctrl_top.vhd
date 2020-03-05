-------------------------------------------------------------------------------
-- Title      : Top level of Dilogic control
-- Project    : Column Controller CPV
-------------------------------------------------------------------------------
-- File       : dilogic_ctrl_top.vhd
-- Author     : Artem Shangaraev <artem.shangaraev@cern.ch>
-- Company    : NRC "Kurchatov institute" - IHEP
-- Created    : 2020-02-18
-- Last update: 2020-03-04
-- Platform   : Quartus Prime 18.1.0
-- Target     : Cyclone V GX
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Top level control of all 5-Dilogic cards.
--              Provides the synchronization of four cards during parallel 
--              readout or thresholds loading.
--              Generates correct FCODE.
--              Convert 18-bit Dil word to 32-bit word for XCVR.
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CERN
-------------------------------------------------------------------------------
--  Revisions  :
--  Date          Version   Author    Description
--  2020-02-18    1.0       ashangar  Created
--  2020-02-22    1.1       ashangar  FSM generates FCODE, synchronises 4 cards
--                                    and creates datapath to fabric.
--                                    Thresholds loading temporary missing.
--  2020-02-27    1.2       ashangar  Added RAM for thresholds.
--                                    Replaced LVDS commands by simple pulses.
-------------------------------------------------------------------------------

Library IEEE;
Use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity dilogic_ctrl_top is
  port (
    arst            : in std_logic;
    
    -- 50M clock domain
    CLK50           : in std_logic;
    
    -- RAM for thresholds
    ram_addr_i      : in  std_logic_vector(8 downto 0);
    ram_data_i      : in  std_logic_vector(8 downto 0);
    ram_wren_i      : in  std_logic;
    ram_select_i    : in  unsigned (1 downto 0);
    
    -- 10M clock domain
    CLK10           : in  std_logic;
    trigger_i       : in  std_logic;
    started_rd_i    : in  std_logic;
    read_conf_i     : in  std_logic;
    write_conf_i    : in  std_logic;
    
    -- Dilogic connection x4 cards
    RST_o           : out std_logic_vector(3 downto 0);
    MACK_i          : in  std_logic_vector(3 downto 0);
    ALMFULL_i       : in  std_logic_vector(3 downto 0);
    STRIN_o         : out std_logic_vector(3 downto 0);
    EMPTY_N_i       : in  std_logic_vector(3 downto 0);
    NO_ADATA_N_i    : in  std_logic_vector(3 downto 0);
    ENIN_N_o        : out std_logic_vector(3 downto 0);
    ENOUT_N_i       : in  std_logic_vector(19 downto 0);
    DATA_FROM_DIL_i : in  std_logic_vector(71 downto 0);
    DATA_TO_DIL_o   : out std_logic_vector(71 downto 0);
    DIL_ENA_o       : out std_logic_vector(3 downto 0);
    
    FCODE_o         : out  std_logic_vector(3 downto 0);
    
    -- XCVR connection
    DATA_RDY_o      : out std_logic_vector(3 downto 0);
    DATAOUT_o       : out std_logic_vector(127 downto 0)
  );
end entity;

architecture beh of dilogic_ctrl_top is

-------------------------------------------------------------------------------
------ Component declaration --------------------------------------------------

  component ram_9x320 is
    port(
      data      : in  std_logic_vector (8 downto 0);
      rdaddress : in  std_logic_vector (8 downto 0);
      rdclock   : in  std_logic;
      wraddress : in  std_logic_vector (8 downto 0);
      wrclock   : in  std_logic;
      wren      : in  std_logic;
      q         : out std_logic_vector (8 downto 0)
    );
  end component ram_9x320;

-------------------------------------------------------------------------------
------ Signal declaration -----------------------------------------------------

  constant C_TEST_MODE    : std_logic_vector (3 downto 0) := b"0000";
  constant C_LOAD_ALMFULL : std_logic_vector (3 downto 0) := b"0001";
  constant C_IDLE         : std_logic_vector (3 downto 0) := b"0010";
  constant C_PATTERN_READ : std_logic_vector (3 downto 0) := b"1000";
  constant C_PATTERN_DEL  : std_logic_vector (3 downto 0) := b"1001";
  constant C_ANALOG_READ  : std_logic_vector (3 downto 0) := b"1010";
  constant C_ANALOG_DEL   : std_logic_vector (3 downto 0) := b"1011";
  constant C_RESET_FIFO   : std_logic_vector (3 downto 0) := b"1100";
  constant C_RESET_CHAIN  : std_logic_vector (3 downto 0) := b"1101";
  constant C_CONFIG_WRITE : std_logic_vector (3 downto 0) := b"1110";
  constant C_CONFIG_READ  : std_logic_vector (3 downto 0) := b"1111";
  
  type t_readout_fsm is (
    Reset,
    Idle,
    Wait_for_adc,
    Analog_rd_start,
    Analog_rd_process,
    Rst_chain_start,
    Rst_chain_delay,
    Rst_chain_strin,
    Rst_chain_end,
    Conf_wr_start,
    Conf_wr_process,
    Conf_rd_start,
    Conf_rd_process
  );
  signal st_readout: t_readout_fsm := Reset;

  signal s_data_from_dil  : std_logic_vector (71 downto 0) := (others => '0');
  signal s_data_to_dil    : std_logic_vector (71 downto 0) := (others => '0');
  signal s_data_to_fabric : std_logic_vector (71 downto 0) := (others => '0');
  signal s_data_rdy       : std_logic_vector (3 downto 0) := x"0";
  
  signal s_channel        : unsigned (8 downto 0) := (others => '0');
  signal s_ch_addr        : std_logic_vector (8 downto 0) := (others => '0');

  signal s_rst_chain_cnt  : natural range 0 to 7 := 0;
  signal s_timeout_cnt    : natural range 0 to 511 := 0;
  signal s_timeout        : std_logic := '0';
  signal s_dil_ena        : std_logic_vector (3 downto 0) := x"0";
  signal s_dil_rdy        : std_logic_vector (3 downto 0) := x"0";
  signal s_dil_done       : std_logic_vector (3 downto 0) := x"0";
  signal s_dil_rst        : std_logic_vector (3 downto 0) := x"0";
  signal s_strin          : std_logic_vector (3 downto 0) := x"0";
  signal s_mack           : std_logic_vector (3 downto 0) := x"0";
  signal s_almfull        : std_logic_vector (3 downto 0) := x"0";
  signal s_empty_n        : std_logic_vector (3 downto 0) := x"0";
  signal s_no_adata_n     : std_logic_vector (3 downto 0) := x"0";
  signal s_enin_n         : std_logic_vector (3 downto 0) := x"0";
  signal s_enout_n        : std_logic_vector (19 downto 0) := (others => '0');
  
  signal s_fcode          : std_logic_vector (3 downto 0) := C_IDLE;
  
  constant c_card_id      : std_logic_vector (11 downto 0) := 
            "011" & "010" & "001" & "000";
  signal s_dil_id         : std_logic_vector (11 downto 0) := (others => '0');
  signal s_sync_dil       : std_logic := '0';
  
-------------------------------------------------------------------------------
------ Architecture begin -----------------------------------------------------
begin
  
  FCODE_o         <= s_fcode;
  DIL_ENA_o       <= s_dil_ena;
  RST_o           <= s_dil_rst;
  STRIN_o         <= s_strin;
  ENIN_N_o        <= s_enin_n;
  DATA_TO_DIL_o   <= s_data_to_dil;
  
  s_mack          <= MACK_i;
  s_almfull       <= ALMFULL_i;
  s_empty_n       <= EMPTY_N_i;
  s_no_adata_n    <= NO_ADATA_N_i;
  s_enout_n       <= ENOUT_N_i;
  s_data_from_dil <= DATA_FROM_DIL_i;
  
  DATA_RDY_o      <= s_data_rdy;
  
--  s_sync_dil      <= '1' when s_dil_rdy = x"F" else '0';
  s_sync_dil  <= s_dil_rdy(0) and s_dil_rdy(1) and s_dil_rdy(2) and s_dil_rdy(3);
  s_timeout   <= '1' when s_timeout_cnt = 1 else '0';
  
-------------------------------------------------------------------------------
------ Generate instances for 4 cards -----------------------------------------

  DIL_CTRL_GEN : for i in 0 to 3 generate
  
  signal s_thr_value      : std_logic_vector (8 downto 0) := (others => '0');
  signal s_thr_to_dil     : std_logic_vector (17 downto 0) := (others => '0');
  signal s_wren           : std_logic := '0';
  
  begin
  
    s_wren <= ram_wren_i when to_unsigned(i, 2) = ram_select_i else '0';
  
    INST_THR_RAMi: ram_9x320
      port map (
        data      => ram_data_i,
        rdaddress => s_ch_addr,
        rdclock   => CLK10,
        wraddress => ram_addr_i,
        wrclock   => CLK50,
        wren      => s_wren,
        q         => s_thr_value
      );
  
  s_thr_to_dil(17 downto 9) <= (others => '0');
  s_thr_to_dil(8 downto 0)  <= s_thr_value;
  
    INST_DIL_CTRL: entity work.one_dilogic_ctrl
      port map (
        arst              => arst,
        CLK               => CLK10,
        FCODE_i           => s_fcode,
        RDY_o             => s_dil_rdy(i),
        SYNC_i            => s_sync_dil,
        TIMEOUT_i         => s_timeout,
        RST_o             => s_dil_rst(i),
        MACK_i            => s_mack(i),
        ALMFULL_i         => s_almfull(i),
        EMPTY_N_i         => s_empty_n(i),
        STRIN_o           => s_strin(i),
        ENIN_N_o          => s_enin_n(i),
        ENOUT_N_i         => s_enout_n(5*i+4 downto 5*i),
        NO_ADATA_N_i      => s_no_adata_n(i),
        DIL_ID_o          => s_dil_id(3*i+2 downto 3*i),
        DATA_FROM_DIL_i   => s_data_from_dil(18*i+17 downto 18*i),
        DATA_TO_DIL_o     => s_data_to_dil(18*i+17 downto 18*i),
        THR_TO_DIL_i      => s_thr_to_dil,
        DATA_TO_FABRIC_o  => s_data_to_fabric(18*i+17 downto 18*i),
        DATA_RDY_o        => s_data_rdy(i)
      );
    
    DATAOUT_o(32*i+31 downto 32*i) <= 
          x"0" & 
          s_fcode & 
          c_card_id(3*i+2 downto 3*i) & 
          s_dil_id(3*i+2 downto 3*i) & 
          s_data_to_fabric(18*i+17 downto 18*i)
      when s_data_rdy(i) = '1'
      else x"5E000000" when s_sync_dil = '1'
      else (others => '0');
      
  s_dil_ena(i) <= '1' when st_readout = Conf_wr_start
                        or st_readout = Conf_wr_process
                      else '0';
    
  end generate DIL_CTRL_GEN;
  
  s_ch_addr <= std_logic_vector(s_channel);
  
-------------------------------------------------------------------------------
------ Readout control and sync FSM -------------------------------------------

  READOUT_FSM: process (CLK10, arst)
  begin
    if arst = '1' then
      s_fcode         <= C_IDLE;
      s_channel       <= (others => '0');
      s_timeout_cnt   <= 0;
      s_rst_chain_cnt <= 0;
      st_readout      <= Reset;
      
    elsif rising_edge(CLK10) then
      
      case st_readout is
        when Reset =>
          st_readout      <= Conf_wr_start; -- Clear the threshold memory
          
        when Idle =>
          s_fcode         <= C_IDLE;
          s_channel       <= (others => '0');
          s_timeout_cnt   <= 0;
          s_rst_chain_cnt <= 0;
          if write_conf_i = '1' then
            st_readout    <= Conf_wr_start;
          elsif read_conf_i = '1' then
            st_readout    <= Conf_rd_start;
          elsif trigger_i = '1' then
            st_readout    <= Wait_for_adc;
          else
            st_readout    <= Idle;
          end if;
          
-------------------------------------------------------------------------------
------ Analog read subFSM -----------------------------------------------------

        when Wait_for_adc =>
          if started_rd_i = '1' then
            st_readout    <= Analog_rd_start;
          end if;
        
        when Analog_rd_start =>
          s_fcode         <= C_ANALOG_READ;
          s_timeout_cnt   <= 253;
          st_readout      <= Analog_rd_process;
        
        when Analog_rd_process =>
          s_timeout_cnt    <= s_timeout_cnt - 1;
          if s_sync_dil = '1' then
            s_fcode     <= C_RESET_CHAIN;
            st_readout  <= Rst_chain_start;
          end if;
          
-------------------------------------------------------------------------------
------ Reset daisy chain subFSM -----------------------------------------------

        when Rst_chain_start =>
          s_fcode       <= C_RESET_CHAIN;
          if s_rst_chain_cnt < 2 then
            s_rst_chain_cnt <= s_rst_chain_cnt + 1;
          else
            st_readout    <= Rst_chain_end;
          end if;
        
        when Rst_chain_end =>
          st_readout    <= Idle;
        
-------------------------------------------------------------------------------
------ Configuration write subFSM ---------------------------------------------

        when Conf_wr_start =>
          s_fcode         <= C_CONFIG_WRITE;
          s_timeout_cnt   <= 320;
          st_readout      <= Conf_wr_process;
        
        when Conf_wr_process =>
          s_timeout_cnt    <= s_timeout_cnt - 1;
          if s_channel < 64*5 - 1 then
            s_channel     <= s_channel + 1;
          else
            s_channel     <= (others => '0');
          end if;
          if s_sync_dil = '1' then
            s_fcode     <= C_RESET_CHAIN;
            st_readout  <= Rst_chain_start;
          end if;
        
-------------------------------------------------------------------------------
------ Configuration read subFSM ----------------------------------------------

        when Conf_rd_start =>
          s_fcode         <= C_CONFIG_READ;
          s_timeout_cnt   <= 320;
          st_readout      <= Conf_rd_process;
        
        when Conf_rd_process =>
          s_timeout_cnt    <= s_timeout_cnt - 1;
          if s_sync_dil = '1' then
            s_fcode       <= C_RESET_CHAIN;
            st_readout    <= Rst_chain_start;
          end if;
          
        when others =>
          null;
      end case;
    end if;
  end process;

end architecture;
