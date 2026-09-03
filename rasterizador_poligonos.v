module rasterizador_poligonos (
    input  wire        clk,
    input  wire        reset,
    
    input  wire [8:0]  logical_x,
    input  wire [7:0]  logical_y,
    
    // Parâmetros do Retângulo
    input  wire        rect_enable,
    input  wire [8:0]  rect_x0,
    input  wire [7:0]  rect_y0,
    input  wire [8:0]  rect_x1,
    input  wire [7:0]  rect_y1,
    input  wire [7:0]  rect_color,
    
    // Parâmetros do Triângulo 
    input  wire        tri_enable,
    input  wire signed [9:0] tri_x0,
    input  wire signed [8:0] tri_y0,
    input  wire signed [9:0] tri_x1,
    input  wire signed [8:0] tri_y1,
    input  wire signed [9:0] tri_x2,
    input  wire signed [8:0] tri_y2,
    input  wire [7:0]  tri_color,
    
    output reg  [7:0]  poly_color_index,
    output reg         poly_active
);

    wire is_inside_rect;
    assign is_inside_rect = rect_enable &&
                           (logical_x >= rect_x0) && (logical_x <= rect_x1) &&
                           (logical_y >= rect_y0) && (logical_y <= rect_y1);

    wire signed [9:0] px = {1'b0, logical_x};
    wire signed [8:0] py = {1'b0, logical_y};

    // Vetores de diferença
    wire signed [10:0] dx01 = tri_x1 - tri_x0;
    wire signed [9:0]  dy01 = tri_y1 - tri_y0;
    wire signed [10:0] dx12 = tri_x2 - tri_x1;
    wire signed [9:0]  dy12 = tri_y2 - tri_y1;
    wire signed [10:0] dx20 = tri_x0 - tri_x2;
    wire signed [9:0]  dy20 = tri_y0 - tri_y2;

    // Funções de aresta: E(x, y) = (x - x0)*dy - (y - y0)*dx
    wire signed [20:0] e01 = (px - tri_x0) * dy01 - (py - tri_y0) * dx01;
    wire signed [20:0] e12 = (px - tri_x1) * dy12 - (py - tri_y1) * dx12;
    wire signed [20:0] e20 = (px - tri_x2) * dy20 - (py - tri_y2) * dx20;

    // Ponto interno se tiver o mesmo sinal nas 3 arestas
    wire is_ccw = (e01 >= 0) && (e12 >= 0) && (e20 >= 0);
    wire is_cw  = (e01 <= 0) && (e12 <= 0) && (e20 <= 0);
    wire is_inside_tri = tri_enable && (is_ccw || is_cw);


    always @(posedge clk or posedge reset) begin
        if (reset) begin
            poly_color_index <= 8'd0;
            poly_active      <= 1'b0;
        end else begin
            if (is_inside_tri && tri_color != 8'd0) begin
                poly_color_index <= tri_color;
                poly_active      <= 1'b1;
            end else if (is_inside_rect && rect_color != 8'd0) begin
                poly_color_index <= rect_color;
                poly_active      <= 1'b1;
            end else begin
                poly_color_index <= 8'd0; // Índice 0 = Transparente
                poly_active      <= 1'b0;
            end
        end
    end

endmodule