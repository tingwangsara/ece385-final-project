//-------------------------------------------------------------------------
//    mb_usb_hdmi_top.sv                                                 --
//    Zuofu Cheng                                                        --
//    2-29-24                                                            --
//    10-14-25                                                           --
//                                                                       --
//    Fall 2025 Distribution                                           --
//                                                                       --
//    For use with ECE 385 USB + HDMI                                    --
//    University of Illinois ECE Department                              --
//-------------------------------------------------------------------------


module mb_usb_hdmi_top(
    input logic Clk,
    input logic reset_rtl_0,
    
    //USB signals
    input logic [0:0] gpio_usb_int_tri_i,
    output logic gpio_usb_rst_tri_o,
    input logic usb_spi_miso,
    output logic usb_spi_mosi,
    output logic usb_spi_sclk,
    output logic usb_spi_ss,
    
    //UART
    input logic uart_rtl_0_rxd,
    output logic uart_rtl_0_txd,
    
    //HDMI
    output logic hdmi_tmds_clk_n,
    output logic hdmi_tmds_clk_p,
    output logic [2:0]hdmi_tmds_data_n,
    output logic [2:0]hdmi_tmds_data_p,
        
    //HEX displays
    output logic [7:0] hex_segA,
    output logic [3:0] hex_gridA,
    output logic [7:0] hex_segB,
    output logic [3:0] hex_gridB,
    
    output logic [3:0] led,

    // DDR3
    inout  logic [15:0] ddr3_dq,
    inout  logic [1:0]  ddr3_dqs_n,
    inout  logic [1:0]  ddr3_dqs_p,
    output logic [12:0] ddr3_addr,
    output logic [2:0]  ddr3_ba,
    output logic        ddr3_ras_n,
    output logic        ddr3_cas_n,
    output logic        ddr3_we_n,
    output logic        ddr3_reset_n,
    output logic [0:0]  ddr3_ck_p,
    output logic [0:0]  ddr3_ck_n,
    output logic [0:0]  ddr3_cke,
    output logic [1:0]  ddr3_dm,
    output logic [0:0]  ddr3_odt,
    
    input logic sys_clk_p,
    input logic sys_clk_n
);
    
    logic [31:0] keycode0_gpio, keycode1_gpio;
    logic clk_25MHz, clk_125MHz, clk, clk_100MHz;
    logic locked;
    logic [9:0] drawX, drawY;

    logic hsync, vsync, vde;
    logic [3:0] red, green, blue, road_red, road_green, road_blue, car_red, car_green, car_blue;
    logic reset_ah;
    
    logic [15:0] player_dist;
    logic signed [15:0] player_x;
    
    //for smooth steering
    logic [7:0] steer_val;
    
    logic [9:0] speed;
    logic key_left, key_right, key_gas, key_brake, off_road;
    
    logic traffic_light_on, traffic_light_off, in_sprite;
    logic [11:0] traffic_out;
    
    logic sky_on;
    logic [11:0] sky_pixel;
    
    logic object_on;
    logic [3:0] obj_red,obj_green, obj_blue;
