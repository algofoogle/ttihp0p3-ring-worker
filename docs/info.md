<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

Explain how your project works

## How to test

1.  Set `clock_sel`=1 (internal ring oscillator is used as the clock source). Ring-osc clock, divided by 16, should be present on `cdebug` -- expected to be on the order of 12.5MHz to 25MHz.
2.  Set `mode`=0 (we're going to load the number of cycles for which we want the worker to run).
3.  Assert reset. No need to supply a clock on `clk`. Expect `done==0`. 
4.  Load a sequence of 4 bytes: a rising edge on `shift` loads each byte, in turn, via `din[7:0]`. First 2 bytes are a starting value (MSB first). The next 2 bytes are a cycle count. In `mode==0` this cycle count is used, while in `mode==1` it is repurposed an addend for an adder experiment.
5.  After the 4th byte has been loaded, the worker should start, and set `done==1` when it finishes.
6.  Shift out 4 bytes via `dout[7:0]` by raising `shift` each time again (which in turn loads 4 more bytes, so it will start again). The first 2 bytes out are the internal counter value (which started at 0) and the last 2 bytes are the 'starting value' incremented by the counter value (i.e. it should be the starting value, plus the internal counter value).


## External hardware

List external hardware used in your project (e.g. PMOD, LED display, etc), if any
