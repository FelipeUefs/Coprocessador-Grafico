module top_coprocessador (
    input  wire        clock,    // 50 MHz da DE1-SoC
    input  wire        reset,    // KEY0 da DE1-SoC
    input  wire [3:1]  botoes,
    input  wire [9:0]  sw,
    output wire        hsync,
    output wire        vsync,
    output wire [7:0]  red,
    output wire [7:0]  green,
    output wire [7:0]  blue,
    output wire        clk,
    output wire        blank,
    output wire        sync
);

    // =========================================================================
    // DIVISOR DE CLOCK E POWER-ON RESET (POR)
    // =========================================================================
    reg clk_25m = 1'b0;
    always @(posedge clock) begin
        clk_25m <= ~clk_25m;
    end

    reg [7:0] por_counter = 8'hFF; 
    always @(posedge clk_25m) begin
        if (por_counter != 8'd0) begin
            por_counter <= por_counter - 1'b1;
        end
    end

    wire global_reset = (~reset) | (por_counter != 8'd0);

    // =========================================================================
    // DECLARAÇÃO DOS FIOS 
    // =========================================================================
    wire [9:0] vga_next_x; 
    wire [9:0] vga_next_y; 
    wire [8:0] logical_x = vga_next_x[9:1]; 
    wire [7:0] logical_y = vga_next_y[8:1]; 
    
    wire [13:0] bkg_rom_addr;
    wire [7:0]  bkg_rom_data;
    wire [7:0]  bkg_color;

    wire [13:0] spr_rom_addr;
    wire [7:0]  spr_rom_data;
    wire [7:0]  spr_color;
    wire        spr_active;

    wire [7:0]  poly_color;
    wire        poly_active;
    wire [23:0] final_rgb;
    
    wire [8:0]  bg_scroll_x;
    wire [7:0]  bg_scroll_y;
    wire [8:0]  boneco_x;
    wire [7:0]  boneco_y;
    wire [7:0]  cor_de_fundo;
    wire [7:0]  rect_color_ctrl;
    wire [7:0]  tri_color_ctrl;
    wire        rect_visible;
    wire        tri_visible;
    wire        is_tile_mode; // Fio que recebe a indicação do modo atual da FSM

    wire fim_de_quadro = (logical_x == 9'd319) && (logical_y == 8'd239);

    // =========================================================================
    // COMPOSITOR DE CAMADAS
    // =========================================================================
    wire poligonos_visiveis = poly_active && (poly_color != 8'd0);
     
    wire [7:0] final_pixel_index = (spr_active && spr_color != 8'd0) ? spr_color :
                                    poligonos_visiveis               ? poly_color : 
                                   (bkg_color != 8'd0)               ? bkg_color  : 
                                                                       cor_de_fundo;

    // =========================================================================
    // INSTÂNCIAS DAS MEMÓRIAS
    // =========================================================================
    ram_tile u_bkg_tiles_rom (
        .clock     (clk_25m),
        .data      (8'd0),
        .rdaddress (bkg_rom_addr),
        .wraddress (14'd0),
        .wren      (1'b0),
        .q         (bkg_rom_data)
    );

    rom_memoria2 u_sprites_rom (
        .address_a (14'd0),
        .q_a       (),
        .address_b (spr_rom_addr),
        .q_b       (spr_rom_data),
        .clock     (clk_25m)
    );

    paleta_rom u_paleta (
        .clock   (clk_25m),
        .address (final_pixel_index),
        .q       (final_rgb)
    );
     
    // =========================================================================
    // MOTORES E UNIDADE DE CONTROLE
    // =========================================================================
    unidade_de_controle u_controle (
        .clk           (clk_25m),
        .reset         (~global_reset), 
        .btn_change    (~botoes[1]),
        .btn_rect      (~botoes[2]),
        .btn_tri       (~botoes[3]),
        .fim_de_quadro (fim_de_quadro),
        .sw            (sw[7:0]),          
        .bg_scroll_x   (bg_scroll_x),
        .bg_scroll_y   (bg_scroll_y),
        .boneco_x      (boneco_x),
        .boneco_y      (boneco_y),
        .cor_de_fundo  (cor_de_fundo),
        .rect_color    (rect_color_ctrl),
        .tri_color     (tri_color_ctrl),
        .rect_visible  (rect_visible),
        .tri_visible   (tri_visible),
        .is_tile_mode  (is_tile_mode) // Conecta a bandeira do novo modo aqui
    );
     
    vga_driver u_driver (
        .clock    (clk_25m),
        .reset    (global_reset),
        .color_in (final_rgb),
        .next_x   (vga_next_x),        
        .next_y   (vga_next_y),        
        .hsync    (hsync), 
        .vsync    (vsync), 
        .red      (red),   
        .green    (green), 
        .blue     (blue),  
        .sync     (sync),  
        .clk      (clk),   
        .blank    (blank)
    );

    background_renderer u_bkg_renderer (
        .clk         (clk_25m),
        .reset       (global_reset),
        .logic_x     (logical_x),
        .logic_y     (logical_y),
        .scroll_x    (bg_scroll_x), 
        .scroll_y    (bg_scroll_y), 
        .rom_addr    (bkg_rom_addr),   
        .rom_data_in (bkg_rom_data),
        .color_out   (bkg_color)
    );

    motor_sprite u_sprites ( 
        .clk              (clk_25m),
        .reset            (global_reset),
        .logical_x        (logical_x),
        .logical_y        (logical_y),
        .sprite_x_in      (boneco_x), 
        .sprite_y_in      (boneco_y), 
        .sprite_hflip_in  (sw[8]),   
        .sprite_vflip_in  (sw[9]),   
        .rom_addr         (spr_rom_addr),
        .rom_data_in      (spr_rom_data),
        .sprite_color_idx (spr_color),
        .sprite_active    (spr_active)
    );

    rasterizador_poligonos u_poly_raster (
        .clk              (clk_25m),
        .reset            (global_reset),
        .logical_x        (logical_x),
        .logical_y        (logical_y),
        .rect_enable      (rect_visible), 
        .rect_x0          (9'd20),  .rect_y0 (8'd40),
        .rect_x1          (9'd60),  .rect_y1 (8'd110),
        .rect_color       (rect_color_ctrl),
        .tri_enable       (tri_visible), 
        .tri_x0           (10'sd220), .tri_y0 (9'sd30),
        .tri_x1           (10'sd190), .tri_y1 (9'sd115),
        .tri_x2           (10'sd250), .tri_y2 (9'sd115),
        .tri_color        (tri_color_ctrl),
        .poly_color_index (poly_color),
        .poly_active      (poly_active)
    );

endmodule