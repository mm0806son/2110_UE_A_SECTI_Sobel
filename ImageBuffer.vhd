----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 24.11.2021 08:44:34
-- Design Name: 
-- Module Name: ImageBuffer - Behavioral
-- Project Name: Sobel Processer
-- Version v2.2
-- modified by Zijie NING & Guoxiong SUN
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

ENTITY ImageBuffer IS
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

END ImageBuffer;

ARCHITECTURE Behavioral OF ImageBuffer IS

    COMPONENT LineBuffer IS
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
            data_out : OUT STD_LOGIC_VECTOR (FILTER_SIZE * PIXEL_BW - 1 DOWNTO 0);
            read_en : IN STD_LOGIC
        );
    END COMPONENT LineBuffer;

    --    SIGNAL data_out_0, data_out_1, data_out_2, data_out_3 : STD_LOGIC_VECTOR(3 * PIXEL_BW - 1 DOWNTO 0); --output of each linebuffer
    TYPE T_DATA_OUT IS ARRAY (0 TO FILTER_SIZE) OF STD_LOGIC_VECTOR(FILTER_SIZE * PIXEL_BW - 1 DOWNTO 0);
    SIGNAL data_out : T_DATA_OUT;
    SIGNAL read_en : STD_LOGIC_VECTOR(FILTER_SIZE DOWNTO 0); --valid write for each linebuffer
    SIGNAL read_not_en_ptr, LineBuffer_rd_ptr : INTEGER RANGE 0 TO FILTER_SIZE; -- (1 DOWNTO 0) := "00"; --which buffer will be read
    SIGNAL LineBuffer_wr_ptr : STD_LOGIC_VECTOR (1 DOWNTO 0) := "00"; --which buffer will be written
    SIGNAL count_read : INTEGER RANGE 0 TO IMAGE_WIDTH - FILTER_SIZE := 0; --which pixel to read in the line
    SIGNAL count_write : INTEGER RANGE 0 TO IMAGE_WIDTH - 1 := 0; --which pixel to write in the line
    SIGNAL count_read_line : INTEGER RANGE 0 TO IMAGE_HEIGHT - 1 := 0; --which line to read
    SIGNAL count_write_line : INTEGER RANGE 0 TO IMAGE_HEIGHT - 1 := 0; --which line to write

    SIGNAL read_en_s, write_en_s, write_en : STD_LOGIC_VECTOR(FILTER_SIZE DOWNTO 0); --output of each linebuffer
    SIGNAL write_en_p : STD_LOGIC; --protection
