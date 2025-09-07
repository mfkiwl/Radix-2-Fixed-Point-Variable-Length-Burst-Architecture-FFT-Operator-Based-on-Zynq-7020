# 时钟约束  
set_property PACKAGE_PIN M19 [get_ports {i_clk}]        
set_property IOSTANDARD LVCMOS33 [get_ports {i_clk}]    

# 复位约束  
set_property PACKAGE_PIN L18 [get_ports {i_rst_n}]       
set_property IOSTANDARD LVCMOS33 [get_ports {i_rst_n}]   

# 按钮约束  
set_property PACKAGE_PIN AB6 [get_ports {i_btn}]          
set_property IOSTANDARD LVCMOS33 [get_ports {i_btn}]    