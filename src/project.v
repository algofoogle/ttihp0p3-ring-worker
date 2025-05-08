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
  assign uio_out[7]   = clock_div[3];
  assign uio_oe       = 8'b11000000;

  wire shift          = uio_in[0];
  wire clock_sel      = uio_in[1];
  wire mode           = uio_in[2];

  wire ring_clock;

  ring_osc #(.DEPTH(4)) myring (
    .ena(ena & clock_sel),
    .osc_out(ring_clock)
  );

  wire internal_clock = clock_sel ? ring_clock : clk;

  // Clock div counts on internal_clock, unless reset is asserted:
  always @(posedge internal_clock) begin
    clock_div <= reset ? 0 : clock_div + 1;
  end

  // Reset logic for 'done' flag:
  always @(posedge internal_clock) begin
    if (reset) done <= 0;
  end

  // List all unused inputs to prevent warnings
  wire _unused = &{rst_n, 1'b0};

endmodule


module amm_inverter (
  input   wire a,
  output  wire y
);
  // See: https://github.com/IHP-GmbH/IHP-Open-PDK/blob/68eebafcd9b2f5e92c69d37a8d3d90eb266550f5/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_stdcell.v#L870
  // (* keep_hierarchy *) sg13g2_inv_1   inverter (
  //     .A  (a),
  //     .Y  (y)
  // );
  assign y = ~a;
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

