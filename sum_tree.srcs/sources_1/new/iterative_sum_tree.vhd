--FPGA
--Autor: Gustavo Oliveira Alves
--Lista 2 - Mentoria

--BIBLIOTECAS:
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.MATH_REAL.ALL; -- fun��es log2 e ceil

--ENTIDADE:
ENTITY iterative_sum_tree IS
    GENERIC (
        N : integer := 8; -- N�mero de elementos a serem somados
        M : integer := 8  -- Largura em bits de cada elemento
    );
    PORT (
        clk     : IN  STD_LOGIC;
        rst     : IN  STD_LOGIC;
        data_in : IN  STD_LOGIC_VECTOR(N * M - 1 DOWNTO 0);
        sum_out : OUT STD_LOGIC_VECTOR(M + INTEGER(CEIL(LOG2(REAL(N)))) - 1 DOWNTO 0)
    );
END ENTITY iterative_sum_tree;

ARCHITECTURE Comportamento OF iterative_sum_tree IS

    -- 1. CONSTANTES E TIPOS
    --------------------------
    -- N�mero de est�gios do pipeline. Ex: N=8 -> log2(8)=3 est�gios.
    CONSTANT NUM_STAGES : INTEGER := INTEGER(CEIL(LOG2(REAL(N))));

    -- Largura final do somador. Ex: N=8, M=8 -> 8 + 3 = 11 bits.
    CONSTANT FINAL_WIDTH : INTEGER := M + NUM_STAGES;

    -- Declara��o do componente que ser� instanciado.
    COMPONENT pipelined_adder is
        GENERIC (
            DATA_WIDTH : INTEGER := 8
        );
        PORT (
            clk     : IN  STD_LOGIC;
            rst     : IN  STD_LOGIC;
            a_in    : IN  STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);
            b_in    : IN  STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);
            sum_out : OUT STD_LOGIC_VECTOR(DATA_WIDTH DOWNTO 0)
        );
    END component pipelined_adder;

    -- Tipo para um array de vetores. Usado para conectar os est�gios.
    -- Todos os vetores s�o declarados com a largura m�xima (FINAL_WIDTH) para
    TYPE t_stage_level IS ARRAY (0 TO N - 1) OF STD_LOGIC_VECTOR(FINAL_WIDTH - 1 DOWNTO 0);
    
    -- Array 2D para conter os sinais de todos os est�gios do pipeline.
    -- s_pipeline_levels(s)(i) � o i-�simo sinal no est�gio s.
    TYPE t_pipeline_stages IS ARRAY (0 TO NUM_STAGES) OF t_stage_level;
    SIGNAL s_pipeline_levels : t_pipeline_stages;


BEGIN

    -- EST�GIO 0: DESEMPACOTAMENTO DA ENTRADA
    -- Este 'generate' pega o vetor de entrada 'data_in' e o divide em N
    -- vetores de M bits, que formar�o as entradas do primeiro est�gio da �rvore.
    gen_input_unpack: FOR i IN 0 TO N - 1 GENERATE
        -- Pega a fatia correspondente ao i-�simo n�mero
        ALIAS input_slice : STD_LOGIC_VECTOR(M - 1 DOWNTO 0) IS data_in((i + 1) * M - 1 DOWNTO i * M);
    BEGIN
        -- Armazena no primeiro n�vel do nosso array de sinais, redimensionando para a largura m�xima.
        s_pipeline_levels(0)(i) <= STD_LOGIC_VECTOR(RESIZE(UNSIGNED(input_slice), FINAL_WIDTH));
    END GENERATE gen_input_unpack;


    --GERA��O DA �RVORE DE SOMA PIPELINED
    -------------------------------------------
    -- Este � o generate principal. Ele itera atrav�s dos est�gios da �rvore (s de 0 a NUM_STAGES-1).
    gen_adder_stages: FOR s IN 0 TO NUM_STAGES - 1 GENERATE
        -- Calcula quantos operandos e quantos somadores temos neste est�gio.
        -- Ex: N=8, Est�gio s=0: 8 entradas, 4 somadores.
        -- Ex: N=8, Est�gio s=1: 4 entradas, 2 somadores.
        -- Ex: N=8, Est�gio s=2: 2 entradas, 1 somador.
        CONSTANT num_inputs_at_stage : INTEGER := INTEGER(CEIL(REAL(N) / (2.0**REAL(s))));
        CONSTANT num_adders_at_stage : INTEGER := num_inputs_at_stage / 2;
        CONSTANT current_width       : INTEGER := M + s;

    BEGIN

        -- Gera as inst�ncias dos somadores para o est�gio 's'.
        gen_adders: FOR i IN 0 TO num_adders_at_stage - 1 GENERATE
            
            -- Instancia o nosso bloco somador pipelined.
            adder_inst: COMPONENT pipelined_adder
                GENERIC MAP (
                    DATA_WIDTH => current_width -- A largura aumenta a cada est�gio.
                )
                PORT MAP (
                    clk     => clk,
                    rst     => rst,
                    -- Operandos v�m do est�gio anterior (s).
                    a_in    => s_pipeline_levels(s)(2 * i)      (current_width - 1 DOWNTO 0),
                    b_in    => s_pipeline_levels(s)(2 * i + 1)  (current_width - 1 DOWNTO 0),
                    -- Sa�da vai para o pr�ximo est�gio (s+1).
                    sum_out => s_pipeline_levels(s + 1)(i)      (current_width DOWNTO 0)
                );
        END GENERATE gen_adders;

        -- Se houver um n�mero �mpar de operandos no est�gio atual, o �ltimo
        -- operando precisa passar para o pr�ximo est�gio para manter o pipeline sincronizado.
        -- Para isso, passamos por um registrador (um pipeline de 1 est�gio).
        gen_passthrough_register: IF (num_inputs_at_stage mod 2 /= 0) GENERATE
            
            -- O operando "solit�rio" � o �ltimo da lista.
            ALIAS passthrough_input : STD_LOGIC_VECTOR(current_width - 1 DOWNTO 0) IS 
                s_pipeline_levels(s)(num_inputs_at_stage - 1)(current_width - 1 DOWNTO 0);
        
        BEGIN
            -- Processo que atua como um registrador para manter a lat�ncia igual � dos somadores.
            passthrough: PROCESS(clk, rst)
            BEGIN
                IF (rst = '1') THEN
                    s_pipeline_levels(s + 1)(num_adders_at_stage) <= (OTHERS => '0');
                ELSIF (rising_edge(clk)) THEN
                    -- Redimensiona e passa para o pr�ximo est�gio.
                    s_pipeline_levels(s + 1)(num_adders_at_stage) <= STD_LOGIC_VECTOR(RESIZE(UNSIGNED(passthrough_input), FINAL_WIDTH));
                END IF;
            END PROCESS passthrough;

        END GENERATE gen_passthrough_register;

    END GENERATE gen_adder_stages;

   -- ATRIBUI��O FINAL DA SA�DA
    
    -- A sa�da final � o resultado do primeiro (e �nico) somador do �ltimo est�gio.
    sum_out <= s_pipeline_levels(NUM_STAGES)(0)(sum_out'RANGE);

END Comportamento;