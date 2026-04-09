// tt_um_reactive_plasma.v
// Reactive Plasma Demo for Tiny Tapeout
// TTSKY26a - 1-tile audio-reactive plasma

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
    
    wire [9:0] x;
    wire [9:0] y;
    wire video_active;
    
    // VGA sync generator
    hvsync_generator hvsync_gen(
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(x),
        .vpos(y)
    );
    
    // === Frame Counter ===
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
    
    // === Beat Counter (for audio and palette sync) ===
    reg [3:0] beat_cnt;
    wire beat_tick;
    assign beat_tick = (frame_counter[5:0] == 0);  // Every 64 frames
    
    always @(posedge clk) begin
        if (~rst_n)
            beat_cnt <= 0;
        else if (beat_tick)
            beat_cnt <= beat_cnt + 1;
    end
    
    // === Audio Generation (8-note C Major Arpeggio) ===
    reg [15:0] audio_phase;
    reg [7:0] note_freq;
    wire [7:0] note_lookup;
    
    assign note_lookup = (beat_cnt[2:0] == 0) ? 8'd191 :  // C4
                         (beat_cnt[2:0] == 1) ? 8'd152 :  // E4
                         (beat_cnt[2:0] == 2) ? 8'd127 :  // G4
                         (beat_cnt[2:0] == 3) ? 8'd95  :  // C5
                         (beat_cnt[2:0] == 4) ? 8'd76  :  // E5
                         (beat_cnt[2:0] == 5) ? 8'd64  :  // G5
                         (beat_cnt[2:0] == 6) ? 8'd48  :  // C6
                         8'd38;                           // E6
    
    always @(posedge clk) begin
        note_freq <= note_lookup;
        if (audio_phase[15:8] >= note_freq)
            audio_phase <= 0;
        else
            audio_phase <= audio_phase + 1;
    end
    
    wire audio_pwm;
    assign audio_pwm = (audio_phase[15] == 1'b1);
    
    // === Palette Select (flip on every 2nd beat) ===
    wire palette_sel;
    assign palette_sel = beat_cnt[1];
    
    // === Smooth Plasma Angles ===
    wire [7:0] frame = frame_counter[7:0];
    
    wire [9:0] angle1 = {2'b0, x[7:0]} + {4'b0, frame[5:0]};
    wire [9:0] angle2 = {2'b0, y[7:0]} + {3'b0, frame[6:0]};
    wire [9:0] angle3 = {2'b0, ((x[7:0] + y[7:0]) >> 1)} + {2'b0, frame[7:0]};
    
    // === Sine ROM (64-entry quarter wave) ===
    reg [6:0] sin_rom [0:63];
    initial begin
        sin_rom[0]  = 0;   sin_rom[1]  = 3;   sin_rom[2]  = 6;   sin_rom[3]  = 9;
        sin_rom[4]  = 12;  sin_rom[5]  = 16;  sin_rom[6]  = 19;  sin_rom[7]  = 22;
        sin_rom[8]  = 25;  sin_rom[9]  = 28;  sin_rom[10] = 31;  sin_rom[11] = 34;
        sin_rom[12] = 37;  sin_rom[13] = 40;  sin_rom[14] = 43;  sin_rom[15] = 46;
        sin_rom[16] = 49;  sin_rom[17] = 52;  sin_rom[18] = 55;  sin_rom[19] = 58;
        sin_rom[20] = 60;  sin_rom[21] = 63;  sin_rom[22] = 66;  sin_rom[23] = 68;
        sin_rom[24] = 71;  sin_rom[25] = 73;  sin_rom[26] = 76;  sin_rom[27] = 78;
        sin_rom[28] = 81;  sin_rom[29] = 83;  sin_rom[30] = 85;  sin_rom[31] = 88;
        sin_rom[32] = 90;  sin_rom[33] = 92;  sin_rom[34] = 94;  sin_rom[35] = 96;
        sin_rom[36] = 98;  sin_rom[37] = 100; sin_rom[38] = 102; sin_rom[39] = 103;
        sin_rom[40] = 105; sin_rom[41] = 107; sin_rom[42] = 108; sin_rom[43] = 110;
        sin_rom[44] = 111; sin_rom[45] = 112; sin_rom[46] = 114; sin_rom[47] = 115;
        sin_rom[48] = 116; sin_rom[49] = 117; sin_rom[50] = 118; sin_rom[51] = 119;
        sin_rom[52] = 120; sin_rom[53] = 121; sin_rom[54] = 122; sin_rom[55] = 122;
        sin_rom[56] = 123; sin_rom[57] = 124; sin_rom[58] = 124; sin_rom[59] = 125;
        sin_rom[60] = 125; sin_rom[61] = 126; sin_rom[62] = 126; sin_rom[63] = 127;
    end
    
    function [6:0] sine_lookup;
        input [9:0] phase;
        reg [5:0] addr;
        reg invert;
        begin
            case (phase[9:8])
                2'b00: begin addr = phase[7:2]; invert = 1'b0; end
                2'b01: begin addr = ~phase[7:2]; invert = 1'b0; end
                2'b10: begin addr = phase[7:2]; invert = 1'b1; end
                2'b11: begin addr = ~phase[7:2]; invert = 1'b1; end
            endcase
            sine_lookup = invert ? (7'd127 - sin_rom[addr]) : sin_rom[addr];
        end
    endfunction
    
    wire [6:0] sin1 = sine_lookup(angle1);
    wire [6:0] sin2 = sine_lookup(angle2);
    wire [6:0] sin3 = sine_lookup(angle3);
    
    wire [8:0] plasma_sum = {1'b0, sin1} + {1'b0, sin2} + {1'b0, sin3};
    wire [6:0] plasma_val = plasma_sum[8:2];
    
    // === Palettes ===
    reg [11:0] palette0 [0:15];
    reg [11:0] palette1 [0:15];
    
    initial begin
        // Green → Cyan
        palette0[0]  = 12'h000; palette0[1]  = 12'h010; palette0[2]  = 12'h020; palette0[3]  = 12'h030;
        palette0[4]  = 12'h040; palette0[5]  = 12'h051; palette0[6]  = 12'h062; palette0[7]  = 12'h073;
        palette0[8]  = 12'h084; palette0[9]  = 12'h0A5; palette0[10] = 12'h0C6; palette0[11] = 12'h0E7;
        palette0[12] = 12'h0F8; palette0[13] = 12'h0F9; palette0[14] = 12'h0FA; palette0[15] = 12'h0FF;
        
        // Purple → Orange
        palette1[0]  = 12'h000; palette1[1]  = 12'h101; palette1[2]  = 12'h202; palette1[3]  = 12'h303;
        palette1[4]  = 12'h404; palette1[5]  = 12'h515; palette1[6]  = 12'h626; palette1[7]  = 12'h737;
        palette1[8]  = 12'h848; palette1[9]  = 12'hA59; palette1[10] = 12'hC6A; palette1[11] = 12'hE7B;
        palette1[12] = 12'hF8C; palette1[13] = 12'hFAD; palette1[14] = 12'hFCE; palette1[15] = 12'hFFF;
    end
    
    wire [3:0] color_idx = plasma_val[6:3];
    wire [11:0] rgb_out = palette_sel ? palette1[color_idx] : palette0[color_idx];
    
    always @(*) begin
        if (~video_active) begin
            {R, G, B} = 6'b00_00_00;
        end else begin
            {R, G, B} = {rgb_out[11:10], rgb_out[7:6], rgb_out[3:2]};
        end
    end

endmodule
