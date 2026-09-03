module motor_sprite (
    input  wire        clk,
    input  wire        reset,
    
    // Coordenadas lógicas da tela (320x240)
    input  wire [8:0]  logical_x,
    input  wire [7:0]  logical_y,

	 //Injeção de movimento para teste
	 input  wire [8:0]  sprite_x_in,
    input  wire [7:0]  sprite_y_in,
    input  wire        sprite_hflip_in, // Espelhamento horizontal do Sprite 0
    input  wire        sprite_vflip_in, // Espelhamento vertical do Sprite 0
	 
    // Interface com a ROM de Padrões (Tileset - Porta B)
    output wire [13:0] rom_addr,
    input  wire [7:0]  rom_data_in,

    // Saída para o Compositor de Camadas
    output reg  [7:0]  sprite_color_idx,
    output reg         sprite_active
);

    // =========================================================================
    // 1. OAM (Object Attribute Memory) - 32 Sprites
    // =========================================================================
    reg [8:0] oam_x      [0:31]; // Posição X (0 a 319)
    reg [7:0] oam_y      [0:31]; // Posição Y (0 a 239)
    reg [7:0] oam_tile   [0:31]; // Índice do desenho base na ROM
    reg       oam_enable [0:31]; // Sprite ligado/desligado
    reg       oam_hflip  [0:31]; // Espelhamento horizontal
    reg       oam_vflip  [0:31]; // Espelhamento vertical
    
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Limpa a memória RAM
            for (i = 0; i < 32; i = i + 1) begin
                oam_x[i]      <= 9'd0;
                oam_y[i]      <= 8'd0;
                oam_tile[i]   <= 8'd0;
                oam_enable[i] <= 1'b0;
                oam_hflip[i]  <= 1'b0;
                oam_vflip[i]  <= 1'b0;
            end
            
            // Habilita e define o tile do Sprite 0 (Centro) -- a nave (móvel)
            oam_tile[0]   <= 8'd32;
            oam_enable[0] <= 1'b1;
            
            // Sprite 1 -- alienígena, estático em (200,120)
            oam_x[1]      <= 9'd200;
            oam_y[1]      <= 8'd120;
            oam_tile[1]   <= 8'd36;
            oam_enable[1] <= 1'b1;

            // Sprite 2 -- asteroide, estático em (60,180)
            oam_x[2]      <= 9'd60;
            oam_y[2]      <= 8'd180;
            oam_tile[2]   <= 8'd40;
            oam_enable[2] <= 1'b1;
        end else begin
            // ATUALIZAÇÃO DINÂMICA: O Sprite 0 obedece ao Top-Level
            oam_x[0]     <= sprite_x_in;
            oam_y[0]     <= sprite_y_in;
            oam_hflip[0] <= sprite_hflip_in;
            oam_vflip[0] <= sprite_vflip_in;
        end
    end

    // =========================================================================
    // 2. HIT DETECTION E PRIORIDADE (Varredura Paralela)
    // =========================================================================
    reg       hit_found;
    reg [3:0] hit_dx;         // Deslocamento X dentro do sprite (0 a 15)
    reg [3:0] hit_dy;         // Deslocamento Y dentro do sprite (0 a 15)
    reg [7:0] hit_tile_base;  
    reg       hit_hflip;
    reg       hit_vflip;

    integer j;
    always @(*) begin
        hit_found     = 1'b0;
        hit_dx        = 4'd0;
        hit_dy        = 4'd0;
        hit_tile_base = 8'd0;
        hit_hflip     = 1'b0;
        hit_vflip     = 1'b0;
        
        // Loop de 31 a 0. Como o 0 é processado por último, ele sobrescreve 
        // os outros e ganha a prioridade mais alta em caso de sobreposição.
        for (j = 31; j >= 0; j = j - 1) begin
            if (oam_enable[j] && 
               (logical_x >= oam_x[j]) && (logical_x < oam_x[j] + 9'd16) &&
               (logical_y >= oam_y[j]) && (logical_y < oam_y[j] + 8'd16)) begin
                
                hit_found     = 1'b1;
                hit_dx        = logical_x - oam_x[j]; 
                hit_dy        = logical_y - oam_y[j]; 
                hit_tile_base = oam_tile[j];
                hit_hflip     = oam_hflip[j];
                hit_vflip     = oam_vflip[j];
            end
        end
    end

    // =========================================================================
    // 3. MATEMÁTICA DE MONTAGEM DO SPRITE 16x16 (com espelhamento)
    // =========================================================================
    // Espelhar é simplesmente inverter o deslocamento dentro do sprite (0..15).
    // Isso resolve os dois níveis de uma vez: troca qual dos 4 tiles 8x8 é lido
    // (quadrante) E espelha os pixels dentro do próprio tile.
    wire [3:0] eff_dx = hit_hflip ? (4'd15 - hit_dx) : hit_dx;
    wire [3:0] eff_dy = hit_vflip ? (4'd15 - hit_dy) : hit_dy;

    wire is_right_half  = eff_dx[3]; // X >= 8 (após espelhar)
    wire is_bottom_half = eff_dy[3]; // Y >= 8 (após espelhar)
    
    // Define qual dos 4 sub-blocos de 8x8 está sendo lido
    wire [7:0] actual_tile = hit_tile_base + (is_bottom_half ? 8'd2 : 8'd0) + (is_right_half ? 8'd1 : 8'd0);
    
    wire [2:0] pixel_x = eff_dx[2:0];
    wire [2:0] pixel_y = eff_dy[2:0];

    // Entrega o endereço para a ROM (Porta B) no top_vga
    assign rom_addr = {actual_tile, pixel_y, pixel_x};

    // =========================================================================
    // 4. PIPELINE (Sincronismo com a Latência da ROM)
    // =========================================================================
    reg hit_found_delay;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            hit_found_delay  <= 1'b0;
            sprite_active    <= 1'b0;
            sprite_color_idx <= 8'd0;
        end else begin
            // Atrasamos a constatação de Hit em 1 ciclo para aguardar a RAM cuspir a cor
            hit_found_delay  <= hit_found;
            
            // O Índice 0 representa a transparência
            if (hit_found_delay && rom_data_in != 8'd0) begin
                sprite_active    <= 1'b1;
                sprite_color_idx <= rom_data_in;
            end else begin
                sprite_active    <= 1'b0;
                sprite_color_idx <= 8'd0;
            end
        end
    end

endmodule