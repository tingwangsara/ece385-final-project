module windshield_frame (
    input  logic        clk,
    input  logic        reset,
    input  logic [9:0]  DrawX,
    input  logic [9:0]  DrawY,
    input  logic        active_nblank,
    output logic        windshield_on,
    output logic [3:0] red,
    output logic [3:0] green,
    output logic [3:0] blue
);
    //For dashboard
    logic [18:0] dash_addr;
    logic [11:0] dash_ram_pixel;

    logic [11:0] windshield_pixel;   // {R[3:0], G[3:0], B[3:0]}

    localparam [9:0] SCREEN_W  = 10'd640;
    localparam [9:0] SCREEN_H  = 10'd480;

    //Windshield frame
    localparam [9:0] LEFT_W    = 10'd0;   // Left A-pillar width
    localparam [9:0] RIGHT_W   = 10'd0;   // Right A-pillar width
    localparam [9:0] TOP_H     = 10'd0;   // Roof height
    localparam [9:0] BOT_H     = 10'd128;  // Dashboard height Y = 360-479

    //Steering wheel parameters
//    localparam [9:0] SW_CX       = 10'd320;  // Wheel center X
//    localparam [9:0] SW_CY       = 10'd400;  // Wheel center Y
//    localparam [9:0] SW_R_OUT    = 10'd76;   // Outer radius of rim
//    localparam [9:0] SW_R_IN     = 10'd62;   // Inner boundary of rim
//    localparam [9:0] SW_HUB_R    = 10'd18;  // Hub outer radius
//    localparam [9:0] SW_HUB_R_IN = 10'd12;  // Hub inner radius
//    localparam [9:0] SW_DOT_R    = 10'd5;   // Center dot radius
//    localparam [9:0] SPOKE_W     = 10'd3;   // Half-width of spokes

    //Colors
    localparam [11:0] PILLAR_COLOR   = 12'h222;  // Dark A-pillar / roof
    localparam [11:0] RIM_COLOR      = 12'hB78;  // Gold rim main color  (#b07808 approx)
    localparam [11:0] RIM_HIGHLIGHT  = 12'hFB3;  // Bright gold highlight ring
    localparam [11:0] RIM_INNER      = 12'h754;  // Dark gold inner edge
    localparam [11:0] SPOKE_COLOR    = 12'hD92;  // Spoke gold
    localparam [11:0] SPOKE_HLIGHT   = 12'hFC4;  // Spoke highlight
    localparam [11:0] HUB_RING_COLOR = 12'hD92;  // Hub ring gold

    localparam [11:0] DOT_COLOR      = 12'hD92;  // Center dot gold

    //Dashboard gradient colors
