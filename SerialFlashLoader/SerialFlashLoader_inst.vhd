	component SerialFlashLoader is
		port (
			noe_in : in std_logic := 'X'  -- noe
		);
	end component SerialFlashLoader;

	u0 : component SerialFlashLoader
		port map (
			noe_in => CONNECTED_TO_noe_in  -- noe_in.noe
		);

