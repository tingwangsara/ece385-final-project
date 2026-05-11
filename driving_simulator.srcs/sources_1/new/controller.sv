module controller(
    input logic clk, reset, frame_clk,
    input logic key_left, key_right, key_gas, key_brake,
    input logic off_road,
    input logic [7:0] steer_val,
    input logic signed [15:0] road_curve,

    output logic signed [11:0] player_x,
    output logic [9:0] speed
);

    localparam signed [11:0] X_MIN = -12'sd960;
    localparam signed [11:0] X_MAX =  12'sd960;

    localparam [9:0] SPEED_MIN = 0;
    localparam [9:0] SPEED_MAX = 10;
    localparam [9:0] SPEED_OFFROAD_MAX = 1;

    logic key_gas_prev, key_brake_prev;
    logic key_gas_rising, key_brake_rising;

    logic signed [8:0] steer_signed;
    logic signed [15:0] steer_delta;
    logic signed [15:0] curve_force;
    logic signed [15:0] next_x;

    assign key_gas_rising   = key_gas && !key_gas_prev;
    assign key_brake_rising = key_brake && !key_brake_prev;

    assign steer_signed = $signed({1'b0, steer_val}) - 9'sd127;

    // steering from wheel
    assign steer_delta = (speed == 0) ? 16'sd0 : $signed(steer_signed >>> 4);

    // centrifugal force
    // road_curve > 0 means right curve.
    // If direction feels reversed, change - to + below.
    assign curve_force = ($signed(road_curve) * $signed({6'd0, speed})) >>> 1;

    always_comb begin
        next_x = $signed(player_x);

        if (speed != 0)
            next_x = next_x + steer_delta;

        // curve makes car drift outward
        next_x = next_x - curve_force;

        if (next_x < X_MIN)
            next_x = X_MIN;
        else if (next_x > X_MAX)
            next_x = X_MAX;
    end

    always_ff @(posedge frame_clk or posedge reset) begin
        if (reset) begin
            player_x <= 0;
            speed <= 0;
            key_gas_prev <= 0;
            key_brake_prev <= 0;
        end
        else begin
            key_gas_prev <= key_gas;
            key_brake_prev <= key_brake;

            if (key_gas_rising && !key_brake) begin
                if (!off_road) begin
                    if (speed < SPEED_MAX)
                        speed <= speed + 1;
                end
                else begin
                    if (speed < SPEED_OFFROAD_MAX)
                        speed <= speed + 1;
                    else
                        speed <= SPEED_OFFROAD_MAX;
                end
            end
            else if (!key_gas && key_brake_rising) begin
                if (speed > 1)
                    speed <= speed - 1;
                else
                    speed <= 0;
            end

            player_x <= next_x[11:0];
        end
    end

endmodule