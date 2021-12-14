--!
--! @file   tb_sobel.vhd
--! @author Stefan Weithoffer (stefan.weithoffer@imt-atlantique.fr)
--! Version v2.0
--! @modified by Zijie NING & Guoxiong SUN

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY std;
USE std.textio.ALL;

USE work.pkg_csv_reader.ALL;
ENTITY tb_sobel IS
    GENERIC (
        -- general
        CHECK_ERROR_LEVEL : severity_level := note;

        CLOCK_PERIOD : TIME := 10.00 ns;
        CLK_EXTRA_DELAY : TIME := 0 ns;

        -- implementation parameters
        CONSTANT FILTER_SIZE : NATURAL := 3;
        CONSTANT PIXEL_BW : NATURAL := 8;
        CONSTANT IMAGE_WIDTH : NATURAL := 10;
        CONSTANT IMAGE_HEIGHT : NATURAL := 10

    );
END ENTITY tb_sobel;
ARCHITECTURE sim OF tb_sobel IS

    TYPE t_image_row IS ARRAY (0 TO IMAGE_WIDTH - 1) OF INTEGER RANGE 0 TO 255;
    TYPE t_image IS ARRAY (0 TO IMAGE_HEIGHT - 1) OF t_image_row;

    SIGNAL input_image : t_image;
    SIGNAL reference_image : t_image;
    SIGNAL output_image : t_image;

    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL rst_n : STD_LOGIC := '0';
    CONSTANT CLK_HALF : TIME := CLOCK_PERIOD / 2;
    SIGNAL clk_en : STD_LOGIC := '1';

    --
    -- ADAPT TO YOUR COMPONENT HERE IF NECESSARY
    --
    COMPONENT sobel_coproc IS
        GENERIC (
            CONSTANT FILTER_SIZE : NATURAL;
            CONSTANT PIXEL_BW : NATURAL := 8;
            CONSTANT IMAGE_WIDTH : NATURAL := 100;
            CONSTANT IMAGE_HEIGHT : NATURAL := 100
        );
        PORT (
            clk : IN STD_LOGIC;
            rst_n : IN STD_LOGIC;

            -- AXIS Input Interface
            t_valid_in : IN STD_LOGIC;
            t_ready_in : OUT STD_LOGIC;
            t_data_in : IN STD_LOGIC_VECTOR(PIXEL_BW - 1 DOWNTO 0);

            -- AXIS Output Interface
            t_valid_out : OUT STD_LOGIC;
            t_ready_out : IN STD_LOGIC;
            t_data_out : OUT STD_LOGIC_VECTOR(PIXEL_BW - 1 DOWNTO 0);

            interrupt_out : OUT STD_LOGIC
        );
    END COMPONENT sobel_coproc;

    SIGNAL t_valid_in : STD_LOGIC := '0';
    SIGNAL t_ready_in : STD_LOGIC;
    SIGNAL t_data_in : STD_LOGIC_VECTOR(PIXEL_BW - 1 DOWNTO 0);
    SIGNAL t_valid_out : STD_LOGIC;
    SIGNAL t_ready_out : STD_LOGIC := '0';
    SIGNAL t_data_out : STD_LOGIC_VECTOR(PIXEL_BW - 1 DOWNTO 0);
    SIGNAL interrupt_out : STD_LOGIC;
    SIGNAL input_i : INTEGER RANGE 0 TO IMAGE_HEIGHT - 1 := 0;
    SIGNAL input_k : INTEGER RANGE 0 TO IMAGE_WIDTH - 1 := 0;
    SIGNAL output_i : INTEGER RANGE 0 TO IMAGE_HEIGHT - 3 := 0;
    SIGNAL output_k : INTEGER RANGE 0 TO IMAGE_WIDTH - 3 := 0;

    SIGNAL cpt : INTEGER RANGE 0 TO IMAGE_WIDTH * IMAGE_HEIGHT;

