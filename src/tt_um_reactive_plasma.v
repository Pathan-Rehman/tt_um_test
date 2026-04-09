// tt_um_reactive_plasma.v
// Plasma demo for Tiny Tapeout

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
    
    wire [9:0] x;
    wire [9:0] y;
    wire video_active;
    
    hvsync_generator hvsync_gen(
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(x),
        .vpos(y)
    );
    
    // Frame counter
    reg [11:0] frame_counter;
    
    always @(posedge clk) begin
        if (~rst_n) begin
            frame_counter <= 0;
        end else begin
            if (x == 0 && y == 0) begin
                frame_counter <= frame_counter + 1;
            end
        end
    end
    
    // Simple moving plasma
    wire [9:0] frame = frame_counter[7:0];
    wire [7:0] wave1 = x[7:0] + y[7:0] + frame[7:0];
    wire [7:0] wave2 = x[7:0] - y[7:0] + {frame[6:0], 1'b0};
    wire [7:0] wave3 = (x[7:0] ^ y[7:0]) + frame[7:0];
    wire [7:0] pattern = wave1 ^ wave2 ^ wave3;
    
    always @(*) begin
        if (~video_active) begin
            {R, G, B} = 6'b00_00_00;
        end else begin
            R = pattern[7:6];
            G = pattern[5:4];
            B = pattern[3:2];
        end
    end

endmodule
