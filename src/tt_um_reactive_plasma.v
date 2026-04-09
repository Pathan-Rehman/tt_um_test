// tt_um_reactive_plasma.v - COMPLETE SINGLE FILE VERSION
// Works directly in VGA Playground without external modules

`default_nettype none

module tt_um_reactive_plasma (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // VGA signals
    wire hsync;
    wire vsync;
    wire [1:0] R;
    wire [1:0] G;
    wire [1:0] B;
    
    // TinyVGA PMOD pinout
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
    
    assign uio_out = 0;
    assign uio_oe  = 0;
    
    wire _unused_ok = &{ena, ui_in, uio_in};
    
    // === VGA SYNC GENERATOR (INLINE - NO EXTERNAL MODULE NEEDED) ===
    reg [9:0] hpos, vpos;
    reg hsync_reg, vsync_reg;
    wire video_active;
    
    // VGA 640x480 @ 60Hz timing constants
    parameter H_VISIBLE = 640;
    parameter H_FRONT   = 16;
    parameter H_SYNC    = 96;
    parameter H_BACK    = 48;
    parameter H_TOTAL   = 800;
    
    parameter V_VISIBLE = 480;
    parameter V_FRONT   = 10;
    parameter V_SYNC    = 2;
    parameter V_BACK    = 33;
    parameter V_TOTAL   = 525;
    
    always @(posedge clk) begin
        if (~rst_n) begin
            hpos <= 0;
            vpos <= 0;
        end else begin
            if (hpos == H_TOTAL - 1) begin
                hpos <= 0;
                if (vpos == V_TOTAL - 1)
                    vpos <= 0;
                else
                    vpos <= vpos + 1;
            end else begin
                hpos <= hpos + 1;
            end
        end
    end
    
    assign hsync = ~((hpos >= H_VISIBLE + H_FRONT) && 
                     (hpos < H_VISIBLE + H_FRONT + H_SYNC));
    assign vsync = ~((vpos >= V_VISIBLE + V_FRONT) && 
                     (vpos < V_VISIBLE + V_FRONT + V_SYNC));
    
    assign video_active = (hpos < H_VISIBLE) && (vpos < V_VISIBLE);
    
    wire [9:0] x = hpos;
    wire [9:0] y = vpos;
    
    // === FRAME COUNTER ===
    reg [15:0] frame_counter;
    
    always @(posedge clk) begin
        if (~rst_n) begin
            frame_counter <= 0;
        end else begin
            if (hpos == 0 && vpos == 0) begin
                frame_counter <= frame_counter + 1;
            end
        end
    end
    
    // === SMOOTH PLASMA EFFECT ===
    wire [7:0] frame = frame_counter[9:2];  // Slower for VGA Playground
    
    // Three-layer interference pattern
    wire [7:0] wave1 = x[7:0] + y[7:0] + frame;
    wire [7:0] wave2 = (x[7:0] >> 1) + (y[7:0] >> 1) + {frame[6:0], 1'b0};
    wire [7:0] wave3 = (x[7:0] ^ y[7:0]) + {frame[5:0], 2'b00};
    
    // Organic interference using XOR and addition
    wire [7:0] plasma = (wave1 ^ wave2) + (wave2 ^ wave3);
    
    // Distance-based rings for extra complexity
    wire signed [9:0] center_x = 320 + {frame[7:0], 2'b00};
    wire signed [9:0] center_y = 240 + {frame[6:0], 3'b00};
    wire signed [10:0] dx = {1'b0, x} - {1'b0, center_x};
    wire signed [10:0] dy = {1'b0, y} - {1'b0, center_y};
    wire [21:0] dist_sq = (dx * dx) + (dy * dy);
    wire [7:0] rings = dist_sq[15:8];
    
    // Combine effects
    wire [7:0] combined = plasma + rings;
    wire [7:0] color_shift = combined + {frame[6:0], 1'b0};
    
    // === COLOR OUTPUT ===
    always @(*) begin
        if (~video_active) begin
            {R, G, B} = 6'b00_00_00;
        end else begin
            // Smooth color cycling
            R = color_shift[7:6] ^ color_shift[5:4];
            G = color_shift[6:5] ^ color_shift[4:3];
            B = color_shift[5:4] ^ color_shift[3:2];
        end
    end

endmodule