//    logic active_nblank;
    
    logic signed [15:0] road_center_y;
    logic [15:0] road_half_width_y;
    logic [9:0] road_start_y;
    logic [9:0] road_end_y;
    
    assign reset_ah = reset_rtl_0;
    
    // DDR3 MIG UI signals
    logic ui_clk;
    logic ui_rst;
    logic init_calib_complete;
    
    logic [26:0] app_addr;
    logic [2:0]  app_cmd;
    logic        app_en;
    logic        app_rdy;
    
    logic [63:0] app_rd_data;
    logic        app_rd_data_end;
    logic        app_rd_data_valid;
    
    logic [63:0] app_wdf_data;
    logic        app_wdf_end;
    logic        app_wdf_wren;
    logic        app_wdf_rdy;
    logic [7:0]  app_wdf_mask;
    
    logic app_sr_active;
    logic app_ref_ack;
    logic app_zq_ack;
    logic [11:0] device_temp;
    
    logic [11:0] sprite_pixel_from_buffer;   
    localparam int IMG_H = 200;
    localparam int WORDS_PER_LINE = 160;
    
    logic [63:0] linebuf0_dout;
    logic [63:0] linebuf1_dout;
    
    logic display_buf;   // 0: show linebuf0, 1: show linebuf1
    
    logic [9:0] display_line_y;
    logic [9:0] request_line_y;
    logic request_line_toggle;
    
    logic line_ready;
    logic [9:0] line_ready_y;
    
    // === DDR3 line buffer ? pixel ?? ===
    logic [63:0] line_word;
    logic [15:0] pixel16;
    
    logic [1:0] drawX_lsb_d;
    
    logic display_buf_d;
    
    logic [63:0] first_read_word;
    logic first_read_captured;
    
    always_ff @(posedge ui_clk or posedge ui_rst) begin
        if (ui_rst) begin
            first_read_word <= 64'd0;
            first_read_captured <= 1'b0;
        end else begin
            if (app_rd_data_valid && !first_read_captured) begin
                first_read_word <= app_rd_data;
                first_read_captured <= 1'b1;
            end
        end
    end
    
    always_ff @(posedge clk_25MHz or posedge reset_ah) begin
        if (reset_ah) begin
            drawX_lsb_d   <= 2'd0;
            display_buf_d <= 1'b0;
        end else begin
            drawX_lsb_d   <= drawX[1:0];
            display_buf_d <= display_buf;
        end
    end
    
    always_comb begin
        if (drawY < IMG_H) begin
           if (display_buf_d)
                line_word = linebuf1_dout;
            else
                line_word = linebuf0_dout;
        end else begin
            line_word = 64'd0;
        end
    
        case (drawX_lsb_d)
           2'd0: pixel16 = line_word[63:48];
            2'd1: pixel16 = line_word[47:32];
            2'd2: pixel16 = line_word[31:16];
            2'd3: pixel16 = line_word[15:0];
            default: pixel16 = 16'h0000;
        endcase
    
        sprite_pixel_from_buffer = pixel16[11:0];
    end
    
    assign sky_pixel = sprite_pixel_from_buffer;
    assign sky_on = (drawY < IMG_H);
    
    logic [10:0] sky_scroll_x;
    logic [8:0]  sky_scroll_word;
    logic signed [15:0] sky_curve_step_signed;
    
    logic [31:0] img_word_low;
    logic [31:0] img_word_high;
    logic [31:0] img_ctrl_out;
        
    //Keycode HEX drivers
//    hex_driver HexA (
//        .clk(Clk),
//        .reset(reset_ah),
//        .in({keycode0_gpio[31:28], keycode0_gpio[27:24], keycode0_gpio[23:20], keycode0_gpio[19:16]}),
//        .hex_seg(hex_segA),
//        .hex_grid(hex_gridA)
//    );
    
