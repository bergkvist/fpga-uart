uart.vcd: uart.vvp
	vvp -n $<

uart.vvp: uart.sv uart_tb.sv
	iverilog -g2012 -o $@ $^

.PHONY: watch
watch:
	ls *.sv | entr -csr "make uart.vcd"

clean:
	rm uart.vvp uart.vcd