BEGIN
    G_LineBuffer : FOR i IN 0 TO FILTER_SIZE GENERATE
        inst_LineBuffer : LineBuffer
        GENERIC MAP(
            FILTER_SIZE => FILTER_SIZE,
            PIXEL_BW => PIXEL_BW,
            IMAGE_WIDTH => IMAGE_WIDTH,
            IMAGE_HEIGHT => IMAGE_HEIGHT
        )
        PORT MAP(
            clk => clk,
            rst_n => rst_n,
            pixel_in => pixel_in,
            valid_in => write_en(i),
            data_out => data_out(i),
            read_en => read_en(i)
        );
    END GENERATE G_LineBuffer;

    -- ========================================
    -- increment_write_en_s
    -- When a line is full and new data is entered from outside, 
    -- the written linebuffer is modified by cyclically shifting 
    -- all data in write_en_s one bit to the left.
    -- This is done by taking the value of write_en_s(FILTER_SIZE) 
    -- from write_en_s and placing it in write_en_s(0), shifting the 
    -- rest of the value one bit to the left.
    -- ========================================
    increment_write_en_s : PROCESS (clk, rst_n)
    BEGIN
        IF (rst_n = '0') THEN
            write_en_s <= (0 => '1', OTHERS => '0');
        ELSIF rising_edge(clk) THEN
            IF (count_write = IMAGE_WIDTH - 1) AND valid_in = '1' THEN -- move to next linebuffer when writing finished
                write_en_s <= write_en_s(FILTER_SIZE - 1 DOWNTO 0) & write_en_s(FILTER_SIZE);
            END IF;
        END IF;
    END PROCESS increment_write_en_s;

    -- ========================================
    -- proc_write
    -- Activates the specific Linebuffer used.
    -- To avoid overwriting the part being read by writing too fast.
    -- The difference between the number of lines written and the number 
    -- of lines read must not exceed FILTER_SIZE lines, except for the 
    -- first few lines. If the above conditions are met and new data is 
    -- entered, activate the Linebuffer according to the parameters changed 
    -- by increment_write_in_s
    -- ========================================
    proc_write : PROCESS (write_en, valid_in, count_write_line, count_read_line)
    BEGIN
        FOR i IN 0 TO FILTER_SIZE LOOP
            IF (count_write_line - count_read_line) <= 3 OR (count_write_line <= 3) THEN
                write_en(i) <= (write_en_s(i) AND valid_in);
            ELSE
                write_en(i) <= '0';
            END IF;
        END LOOP;

    END PROCESS proc_write;

    -- ========================================
    -- increment_count_write
    -- Record how many lines of data have been read so far.
    -- ========================================
    increment_count_write : PROCESS (clk, rst_n)
    BEGIN
        IF (rst_n = '0') THEN
            count_write <= 0;
            count_write_line <= 0;
            -- LineBuffer_wr_ptr <= "00";
        ELSIF rising_edge(clk) THEN
            IF valid_in = '1' THEN
                IF (count_write = IMAGE_WIDTH - 1) THEN
                    count_write <= 0;

                    IF (count_write_line < IMAGE_HEIGHT) THEN
                        count_write_line <= count_write_line + 1;
                    ELSE
                        count_write_line <= IMAGE_HEIGHT;
                    END IF;
                ELSE
                    count_write <= count_write + 1;
                END IF;
            END IF;
        END IF;

    END PROCESS increment_count_write;

    read_not_en_ptr <= LineBuffer_rd_ptr - 1 WHEN LineBuffer_rd_ptr > 0 ELSE --point to the linebuffer which is not used
        FILTER_SIZE;

    -- ========================================
    -- proc_read
    -- Activates the specific Linebuffer used.
    -- However, unlike before, the writing section uses only 
    -- one Linebuffer, while the reading section uses three.
    -- When the edge of an image line is read, the next 
    -- Linebuffer usage is determined by considering all cases,
    -- based on the current Linebuffer usage.
    -- ========================================
    proc_read : PROCESS (read_not_en_ptr, LineBuffer_rd_ptr, data_out, count_read_line, count_write_line)
    BEGIN

        IF (count_write_line - count_read_line >= FILTER_SIZE) THEN

            read_en <= (OTHERS => '1');
            read_en(read_not_en_ptr) <= '0';

            CASE LineBuffer_rd_ptr IS
                WHEN 0 =>
                    neighbourhood_out <= data_out(0) & data_out(1) & data_out(2);
                WHEN 1 =>
                    neighbourhood_out <= data_out(1) & data_out(2) & data_out(3);
                WHEN 2 =>
                    neighbourhood_out <= data_out(2) & data_out(3) & data_out(0);
                WHEN 3 =>
                    neighbourhood_out <= data_out(3) & data_out(0) & data_out(1);
                WHEN OTHERS =>
                    neighbourhood_out <= (OTHERS => '0');
            END CASE;
        ELSE
            read_en <= (OTHERS => '0');
            neighbourhood_out <= (OTHERS => '0');
        END IF;
    END PROCESS proc_read;

    valid_out <= '1' WHEN unsigned(read_en) > 0 ELSE
        '0';

    -- ========================================
    -- increment_LineBuffer_rd_ptr
    -- Activates the specific Linebuffer used.
    -- To avoid overwriting the part being read by writing too fast.
    -- The difference between the number of lines written and the number 
    -- of lines read must not exceed FILTER_SIZE lines, except for the 
    -- first few lines. If the above conditions are met and new data is 
    -- entered, activate the Linebuffer according to the parameters changed 
    -- by increment_write_in_s
    -- ========================================
    increment_LineBuffer_rd_ptr : PROCESS (clk, rst_n)
    BEGIN
        IF (rst_n = '0') THEN
            count_read <= 0;
            count_read_line <= 0;
            LineBuffer_rd_ptr <= 0;
        ELSIF rising_edge(clk) THEN
            IF (count_write_line - count_read_line >= FILTER_SIZE) THEN --same as proc_read
                IF (count_read = IMAGE_WIDTH - FILTER_SIZE) THEN
                    count_read <= 0;
                    IF (count_read_line < IMAGE_HEIGHT - FILTER_SIZE) THEN
                        count_read_line <= count_read_line + 1;
                    ELSE
                        count_read_line <= IMAGE_HEIGHT - FILTER_SIZE;
                    END IF;
                    IF LineBuffer_rd_ptr = FILTER_SIZE THEN
                        LineBuffer_rd_ptr <= 0;
                    ELSE
                        LineBuffer_rd_ptr <= LineBuffer_rd_ptr + 1;
                    END IF;

                ELSE
                    count_read <= count_read + 1;
                END IF;
            END IF;
        END IF;
    END PROCESS increment_LineBuffer_rd_ptr;
END Behavioral;