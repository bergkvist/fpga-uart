`timescale 1ns/1ns

module uart(
    input logic clk,
    input logic rxd,
    output logic txd,
    output logic [7:0] led_anode,
    output logic [7:0] led_cathode
);
    parameter CLOCK_RATE = 100_000_000;
    parameter BAUD_RATE = 9600;
    parameter DISPLAY_RATE = 9600;
    byte tmpData1, tmpData2, tmpDataSum;

    logic uartClk;
    ClockDivider#(.DIVIDER(CLOCK_RATE/BAUD_RATE))
        clockdivUart(.clkIn(clk), .clkOut(uartClk));

    logic dataIsValid;
    byte data;
    UartRx#(.BAUD_RATE(BAUD_RATE), .CLOCK_RATE(CLOCK_RATE))
        uartRx1(.clk(clk), .rxd(rxd), .data(data), .dataIsValid(dataIsValid));

    logic txStart, idle;
    UartTx#(.DATA_WIDTH(8))
        uartTx1(.uartClk(uartClk), .message(tmpDataSum), .start(txStart), .txd(txd), .idle(idle));

    logic displayClk;
    ClockDivider#(.DIVIDER(CLOCK_RATE/DISPLAY_RATE))
        clockdiv7seg(.clkIn(clk), .clkOut(displayClk));

    logic [31:0] data7seg;
    assign data7seg = {tmpData1, tmpData2, 8'h00, tmpDataSum};

    DisplayHex7Seg dHex(.displayClk(displayClk), .data(data7seg), .ledAnode(led_anode), .ledCathode(led_cathode));

    always_ff @(posedge dataIsValid) begin
        tmpData1 <= data;
        tmpData2 <= tmpData1;
        tmpDataSum <= tmpData1 + data;
    end

    logic lastDataIsValid;
    always_ff @(posedge uartClk) begin
        txStart <= dataIsValid & ~lastDataIsValid;
        lastDataIsValid <= dataIsValid;
    end
endmodule


module UartTx #(parameter DATA_WIDTH = 8) (
    input logic uartClk,
    input logic [DATA_WIDTH-1:0] message,
    input logic start,
    output logic txd,
    output logic idle
);
    typedef enum { IDLE, START, DATA, STOP } state_t;
    state_t state = IDLE, nextState;
    logic [$clog2(DATA_WIDTH)-1:0] bitPos = DATA_WIDTH - 8, nextBitPos;

    always_comb case(state)
        IDLE: idle = 1;
        default: idle = 0;
    endcase

    always_comb case(state)
        START: txd = 0;
        DATA: txd = message[bitPos];
        default: txd = 1;
    endcase

    always_comb case(state)
        IDLE: nextState = (start === 1) ? START : IDLE;
        START: nextState = DATA;
        DATA: nextState = (bitPos % 8 === 7) ? STOP : DATA;
        STOP: nextState = (((bitPos === DATA_WIDTH - 8) && (start === 0)) === 1) ? IDLE : START;
        default: nextState = IDLE;
    endcase

    always_comb case(state)
        START: nextBitPos = bitPos;
        DATA: begin
            if (bitPos === 7) nextBitPos = DATA_WIDTH - 8;
            else if (bitPos % 8 === 7) nextBitPos = bitPos - 15;
            else nextBitPos = bitPos + 1;
        end
        STOP: nextBitPos = bitPos;
        default: nextBitPos = DATA_WIDTH - 8;
    endcase

    always_ff @(posedge uartClk) begin
        state <= nextState;
        bitPos <= nextBitPos;
    end
endmodule


module UartRx #(parameter BAUD_RATE, parameter CLOCK_RATE) (
    input logic clk,
    input logic rxd,
    output byte data,
    output logic dataIsValid
);
    localparam PULSECNT_MAX = (10 * CLOCK_RATE) / BAUD_RATE;
    localparam PULSECNT_WIDTH = $clog2(PULSECNT_MAX + 1);
    typedef enum logic [3:0] { D0, D1, D2, D3, D4, D5, D6, D7, IDLE, START, STOP } state_t;

    state_t state = IDLE, nextState;
    logic [PULSECNT_WIDTH:0] pulseCnt = 0, nextPulseCnt;
    logic startBit, pulseCntDone, pulseCntMeasure;
    byte nextData;

    always_comb case(state)
        START:   pulseCntDone = (pulseCnt === ( 2 * PULSECNT_MAX) / 20);
        D0:      pulseCntDone = (pulseCnt === ( 4 * PULSECNT_MAX) / 20);
        D1:      pulseCntDone = (pulseCnt === ( 6 * PULSECNT_MAX) / 20);
        D2:      pulseCntDone = (pulseCnt === ( 8 * PULSECNT_MAX) / 20);
        D3:      pulseCntDone = (pulseCnt === (10 * PULSECNT_MAX) / 20);
        D4:      pulseCntDone = (pulseCnt === (12 * PULSECNT_MAX) / 20);
        D5:      pulseCntDone = (pulseCnt === (14 * PULSECNT_MAX) / 20);
        D6:      pulseCntDone = (pulseCnt === (16 * PULSECNT_MAX) / 20);
        D7:      pulseCntDone = (pulseCnt === (18 * PULSECNT_MAX) / 20);
        STOP:    pulseCntDone = (pulseCnt === (20 * PULSECNT_MAX) / 20);
        default: pulseCntDone = 0;
    endcase

    always_comb case(state)
        START:   pulseCntMeasure = (pulseCnt === ( 1 * PULSECNT_MAX) / 20);
        D0:      pulseCntMeasure = (pulseCnt === ( 3 * PULSECNT_MAX) / 20);
        D1:      pulseCntMeasure = (pulseCnt === ( 5 * PULSECNT_MAX) / 20);
        D2:      pulseCntMeasure = (pulseCnt === ( 7 * PULSECNT_MAX) / 20);
        D3:      pulseCntMeasure = (pulseCnt === ( 9 * PULSECNT_MAX) / 20);
        D4:      pulseCntMeasure = (pulseCnt === (11 * PULSECNT_MAX) / 20);
        D5:      pulseCntMeasure = (pulseCnt === (13 * PULSECNT_MAX) / 20);
        D6:      pulseCntMeasure = (pulseCnt === (15 * PULSECNT_MAX) / 20);
        D7:      pulseCntMeasure = (pulseCnt === (17 * PULSECNT_MAX) / 20);
        STOP:    pulseCntMeasure = (pulseCnt === (19 * PULSECNT_MAX) / 20);
        default: pulseCntMeasure = 0;
    endcase

    always_ff @(posedge clk) begin
        state <= nextState;
        pulseCnt <= nextPulseCnt;
        data <= nextData;
    end

    always_ff @(posedge pulseCntMeasure) case(state)
        IDLE:; START:;
        STOP: if (startBit === 0 && rxd === 1) dataIsValid <= 1;
        default: dataIsValid <= 0;
    endcase

    always_ff @(posedge pulseCntMeasure) case(state)
        START: startBit <= rxd;
        D0: nextData[0] <= rxd;
        D1: nextData[1] <= rxd;
        D2: nextData[2] <= rxd;
        D3: nextData[3] <= rxd;
        D4: nextData[4] <= rxd;
        D5: nextData[5] <= rxd;
        D6: nextData[6] <= rxd;
        D7: nextData[7] <= rxd;
        default:;
    endcase

    always_comb case(state)
        IDLE: nextState = (rxd === 0) ? START : IDLE;
        START: nextState = (pulseCntDone === 1) ? D0 : START;
        D0: nextState = (pulseCntDone === 1) ? D1 : D0;
        D1: nextState = (pulseCntDone === 1) ? D2 : D1;
        D2: nextState = (pulseCntDone === 1) ? D3 : D2;
        D3: nextState = (pulseCntDone === 1) ? D4 : D3;
        D4: nextState = (pulseCntDone === 1) ? D5 : D4;
        D5: nextState = (pulseCntDone === 1) ? D6 : D5;
        D6: nextState = (pulseCntDone === 1) ? D7 : D6;
        D7: nextState = (pulseCntDone === 1) ? STOP : D7;
        STOP: nextState = (pulseCntMeasure === 0) ? STOP : IDLE;
        default: nextState = IDLE;
    endcase

    always_comb case(state)
        IDLE: nextPulseCnt = 0;
        default: nextPulseCnt = pulseCnt + 1;
    endcase
endmodule


module DisplayHex7Seg(
    input logic displayClk,
    input logic [31:0] data,
    output logic [7:0] ledAnode,
    output logic [7:0] ledCathode
);
    // There are 8 displays, so we will wrap around correctly with 3 bits
    logic [2:0] displayIndex = 0;
    logic [2:0] nextDisplayIndex;
    always_comb nextDisplayIndex = displayIndex + 1;

    logic [7:0] nextLedAnode;
    always_comb begin
        nextLedAnode = 8'b11111111;
        nextLedAnode[nextDisplayIndex] = 1'b0;
    end

    logic [7:0] nextLedCathode;
    always_comb case(data[28-4*nextDisplayIndex+:4])
        4'h0: nextLedCathode = 8'b11000000;
        4'h1: nextLedCathode = 8'b11111001;
        4'h2: nextLedCathode = 8'b10100100;
        4'h3: nextLedCathode = 8'b10110000;
        4'h4: nextLedCathode = 8'b10011001;
        4'h5: nextLedCathode = 8'b10010010;
        4'h6: nextLedCathode = 8'b10000010;
        4'h7: nextLedCathode = 8'b11111000;
        4'h8: nextLedCathode = 8'b10000000;
        4'h9: nextLedCathode = 8'b10010000;
        4'ha: nextLedCathode = 8'b10001000;
        4'hb: nextLedCathode = 8'b10000011;
        4'hc: nextLedCathode = 8'b11000110;
        4'hd: nextLedCathode = 8'b10100001;
        4'he: nextLedCathode = 8'b10000110;
        4'hf: nextLedCathode = 8'b10001110;
    endcase

    always_ff @(posedge displayClk) begin
        displayIndex <= nextDisplayIndex;
        ledAnode <= nextLedAnode;
        ledCathode <= nextLedCathode;
    end
endmodule

module ClockDivider #(parameter DIVIDER = 1) (input logic clkIn, output logic clkOut);
    logic [$clog2(DIVIDER)-1:0] counter = 0;
    always @(posedge clkIn) begin
        counter <= (counter === DIVIDER) ? 0 : (counter + 1);
        clkOut <= (counter <= DIVIDER / 2) ? 1 : 0;
    end
endmodule
