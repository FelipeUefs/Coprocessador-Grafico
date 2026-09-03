// ============================================================
// tb_vga_ppm.v
// Testbench de SIMULAÇÃO (não entra na síntese/gravação na placa).
// Captura um frame inteiro (640x480) da saída VGA do coprocessador
// e grava em um arquivo .ppm, pra você conferir a imagem antes de
// gastar tempo de compilação + gravação na DE1-SoC.
// ============================================================
`timescale 1ns/1ps

module tb_vga_ppm;

    // ---------------------------------------------------------------
    // 1. Sinais de estímulo (o que você controlaria com KEY/SW na placa)
    // ---------------------------------------------------------------
    reg        clock = 1'b0;
    reg        reset = 1'b0;      // ATIVO EM BAIXO (igual ao KEY0 físico)
    reg [3:1]  botoes = 3'b111;   // 1 = solto (botões são ativo-baixo)
    
    // CORRIGIDO: Chaves iniciam em 255 (cor sólida) para evitar o índice 0 (transparente)
    reg [9:0]  sw = 10'd255;      

    wire hsync, vsync, blank, sync, clk_out;
    wire [7:0] red, green, blue;

    // ---------------------------------------------------------------
    // 2. Instancia o DUT (Device Under Test) = o seu coprocessador
    // ---------------------------------------------------------------
    top_coprocessador dut (
        .clock  (clock),
        .reset  (reset),
        .botoes (botoes),
        .sw     (sw),
        .hsync  (hsync),
        .vsync  (vsync),
        .red    (red),
        .green  (green),
        .blue   (blue),
        .clk    (clk_out),
        .blank  (blank),
        .sync   (sync)
    );

    // Clock de 50 MHz (mesmo clock da DE1-SoC) -> período de 20ns
    always #10 clock = ~clock;

    // ---------------------------------------------------------------
    // 3. Buffer de imagem: 640x480 pixels, 3 bytes (R,G,B) cada
    // ---------------------------------------------------------------
    reg [7:0] frame_buf [0:640*480*3-1];
    integer   count;
    integer   px;
    integer   fd;

    initial begin
        // 3a. Segura o reset ativo por um tempo, depois libera
        reset = 1'b0;
        repeat (10) @(posedge clock);
        reset = 1'b1;

        // 3b. (Opcional) monta o cenário antes de capturar:
        //     aqui a gente liga o retângulo e o triângulo, já que
        //     por padrão eles começam invisíveis (rect_visible/tri_visible = 0)
        repeat (20) @(posedge clock);
        botoes[2] = 1'b0; repeat (4) @(posedge clock); botoes[2] = 1'b1; // toggle retângulo
        botoes[3] = 1'b0; repeat (4) @(posedge clock); botoes[3] = 1'b1; // toggle triângulo

        // 3c. Espera alguns frames pra tudo estabilizar (pipeline, sprites, etc.)
        repeat (3) @(posedge vsync);

        // 3d. Início de um frame novo -> começa a capturar
        @(posedge vsync);
        count = 0;
        while (count < 640*480) begin
            @(posedge dut.clk_25m); // avança um pixel lógico (25MHz)
            // só grava a amostra quando estamos DENTRO da área ativa
            // (mesma condição que o vga_driver já usa internamente)
            if (dut.u_driver.h_state == dut.u_driver.H_ACTIVE_STATE &&
                dut.u_driver.v_state == dut.u_driver.V_ACTIVE_STATE) begin
                frame_buf[count*3+0] = red;
                frame_buf[count*3+1] = green;
                frame_buf[count*3+2] = blue;
                count = count + 1;
            end
        end

        // ---------------------------------------------------------------
        // 4. Escreve o arquivo .ppm (formato P3 = texto, fácil de entender)
        // ---------------------------------------------------------------
        fd = $fopen("saida_vga.ppm", "w");
        $fdisplay(fd, "P3");            // "P3" = PPM em texto (RGB ASCII)
        $fdisplay(fd, "640 480");       // largura x altura
        $fdisplay(fd, "255");           // valor máximo por canal
        for (px = 0; px < 640*480; px = px + 1) begin
            $fdisplay(fd, "%0d %0d %0d",
                frame_buf[px*3+0], frame_buf[px*3+1], frame_buf[px*3+2]);
        end
        $fclose(fd);

        $display("========================================");
        $display(" saida_vga.ppm gerado com sucesso!");
        $display("========================================");
        $stop;
    end

endmodule