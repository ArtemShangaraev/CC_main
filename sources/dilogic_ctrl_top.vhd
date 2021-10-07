-------------------------------------------------------------------------------
-- Title      : Top level of Dilogic control
-- Project    : Column Controller CPV
-------------------------------------------------------------------------------
-- File       : dilogic_ctrl_top.vhd
-- Author     : Artem Shangaraev <artem.shangaraev@cern.ch>
-- Company    : NRC "Kurchatov institute" - IHEP
-- Created    : 2020-02-18
-- Last update: 2021-04-07
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

Library IEEE;
Use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity dilogic_ctrl_top is
  port (
    arst            : in std_logic;
    
    -- LVDS clock domain
    CLK_FAST        : in std_logic;
    
    -- RAM for thresholds
    ram_addr_i      : in  std_logic_vector(8 downto 0);
    ram_data_i      : in  std_logic_vector(8 downto 0);
    ram_wren_i      : in  std_logic;
    ram_select_i    : in  unsigned (1 downto 0);
    
    -- FEE clock domain
    CLK_SLOW        : in  std_logic;
    trigger_i       : in  std_logic;
    data_ready_i    : in  std_logic;
    accept_data_i   : in  std_logic;
    reject_data_i   : in  std_logic;
    read_conf_i     : in  std_logic;
    write_conf_i    : in  std_logic;
    check_status_i  : in  std_logic;
    
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
    DATAOUT_o       : out std_logic_vector(127 downto 0);
    CTRL_o          : out std_logic_vector(31 downto 0)
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
    Waiting,
    Wait_for_accept,
    Wait_to_read,
    Wait_to_clear,
    Analog_rd_start,
    Analog_rd_process,
    Rst_chain_start,
    Rst_chain_end,
    Rst_fifo_start,
    Rst_fifo_end,
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
  signal s_ctrl_word      : std_logic_vector (31 downto 0) := (others => '1');
  signal s_event_started  : std_logic := '0';
  
  signal s_data_reg       : std_logic_vector (71 downto 0) := (others => '0');
  signal s_data_rdy_delay : std_logic_vector (3 downto 0) := x"0";
  signal s_data_rdy_reg   : std_logic_vector (3 downto 0) := x"0";
  
  signal s_channel        : unsigned (8 downto 0) := (others => '0');
  signal s_ch_addr        : std_logic_vector (8 downto 0) := (others => '0');

  signal s_rst_cnt        : natural range 0 to 7 := 0;
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
  
  constant c_card_id      : std_logic_vector (7 downto 0) := 
            "11" & "10" & "01" & "00";
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
  s_enout_n       <= ENOUT_N_i;
  s_data_from_dil <= DATA_FROM_DIL_i;
  
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
        rdclock   => CLK_SLOW,
        wraddress => ram_addr_i,
        wrclock   => CLK_FAST,
        wren      => s_wren,
        q         => s_thr_value
      );
  
    s_thr_to_dil(17 downto 9) <= s_thr_value;
    s_thr_to_dil(8 downto 0)  <= (others => '0');
  
    INST_DIL_CTRL: entity work.one_dilogic_ctrl
      port map (
        arst              => arst,
        CLK               => CLK_SLOW,
        FCODE_i           => s_fcode,
        RDY_o             => s_dil_rdy(i),
        SYNC_i            => s_sync_dil,
        TIMEOUT_i         => s_timeout,
        RST_o             => s_dil_rst(i),
        STRIN_o           => s_strin(i),
        ENIN_N_o          => s_enin_n(i),
        ENOUT_N_i         => s_enout_n(5*i+4 downto 5*i),
        DIL_ID_o          => s_dil_id(3*i+2 downto 3*i),
        DATA_FROM_DIL_i   => s_data_from_dil(18*i+17 downto 18*i),
        DATA_TO_DIL_o     => s_data_to_dil(18*i+17 downto 18*i),
        THR_TO_DIL_i      => s_thr_to_dil,
        DATA_TO_FABRIC_o  => s_data_to_fabric(18*i+17 downto 18*i),
        DATA_RDY_o        => s_data_rdy(i)
      );
    
      
    s_dil_ena(i) <= '1' when st_readout = Conf_wr_start
                        or st_readout = Conf_wr_process
                      else '0';
    
  end generate DIL_CTRL_GEN;
  
