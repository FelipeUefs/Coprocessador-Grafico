module unidade_de_controle (
    input  wire        clk,
    input  wire        reset,         // Ativo em baixo (~KEY[0])
    input  wire        btn_change,    // Botão de troca de estado (~KEY[1])
    input  wire        btn_rect,      // Botão liga/desliga retangulo (~KEY[2])
    input  wire        btn_tri,       // Botão liga/desliga triangulo (~KEY[3])
    input  wire        fim_de_quadro, // Pulso de sincronismo da tela
    input  wire [7:0]  sw,            // Chaves da placa

    output reg  [8:0]  bg_scroll_x,
    output reg  [7:0]  bg_scroll_y,
    output reg  [8:0]  boneco_x,
    output reg  [7:0]  boneco_y,
    output reg  [7:0]  cor_de_fundo,
    output reg  [7:0]  rect_color,    // Cor de preenchimento do retangulo
    output reg  [7:0]  tri_color,     // Cor de preenchimento do triangulo
    output reg         rect_visible,  // Alterna (toggle) a cada aperto de btn_rect
    output reg         tri_visible,   // Alterna (toggle) a cada aperto de btn_tri
    output wire        is_tile_mode   // NOVO: Indica se estamos no modo de edição de tile
);

    // =========================================================================
    // Limites de posicao do sprite (16x16) dentro da tela logica 320x240
    // MAX_X = 320 - 16 = 304 ; MAX_Y = 240 - 16 = 224
    // =========================================================================
    localparam [8:0] SPRITE_MAX_X = 9'd304;
    localparam [7:0] SPRITE_MAX_Y = 8'd224;

    // Definição dos Estados (Adicionado STATE_TILE_EDIT)
    parameter STATE_SCROLL     = 3'd0;
    parameter STATE_SPRITE     = 3'd1;
    parameter STATE_RECT_COLOR = 3'd2;
    parameter STATE_TRI_COLOR  = 3'd3;
    parameter STATE_TILE_EDIT  = 3'd4; // Novo modo de edição de tile

    reg [2:0] current_state;
    reg       btn_last_state;
    wire      btn_pressed = (btn_change && !btn_last_state);

    // Detecção de borda de subida para os botões de retângulo/triângulo
    reg       btn_rect_last, btn_tri_last;
    wire      btn_rect_pressed = (btn_rect && !btn_rect_last);
    wire      btn_tri_pressed  = (btn_tri  && !btn_tri_last);

    // Sinaliza quando estamos no estado de edição de tile
    assign is_tile_mode = (current_state == STATE_TILE_EDIT);

    always @(posedge clk) begin
        if (~reset) begin
            current_state  <= STATE_SCROLL;
            btn_last_state <= 1'b0;
            btn_rect_last  <= 1'b0;
            btn_tri_last   <= 1'b0;
            rect_visible   <= 1'b0;
            tri_visible    <= 1'b0;

            bg_scroll_x  <= 9'd0;
            bg_scroll_y  <= 8'd0;
            boneco_x     <= 9'd160;
            boneco_y     <= 8'd120;
            cor_de_fundo <= 8'd0;
            rect_color   <= 8'd1;  
            tri_color    <= 8'd2;  
        end else begin
            // 1. Gerenciamento do Botão e Transição de Estados (Ciclo de 0 a 4)
            btn_last_state <= btn_change;

            if (btn_pressed) begin
                if (current_state == STATE_TILE_EDIT)
                    current_state <= STATE_SCROLL;
                else
                    current_state <= current_state + 3'd1;
            end

            // 1b. Alterna visibilidade do retângulo/triângulo a cada aperto
            btn_rect_last <= btn_rect;
            btn_tri_last  <= btn_tri;
            if (btn_rect_pressed) rect_visible <= ~rect_visible;
            if (btn_tri_pressed)  tri_visible  <= ~tri_visible;

            // 2. Roteamento das Chaves (SW) baseado no Estado Atual
            if (fim_de_quadro) begin
                case (current_state)
                    STATE_SCROLL: begin
                        // Eixo X (Largura de 320 pixels: 0 a 319)
                        if (sw[0]) begin // Direita
                            if (bg_scroll_x >= 9'd319)
                                bg_scroll_x <= 9'd0;
                            else
                                bg_scroll_x <= bg_scroll_x + 9'd1;
                        end
                        if (sw[1]) begin // Esquerda
                            if (bg_scroll_x == 9'd0)
                                bg_scroll_x <= 9'd319;
                            else
                                bg_scroll_x <= bg_scroll_x - 9'd1;
                        end

                        // Eixo Y (Altura de 240 pixels: 0 a 239)
                        if (sw[2]) begin // Baixo
                            if (bg_scroll_y >= 8'd239)
                                bg_scroll_y <= 8'd0;
                            else
                                bg_scroll_y <= bg_scroll_y + 8'd1;
                        end
                        if (sw[3]) begin // Cima
                            if (bg_scroll_y == 8'd0)
                                bg_scroll_y <= 8'd239;
                            else
                                bg_scroll_y <= bg_scroll_y - 8'd1;
                        end
                    end
                    STATE_SPRITE: begin
                        if (sw[0] && ~sw[1] && (boneco_x < SPRITE_MAX_X))
                            boneco_x <= boneco_x + 9'd1;
                        if (sw[1] && ~sw[0] && (boneco_x > 9'd0))
                            boneco_x <= boneco_x - 9'd1;

                        if (sw[2] && ~sw[3] && (boneco_y < SPRITE_MAX_Y))
                            boneco_y <= boneco_y + 8'd1; // Baixo
                        if (sw[3] && ~sw[2] && (boneco_y > 8'd0))
                            boneco_y <= boneco_y - 8'd1; // Cima
                    end

                    STATE_RECT_COLOR: begin
                        rect_color <= sw[3:0];
                    end

                    STATE_TRI_COLOR: begin
                        tri_color <= sw[3:0];
                    end

                    STATE_TILE_EDIT: begin
                        // Nenhuma ação interna necessária aqui nas chaves, 
                        // pois o top_coprocessador interceptará as chaves para o Swap da Lua.
                    end
                endcase
            end
        end
    end

endmodule