BEGIN

    -- ========================================
    -- Clock-Generator
    -- ========================================

    clk <= clk NAND clk_en AFTER CLK_HALF;
    -- ==========================================
    -- Read the configuration and the data files
    -- ==========================================

    pr_data_loader : PROCESS
        VARIABLE v_csv : csv_file_reader_type;
        VARIABLE v_image : t_image;
        VARIABLE v_int : INTEGER;
    BEGIN
        WAIT UNTIL clk = '1';
        WAIT FOR 4 * CLK_HALF;

        -- Change here to the proper path and name of the input image
        v_csv.initialize("/homes/z20ning/Bureau/UE_A_SECTI/supplementary_materials/IMT_LOGO_100x100.csv");
        --		v_csv.initialize("IMT_LOGO_100x100.csv");
        input_row_loop : FOR i IN 0 TO IMAGE_WIDTH - 1 LOOP
            v_csv.readline;
            input_column_loop : FOR k IN 0 TO IMAGE_HEIGHT - 1 LOOP
                v_image(i)(k) := v_csv.read_integer;
            END LOOP;
        END LOOP;
        v_csv.dispose;
        input_image <= v_image;

        -- Change here to the proper path and name of the reference image
        v_csv.initialize("/homes/z20ning/Bureau/UE_A_SECTI/supplementary_materials/IMT_LOGO_100x100_reference.csv");
        --		v_csv.initialize("IMT_LOGO_100x100_reference.csv");
        reference_row_loop : FOR i IN 0 TO IMAGE_WIDTH - 1 LOOP
            v_csv.readline;
            reference_column_loop : FOR k IN 0 TO IMAGE_HEIGHT - 1 LOOP
                v_image(i)(k) := v_csv.read_integer;
            END LOOP;
        END LOOP;
        v_csv.dispose;
        reference_image <= v_image;

        --output_image <= v_image;

        WAIT FOR 2 * CLK_HALF;

        WAIT; -- forever, after data is loaded
    END PROCESS;
    -- ==========================================
    -- Test Outputs
    -- ==========================================

    pr_verif : PROCESS
        --        variable v_ref : std_logic_vector(NUM_STATES*BW_SM_CALC-1 downto 0);
    BEGIN
        WAIT UNTIL clk = '1';
        WAIT FOR 14 * CLK_HALF;

        --
        -- USE ASSERT STATEMENTS TO TEST OUTPUT OF THE DESIGN UNDER TEST
        -- AGAINST THE REFERENCE IMAGE
        --
        ASSERT output_image /= reference_image REPORT "Correct" SEVERITY note;
        ASSERT output_image = reference_image REPORT "Wrong" SEVERITY note;

        -- assert false report "Simulation Finished!" severity failure;
    END PROCESS;

    --    Input : PROCESS (clk, rst_n)
    --    BEGIN
    --        IF (rst_n = '0') THEN --reset
    --            -- t_valid_in <= '0';
    --            -- t_ready_out <= '0';
    --            t_data_in <= (OTHERS => '0');
    --        ELSIF (rising_edge(clk) AND (t_ready_in = '1')) THEN
    --            t_data_in <= STD_LOGIC_VECTOR(to_unsigned(input_image(input_i)(input_k), 8));
    --            IF (input_k < IMAGE_WIDTH - 1) THEN
    --                input_k <= input_k + 1;
    --            ELSE
    --                input_k <= 0;
    --                IF (input_i < IMAGE_HEIGHT - 1) THEN
    --                    input_i <= input_i + 1;
    --                ELSE
    --                    input_i <= 0;
    --                END IF;
    --            END IF;

    --        END IF;

    --    END PROCESS Input;

    Output : PROCESS (clk, rst_n)
    BEGIN
        IF (rst_n = '0') THEN --reset
            output_image <= (OTHERS => (OTHERS => 0));
        ELSIF (rising_edge(clk)) THEN
            IF (t_ready_out = '1') AND (t_valid_out = '1') THEN
                output_image(output_i)(output_k) <= to_integer(unsigned(t_data_out));
                IF (output_k < IMAGE_WIDTH - 1) THEN
                    output_k <= output_k + 1;
                ELSE
                    output_k <= 0;
                    IF (output_i < IMAGE_HEIGHT - 1) THEN
                        output_i <= output_i + 1;
                    ELSE
                        output_i <= 0;
                    END IF;
                END IF;
            END IF;
        END IF;

    END PROCESS Output;

    -- ========================================
    -- Design under Test (DUT)
    -- ========================================

    PROCESS (clk, rst_n)
    BEGIN
        IF (rst_n = '0') THEN
            cpt <= 0;
            t_valid_in <= '1';
        ELSIF rising_edge(clk) THEN
            IF cpt < IMAGE_WIDTH * IMAGE_HEIGHT THEN
                cpt <= cpt + 1;
            ELSE
                t_valid_in <= '0';
            END IF;
        END IF;
    END PROCESS;

    t_data_in <= STD_LOGIC_VECTOR(to_unsigned(cpt, PIXEL_BW));

    DUT : sobel_coproc
    GENERIC MAP(
        FILTER_SIZE => FILTER_SIZE,
        PIXEL_BW => PIXEL_BW,
        IMAGE_WIDTH => IMAGE_WIDTH,
        IMAGE_HEIGHT => IMAGE_HEIGHT
    )
    PORT MAP(
        clk => clk,
        rst_n => rst_n,

        -- AXIS Input Interface
        t_valid_in => t_valid_in,
        t_ready_in => t_ready_in,
        t_data_in => t_data_in,

        -- AXIS Output Interface
        t_valid_out => t_valid_out,
        t_ready_out => t_ready_out,
        t_data_out => t_data_out,

        interrupt_out => interrupt_out);

    -- clock generation
    rst_n <= '0', '1' AFTER 100ns;
    --    t_valid_in <= NOT t_valid_in AFTER 30ns;
    t_ready_out <= NOT t_ready_out AFTER 50ns;
    --t_ready_out <= '1';

END ARCHITECTURE sim;