-------------------------------------------------------------------------------
------ Control words generation -----------------------------------------------

  CTRL_ENABLE: process (CLK_SLOW, arst)
  begin
    if arst = '1' then
      s_event_started <= '0';
    elsif rising_edge(CLK_SLOW) then
      if accept_data_i = '1' then
        s_event_started <= '1';
      elsif st_readout = Rst_chain_end then
        s_event_started <= '0';
      end if;
    end if;
  end process CTRL_ENABLE;
  
  CTRL_WORDS: process (CLK_SLOW, arst)
  begin
    if arst = '1' then
      s_ctrl_word <= (others => '1');
    elsif rising_edge(CLK_SLOW) then
      if check_status_i = '1' then
        s_ctrl_word <= x"C1FFFFFF";
      elsif accept_data_i = '1' then
        s_ctrl_word <= x"A1FFFFFF";
      elsif st_readout = Rst_chain_end and s_event_started = '1'then
        s_ctrl_word <= x"B1FFFFFF";
      else
        s_ctrl_word <= (others => '1');
      end if;
    end if;
  end process CTRL_WORDS;
  
  CTRL_o  <= s_ctrl_word;
  
-------------------------------------------------------------------------------
------ Output data from 5Dilogics. Data only ----------------------------------

-- -- Don't use this part! It is special firmware for CC(23) with bad FEE
--  DIL_DATA_OUT_0: process (CLK_SLOW, arst)
--  
--    variable v_enout_cnt: natural range 0 to 31 := 0;
--  
--  begin
--    if arst = '1' then
--      DATAOUT_o(31 downto 0)  <= (others => '0');
--      DATA_RDY_o(0)   <= '0';
--      v_enout_cnt     := 0;
--    elsif rising_edge(CLK_SLOW) then
--    
--      v_enout_cnt := 5 * to_integer(unsigned(c_card_id(1 downto 0)))
--                       + to_integer(unsigned(s_dil_id(2 downto 0)));
--    
--      s_data_rdy_reg(0)               <= s_data_rdy(0);
--      s_data_rdy_delay(0)             <= s_data_rdy_reg(0);
--      s_data_reg(17 downto 0) <= 
--          s_data_to_fabric(17 downto 0);
--      
--      if s_dil_id(2 downto 0) = "000" or
--         s_dil_id(2 downto 0) = "001" then
--        DATA_RDY_o(0)   <= '0';
--      else
--        if s_data_rdy_delay(0) = '1' and s_data_rdy_reg(0) = '1' then
--          DATA_RDY_o(0)   <= '1';
--        else
--          DATA_RDY_o(0)   <= '0';
--        end if;
--      end if;
--      
--      if s_data_rdy_reg(0) = '1' then
----            DATAOUT_o(32*i+31 downto 32*i)  <= 
----              x"0" & 
----              s_fcode & 
----              s_mack(i) &
----              c_card_id(2*i+1 downto 2*i) & 
----              s_dil_id(3*i+2 downto 3*i) & 
----              s_data_reg(18*i+17 downto 18*i);
--        if s_enout_n(v_enout_cnt) = '1' then
--          DATAOUT_o(31 downto 0)  <= 
--            x"0" & 
--            s_fcode & 
--            "0" & --s_mack(i) &
--            c_card_id(1 downto 0) & 
--            s_dil_id(2 downto 0) & 
--            s_data_reg(17 downto 0);
--        else
--          DATAOUT_o(31 downto 0)  <= 
--            x"0" & 
--            s_fcode & 
--            "1" & --s_mack(i) &
--            c_card_id(1 downto 0) & 
--            s_dil_id(2 downto 0) & 
--            s_data_reg(17 downto 0);
--        end if;
--      else
--        DATAOUT_o(31 downto 0)  <= (others => '0');
--      end if;
--    end if;
--  end process;
--  
  DIL_DATA_GEN : for i in 0 to 3 generate
    
    DIL_DATA_OUT: process (CLK_SLOW, arst)
    
