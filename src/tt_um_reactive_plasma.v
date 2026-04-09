// hvsync_generator.v
// Standard VGA 640x480 @ 60Hz sync generator
// Based on Tiny Tapeout VGA examples

`default_nettype none

module hvsync_generator(
    input clk,
    input reset,
    output reg hsync,
    output reg vsync,
    output display_on,
    output reg [9:0] hpos,
    output reg [9:0] vpos
);
    // Horizontal constants
    parameter H_DISPLAY = 640;
    parameter H_BACK = 48;
    parameter H_FRONT = 16;
    parameter H_SYNC = 96;
    
    // Vertical constants
    parameter V_DISPLAY = 480;
    parameter V_TOP = 33;
    parameter V_BOTTOM = 10;
    parameter V_SYNC = 2;
    
    // Derived constants
    parameter H_SYNC_START = H_DISPLAY + H_FRONT;
    parameter H_SYNC_END = H_DISPLAY + H_FRONT + H_SYNC - 1;
    parameter H_MAX = H_DISPLAY + H_BACK + H_FRONT + H_SYNC - 1;
    parameter V_SYNC_START = V_DISPLAY + V_BOTTOM;
    parameter V_SYNC_END = V_DISPLAY + V_BOTTOM + V_SYNC - 1;
    parameter V_MAX = V_DISPLAY + V_TOP + V_BOTTOM + V_SYNC - 1;
    
    wire hmaxxed = (hpos == H_MAX) || reset;
    wire vmaxxed = (vpos == V_MAX) || reset;
    
    always @(posedge clk) begin
        hsync <= ~(hpos>=H_SYNC_START && hpos<=H_SYNC_END);
        if(hmaxxed)
            hpos <= 0;
        else
            hpos <= hpos + 1;
    end
    
    always @(posedge clk) begin
        vsync <= ~(vpos>=V_SYNC_START && vpos<=V_SYNC_END);
        if(hmaxxed)
            if (vmaxxed)
                vpos <= 0;
            else
                vpos <= vpos + 1;
    end
    
    assign display_on = (hpos<H_DISPLAY) && (vpos<V_DISPLAY);
endmodule