//    localparam [11:0] DASH_T0 = 12'h444;
//    localparam [11:0] DASH_T1 = 12'h333;
//    localparam [11:0] DASH_T2 = 12'h222;
//    localparam [11:0] DASH_T3 = 12'h111;

    localparam [9:0] DASH_TOP  = SCREEN_H - BOT_H;   // Y = 360
    localparam [9:0] RIGHT_X   = SCREEN_W - RIGHT_W; // X = 600

    // Dashboard gradient
 //   logic [9:0]  dash_y;
 //   logic [11:0] dash_color;


    // Address = row * width + col
    assign dash_addr = (DrawY >= DASH_TOP) ? ((DrawY - DASH_TOP) * 19'd640 + DrawX) : 19'd0;

    // Instantiate RAM
    frameRAM dashboard_ram (
        .data_In(12'd0),
        .write_address(19'd0),
        .read_address(dash_addr),
        .we(1'b0),
        .Clk(clk),
        .data_Out(dash_ram_pixel)
    );
/*    always_comb begin
        dash_y = (DrawY >= DASH_TOP) ? (DrawY - DASH_TOP) : 10'd0;
        if      (dash_y < 10'd30)  dash_color = DASH_T0;
        else if (dash_y < 10'd60)  dash_color = DASH_T1;
        else if (dash_y < 10'd90)  dash_color = DASH_T2;
        else                       dash_color = DASH_T3;
    end
*/
    // Steering wheel distance calculation
//    logic signed [10:0] dx, dy;
//    logic [19:0]        dist_sq;

//    assign dx = $signed({1'b0, DrawX}) - $signed({1'b0, SW_CX});
//    assign dy = $signed({1'b0, DrawY}) - $signed({1'b0, SW_CY});
//    assign dist_sq = 20'($signed(dx) * $signed(dx)) +
//                     20'($signed(dy) * $signed(dy));

    // Radius squared values
//    logic [19:0] r_out_sq, r_in_sq;
//    logic [19:0] r_hub_sq, r_hub_in_sq, r_dot_sq;
//    logic [19:0] r_hlight_sq, r_hlight_in_sq;

//    assign r_out_sq        = 20'(SW_R_OUT)    * 20'(SW_R_OUT);
//    assign r_in_sq         = 20'(SW_R_IN)     * 20'(SW_R_IN);
//    assign r_hub_sq        = 20'(SW_HUB_R)    * 20'(SW_HUB_R);
//    assign r_hub_in_sq     = 20'(SW_HUB_R_IN) * 20'(SW_HUB_R_IN);
//    assign r_dot_sq        = 20'(SW_DOT_R)    * 20'(SW_DOT_R);
//    // Highlight ring = outer 2px band
//    assign r_hlight_sq     = 20'(SW_R_OUT)    * 20'(SW_R_OUT);
//    assign r_hlight_in_sq  = 20'(SW_R_OUT - 2) * 20'(SW_R_OUT - 2);

//    // Spoke absolute values
//    logic [10:0] abs_dx, abs_dy;
//    assign abs_dx = dx[10] ? 11'(-$signed(dx)) : 11'(dx);
//    assign abs_dy = dy[10] ? 11'(-$signed(dy)) : 11'(dy);

    // Layer flags
//    logic on_rim_main;       // Main gold rim band
//    logic on_rim_highlight;  // Bright outer highlight (1-2px band)
//    logic on_rim_inner_edge; // Dark inner edge accent (1-2px band)
//    logic on_spoke;          // Spoke body
//    logic on_spoke_highlight;// Spoke highlight (narrower, same axis)
//    logic on_hub;            // Hub ring
//    logic on_hub_inner;      // Hub inner dark fill
//    logic on_dot;            // Center dot

//    assign on_rim_main       = (dist_sq >= r_in_sq)  && (dist_sq <= r_out_sq);
//    assign on_rim_highlight  = (dist_sq >= r_hlight_in_sq) && (dist_sq <= r_hlight_sq);
//    assign on_rim_inner_edge = (dist_sq >= r_in_sq)  && (dist_sq <= (r_in_sq + 20'd500));

//    assign on_spoke = (dist_sq <= r_out_sq) && (dist_sq >= r_hub_sq) && (
//                          (abs_dy <= {1'b0, SPOKE_W[8:0]}) ||
//                          (abs_dx <= {1'b0, SPOKE_W[8:0]})
//                      );

//    // Spoke highlight: 1px center line on each spoke
//    assign on_spoke_highlight = (dist_sq <= r_out_sq) && (dist_sq >= r_hub_sq) && (
//                          (abs_dy <= 11'd1) ||
//                          (abs_dx <= 11'd1)
//                      );

//    assign on_hub       = (dist_sq <= r_hub_sq) && (dist_sq >= r_hub_in_sq);
//    assign on_hub_inner = (dist_sq < r_hub_in_sq) && (dist_sq >= r_dot_sq + 20'd50);
//    assign on_dot       = (dist_sq <= r_dot_sq);

    always_comb begin
        windshield_on    = 1'b0;
        windshield_pixel = 12'h000;

        if (active_nblank) begin
            // A-pillars (left and right)
            if ((DrawX < LEFT_W || DrawX >= RIGHT_X) && DrawY < DASH_TOP) begin
                windshield_on    = 1'b1;
                windshield_pixel = PILLAR_COLOR;
            end

            // Roof on top
            else if (DrawY < TOP_H) begin
                windshield_on    = 1'b1;
                windshield_pixel = PILLAR_COLOR;
            end

            // Steering wheel layers (draw back to front)
            // Rim main body
//            else if (on_rim_main) begin
//                windshield_on    = 1'b1;
//                if (on_rim_highlight)
//                    windshield_pixel = RIM_HIGHLIGHT;     // Bright outer band
//                else if (on_rim_inner_edge)
//                    windshield_pixel = RIM_INNER;         // Dark inner edge
//                else
//                    windshield_pixel = RIM_COLOR;         // Main gold
//            end

//            // Spokes
//            else if (on_spoke) begin
//                windshield_on    = 1'b1;
//                if (on_spoke_highlight)
//                    windshield_pixel = SPOKE_HLIGHT;      // Bright center line
//                else
//                    windshield_pixel = SPOKE_COLOR;       // Gold spoke
//            end

//            // Hub ring
//            else if (on_hub) begin
//                windshield_on    = 1'b1;
//                windshield_pixel = HUB_RING_COLOR;
//            end

//            // Hub inner dark
//            else if (on_hub_inner) begin
//                windshield_on    = 1'b1;
//                windshield_pixel = 12'h000;
//            end

//            // Center dot
//            else if (on_dot) begin
//                windshield_on    = 1'b1;
//                windshield_pixel = DOT_COLOR;
//            end

            // Dashboard at the bottom
            else if (DrawY >= DASH_TOP) begin
                windshield_on    = 1'b1;
//                windshield_pixel = dash_color;
                windshield_pixel = dash_ram_pixel;
            end

            // Inside windshield: transparent (road shows through)
        end
    end

    always_comb begin
        if (!active_nblank) begin
            red   = 4'h0;
            green = 4'h0;
            blue  = 4'h0;
        end
        else if (windshield_on) begin
            red   = windshield_pixel[11:8];
            green = windshield_pixel[7:4];
            blue  = windshield_pixel[3:0];
        end
        else begin
            red   = 4'h0;
            green = 4'h0;
            blue  = 4'h0;
        end
    end

endmodule
