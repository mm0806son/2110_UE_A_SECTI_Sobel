----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 16.11.2021 09:14:23
-- Design Name: 
-- Module Name: sobel_coproc - Behavioral
-- Project Name: Sobel Processer
-- Version v2.0
-- @modified by Zijie NING & Guoxiong SUN
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
USE IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY sobel_coproc IS
    GENERIC (
        -- implementation parameters
        CONSTANT FILTER_SIZE : NATURAL := 3;
        CONSTANT PIXEL_BW : NATURAL := 8;
        CONSTANT IMAGE_WIDTH : NATURAL := 100;
        CONSTANT IMAGE_HEIGHT : NATURAL := 100
    );
    PORT (
        clk : IN STD_LOGIC; --clock
        rst_n : IN STD_LOGIC; --reset (active low)
        t_valid_in : IN STD_LOGIC; --data coming?
        t_ready_in : OUT STD_LOGIC; --ready to receive?
        t_data_in : IN STD_LOGIC_VECTOR (PIXEL_BW - 1 DOWNTO 0); --input data
        interrupt_out : OUT STD_LOGIC; --activate for 1 clock period when one line is finished
        t_valid_out : OUT STD_LOGIC; --data in the register?
        t_ready_out : IN STD_LOGIC; --data is read? 
        t_data_out : OUT STD_LOGIC_VECTOR (PIXEL_BW - 1 DOWNTO 0)); --data register
END sobel_coproc;

ARCHITECTURE Behavioral OF sobel_coproc IS

    COMPONENT ImageBuffer IS
        GENERIC (
            CONSTANT FILTER_SIZE : NATURAL;
            CONSTANT PIXEL_BW : NATURAL;
            CONSTANT IMAGE_WIDTH : NATURAL;
            CONSTANT IMAGE_HEIGHT : NATURAL
        );
        PORT (
            clk : IN STD_LOGIC;
            rst_n : IN STD_LOGIC;
            pixel_in : IN STD_LOGIC_VECTOR (PIXEL_BW - 1 DOWNTO 0); --8 bit to store 1 pix
            valid_in : IN STD_LOGIC;
            neighbourhood_out : OUT STD_LOGIC_VECTOR (9 * PIXEL_BW - 1 DOWNTO 0); --72
            valid_out : OUT STD_LOGIC
        );
    END COMPONENT ImageBuffer;

    SIGNAL t_valid_out_s : STD_LOGIC;
    SIGNAL neighbourhood_out : STD_LOGIC_VECTOR (9 * PIXEL_BW - 1 DOWNTO 0);
    SIGNAL Gh : INTEGER RANGE 0 TO 1023;
    SIGNAL Gv : INTEGER RANGE 0 TO 1023;
    SIGNAL gradient : INTEGER RANGE 0 TO 2047 := 0;
    CONSTANT threshold : INTEGER RANGE 0 TO 2047 := 255;
    SIGNAL ImageBuffer_valid_out : STD_LOGIC;
    SIGNAL read_count : INTEGER RANGE 0 TO IMAGE_WIDTH := 0; --counter of pixels read
BEGIN

    ImageBuffer_0 : ImageBuffer
    GENERIC MAP(
        FILTER_SIZE => FILTER_SIZE,
        PIXEL_BW => PIXEL_BW,
        IMAGE_WIDTH => IMAGE_WIDTH,
        IMAGE_HEIGHT => IMAGE_HEIGHT
    )
    PORT MAP(
        clk => clk,
        rst_n => rst_n,
        --input
        pixel_in => t_data_in,
        valid_in => t_valid_in,
        --output
        neighbourhood_out => neighbourhood_out,
        valid_out => ImageBuffer_valid_out
    );

    sobel : PROCESS (clk, rst_n)
        VARIABLE A, B, C, D, F, G, H, I : INTEGER;
    BEGIN
        IF (rst_n = '0') THEN --reset
            t_valid_out_s <= '0'; --register is vide
            t_data_out <= (OTHERS => '0'); --clear the register
            read_count <= 0;
            interrupt_out <= '0';

        ELSIF (rising_edge(clk)) THEN
            --IF (ImageBuffer_valid_out = '1' AND (t_valid_out_s = '0' OR t_ready_out = '1')) THEN --data coming & (register is vide | data in the register is already read)
            IF (ImageBuffer_valid_out = '1') THEN --data coming
                t_valid_out_s <= '1'; --data in the register

                IF (read_count = IMAGE_WIDTH - FILTER_SIZE) THEN
                    interrupt_out <= '1';
                    read_count <= 0;
                ELSE
                    read_count <= read_count + 1;
                    interrupt_out <= '0';
                END IF;

                A := to_integer(unsigned(neighbourhood_out(7 DOWNTO 0)));
                B := to_integer(unsigned(neighbourhood_out(15 DOWNTO 8)));
                C := to_integer(unsigned(neighbourhood_out(23 DOWNTO 16)));
                D := to_integer(unsigned(neighbourhood_out(31 DOWNTO 24)));
                F := to_integer(unsigned(neighbourhood_out(47 DOWNTO 40)));
                G := to_integer(unsigned(neighbourhood_out(55 DOWNTO 48)));
                H := to_integer(unsigned(neighbourhood_out(63 DOWNTO 56)));
                I := to_integer(unsigned(neighbourhood_out(71 DOWNTO 64)));
                Gh <= - A - 2 * D - G + C + 2 * F + I;
                Gv <= A + 2 * B + C - G - 2 * H - I;
                gradient <= ABS(Gh) + ABS(Gv);

                IF (gradient > threshold) THEN
                    t_data_out <= "11111111"; --save output data (a write pixel) in the register
                ELSE
                    t_data_out <= "00000000"; --a black pixel
                END IF;
            ELSIF (t_ready_out = '1') THEN --data in the register is already read
                t_valid_out_s <= '0'; --register is vide
            END IF;
        END IF;

    END PROCESS sobel;

    t_ready_in <= NOT t_valid_out_s; --ready to read when register is vide
    t_valid_out <= t_valid_out_s;

END Behavioral;