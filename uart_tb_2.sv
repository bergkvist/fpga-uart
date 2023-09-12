module uart_tb_2();
    localparam TX_MESSAGE = {8'h11, 8'h22, 8'h44};
    localparam CLOCK_RATE = 100_000;
    localparam BAUD_RATE = 9600;
    initial begin
        $dumpfile("uart.vcd");
        $dumpvars(0, uart_tb_2);
    end

    logic tx, idle, startTx = 0;
    logic clk = 1, uartClk = 1;
    initial forever #(0.5s/CLOCK_RATE) clk = ~clk;
    initial forever #(0.5s/BAUD_RATE) uartClk = ~uartClk;

    initial begin
        #100ms startTx = 1;
        #150us startTx = 0;
    end

    UartTx #(.DATA_WIDTH($size(TX_MESSAGE))) uartTx0(
        .uartClk(uartClk),
        .message(TX_MESSAGE),
        .start(startTx),
        .tx(tx),
        .idle(idle)
    );

    byte rxData;
    logic dataIsValid;
    UartRx #(.BAUD_RATE(BAUD_RATE), .CLOCK_RATE(CLOCK_RATE)) uartRx0(
        .clk(clk),
        .rx(tx),
        .data(rxData),
        .dataIsValid(dataIsValid)
    );

    byte data1;
    byte data2;

    always @(posedge dataIsValid) begin
        $display("received byte: 0x%h", rxData);
    end

    // TODO: receive 2 bytes, add them together and return the result.
    // change to data is valid strategy? then we can do edge detection on valid data

    initial #1s $finish;
endmodule
