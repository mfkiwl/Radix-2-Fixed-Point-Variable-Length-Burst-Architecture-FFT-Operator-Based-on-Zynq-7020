`timescale 1ns / 1ps

module pingpongram_test#(
    parameter P_DEPTH = 2048 // Depth of RAM, should match the FFT size (2048 in this case)
  )
  (   input             i_clk,           // Clock signal from outside
      input             i_rst_n,         // Reset signal from outside (active low)
      input      [4:0]  i_current_n_cfg, // current fft size configuration from CU
      input      [1:0]  i_ram1_ctrl,     //控制pingpong_ram1的读写,默认00,read=01,write=10,from CU
      input      [1:0]  i_ram2_ctrl,     //控制pingpong_ram2的读写,默认00,read=01,write=10,from CU

      input      [31:0] i_store_data,    // Data to store from fifo, [31:16] real, [15:0] imaginary
      input             i_store_valid,   // Store valid signal from CU
      input      [15:0] i_store_addr,    // Address of store data from CU

      input      [31:0] i_do_1_bf,       // Result1 from butterfly_unit
      input      [31:0] i_do_2_bf,       // Result2 from butterfly_unit
      input             i_do_bf_valid,   //Valid signal for result from butterfly_unit

      input      [15:0] i_di_1_addr,     // Data address from CU, corresponds to do_1_addr in the figure
      input      [15:0] i_di_2_addr,     // Data address from CU, corresponds to do_2_addr in the figure
      input             i_di_valid,      // Data address valid signal from CU

      input      [15:0] i_w_addr,        //Twiddle factor address from CU
      input             i_w_valid,       //Twiddle factor address valid from CU

      output reg [31:0] o_di_1,          // Data output to butterfly_unit
      output reg [31:0] o_di_2,          // Data output to butterfly_unit
      output reg        o_di_valid,      // Data output valid signal to butterfly_unit

      output reg [31:0] o_w,             //Twiddle factor output to butterfly_unit
      output reg        o_w_valid,       //Twiddle factor valid signal output to butterfly_unit

      input             i_d_out_valid,   // Hold logic 1 until the output of FFT result ends,from CU
      input      [15:0] i_d_out_addr,    // Address from CU at the output stage

      output reg        o_cal_end,       //control signal to CU,告知计算阶段完成
      output reg        o_store_end,     //control signal to CU,告知存储阶段完成
      output reg        o_output_end,    ////control signal to CU,告知输出阶段完成
      output reg [31:0] o_ram_data_out,  // Final FFT serial output to outside
      output reg        o_ram_data_out_valid // Final FFT serial output valid signal to outside

  );

  // Signals for the ROM IP core
  reg w_rom_ena;
  reg [15:0] w_rom_addra;
  wire [31:0] w_rom_douta;

  // Instantiate the ROM IP core
  //(cancel the 'primitive register' option)
  w_rom w_rom_inst(
          .clka(i_clk),
          .ena(w_rom_ena),
          .addra(w_rom_addra),
          .douta(w_rom_douta)
        );

  // Signals for the pingpongram_1 IP core
  reg  [31:0] pingpongram_1_dina;
  reg  [31:0] pingpongram_1_dinb;
  reg  [15:0] pingpongram_1_addra;
  reg  [15:0] pingpongram_1_addrb;
  reg         pingpongram_1_wea;
  reg         pingpongram_1_web;
  reg         pingpongram_1_ena;
  reg         pingpongram_1_enb;
  wire [31:0] pingpongram_1_douta;
  wire [31:0] pingpongram_1_doutb;

  // Instantiate the pingpongram_1 IP core
  pingpongram_1 pingpongram_1_inst (
                  .clka(i_clk),
                  .wea(pingpongram_1_wea),
                  .ena(pingpongram_1_ena),       // Enable signal for port A
                  .addra(pingpongram_1_addra),
                  .dina(pingpongram_1_dina),
                  .douta(pingpongram_1_douta),
                  .clkb(i_clk),
                  .web(pingpongram_1_web),
                  .enb(pingpongram_1_enb),       // Enable signal for port B
                  .addrb(pingpongram_1_addrb),
                  .dinb(pingpongram_1_dinb),
                  .doutb(pingpongram_1_doutb)
                );

  // Signals for the pingpongram_2 IP core
  reg  [31:0] pingpongram_2_dina;
  reg  [31:0] pingpongram_2_dinb;
  reg  [15:0] pingpongram_2_addra;
  reg  [15:0] pingpongram_2_addrb;
  reg         pingpongram_2_wea;
  reg         pingpongram_2_web;
  reg         pingpongram_2_ena;
  reg         pingpongram_2_enb;
  wire [31:0] pingpongram_2_douta;
  wire [31:0] pingpongram_2_doutb;

  // Instantiate the pingpongram_2 IP core
  pingpongram_2 pingpongram_2_inst (
                  .clka(i_clk),
                  .wea(pingpongram_2_wea),
                  .ena(pingpongram_2_ena),       // Enable signal for port A
                  .addra(pingpongram_2_addra),
                  .dina(pingpongram_2_dina),
                  .douta(pingpongram_2_douta),
                  .clkb(i_clk),
                  .web(pingpongram_2_web),
                  .enb(pingpongram_2_enb),       // Enable signal for port B
                  .addrb(pingpongram_2_addrb),
                  .dinb(pingpongram_2_dinb),
                  .doutb(pingpongram_2_doutb)
                );

  reg [15:0] store_addr_reg;
  reg        store_valid_reg;

  reg [1:0]  ram1_ctrl_reg1;
  reg [1:0]  ram1_ctrl_reg2;
  reg [1:0]  ram1_ctrl_reg3;
  reg [1:0]  ram2_ctrl_reg1;
  reg [1:0]  ram2_ctrl_reg2;
  reg [1:0]  ram2_ctrl_reg3;


  reg [1:0] di_valid_reg;
  reg [2:0] d_out_valid_reg;

  reg [15:0] di_1_addr_reg1;
  reg [15:0] di_1_addr_reg2;
  reg [15:0] di_1_addr_reg3;
  reg [15:0] di_2_addr_reg1;
  reg [15:0] di_2_addr_reg2;
  reg [15:0] di_2_addr_reg3;


  reg [1:0] w_valid_reg;


  reg [15:0] store_cnt;          // cnter for store
  wire [15:0] store_cnt_max;     // Maximum value for number of data store
  assign store_cnt_max = 1<<i_current_n_cfg; //2^n

  reg [15:0] output_cnt;         // cnter for output
  wire [15:0] output_cnt_max;    // Maximum value for number of data output
  assign output_cnt_max = 1<<i_current_n_cfg; //2^n

  reg [15:0] cal_cnt;            // cnter for butterfly operation
  wire [15:0] cal_cnt_max;       // Maximum value for number of butterfly operation
  assign cal_cnt_max = i_current_n_cfg*(1<<(i_current_n_cfg-1)); //n*2^(n-1)
  //n=3 3*4 n=4 4*8 n=5 5*16 etc.






  // 输入数据打拍以及计数器逻辑
  always @(posedge i_clk or negedge i_rst_n)
  begin
    if (!i_rst_n)
    begin
      store_addr_reg <= 16'b0;
      store_valid_reg <= 1'b0;
      ram1_ctrl_reg1 <= 2'b0;
      ram1_ctrl_reg2 <= 2'b0;
      ram1_ctrl_reg3 <= 2'b0;
      ram2_ctrl_reg1 <= 2'b0;
      ram2_ctrl_reg2 <= 2'b0;
      ram2_ctrl_reg3 <= 2'b0;
      di_1_addr_reg1 <= 16'b0;
      di_1_addr_reg2 <= 16'b0;
      di_1_addr_reg3 <= 16'b0;
      di_2_addr_reg1 <= 16'b0;
      di_2_addr_reg2 <= 16'b0;
      di_2_addr_reg3 <= 16'b0;
      di_valid_reg <= 2'b0;
      d_out_valid_reg <= 3'b0;
      w_valid_reg <= 2'b0;
      store_cnt <= 16'b0;
      output_cnt <= 16'b0;
      cal_cnt <= 16'b0;
      o_cal_end <= 1'b0;
      o_store_end <= 1'b0;
      o_output_end <= 1'b0;
    end
    else
    begin
      //store信号的打拍
      store_addr_reg <= i_store_addr;
      store_valid_reg <= i_store_valid;

      //控制读写信号的打拍
      ram1_ctrl_reg1 <= i_ram1_ctrl;
      ram1_ctrl_reg2 <= ram1_ctrl_reg1;
      ram1_ctrl_reg3 <= ram1_ctrl_reg2;
      ram2_ctrl_reg1 <= i_ram2_ctrl;
      ram2_ctrl_reg2 <= ram2_ctrl_reg1;
      ram2_ctrl_reg3 <= ram2_ctrl_reg2;

      //计算有效信号和地址的打拍
      di_valid_reg[0] <= i_di_valid;
      di_valid_reg[1] <= di_valid_reg[0];
      di_1_addr_reg1 <= i_di_1_addr;
      di_1_addr_reg2 <= di_1_addr_reg1;
      di_1_addr_reg3 <= di_1_addr_reg2;
      di_2_addr_reg1 <= i_di_2_addr;
      di_2_addr_reg2 <= di_2_addr_reg1;
      di_2_addr_reg3 <= di_2_addr_reg2;

      //计算时旋转因子地址和有效信号打拍
      w_valid_reg[0] <= i_w_valid;
      w_valid_reg[1] <= w_valid_reg[0];

      //输出时有效信号的打拍
      d_out_valid_reg[0] <= i_d_out_valid;
      d_out_valid_reg[1] <= d_out_valid_reg[0];
      d_out_valid_reg[2] <= d_out_valid_reg[1];

      //用于指示每一阶段完成的逻辑
      o_cal_end <= 1'b0; //default case
      o_output_end <= 1'b0;
      o_store_end <= 1'b0;

      //判断储存阶段是否完成
      if (store_cnt >= store_cnt_max)
      begin
        o_store_end <= 1'b1;
        store_cnt <= 16'b0;
      end
      else if (store_valid_reg)
      begin
        store_cnt <= store_cnt + 1;
      end

      //判断输出阶段是否完成
      if (output_cnt >= output_cnt_max)
      begin
        o_output_end <= 1'b1;
        output_cnt <= 16'b0;
      end
      else if (d_out_valid_reg[1])
      begin
        output_cnt <= output_cnt + 1;
      end

      if (cal_cnt >= cal_cnt_max && cal_cnt_max != 0)
      begin
        o_cal_end <= 1'b1;
        cal_cnt <= 16'b0;
      end
      else if (i_do_bf_valid)
      begin //看情况调整
        cal_cnt <= cal_cnt + 1;
      end
    end
  end



  // Data storage and retrieval
  always @(posedge i_clk or negedge i_rst_n)
  begin
    if (!i_rst_n)
    begin
      o_di_1 <= 32'b0;
      o_di_2 <= 32'b0;
      o_di_valid <= 1'b0;
      o_ram_data_out <= 32'b0;
      o_ram_data_out_valid <= 1'b0;
      pingpongram_1_wea <= 1'b0;
      pingpongram_1_web <= 1'b0;
      pingpongram_1_ena <= 1'b0;
      pingpongram_1_enb <= 1'b0;
      pingpongram_1_dina <= 32'b0;
      pingpongram_1_dinb <= 32'b0;
      pingpongram_1_addra <= 0;
      pingpongram_1_addrb <= 0;
      pingpongram_2_wea <= 1'b0;
      pingpongram_2_web <= 1'b0;
      pingpongram_2_ena <= 1'b0;
      pingpongram_2_enb <= 1'b0;
      pingpongram_2_dina <= 32'b0;
      pingpongram_2_dinb <= 32'b0;
      pingpongram_2_addra <= 0;
      pingpongram_2_addrb <= 0;
      w_rom_ena <= 1'b0;
      w_rom_addra <= 11'b0;
      o_w_valid <= 1'b0;
      o_w <= 0;
    end
    else
    begin
      // Default values
      pingpongram_1_wea <= 1'b0;
      pingpongram_1_web <= 1'b0;
      pingpongram_1_ena <= 1'b0;
      pingpongram_1_enb <= 1'b0;
      pingpongram_1_dina <= 32'b0;
      pingpongram_1_dinb <= 32'b0;
      pingpongram_2_wea <= 1'b0;
      pingpongram_2_web <= 1'b0;
      pingpongram_2_ena <= 1'b0;
      pingpongram_2_enb <= 1'b0;
      pingpongram_2_dina <= 32'b0;
      pingpongram_2_dinb <= 32'b0;
      o_ram_data_out_valid <= 1'b0;
      o_di_1 <= 'b0;
      o_di_2 <= 'b0;
      o_di_valid <= 1'b0;
      w_rom_ena <= 1'b0;
      o_w_valid <= 1'b0;
      o_w <= 0;
      if (store_valid_reg && ram1_ctrl_reg1 == 2'b10)
      begin //存储阶段,比i_store_valid慢一拍,后面那个条件没啥用,只是保险
        pingpongram_1_wea <= 1'b1;
        pingpongram_1_ena <= 1'b1;
        pingpongram_1_addra <= store_addr_reg; //比i_store_addr慢一拍
        pingpongram_1_dina <= i_store_data;
      end
      else if (i_d_out_valid || d_out_valid_reg[1])
      begin // 最终输出阶段: ram1 or ram2 -> external device
        if (i_ram1_ctrl == 2'b01 || ram1_ctrl_reg2 == 2'b01)
        begin //读ram1
          pingpongram_1_ena <= i_d_out_valid;
          pingpongram_1_addra <= i_d_out_addr;
          o_ram_data_out <= pingpongram_1_douta;
          o_ram_data_out_valid <= (d_out_valid_reg[1]);
        end
        else if (i_ram2_ctrl == 2'b01 || ram2_ctrl_reg2 == 2'b01)
        begin //读ram2
          pingpongram_2_ena <= i_d_out_valid;
          pingpongram_2_addra <= i_d_out_addr;
          o_ram_data_out <= pingpongram_2_douta;
          o_ram_data_out_valid <= (d_out_valid_reg[1]);
        end
      end
      if (i_di_valid || di_valid_reg[1])
      begin // 计算和存回结果stage: butterfly  <-> RAM
        //ram1 or ram2 to butterfly
        if (i_ram1_ctrl == 2'b01 || ram1_ctrl_reg2 == 2'b01)
        begin //读ram1
          pingpongram_1_ena <= i_di_valid;
          pingpongram_1_enb <= i_di_valid;
          pingpongram_1_wea <= 1'b0;
          pingpongram_1_web <= 1'b0;
          pingpongram_1_addra <= (i_di_valid) ? i_di_1_addr :'b0;
          pingpongram_1_addrb <= (i_di_valid) ? i_di_2_addr :'b0;
          o_di_1 <=  (di_valid_reg[1])? pingpongram_1_douta :'b0; //真正取出数据比i_di_valid迟两拍
          o_di_2 <=  (di_valid_reg[1])? pingpongram_1_doutb :'b0;
          o_di_valid <= di_valid_reg[1];
        end
        else if (i_ram2_ctrl == 2'b01 || ram2_ctrl_reg2 == 2'b01)
        begin //读ram2
          pingpongram_2_ena <= i_di_valid;
          pingpongram_2_enb <= i_di_valid;
          pingpongram_2_wea <= 1'b0;
          pingpongram_2_web <= 1'b0;
          pingpongram_2_addra <= (i_di_valid) ? i_di_1_addr :'b0;
          pingpongram_2_addrb <= (i_di_valid) ? i_di_2_addr :'b0;
          o_di_1 <=  (di_valid_reg[1])? pingpongram_2_douta :'b0; //真正取出数据比i_di_valid迟两拍
          o_di_2 <=  (di_valid_reg[1])? pingpongram_2_doutb :'b0;
          o_di_valid <= di_valid_reg[1];
        end
      end
      if (i_w_valid || w_valid_reg[1])
      begin
        w_rom_ena <= i_w_valid;
        w_rom_addra <= (i_w_valid) ? i_w_addr : 'b0;
        o_w <= (w_valid_reg[1]) ? w_rom_douta : 'b0;
        o_w_valid <= w_valid_reg[1];
      end

      //Store data butterfly to ram1 or ram2 存数据比i_di_valid迟3拍
      if (i_do_bf_valid)
      begin
        if (ram1_ctrl_reg3 == 2'b10)
        begin //写ram1,这个要看情况调整
          pingpongram_1_ena <= 1;
          pingpongram_1_enb <= 1;
          pingpongram_1_wea <= 1;
          pingpongram_1_web <= 1;
          pingpongram_1_addra <= di_1_addr_reg3;  //相当于等于当前的addr_reg4
          pingpongram_1_addrb <= di_2_addr_reg3;
          pingpongram_1_dina <= i_do_1_bf;
          pingpongram_1_dinb <= i_do_2_bf;
        end
        else if (ram2_ctrl_reg3 == 2'b10)
        begin //写ram2,这个要看情况调整
          pingpongram_2_ena <= 1;
          pingpongram_2_enb <= 1;
          pingpongram_2_wea <= 1;
          pingpongram_2_web <= 1;
          pingpongram_2_addra <= di_1_addr_reg3;  //相当于等于当前的addr_reg4
          pingpongram_2_addrb <= di_2_addr_reg3;
          pingpongram_2_dina <= i_do_1_bf;
          pingpongram_2_dinb <= i_do_2_bf;
        end
      end
    end
  end


  
endmodule
