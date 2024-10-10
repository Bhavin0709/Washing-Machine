`timescale 1ms / 1ms
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.11.2023 21:54:25
// Design Name: 
// Module Name: DP_project
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module DP_project(
    input [1:0] mode,
    input start, cancel, door_close, fill_water, drain_water, in_clk,
    output reg door_lock, fill_valve, drain_valve, motor_bled,
    output reg [3:0] mode_led,
    output reg [2:0] status,  
    output reg [4:0] ps_led,
    output reg [6:0] lcd_out,
    output reg [7:0] lcd_an
    );
    reg [17:0] clk_counter, lcd_counter;
    reg motor = 0, clk = 0, display_flag = 0;
    reg wash_up = 0, wash_done = 0, rinse_up = 0, rinse_done = 0, spin_up = 0, spin_done = 0;
    reg [16:0]  washcount, rinsecount, spincount;
    reg [4:0] pwm_count = 0, duty = 0;
    reg [2:0] ps = 0,ns = 0, motor_count = 0;
    
    reg [1:0] step = 0;
    reg [1:0] digit_display = 0;
    reg [6:0] display1 [1:0];
    reg [3:0] lcd_bit [1:0];
    
    reg [4:0] display = 0;
    parameter idle = 3'b000,
              ready = 3'b001,
              wash = 3'b010,
              rinse = 3'b011,
              spin = 3'b100;

    initial 
        begin
            door_lock = 1'b0;
            motor = 1'b0;
            fill_valve = 1'b0;
            drain_valve = 1'b0;
            mode_led = 0;
            status = 3'b000;
            ps_led = 5'b00000; 
            clk = 1'b0;
        end        
              
//     generation clock cycle with 250hz freq from inbuit 100 Mhz     
    always@(posedge in_clk)
        begin
            if(clk_counter <= 200000)   // 100*1000_000 / (250 * 2) 
                clk_counter <= clk_counter + 1'b1; 
            else
                begin
                clk <= ~clk;
                clk_counter <= 1'b1;
                end
        end
   
//     check reset - sequential crt
    always@(posedge clk or posedge cancel)
        begin
            if(cancel)
                ps <= idle;
            else
                ps <= ns; 
        end
    
    // next state logic
    always@(*)
        begin
            case(ps)
                idle:                        
                    if(start && door_close)
                        begin
                        door_lock = 1'b1;
                        status = 3'b010;  // green color 
                        ns = ready;
                        end
                    else if(start && !door_close)
                        begin
                        status = 3'b001;  // error - red color
                        ns = idle;
                        end
                    else
                        begin
                        status = 3'b100;  // blue color                        
                        case(mode)
                            2'b00 : begin
                                    mode_led = 4'b0001;
                                    end
                            2'b01 : begin
                                    mode_led = 4'b0010;
                                    end
                            2'b10 : begin
                                    mode_led = 4'b0100;
                                    end
                            2'b11 : begin
                                    mode_led = 4'b1000;
                                    end
                        endcase 
                        ps_led = 5'b00001;
                        door_lock = 1'b0;
                        fill_valve = 1'b0;
                        drain_valve = 1'b0;
                        ns = idle;
                        step = 2'b00;
                        end
                        
                 ready:
                    if(mode == 2'b00)
                        begin
                        ps_led = 5'b00010;
                        mode_led = 4'b0001;
                        step = 2'b00;
                        ns = wash;
                        end
                    else if(mode == 2'b01)
                        begin
                        ps_led = 5'b00010;
                        mode_led = 4'b0010;
                        step = 2'b00;
                        ns = wash;
                        end
                    else if(mode == 2'b10)
                        begin
                        ps_led = 5'b00010;
                        mode_led = 4'b0100;
                        step = 2'b00;
                        ns = rinse;
                        end
                    else if(mode == 2'b11)
                        begin
                        ps_led = 5'b00010;
                        mode_led = 4'b1000;
                        step = 2'b00;
                        ns = spin;
                        end
                    else
                        begin
                        ps_led = 5'b00010;
                        mode_led = 4'b0000;
                        ns = ready;
                        end
                        
                  wash:
                    begin
                        if(step == 2'b00)
                            begin
                            ps_led = 5'b00100;
                            fill_valve = 1'b1;
                            step = fill_water;
                            ns = wash;
                            end
                        else if(step == 2'b01)
                            begin
                            ps_led = 5'b00100;
                            fill_valve = 1'b0;
                            wash_up = 1'b1;
                            motor = 1'b1;                         
                            step = step + wash_done;
                            ns = wash;
                            end
                        else if(step == 2'b10)
                            begin
                            ps_led = 5'b00100;
                            motor = 1'b0;
                            wash_up = 1'b0;
                            drain_valve = 1'b1;
                            step = step + drain_water;
                            ns = wash;
                            end
                        else if(step == 2'b11)
                            begin
                            ps_led = 5'b00100;
                            drain_valve = 1'b0;
                            ns = rinse;
//                            step = 2'b00;
                            end
                        else
                            ns = wash;
                    end
        
                  rinse:
                    begin
                        if(step == 2'b11 && !rinse_done)
                            step = 2'b00;
                        else if(step == 2'b00)
                            begin
                            ps_led = 5'b01000;
                            fill_valve = 1'b1;
                            step = fill_water;
                            ns = rinse;
                            end
                        else if(step == 2'b01)
                            begin
                            fill_valve = 1'b0;
                            rinse_up = 1'b1;
                            motor = 1'b1;
                            step = step + rinse_done;
                            ns = rinse;
                            end
                        else if(step == 2'b10)
                            begin
                            motor = 1'b0;
                            rinse_up = 1'b0;
                            drain_valve = 1'b1;
                            step = step + drain_water;
                            ns = rinse;
                            end
                        else if(step == 2'b11)
                            begin
                            drain_valve = 1'b0;
                            ns = spin;
                            end
                        else
                            ns = rinse;
                    end

                  spin:
                    if(!spin_done)
                        begin
                        ps_led = 5'b10000;
                        spin_up = 1'b1;
                        motor = 1'b1;
                        ns = spin;
                        end
                    else if(spin_done)
                        begin
                        ps_led = 5'b10000;
                        spin_up = 1'b0;
                        motor = 1'b0;
                        door_lock = 1'b0;
                        ns = idle;
                        end
                    else
                        ns = spin;

            endcase
        end
        
    // check wash time 
    always@(mode, washcount)
        begin
            if(mode == 2'b00)
                wash_done = (washcount == 1500) ? 1'b1 : 1'b0;  // 6 sec
            else if(mode == 2'b01)
                wash_done = (washcount == 1250) ? 1'b1 : 1'b0;  // 5 sec
            else
                wash_done = 1'b0;
        end
        
    // check rinse time 
    always@(mode, rinsecount)
        begin
            if(mode == 2'b00)
                rinse_done = (rinsecount == 1500) ? 1'b1 : 1'b0;  // 6 sec
            else if(mode == 2'b01)
                rinse_done = (rinsecount == 1000) ? 1'b1 : 1'b0;  // 4 sec
            else if(mode == 2'b10)
                rinse_done = (rinsecount == 1500) ? 1'b1 : 1'b0;  // 6 sec
            else 
                rinse_done = 1'b0;
        end
            
    // check spin time 
    always@(mode, spincount)
        begin
            if(mode == 2'b00)
                spin_done = (spincount == 1000) ? 1'b1 : 1'b0;  // 4sec
            else if(mode == 2'b01)
                spin_done = (spincount == 750) ? 1'b1 : 1'b0;  // 3 sec
            else if(mode == 2'b10)
                spin_done = (spincount == 1000) ? 1'b1 : 1'b0;  // 4 sec
            else if(mode == 2'b11)
                spin_done = (spincount == 1000) ? 1'b1 : 1'b0;  // sec
            else
                spin_done = 1'b0;
        end
    
    // count wash time 
    always@(posedge clk)
        begin
            if(wash_done && ps == 3'b010)
                begin
                washcount <= washcount;
                end
            else if(wash_up)
                begin
                washcount <= washcount + 1'b1;
                end
            else
                begin
                washcount <= 0;
                end
        end	
        
    // count rinse time 
    always@(posedge clk)
        begin
            if(rinse_done && ps == 3'b011)
                begin
                rinsecount <= rinsecount;
                end
            else if(rinse_up)
                begin
                rinsecount <= rinsecount + 1'b1;
                end
            else
                begin
                rinsecount <= 0;
                end
        end	
    
    // count spin time 
    always@(posedge clk)
        begin
            if(spin_done && ps == 3'b100)
                begin
                spincount <= spincount;
                end
            else if(spin_up)
                begin
                spincount <= spincount + 1'b1;
                end
            else
                begin
                spincount <= 0;
            end
        end	
     
    
    always@(posedge clk)
        begin        
            if(ps == 3'b000)
                begin
                case(mode)
                    2'b00 : display <= 16;
                    2'b01 : display <= 12;
                    2'b10 : display <= 10;
                    2'b11 : display <= 4;
                endcase 
                end
                
            else if(wash_up)
                begin
                if((washcount % 250) == 0)
                    begin
                    display <= display - 1'b1;
                    end
                else
                    display <= display;
                end
            
            else if(rinse_up)
                begin
                if((rinsecount % 250) == 0)
                    begin
                    display <= display - 1'b1;
                    end
                else
                    display <= display;
                end
            
            else if(spin_up)
                begin
                if((spincount % 250) == 0)
                    begin
                    display <= display - 1'b1;
                    end
                else
                    display <= display;
                end
            else
                display <= display;
        end
    
    
    //   lcd display
    always@(posedge in_clk)
        begin
            if(lcd_counter <= 200000)   // 100*1000_000 / (250 * 2) 
                lcd_counter <= lcd_counter + 1'b1; 
            else
                begin
                digit_display <= digit_display + 1'b1;
                lcd_counter <= 1'b1;
                end   
            
            case(display)
                0 : begin
                    lcd_bit[0] <= 4'b0000;
                    lcd_bit[1] <= 4'b0000;
                    end
                1 : begin
                    lcd_bit[0] <= 4'b0001;
                    lcd_bit[1] <= 4'b0000;
                    end
                2 : begin
                    lcd_bit[0] <= 4'b0010;
                    lcd_bit[1] <= 4'b0000;
                    end
                3 : begin
                    lcd_bit[0] <= 4'b0011;
                    lcd_bit[1] <= 4'b0000;
                    end
                4 : begin
                    lcd_bit[0] <= 4'b0100;
                    lcd_bit[1] <= 4'b0000;
                    end
                5 : begin
                    lcd_bit[0] <= 4'b0101;
                    lcd_bit[1] <= 4'b0000;
                    end
                6 : begin
                    lcd_bit[0] <= 4'b0110;
                    lcd_bit[1] <= 4'b0000;
                    end
                7 : begin
                    lcd_bit[0] <= 4'b0111;
                    lcd_bit[1] <= 4'b0000;
                    end
                8 : begin
                    lcd_bit[0] <= 4'b1000;
                    lcd_bit[1] <= 4'b0000;
                    end
                9 : begin
                    lcd_bit[0] <= 4'b1001;
                    lcd_bit[1] <= 4'b0000;
                    end
               10 : begin
                    lcd_bit[0] <= 4'b0000;
                    lcd_bit[1] <= 4'b0001;
                    end
               11 : begin
                    lcd_bit[0] <= 4'b0001;
                    lcd_bit[1] <= 4'b0001;
                    end
               12 : begin
                    lcd_bit[0] <= 4'b0010;
                    lcd_bit[1] <= 4'b0001;
                    end
               13 : begin
                    lcd_bit[0] <= 4'b0011;
                    lcd_bit[1] <= 4'b0001;
                    end
               14 : begin
                    lcd_bit[0] <= 4'b0100;
                    lcd_bit[1] <= 4'b0001;
                    end
               15 : begin
                    lcd_bit[0] <= 4'b0101;
                    lcd_bit[1] <= 4'b0001;
                    end
               16 : begin
                    lcd_bit[0] <= 4'b0110;
                    lcd_bit[1] <= 4'b0001;
                    end  
          default : begin
                    lcd_bit[0] <= 4'b0000;
                    lcd_bit[1] <= 4'b0000;
                    end 
            endcase
               
            case(lcd_bit[digit_display])
                0 : display1[digit_display] <= 7'b1000000;
                1 : display1[digit_display] <= 7'b1111001;
                2 : display1[digit_display] <= 7'b0100100;
                3 : display1[digit_display] <= 7'b0110000;
                4 : display1[digit_display] <= 7'b0011001;
                5 : display1[digit_display] <= 7'b0010010;
                6 : display1[digit_display] <= 7'b0000010;
                7 : display1[digit_display] <= 7'b1111000;
                8 : display1[digit_display] <= 7'b0000000;
                9 : display1[digit_display] <= 7'b0010000;
          default : display1[digit_display] <= 7'b1111111;
            endcase
            
            case(digit_display)
                0 : begin
                    lcd_an <= 8'b11111110;
                    lcd_out <= display1[0];
                    end
                    
                1 : begin
                    lcd_an <= 8'b11111101;
                    lcd_out <= display1[1];
                    end
            endcase
        end

endmodule
