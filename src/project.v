/*
 * Copyright (c) 2025 Anton Maurovic
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_algofoogle_ro_worker (
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);

  reg done;
  wire reset = ~rst_n;

  reg [3:0] clock_div;

  // All output pins must be assigned. If not used, assign to 0.
  assign uio_out[5:0] = 0; // Unused.
  assign uio_out[6]   = done;
  assign uio_out[7]   = clock_div[3]; // cdebug.
  assign uio_oe       = 8'b11000000;

  assign uo_out       = 0;

  wire shift          = uio_in[0];
  wire clock_sel      = uio_in[1];
  wire mode           = uio_in[2];
  wire stop           = uio_in[3];

  wire [7:0] din      = ui_in;

  wire ring_clock;

  ring_osc #(.DEPTH(4)) myring (
    .ena(ena & clock_sel),
    .osc_out(ring_clock)
  );

  wire internal_clock_unbuffered = clock_sel ? ring_clock : clk;
  wire internal_clock;
  (* keep_hierarchy *) sg13g2_buf_16 intclkbuff (.A(internal_clock_unbuffered), .X(internal_clock));

  // Clock div counts on internal_clock, unless reset is asserted:
  always @(posedge internal_clock) begin
    clock_div <= reset ? 0 : clock_div + 1;
  end

  // Reset logic for 'done' flag:
  always @(posedge internal_clock) begin
    if (reset) begin
      done <= 0;
      run <= 0;
    end
  end

  reg [1:0] shift_counter;

  wire shift_rising;
  wire stop_rising;

  reg [15:0] da;
  reg [15:0] db;

  reg [15:0] ca;
  reg [15:0] cb;

  reg run;

  edge_sync shiftedge (.clk(internal_clock), .rst(reset), .src(shift), .rising(shift_rising));
  edge_sync stopedge  (.clk(internal_clock), .rst(reset), .src(stop),  .rising(stop_rising));

  // ca & cb update logic:
  always @(posedge internal_clock) begin
    if (reset) begin
      ca <= 0;
      cb <= 0;
    end else if (run) begin
      ca <= ca + 1;
      cb <= cb + 1;
    end else if (shift_rising) begin
      if (shift_counter == 3) begin
        ca <= (mode==0) ? da : da + db;
        cb <= 0;
      end else begin
        {ca,cb} <= {ca[7:0],cb,ca[15:8]}; // Rotate out a byte.
      end
    end
  end

  // shift_counter update logic:
  always @(posedge internal_clock) begin
    if (reset) begin
      shift_counter <= 0;
    end else if (shift_rising) begin
      shift_counter <= shift_counter + 1;
    end
  end

  // da & db update logic:
  always @(posedge internal_clock) begin
    if (reset) begin
      da <= 0;
      db <= 0;
    end else if (shift_rising) begin
      {da,db} <= {da[7:0],db,din}; // Shift in a byte.
    end
  end

  // run update logic:
  always @(posedge internal_clock) begin
    if (reset) begin
      run <= 0;
    end else if (shift_rising && shift_counter == 3) begin
      run <= 1; // Start worker after shifting in last byte.
    end else if (run && mode == 0 && cb == db) begin
      run <= 0; // Stop when we hit our target count.
    end else if (run && mode == 1 && stop_rising) begin
      run <= 0; // Stop if signaled.
    end
  end

  // done update logic:
  always @(posedge internal_clock) begin
    if (reset) begin
      done <= 0;
    end else if (run && mode == 0 && cb == db) begin
      done <= 1;
    end else if (run && mode == 1 && stop_rising) begin
      done <= 1;
    end else if (shift_rising) begin
      done <= 0;
    end
  end

  assign uo_out = ca[15:8];

  // List all unused inputs to prevent warnings
  wire _unused = &{rst_n, ui_in, uio_in[7:3], 1'b0};

endmodule


module edge_sync(
  input wire clk,
  input wire rst,
  input wire src,
  output wire rising,
  output wire falling
);
  reg [3:0] buff;
  always @(posedge clk) begin
    if (rst)
      buff <= {buff[2:0], src};
    else
      buff <= 0;
  end
  assign rising = (buff == 4'b0111);
  assign falling = (buff == 4'b1000);
endmodule


module amm_inverter (
  input   wire a,
  output  wire y
);
  // See: https://github.com/IHP-GmbH/IHP-Open-PDK/blob/68eebafcd9b2f5e92c69d37a8d3d90eb266550f5/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_stdcell.v#L870
  (* keep_hierarchy *) sg13g2_inv_1   inverter (
      .A  (a),
      .Y  (y)
  );
  // assign y = ~a;
endmodule


module ring_osc #(
  parameter DEPTH = 5 // Becomes DEPTH*2+1 inverters to ensure it is odd.
) (
  input wire ena,
  output osc_out
);

  wire [DEPTH*2:0] inv_in;
  wire [DEPTH*2:0] inv_out;
  assign inv_in[DEPTH*2:1] = inv_out[DEPTH*2-1:0]; // Chain.
  assign inv_in[0] = inv_out[DEPTH*2] & ena; // Loop back.
  // Generate an instance array of inverters, chained and looped back via the 2 assignments above:
  (* keep_hierarchy *) amm_inverter inv_array [DEPTH*2:0] ( .a(inv_in), .y(inv_out) );
  assign osc_out = inv_in[0];

endmodule

