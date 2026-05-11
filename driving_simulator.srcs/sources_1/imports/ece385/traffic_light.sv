module startup_screen(
    input  logic        pixel_clk,
    input  logic        reset,
    input  logic [9:0]  DrawX, DrawY,
    input  logic [11:0] sprite_pixel_from_buffer,
    output logic [11:0] pixel_out,
    output logic        traffic_light_off,
    output logic        traffic_pixel_on  
);

    // ============================================================
    // Sprite size / position
    // ============================================================

    localparam int SPRITE_W = 640;
    localparam int SPRITE_H = 210;

    localparam int X_OFFSET = 0;
    localparam int Y_OFFSET = 0;

    logic in_sprite;
    logic [17:0] sprite_addr;
//    logic [11:0] sprite_pixel;
    
    logic [31:0] clk_per_init;

    assign in_sprite =
        (DrawX >= X_OFFSET) &&
        (DrawX <  X_OFFSET + SPRITE_W) &&
        (DrawY >= Y_OFFSET) &&
        (DrawY <  Y_OFFSET + SPRITE_H);

    assign sprite_addr =
        (DrawY - Y_OFFSET) * SPRITE_W + (DrawX - X_OFFSET);


    // ============================================================
    // ROM for background image
    // ============================================================

    logic [11:0] mem [0:134399];

    initial begin
        $readmemh("f1_gantry_640w_full_rgb444.txt", mem);
    end

    logic [11:0] sprite_pixel;

    always_comb begin
        if (in_sprite)
            sprite_pixel = mem[sprite_addr];
        else
            sprite_pixel = 12'h000;
    end


    // ============================================================
    // F1 light timing
    // ============================================================

    localparam int CLK_PER_STEP = 12_500_000;  // 0.5 sec if pixel_clk = 25MHz
    localparam int CLK_PER_INIT = 75_000_000;

    logic [31:0] counter;
    logic [2:0] phase;

always_ff @(posedge pixel_clk or posedge reset) begin
    if (reset) begin
        counter <= 32'd0;
        phase <= 3'd0;
        traffic_light_off <= 1'b0;
        clk_per_init <= CLK_PER_INIT;
    end else if (!traffic_light_off) begin
        if (counter >= CLK_PER_STEP - 1 + clk_per_init) begin
            counter <= 32'd0;
            clk_per_init <= 0;

            if (phase < 3'd6)
                phase <= phase + 3'd1;
            else
                traffic_light_off <= 1'b1;
        end else begin
            counter <= counter + 32'd1;
        end
    end
end


    // ============================================================
    // Dynamic light overlay
    // Coordinates are relative to sprite top-left
    // You may tune these values slightly if needed
    // ============================================================

    logic signed [11:0] local_x, local_y;

    assign local_x = $signed({1'b0, DrawX}) - X_OFFSET;
    assign local_y = $signed({1'b0, DrawY}) - Y_OFFSET;

    localparam int LIGHT_Y = 173;
    localparam int LIGHT_R = 13;

    localparam int L0_X = 223;
    localparam int L1_X = 272;
    localparam int L2_X = 319;
    localparam int L3_X = 367;
    localparam int L4_X = 414;

    logic [4:0] in_light;
    logic [4:0] light_on;

    function automatic logic in_circle(
        input logic signed [11:0] x,
        input logic signed [11:0] y,
        input int cx,
        input int cy,
        input int r
    );
        logic signed [11:0] dx;
        logic signed [11:0] dy;
        logic [23:0] dist_sq;
        begin
            dx = x - cx;
            dy = y - cy;
            dist_sq = dx * dx + dy * dy;
            in_circle = dist_sq <= r * r;
        end
    endfunction

    always_comb begin
        in_light[0] = in_sprite && in_circle(local_x, local_y, L0_X, LIGHT_Y, LIGHT_R);
        in_light[1] = in_sprite && in_circle(local_x, local_y, L1_X, LIGHT_Y, LIGHT_R);
        in_light[2] = in_sprite && in_circle(local_x, local_y, L2_X, LIGHT_Y, LIGHT_R);
        in_light[3] = in_sprite && in_circle(local_x, local_y, L3_X, LIGHT_Y, LIGHT_R);
        in_light[4] = in_sprite && in_circle(local_x, local_y, L4_X, LIGHT_Y, LIGHT_R);
    end

    always_comb begin
    case (phase)
        3'd0: light_on = 5'b11111; 
        3'd1: light_on = 5'b01111; 
        3'd2: light_on = 5'b00111;
        3'd3: light_on = 5'b00011;
        3'd4: light_on = 5'b00001;
        3'd5: light_on = 5'b00000; 
        3'd6: light_on = 5'b11111; 
        default: light_on = 5'b00000;
    endcase
end


    // ============================================================
    // Final pixel
    // ============================================================

    always_comb begin
        if (in_sprite && sprite_pixel != 12'h001)
        begin
            pixel_out = sprite_pixel;
            traffic_pixel_on = 1'b1;
       end else begin
            pixel_out = 12'h000;
            traffic_pixel_on = 1'b0;
       end

        for (int i = 0; i < 5; i++) begin
            if (in_light[i]) begin
                if (light_on[i])
                    pixel_out = 12'hF00;   // bright red
                else
                    pixel_out = 12'h200;   // dark red / off
            end
        end
    end

endmodule