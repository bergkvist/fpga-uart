uart.vcd: uart
	vvp $<

uart: uart.sv uart_tb.sv
	iverilog -g2012 -o $@ $?

clean:
	rm uart uart.vcd