//    hex_driver HexB (
//        .clk(Clk),
//        .reset(reset_ah),
//        .in({keycode0_gpio[15:12], keycode0_gpio[11:8], keycode0_gpio[7:4], keycode0_gpio[3:0]}),
//        .hex_seg(hex_segB),
//        .hex_grid(hex_gridB)
//    );
    
    hex_driver HexA (
        .clk(Clk),
        .reset(reset_ah),
        .in({
            first_read_word[15:12],
            first_read_word[11:8],
            first_read_word[7:4],
            first_read_word[3:0]
        }),
        .hex_seg(hex_segA),
        .hex_grid(hex_gridA)
    );
    
    hex_driver HexB (
        .clk(Clk),
        .reset(reset_ah),
        .in({
            player_dist[15:12],
            player_dist[11:8],
            player_dist[7:4],
            player_dist[3:0]
        }),
        .hex_seg(hex_segB),
        .hex_grid(hex_gridB)
    );
    
    mb_block mb_block_i (
        .clk_100MHz(Clk),
        .gpio_usb_int_tri_i(gpio_usb_int_tri_i),
        .gpio_usb_keycode_0_tri_o(keycode0_gpio),
        .gpio_usb_keycode_1_tri_o(keycode1_gpio),
        .gpio_usb_rst_tri_o(gpio_usb_rst_tri_o),
        
        // ???MicroBlaze -> RTL image data/control
        .img_data_gpio_io_o_tri_o(img_word_low),
       
        .img_data_gpio2_io_o_tri_o(img_word_high),
        
        .img_ctrl_gpio_io_o_tri_o(img_ctrl_out),
        
        
        .reset_rtl_0(~reset_ah), //Block designs expect active low reset, all other modules are active high
        .uart_rtl_0_rxd(uart_rtl_0_rxd),
        .uart_rtl_0_txd(uart_rtl_0_txd),
        .usb_spi_miso(usb_spi_miso),
        .usb_spi_mosi(usb_spi_mosi),
        .usb_spi_sclk(usb_spi_sclk),
        .usb_spi_ss(usb_spi_ss)
    );
   
    //clock wizard configured with a 1x and 5x clock for HDMI
    clk_wiz_0 clk_wiz (
        .clk_out1(clk_25MHz),
        .clk_out2(clk_125MHz),
        .reset(reset_ah),
        .locked(locked),
        .clk_in1(Clk)
    );
    
    
    mig_7series_0 u_mig_7series_0 (
        // Memory interface ports
        .ddr3_addr          (ddr3_addr),
        .ddr3_ba            (ddr3_ba),
        .ddr3_cas_n         (ddr3_cas_n),
        .ddr3_ck_n          (ddr3_ck_n),
        .ddr3_ck_p          (ddr3_ck_p),
        .ddr3_cke           (ddr3_cke),
        .ddr3_ras_n         (ddr3_ras_n),
        .ddr3_we_n          (ddr3_we_n),
        .ddr3_dq            (ddr3_dq),
        .ddr3_dqs_n         (ddr3_dqs_n),
        .ddr3_dqs_p         (ddr3_dqs_p),
        .ddr3_reset_n       (ddr3_reset_n),
        .init_calib_complete(init_calib_complete),
        .ddr3_dm            (ddr3_dm),
        .ddr3_odt           (ddr3_odt),
    
        // Application interface ports
        .app_addr           (app_addr),
        .app_cmd            (app_cmd),
        .app_en             (app_en),
        .app_wdf_data       (app_wdf_data),
        .app_wdf_end        (app_wdf_end),
        .app_wdf_wren       (app_wdf_wren),
        .app_rd_data        (app_rd_data),
        .app_rd_data_end    (app_rd_data_end),
        .app_rd_data_valid  (app_rd_data_valid),
        .app_rdy            (app_rdy),
        .app_wdf_rdy        (app_wdf_rdy),
        .app_sr_req         (1'b0),
        .app_ref_req        (1'b0),
        .app_zq_req         (1'b0),
        .app_sr_active      (app_sr_active),
        .app_ref_ack        (app_ref_ack),
        .app_zq_ack         (app_zq_ack),
        .ui_clk             (ui_clk),
        .ui_clk_sync_rst    (ui_rst),
        .app_wdf_mask       (app_wdf_mask),
    
        // System Clock Ports
        .sys_clk_p          (sys_clk_p),
        .sys_clk_n          (sys_clk_n),
    
        // Reference Clock Ports
        .clk_ref_i          (Clk),
    
        .device_temp        (device_temp),
        .sys_rst            (1'b0)
    );
    
    //VGA Sync signal generator
    vga_controller vga (
        .pixel_clk(clk_25MHz),
        .reset(reset_ah),
        .hs(hsync),
        .vs(vsync),
        .active_nblank(vde),
        .drawX(drawX),
        .drawY(drawY)
    );    

    //Real Digital VGA to HDMI converter
    hdmi_tx_0 vga_to_hdmi (
        //Clocking and Reset
        .pix_clk(clk_25MHz),
        .pix_clkx5(clk_125MHz),
        .pix_clk_locked(locked),
        .rst(reset_ah),
        //Color and Sync Signals
        .red(red),
        .green(green),
        .blue(blue),
        .hsync(hsync),
        .vsync(vsync),
        .vde(vde),
        
        //aux Data (unused)
        .aux0_din(4'b0),
        .aux1_din(4'b0),
        .aux2_din(4'b0),
        .ade(1'b0),
        
        //Differential outputs
        .TMDS_CLK_P(hdmi_tmds_clk_p),          
        .TMDS_CLK_N(hdmi_tmds_clk_n),          
        .TMDS_DATA_P(hdmi_tmds_data_p),         
        .TMDS_DATA_N(hdmi_tmds_data_n)          
    );
    
    logic player_dir;
    
    always_ff @(posedge vsync or posedge reset_ah)
    begin
        if (reset_ah)
        begin
            player_dist <= 16'd0;
        end
        else 
        begin
            player_dist <= player_dist + speed;
        end
    end
    
    always_ff @(posedge vsync or posedge reset_ah) begin
        if (reset_ah)
            sky_scroll_x <= 11'd0;
        else if (speed != 0)
            sky_scroll_x <= sky_scroll_x + sky_curve_step_signed[10:0];
        else 
            sky_scroll_x <= sky_scroll_x;
    end

    assign sky_scroll_word = sky_scroll_x[10:2];

    
    road_render render_inst(
        .clk(clk_25MHz),
        .reset(reset_ah),
        .frame_clk(vsync),
        .DrawX(drawX), 
        .DrawY(drawY),
        .player_dist(player_dist),
        .player_x(player_x),
        .red(road_red),
        .green(road_green),
        .blue(road_blue),
        .road_center_out(road_center_y),
        .road_half_width_out(road_half_width_y),
        .road_start_out(road_start_y),
        .road_end_out(road_end_y),
        .off_road(off_road)
    );
    
    logic windshield_on;
    
    windshield_frame windshield_inst(
        .clk(clk_25MHz),
        .reset(reset_ah),
        .DrawX(drawX),
        .DrawY(drawY),
        .active_nblank(vde),
        .windshield_on(windshield_on),
        .red(car_red),
        .green(car_green),
        .blue(car_blue)
    );
    
    pixel_mux pixel_mux(
        .windshield_on(windshield_on),
        .traffic_light_on(traffic_light_on),
        .traffic_pixel_on(in_sprite),
        .obj_on(object_on),
    
        .sky_on(sky_on),
        .sky_pixel(sky_pixel),
    
        .road_red(road_red), 
        .road_green(road_green), 
        .road_blue(road_blue), 
        .car_red(car_red), 
        .car_green(car_green), 
        .car_blue(car_blue),
        .obj_red(obj_red),
        .obj_green(obj_green),
        .obj_blue(obj_blue),
        .traffic_out(traffic_out),
        .red(red), 
        .green(green), 
        .blue(blue)
    );
    
    logic signed [15:0] player_curve;
    logic [10:0] player_lut_idx;
    
    assign player_lut_idx = player_dist[13:3];
    
    world_lut player_curve_lut(
        .dist_addr(player_lut_idx),
        .y_addr(9'd360),
        .depth(),
        .curve(player_curve),
        .road_width(),
        .scenery(),
        .object_type()
//        .hill_y()
    );
    
    always_comb begin
        case (player_curve)
            16'sd4:   sky_curve_step_signed = 16'sd4;
            16'sd3:   sky_curve_step_signed = 16'sd3;
            16'sd2:   sky_curve_step_signed = 16'sd2;
            16'sd1:   sky_curve_step_signed = 16'sd1;

            -16'sd1:  sky_curve_step_signed = -16'sd1;
            -16'sd2:  sky_curve_step_signed = -16'sd2;
            -16'sd3:  sky_curve_step_signed = -16'sd3;

            default:  sky_curve_step_signed = 16'sd0;
        endcase
    end

    
    controller controller_inst(
        .clk(clk_25MHz),
        .reset(reset_ah),
        .frame_clk(vsync),
        .key_left(key_left),
        .key_right(key_right),
        .key_gas(key_gas),
        .key_brake(key_brake),
        .off_road(off_road),
        .steer_val(steer_val),
        .road_curve(player_curve),
        .player_x(player_x),
        .speed(speed)
    );
    
    //for steering
    assign steer_val = keycode0_gpio[15:8];
    
    keyboard keyboard_inst(
        .keycode(keycode0_gpio[7:0]),
        .key_left(key_left), 
        .key_right(key_right), 
        .key_gas(key_gas), 
        .key_brake(key_brake)
    );
    
    startup_screen startup_inst(
        .pixel_clk(clk_25MHz),
        .reset(reset_ah),
        .DrawX(drawX), 
        .DrawY(drawY),
        .sprite_pixel_from_buffer(sprite_pixel_from_buffer),
        .pixel_out(traffic_out),
        .traffic_light_off(traffic_light_off),
        .traffic_pixel_on(in_sprite)
    );
    
    statemachine statemach_inst(
        .clk(clk_25MHz), 
        .reset(reset_ah), 
        .traffic_light_off(traffic_light_off),
        .traffic_light_on(traffic_light_on)    
    );
    
    object_render objrender_inst(
//        .pixel_clk(clk_25MHz),
//        .reset(reset_ah),
        .clk(clk_25MHz),
        .road_start_in(road_start_y),
        .road_end_in(road_end_y),
        .DrawX(drawX), 
        .DrawY(drawY),
        .player_dist(player_dist),
        .player_x(player_x),
        .object_on(object_on),
        .red(obj_red),
        .green(obj_green),
        .blue(obj_blue)
    );
    
    logic        lb_we;
    logic [7:0]  lb_waddr;
    logic [63:0] lb_wdata;
    
    logic line_ready_ui_d;
    logic line_ready_pulse_ui;
    
    always_ff @(posedge ui_clk or posedge ui_rst) begin
        if (ui_rst)
            line_ready_ui_d <= 1'b0;
        else
            line_ready_ui_d <= line_ready;
    end
    
    assign line_ready_pulse_ui = line_ready & ~line_ready_ui_d;
    
    logic write_buf_ui;

    always_ff @(posedge ui_clk or posedge ui_rst) begin
        if (ui_rst) begin
            write_buf_ui <= 1'b1;
        end else if (line_ready_pulse_ui) begin
            write_buf_ui <= ~write_buf_ui;
        end
    end
 
    xpm_memory_tdpram #(
        .ADDR_WIDTH_A(8),
        .ADDR_WIDTH_B(8),
        .WRITE_DATA_WIDTH_A(64),
        .READ_DATA_WIDTH_A(64),
        .WRITE_DATA_WIDTH_B(64),
        .READ_DATA_WIDTH_B(64),
        .BYTE_WRITE_WIDTH_A(64),
        .BYTE_WRITE_WIDTH_B(64),
        .MEMORY_SIZE(64 * 160),
        .MEMORY_PRIMITIVE("block"),
        .CLOCKING_MODE("independent_clock"),
        .READ_LATENCY_A(1),
        .READ_LATENCY_B(1),
        .WRITE_MODE_A("no_change"),
        .WRITE_MODE_B("no_change"),
        .MEMORY_INIT_FILE("none"),
        .MEMORY_INIT_PARAM("0"),
        .USE_MEM_INIT(0),
        .ECC_MODE("no_ecc"),
        .AUTO_SLEEP_TIME(0),
        .CASCADE_HEIGHT(0),
        .MEMORY_OPTIMIZATION("true"),
        .MESSAGE_CONTROL(0),
        .READ_RESET_VALUE_A("0"),
        .READ_RESET_VALUE_B("0"),
        .RST_MODE_A("SYNC"),
        .RST_MODE_B("SYNC"),
        .SIM_ASSERT_CHK(0),
        .USE_EMBEDDED_CONSTRAINT(0),
        .WAKEUP_TIME("disable_sleep")
    ) linebuf0_bram (
        .clka(ui_clk),
        .rsta(ui_rst),
        .ena(1'b1),
        .regcea(1'b1),
        .wea({8{lb_we && !write_buf_ui}}),
        .addra(lb_waddr),
        .dina(lb_wdata),
        .douta(),
    
        .clkb(clk_25MHz),
        .rstb(reset_ah),
        .enb(1'b1),
        .regceb(1'b1),
        .web(8'd0),
        .addrb(drawX[9:2]),
        .dinb(64'd0),
        .doutb(linebuf0_dout),
    
        .injectdbiterra(1'b0),
        .injectsbiterra(1'b0),
        .sbiterra(),
        .dbiterra(),
        .sbiterrb(),
        .dbiterrb()
    );
    
    xpm_memory_tdpram #(
        .ADDR_WIDTH_A(8),
        .ADDR_WIDTH_B(8),
        .WRITE_DATA_WIDTH_A(64),
        .READ_DATA_WIDTH_A(64),
        .WRITE_DATA_WIDTH_B(64),
        .READ_DATA_WIDTH_B(64),
        .BYTE_WRITE_WIDTH_A(64),
        .BYTE_WRITE_WIDTH_B(64),
        .MEMORY_SIZE(64 * 160),
        .MEMORY_PRIMITIVE("block"),
        .CLOCKING_MODE("independent_clock"),
        .READ_LATENCY_A(1),
        .READ_LATENCY_B(1),
        .WRITE_MODE_A("no_change"),
        .WRITE_MODE_B("no_change"),
        .MEMORY_INIT_FILE("none"),
        .MEMORY_INIT_PARAM("0"),
        .USE_MEM_INIT(0),
        .ECC_MODE("no_ecc"),
        .AUTO_SLEEP_TIME(0),
        .CASCADE_HEIGHT(0),
        .MEMORY_OPTIMIZATION("true"),
        .MESSAGE_CONTROL(0),
        .READ_RESET_VALUE_A("0"),
        .READ_RESET_VALUE_B("0"),
        .RST_MODE_A("SYNC"),
        .RST_MODE_B("SYNC"),
        .SIM_ASSERT_CHK(0),
        .USE_EMBEDDED_CONSTRAINT(0),
        .WAKEUP_TIME("disable_sleep")
    ) linebuf1_bram (
        .clka(ui_clk),
        .rsta(ui_rst),
        .ena(1'b1),
        .regcea(1'b1),
        .wea({8{lb_we && write_buf_ui}}),
        .addra(lb_waddr),
        .dina(lb_wdata),
        .douta(),
    
        .clkb(clk_25MHz),
        .rstb(reset_ah),
        .enb(1'b1),
        .regceb(1'b1),
        .web(8'd0),
        .addrb(drawX[9:2]),
        .dinb(64'd0),
        .doutb(linebuf1_dout),
    
        .injectdbiterra(1'b0),
        .injectsbiterra(1'b0),
        .sbiterra(),
        .dbiterra(),
        .sbiterrb(),
        .dbiterrb()
    );

    
    logic debug_word_seen;
    logic debug_burst_written;
    logic debug_read_started;
    
    logic [63:0] img_word64;
    logic        img_valid_toggle;
    logic        img_valid_pulse;
    
    logic ddr3_line_done;
    logic [3:0] debug_beat_state;
    
    logic [9:0] last_drawY;
    
    logic line_ready_pix0, line_ready_pix1, line_ready_pix_prev;
    logic line_ready_pulse_pix;
    
    always_ff @(posedge clk_25MHz or posedge reset_ah) begin
        if (reset_ah) begin
            line_ready_pix0 <= 1'b0;
            line_ready_pix1 <= 1'b0;
            line_ready_pix_prev <= 1'b0;
        end else begin
            line_ready_pix0 <= line_ready;
            line_ready_pix1 <= line_ready_pix0;
            line_ready_pix_prev <= line_ready_pix1;
        end
    end
    
    assign line_ready_pulse_pix = line_ready_pix1 & ~line_ready_pix_prev;

    logic req_pending;

    always_ff @(posedge clk_25MHz or posedge reset_ah) begin
        if (reset_ah) begin
            last_drawY          <= 10'd0;
            display_line_y      <= 10'd0;
            request_line_y      <= 10'd0;
            request_line_toggle <= 1'b0;
            display_buf         <= 1'b0;
        end else begin
            if (drawY != last_drawY) begin
                last_drawY <= drawY;
    
                if (drawY < IMG_H) begin
                    display_line_y <= drawY;
    
                    // ?????????????? drawY ??? DDR ?
                    request_line_y      <= drawY;
                    request_line_toggle <= ~request_line_toggle;
    
                    // ????? line_ready ? buffer
                    if (line_ready_pix1) begin
                        display_buf <= ~display_buf;
                    end
                end
            end
        end
    end
    
    logic image_loaded_latched;
    
    ddr3_image_loader ddr3_image_loader_inst (
        .ui_clk(ui_clk),
        .ui_rst(ui_rst),
        .init_calib_complete(init_calib_complete),
    
        .img_word64(img_word64),
        .img_valid_pulse(img_valid_pulse),
        .img_load_done(image_loaded_latched),
    
        .read_line_y(request_line_y),
        .read_x_word_offset(sky_scroll_word),
        .read_line_req(request_line_toggle),
        .line_ready(line_ready),
        .line_ready_y(line_ready_y),
    
        .app_addr(app_addr),
        .app_cmd(app_cmd),
        .app_en(app_en),
        .app_rdy(app_rdy),
    
        .app_wdf_data(app_wdf_data),
        .app_wdf_end(app_wdf_end),
        .app_wdf_wren(app_wdf_wren),
        .app_wdf_mask(app_wdf_mask),
        .app_wdf_rdy(app_wdf_rdy),
    
        .app_rd_data(app_rd_data),
        .app_rd_data_valid(app_rd_data_valid),
        .app_rd_data_end(app_rd_data_end),
    
        .lb_we(lb_we),
        .lb_waddr(lb_waddr),
        .lb_wdata(lb_wdata),
    
        .done(ddr3_line_done),
        .debug_word_seen(debug_word_seen),
        .debug_burst_written(debug_burst_written),
        .debug_read_started(debug_read_started),
        .debug_state(debug_beat_state)
    );
    
    
    // toggle ??
    logic [31:0] img_ctrl_sync0, img_ctrl_sync1;
    logic [31:0] img_low_sync0,  img_low_sync1;
    logic [31:0] img_high_sync0, img_high_sync1;
    
    logic prev_toggle;
    
    assign led[0] = init_calib_complete;
    assign led[1] = debug_word_seen;
    assign led[2] = debug_beat_state[0];  // loader?????
    assign led[3] = debug_beat_state[1];  // loader?????
    
    always_ff @(posedge ui_clk or posedge ui_rst) begin
        if (ui_rst) begin
            img_ctrl_sync0 <= 32'd0;
            img_ctrl_sync1 <= 32'd0;
            img_low_sync0  <= 32'd0;
            img_low_sync1  <= 32'd0;
            img_high_sync0 <= 32'd0;
            img_high_sync1 <= 32'd0;
            prev_toggle    <= 1'b0;
        end else begin
            img_ctrl_sync0 <= img_ctrl_out;
            img_ctrl_sync1 <= img_ctrl_sync0;
    
            img_low_sync0  <= img_word_low;
            img_low_sync1  <= img_low_sync0;
    
            img_high_sync0 <= img_word_high;
            img_high_sync1 <= img_high_sync0;
    
            prev_toggle <= img_ctrl_sync1[0];
        end
    end
    
    assign img_word64 = {img_high_sync1, img_low_sync1};
    assign img_valid_pulse = img_ctrl_sync1[0] ^ prev_toggle;
    
    always_ff @(posedge ui_clk or posedge ui_rst) begin
        if (ui_rst) begin
            image_loaded_latched <= 1'b0;
        end else begin
            if (img_ctrl_sync1[1] | img_ctrl_sync1[2]) begin
                image_loaded_latched <= 1'b1;
            end
        end
    end
    
endmodule
