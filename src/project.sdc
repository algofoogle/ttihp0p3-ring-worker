# Declare internal_clock as a primary clock at ~333 MHz.
# Note that it is normally derived from a ring oscillator,
# but could also come from a mux that selects the Tiny Tapeout "clk" input instead,
# but we don't care about that for our constraints.
create_clock -name internal_clk -period 3.0 [get_pins tt_um_algofoogle_ro_worker/intclkbuff/X]

# Set clock uncertainty and transition estimates:
set_clock_uncertainty 0.5 [get_clocks internal_clk]
set_clock_transition 0.1 [get_clocks internal_clk]

# Prevent false timing paths from external clk to internal_clk, if both exist
set_clock_groups -asynchronous -group [get_clocks clk] -group [get_clocks internal_clk]
