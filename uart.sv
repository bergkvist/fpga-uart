`timescale 1ns/1ns

module uart(input logic clk, input logic rx, output logic tx);
    parameter CLOCK_RATE = 100_000_000;
    parameter BAUD_RATE = 9600;

    logic uartClk, dataIsValid, txStart, idle;
    byte data, tmpData, tmpDataSum;

    ClockDivider#(.DIVIDER(CLOCK_RATE/BAUD_RATE))
    clockdiv1(.clkIn(clk), .clkOut(uartClk));

    UartRx#(.BAUD_RATE(BAUD_RATE), .CLOCK_RATE(CLOCK_RATE))
    uartRx1(.clk(clk), .rx(rx), .data(data), .dataIsValid(dataIsValid));

    UartTx#(.DATA_WIDTH(8))
    uartTx1(.uartClk(uartClk), .message(tmpDataSum), .start(txStart), .tx(tx), .idle(idle));

    always_ff @(posedge dataIsValid) begin
        tmpData <= data;
        tmpDataSum <= tmpData + data;
        txStart <= 1;
    end
    always_ff @(posedge uartClk) txStart <= 0;
endmodule


module UartTx #(parameter DATA_WIDTH = 8) (
    input logic uartClk,
    input logic [DATA_WIDTH-1:0] message,
    input logic start,
    output logic tx = 1,
    output logic idle
);
    typedef enum { IDLE, START, DATA, STOP } state_t;
    state_t state = IDLE, nextState;
    logic [$clog2(DATA_WIDTH)-1:0] bitPos = DATA_WIDTH - 8, nextBitPos;
    logic nextTx;

    always_comb case(state)
        IDLE: idle = 1;
        default: idle = 0;
    endcase

    always_comb case(state)
        START: tx = 0;
        DATA: tx = message[bitPos];
        default: tx = 1;
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
    input logic rx,
    output byte data,
    output logic dataIsValid = 0
);
    localparam PULSECNT_MAX = CLOCK_RATE / BAUD_RATE;
    localparam PULSECNT_WIDTH = $clog2(PULSECNT_MAX);

    typedef enum { IDLE, START, DATA, STOP } state_t;

    state_t state = IDLE, nextState = IDLE;
    logic [PULSECNT_WIDTH-1:0] pulseCnt = 0, nextPulseCnt;
    logic [2:0] bitCnt = 0, nextBitCnt;
    byte nextData;
    logic startBit;

    logic pulseCntMeasure, pulseCntDone;
    assign pulseCntMeasure = pulseCnt === PULSECNT_MAX / 2;
    assign pulseCntDone = pulseCnt === PULSECNT_MAX - 1;

    always_ff @(posedge clk) begin
        state <= nextState;
        bitCnt <= nextBitCnt;
        pulseCnt <= nextPulseCnt;
        data <= nextData;
    end

    always_ff @(posedge pulseCntMeasure) case(state)
        START: startBit <= rx;
        DATA: begin
            nextData[bitCnt] <= rx;
            dataIsValid <= 0;
        end
        STOP: if (startBit === 0 && rx === 1) dataIsValid <= 1;
        default:;
    endcase

    always_comb case(state)
        IDLE: nextState = (rx === 0) ? START : IDLE;
        START: nextState = (pulseCntDone === 1) ? DATA : START;
        DATA: nextState = ((pulseCntDone && bitCnt === 7) === 1) ? STOP : DATA;
        STOP: nextState = (pulseCntMeasure === 0) ? STOP : IDLE;
        default: nextState = IDLE;
    endcase

    always_comb case(state)
        IDLE: nextPulseCnt = 0;
        default: nextPulseCnt = (pulseCntDone === 1) ? 0 : (pulseCnt + 1);
    endcase

    always_comb case(state)
        DATA: nextBitCnt = (pulseCntDone === 1) ? (bitCnt + 1) : bitCnt;
        default: nextBitCnt = 0;
    endcase
endmodule


module ClockDivider #(parameter DIVIDER = 1) (input logic clkIn, output logic clkOut);
    logic [$clog2(DIVIDER)-1:0] counter = 0;
    always @(posedge clkIn) begin
        counter <= (counter === DIVIDER) ? 0 : (counter + 1);
        clkOut <= (counter < DIVIDER/2) ? 1 : 0;
    end
endmodule
