/*
 * Reactive Plasma - Demoscene Entry for Tiny Tapeout
 * Audio-reactive smooth plasma with beat-synced palette cycling
 * TTSKY26a - 1-tile design
 */

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
    
    // Audio output on uio[0]
    assign uio_out = {7'b0, audio_pwm};
    assign uio_oe  = 8'h01;
    
    wire _unused_ok = &{ena, ui_in, uio_in};
    
    // ============================================
    // VGA SYNC GENERATOR (built-in)
    // ============================================
    reg [9:0] hpos, vpos;
    reg hsync_reg, vsync_reg;
    wire video_active;
    
    // VGA 640x480 @ 60Hz timing
    parameter H_DISPLAY = 640;
    parameter H_BACK = 48;
    parameter H_FRONT = 16;
    parameter H_SYNC = 96;
    parameter V_DISPLAY = 480;
    parameter V_TOP = 33;
    parameter V_BOTTOM = 10;
    parameter V_SYNC = 2;
    
    parameter H_SYNC_START = H_DISPLAY + H_FRONT;
    parameter H_SYNC_END = H_DISPLAY + H_FRONT + H_SYNC - 1;
    parameter H_MAX = H_DISPLAY + H_BACK + H_FRONT + H_SYNC - 1;
    parameter V_SYNC_START = V_DISPLAY + V_BOTTOM;
    parameter V_SYNC_END = V_DISPLAY + V_BOTTOM + V_SYNC - 1;
    parameter V_MAX = V_DISPLAY + V_TOP + V_BOTTOM + V_SYNC - 1;
    
    wire hmaxxed = (hpos == H_MAX) || ~rst_n;
    wire vmaxxed = (vpos == V_MAX) || ~rst_n;
    
    always @(posedge clk) begin
        if (~rst_n) begin
            hpos <= 0;
            vpos <= 0;
        end else begin
            if (hpos == H_MAX) begin
                hpos <= 0;
                if (vpos == V_MAX)
                    vpos <= 0;
                else
                    vpos <= vpos + 1;
            end else begin
                hpos <= hpos + 1;
            end
        end
    end
    
    assign hsync = ~(hpos >= H_SYNC_START && hpos <= H_SYNC_END);
    assign vsync = ~(vpos >= V_SYNC_START && vpos <= V_SYNC_END);
    assign video_active = (hpos < H_DISPLAY) && (vpos < V_DISPLAY);
    
    wire [9:0] x = hpos;
    wire [9:0] y = vpos;
    
    // ============================================
    // FRAME COUNTER
    // ============================================
    reg [11:0] frame_counter;
    
    always @(posedge clk) begin
        if (~rst_n) begin
            frame_counter <= 0;
        end else begin
            if (hpos == 0 && vpos == 0) begin
                frame_counter <= frame_counter + 1;
            end
        end
    end
    
    // ============================================
    // BEAT COUNTER (for audio sync)
    // ============================================
    reg [3:0] beat_cnt;
    wire beat_tick;
    assign beat_tick = (frame_counter[5:0] == 0);
    
    always @(posedge clk) begin
        if (~rst_n)
            beat_cnt <= 0;
        else if (beat_tick)
            beat_cnt <= beat_cnt + 1;
    end
    
    // ============================================
    // AUDIO GENERATION (8-note arpeggio)
    // ============================================
    reg [15:0] audio_phase;
    reg [7:0] note_freq;
    wire [7:0] note_lookup;
    
    assign note_lookup = (beat_cnt[2:0] == 0) ? 8'd191 :
                         (beat_cnt[2:0] == 1) ? 8'd152 :
                         (beat_cnt[2:0] == 2) ? 8'd127 :
                         (beat_cnt[2:0] == 3) ? 8'd95  :
                         (beat_cnt[2:0] == 4) ? 8'd76  :
                         (beat_cnt[2:0] == 5) ? 8'd64  :
                         (beat_cnt[2:0] == 6) ? 8'd48  :
                         8'd38;
    
    always @(posedge clk) begin
        note_freq <= note_lookup;
        if (audio_phase[15:8] >= note_freq)
            audio_phase <= 0;
        else
            audio_phase <= audio_phase + 1;
    end
    
    wire audio_pwm;
    assign audio_pwm = (audio_phase[15] == 1'b1);
    
    // ============================================
    // PLASMA EFFECT
    // ============================================
    wire [7:0] frame = frame_counter[7:0];
    wire palette_sel = beat_cnt[1];
    
    // Three smooth waves
    wire [7:0] wave1 = x[7:0] + y[7:0] + frame;
    wire [7:0] wave2 = (x[7:0] >> 1) + (y[7:0] >> 1) + {frame[6:0], 1'b0};
    wire [7:0] wave3 = (x[7:0] ^ y[7:0]) + {frame[5:0], 2'b00};
    
    // Combine for organic interference
    wire [7:0] plasma = (wave1 ^ wave2) + (wave2 ^ wave3);
    
    // ============================================
    // COLOR PALETTES
    // ============================================
    reg [11:0] palette0 [0:15];
    reg [11:0] palette1 [0:15];
    
    // Initialize with known values (synthesis-compatible)
    always @(*) begin
        // Palette 0: Green -> Cyan
        palette0[0]  = 12'h000; palette0[1]  = 12'h010; palette0[2]  = 12'h020; palette0[3]  = 12'h030;
        palette0[4]  = 12'h040; palette0[5]  = 12'h051; palette0[6]  = 12'h062; palette0[7]  = 12'h073;
        palette0[8]  = 12'h084; palette0[9]  = 12'h0A5; palette0[10] = 12'h0C6; palette0[11] = 12'h0E7;
        palette0[12] = 12'h0F8; palette0[13] = 12'h0F9; palette0[14] = 12'h0FA; palette0[15] = 12'h0FF;
        
        // Palette 1: Purple -> Orange
        palette1[0]  = 12'h000; palette1[1]  = 12'h101; palette1[2]  = 12'h202; palette1[3]  = 12'h303;
        palette1[4]  = 12'h404; palette1[5]  = 12'h515; palette1[6]  = 12'h626; palette1[7]  = 12'h737;
        palette1[8]  = 12'h848; palette1[9]  = 12'hA59; palette1[10] = 12'hC6A; palette1[11] = 12'hE7B;
        palette1[12] = 12'hF8C; palette1[13] = 12'hFAD; palette1[14] = 12'hFCE; palette1[15] = 12'hFFF;
    end
    
    wire [3:0] color_idx = plasma[7:4];
    wire [11:0] rgb_out = palette_sel ? palette1[color_idx] : palette0[color_idx];
    
    // ============================================
    // FINAL OUTPUT
    // ============================================
    assign R = video_active ? rgb_out[11:10] : 2'b00;
    assign G = video_active ? rgb_out[7:6]   : 2'b00;
    assign B = video_active ? rgb_out[3:2]   : 2'b00;

endmodule
