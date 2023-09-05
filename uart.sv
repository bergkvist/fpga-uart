module uart_tx(input logic clk, output logic tx = 1);
    typedef enum logic [1:0] { IDLE = 0, START = 1, DATA = 2, STOP = 3 } state_t;

    localparam message_length = 13*8;
    logic [message_length-1:0] message = "Hello World! ";

    state_t state = IDLE, next_state;
    logic [10:0] bit_pos = 0, next_bit_pos;
    logic next_tx;
    
    always_ff @(posedge clk) begin
        state <= next_state;
        bit_pos <= next_bit_pos;
        tx <= next_tx;
    end
    
    always_comb case(state)
        IDLE: next_bit_pos = message_length - 8;
        START: next_bit_pos = bit_pos;
        DATA: begin
            if (bit_pos === 7) next_bit_pos = message_length - 8;
            else if (bit_pos % 8 === 7) next_bit_pos = bit_pos - 15;
            else next_bit_pos = bit_pos + 1;
        end
        STOP: next_bit_pos = bit_pos;
    endcase

    always_comb case(next_state)
        IDLE: next_tx = 1;
        START: next_tx = 0;
        DATA: next_tx = message[next_bit_pos];
        STOP: next_tx = 1;
    endcase

    always_comb case(state)
        IDLE: next_state = START;
        START: next_state = DATA;
        DATA: next_state = (bit_pos % 8 === 7) ? STOP : DATA;
        STOP: next_state = START;
    endcase
endmodule
