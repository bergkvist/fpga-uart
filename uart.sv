`timescale 1ns/1ns

module UartTx #(parameter DATA_WIDTH) (
    input logic uartClk,
    input logic [DATA_WIDTH-1:0] message,
    input logic start,
    output logic tx = 1,
    output logic idle
);
    typedef enum logic [1:0] { IDLE, START, DATA, STOP } state_t;
    state_t state = IDLE, nextState;
    logic [10:0] bitPos = DATA_WIDTH - 8, nextBitPos;
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
    output logic [7:0] data
);
    localparam PULSECNT_MAX = CLOCK_RATE / BAUD_RATE;
    localparam PULSECNT_WIDTH = $clog2(PULSECNT_MAX);

    typedef enum logic [1:0] { IDLE, START, DATA, STOP } state_t;

    state_t state = IDLE, nextState = IDLE;
    logic [PULSECNT_WIDTH-1:0] pulseCnt = 0, nextPulseCnt;
    logic [2:0] bitCnt = 0, nextBitCnt;
    logic [7:0] buffer, nextData;
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
        DATA: buffer[bitCnt] <= rx;
        STOP: if (startBit === 0 && rx === 1) nextData <= buffer;
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
