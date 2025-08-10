--FPGA
--Autor: Gustavo Oliveira Alves
--Lista 2 - Mentoria

--BIBLIOTECAS:
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.MATH_REAL.ALL; -- funções log2 e ceil

--ENTIDADE:
ENTITY iterative_sum_tree IS
    GENERIC (
        N : integer := 8; -- Número de elementos a serem somados
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
    -- Número de estágios do pipeline. Ex: N=8 -> log2(8)=3 estágios.
    CONSTANT NUM_STAGES : INTEGER := INTEGER(CEIL(LOG2(REAL(N))));

    -- Largura final do somador. Ex: N=8, M=8 -> 8 + 3 = 11 bits.
    CONSTANT FINAL_WIDTH : INTEGER := M + NUM_STAGES;

    -- Declaração do componente que será instanciado.
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

    -- Tipo para um array de vetores. Usado para conectar os estágios.
    -- Todos os vetores são declarados com a largura máxima (FINAL_WIDTH) para
    TYPE t_stage_level IS ARRAY (0 TO N - 1) OF STD_LOGIC_VECTOR(FINAL_WIDTH - 1 DOWNTO 0);
    
    -- Array 2D para conter os sinais de todos os estágios do pipeline.
    -- s_pipeline_levels(s)(i) é o i-ésimo sinal no estágio s.
    TYPE t_pipeline_stages IS ARRAY (0 TO NUM_STAGES) OF t_stage_level;
    SIGNAL s_pipeline_levels : t_pipeline_stages;


BEGIN

    -- ESTÁGIO 0: DESEMPACOTAMENTO DA ENTRADA
    -- Este 'generate' pega o vetor de entrada 'data_in' e o divide em N
    -- vetores de M bits, que formarão as entradas do primeiro estágio da árvore.
    gen_input_unpack: FOR i IN 0 TO N - 1 GENERATE
        -- Pega a fatia correspondente ao i-ésimo número
        ALIAS input_slice : STD_LOGIC_VECTOR(M - 1 DOWNTO 0) IS data_in((i + 1) * M - 1 DOWNTO i * M);
    BEGIN
        -- Armazena no primeiro nível do nosso array de sinais, redimensionando para a largura máxima.
        s_pipeline_levels(0)(i) <= STD_LOGIC_VECTOR(RESIZE(UNSIGNED(input_slice), FINAL_WIDTH));
    END GENERATE gen_input_unpack;


    --GERAÇÃO DA ÁRVORE DE SOMA PIPELINED
    -------------------------------------------
    -- Este é o generate principal. Ele itera através dos estágios da árvore (s de 0 a NUM_STAGES-1).
    gen_adder_stages: FOR s IN 0 TO NUM_STAGES - 1 GENERATE
        -- Calcula quantos operandos e quantos somadores temos neste estágio.
        -- Ex: N=8, Estágio s=0: 8 entradas, 4 somadores.
        -- Ex: N=8, Estágio s=1: 4 entradas, 2 somadores.
        -- Ex: N=8, Estágio s=2: 2 entradas, 1 somador.
        CONSTANT num_inputs_at_stage : INTEGER := INTEGER(CEIL(REAL(N) / (2.0**REAL(s))));
        CONSTANT num_adders_at_stage : INTEGER := num_inputs_at_stage / 2;
        CONSTANT current_width       : INTEGER := M + s;

    BEGIN

        -- Gera as instâncias dos somadores para o estágio 's'.
        gen_adders: FOR i IN 0 TO num_adders_at_stage - 1 GENERATE
            
            -- Instancia o nosso bloco somador pipelined.
            adder_inst: COMPONENT pipelined_adder
                GENERIC MAP (
                    DATA_WIDTH => current_width -- A largura aumenta a cada estágio.
                )
                PORT MAP (
                    clk     => clk,
                    rst     => rst,
                    -- Operandos vêm do estágio anterior (s).
                    a_in    => s_pipeline_levels(s)(2 * i)      (current_width - 1 DOWNTO 0),
                    b_in    => s_pipeline_levels(s)(2 * i + 1)  (current_width - 1 DOWNTO 0),
                    -- Saída vai para o próximo estágio (s+1).
                    sum_out => s_pipeline_levels(s + 1)(i)      (current_width DOWNTO 0)
                );
        END GENERATE gen_adders;

        -- Se houver um número ímpar de operandos no estágio atual, o último
        -- operando precisa passar para o próximo estágio para manter o pipeline sincronizado.
        -- Para isso, passamos por um registrador (um pipeline de 1 estágio).
        gen_passthrough_register: IF (num_inputs_at_stage mod 2 /= 0) GENERATE
            
            -- O operando "solitário" é o último da lista.
            ALIAS passthrough_input : STD_LOGIC_VECTOR(current_width - 1 DOWNTO 0) IS 
                s_pipeline_levels(s)(num_inputs_at_stage - 1)(current_width - 1 DOWNTO 0);
        
        BEGIN
            -- Processo que atua como um registrador para manter a latência igual à dos somadores.
            passthrough: PROCESS(clk, rst)
            BEGIN
                IF (rst = '1') THEN
                    s_pipeline_levels(s + 1)(num_adders_at_stage) <= (OTHERS => '0');
                ELSIF (rising_edge(clk)) THEN
                    -- Redimensiona e passa para o próximo estágio.
                    s_pipeline_levels(s + 1)(num_adders_at_stage) <= STD_LOGIC_VECTOR(RESIZE(UNSIGNED(passthrough_input), FINAL_WIDTH));
                END IF;
            END PROCESS passthrough;

        END GENERATE gen_passthrough_register;

    END GENERATE gen_adder_stages;

   -- ATRIBUIÇÃO FINAL DA SAÍDA
    
    -- A saída final é o resultado do primeiro (e único) somador do último estágio.
    sum_out <= s_pipeline_levels(NUM_STAGES)(0)(sum_out'RANGE);

END Comportamento;