--      variable v_enout_cnt: natural range 0 to 31 := 0;
    
    begin
      if arst = '1' then
        DATAOUT_o(32*i+31 downto 32*i)  <= (others => '0');
        DATA_RDY_o(i)   <= '0';
--        v_enout_cnt     := 0;
      elsif rising_edge(CLK_SLOW) then
      
--        v_enout_cnt := 5 * to_integer(unsigned(c_card_id(2*i+1 downto 2*i)))
--                         + to_integer(unsigned(s_dil_id(3*i+2 downto 3*i)));
      
        s_data_rdy_reg(i)               <= s_data_rdy(i);
        s_data_rdy_delay(i)             <= s_data_rdy_reg(i);
        s_data_reg(18*i+17 downto 18*i) <= 
            s_data_to_fabric(18*i+17 downto 18*i);
        
        if s_data_rdy_delay(i) = '1' and s_data_rdy_reg(i) = '1' then
          DATA_RDY_o(i)   <= '1';
        else
          DATA_RDY_o(i)   <= '0';
        end if;
        
        if s_data_rdy_reg(i) = '1' then
            DATAOUT_o(32*i+31 downto 32*i)  <= 
              x"0" & 
              s_fcode & 
              s_mack(i) &
              c_card_id(2*i+1 downto 2*i) & 
              s_dil_id(3*i+2 downto 3*i) & 
              s_data_reg(18*i+17 downto 18*i);
--          if s_enout_n(v_enout_cnt) = '1' then
----            DATAOUT_o(32*i+31 downto 32*i)  <= 
----              x"0" & 
----              s_fcode & 
----              s_mack(i) &
----              c_card_id(2*i+1 downto 2*i) & 
----              s_dil_id(3*i+2 downto 3*i) & 
----              s_data_reg(18*i+17 downto 18*i);
----            DATAOUT_o(32*i+31 downto 32*i)  <= 
----              x"0" & 
----              s_fcode & 
----              "0" & --s_mack(i) &
----              c_card_id(2*i+1 downto 2*i) & 
----              s_dil_id(3*i+2 downto 3*i) & 
----              "01" & x"47D1"; -- constant channel 20 with amplitude 2001
--              DATAOUT_o(32*i+31 downto 32*i)  <= 
--                x"0" & 
--                s_fcode & 
--                "0" & --s_mack(i) &
--                c_card_id(2*i+1 downto 2*i) & 
--                s_dil_id(3*i+2 downto 3*i) & 
--                s_data_reg(18*i+17 downto 18*i); -- constant channel 20 with amplitude 2001
--          else
--            DATAOUT_o(32*i+31 downto 32*i)  <= 
--              x"0" & 
--              s_fcode & 
--              "1" & --s_mack(i) &
--              c_card_id(2*i+1 downto 2*i) & 
--              s_dil_id(3*i+2 downto 3*i) & 
--              s_data_reg(18*i+17 downto 18*i);
--          end if;
        else
          DATAOUT_o(32*i+31 downto 32*i)  <= (others => '0');
        end if;
      end if;
    end process;
  
  end generate DIL_DATA_GEN;
  
  s_ch_addr <= std_logic_vector(s_channel);
  
-------------------------------------------------------------------------------
------ Readout control and sync FSM -------------------------------------------

  READOUT_FSM: process (CLK_SLOW, arst)
  begin
    if arst = '1' then
      s_fcode       <= C_IDLE;
      s_channel     <= (others => '0');
      s_timeout_cnt <= 0;
      s_rst_cnt     <= 0;
      st_readout    <= Reset;
      
    elsif rising_edge(CLK_SLOW) then
      
      case st_readout is
        when Reset =>
          st_readout      <= Conf_wr_start; -- Clear the threshold memory
          
        when Idle =>
          s_fcode       <= C_IDLE;
          s_channel     <= (others => '0');
          s_timeout_cnt <= 0;
          s_rst_cnt     <= 0;
          if write_conf_i = '1' then
            st_readout  <= Conf_wr_start;
          elsif read_conf_i = '1' then
            st_readout  <= Conf_rd_start;
          elsif trigger_i = '1' then
            st_readout  <= Waiting;
          else
            st_readout  <= Idle;
          end if;
          
-------------------------------------------------------------------------------
------ Waiting data and decision subFSM ---------------------------------------

        when Waiting =>
          if data_ready_i = '1' then
            if accept_data_i = '1' then
              st_readout  <= Analog_rd_start;
            elsif reject_data_i = '1' then
              s_fcode     <= C_RESET_FIFO;
              st_readout  <= Rst_fifo_start;
            else
              st_readout  <= Wait_for_accept;
            end if;
          elsif accept_data_i = '1' then
            st_readout    <= Wait_to_read;
          elsif reject_data_i = '1' then
            st_readout    <= Wait_to_clear;
          else
            st_readout    <= Waiting;
          end if;
        
        when Wait_for_accept =>
          if accept_data_i = '1' then
            st_readout    <= Analog_rd_start;
          elsif reject_data_i = '1' then
            s_fcode       <= C_RESET_FIFO;
            st_readout    <= Rst_fifo_start;
          else
            st_readout  <= Wait_for_accept;
          end if;
        
        when Wait_to_read =>
          if data_ready_i = '1' then
            st_readout    <= Analog_rd_start;
          end if;
        
        when Wait_to_clear =>
          if data_ready_i = '1' then
            s_fcode       <= C_RESET_FIFO;
            st_readout    <= Rst_fifo_start;
          end if;
        
-------------------------------------------------------------------------------
------ Analog read subFSM -----------------------------------------------------

        when Analog_rd_start =>
          s_fcode       <= C_ANALOG_READ;
          s_timeout_cnt <= 253;
          st_readout    <= Analog_rd_process;
        
        when Analog_rd_process =>
          s_timeout_cnt <= s_timeout_cnt - 1;
          if s_sync_dil = '1' then
            s_fcode     <= C_RESET_CHAIN;
            st_readout  <= Rst_chain_start;
          end if;
          
-------------------------------------------------------------------------------
------ Reset daisy chain subFSM -----------------------------------------------

        when Rst_chain_start =>
          s_fcode       <= C_RESET_CHAIN;
          if s_rst_cnt < 2 then
            s_rst_cnt   <= s_rst_cnt + 1;
          else
            st_readout  <= Rst_chain_end;
          end if;
        
        when Rst_chain_end =>
          st_readout    <= Idle;
        
-------------------------------------------------------------------------------
------ Reset FIFO pointer subFSM ----------------------------------------------

        when Rst_fifo_start =>
          s_fcode       <= C_RESET_FIFO;
          if s_rst_cnt < 2 then
            s_rst_cnt   <= s_rst_cnt + 1;
          else
            st_readout  <= Rst_fifo_end;
          end if;
        
        when Rst_fifo_end =>
          s_fcode     <= C_RESET_CHAIN;
          st_readout  <= Rst_chain_start;
--          st_readout    <= Idle;
        
-------------------------------------------------------------------------------
------ Configuration write subFSM ---------------------------------------------

        when Conf_wr_start =>
          s_fcode       <= C_CONFIG_WRITE;
          s_timeout_cnt <= 320;
          st_readout    <= Conf_wr_process;
        
        when Conf_wr_process =>
          s_timeout_cnt <= s_timeout_cnt - 1;
          if s_channel < 64*5 - 1 then
            s_channel   <= s_channel + 1;
          else
            s_channel   <= (others => '0');
          end if;
          if s_sync_dil = '1' then
            s_fcode     <= C_RESET_CHAIN;
            st_readout  <= Rst_chain_start;
          end if;
        
-------------------------------------------------------------------------------
------ Configuration read subFSM ----------------------------------------------

        when Conf_rd_start =>
          s_fcode       <= C_CONFIG_READ;
          s_timeout_cnt <= 320;
          st_readout    <= Conf_rd_process;
        
        when Conf_rd_process =>
          s_timeout_cnt <= s_timeout_cnt - 1;
          if s_sync_dil = '1' then
            s_fcode     <= C_RESET_CHAIN;
            st_readout  <= Rst_chain_start;
          end if;
          
        when others =>
          null;
      end case;
    end if;
  end process;

end architecture;
