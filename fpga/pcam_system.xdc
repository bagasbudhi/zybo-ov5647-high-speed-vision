# Zybo Z7-10 Rev B Pcam pin locations, from Digilent Zybo-Z7-Master.xdc.
# Sensor clock and GPIO are intentionally not present in this top yet; exact
# OV5647 module power/oscillator wiring needs physical verification.
set_property INTERNAL_VREF 0.6 [get_iobanks 35]
set_property -dict {PACKAGE_PIN J19 IOSTANDARD HSUL_12} [get_ports mipi_phy_if_0_clk_lp_n]
set_property -dict {PACKAGE_PIN H20 IOSTANDARD HSUL_12} [get_ports mipi_phy_if_0_clk_lp_p]
set_property -dict {PACKAGE_PIN M18 IOSTANDARD HSUL_12} [get_ports {mipi_phy_if_0_data_lp_n[0]}]
set_property -dict {PACKAGE_PIN L19 IOSTANDARD HSUL_12} [get_ports {mipi_phy_if_0_data_lp_p[0]}]
set_property -dict {PACKAGE_PIN L20 IOSTANDARD HSUL_12} [get_ports {mipi_phy_if_0_data_lp_n[1]}]
set_property -dict {PACKAGE_PIN J20 IOSTANDARD HSUL_12} [get_ports {mipi_phy_if_0_data_lp_p[1]}]
set_property -dict {PACKAGE_PIN H18 IOSTANDARD LVDS_25} [get_ports mipi_phy_if_0_clk_hs_n]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVDS_25} [get_ports mipi_phy_if_0_clk_hs_p]
set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVDS_25} [get_ports {mipi_phy_if_0_data_hs_n[0]}]
set_property -dict {PACKAGE_PIN M19 IOSTANDARD LVDS_25} [get_ports {mipi_phy_if_0_data_hs_p[0]}]
set_property -dict {PACKAGE_PIN L17 IOSTANDARD LVDS_25} [get_ports {mipi_phy_if_0_data_hs_n[1]}]
set_property -dict {PACKAGE_PIN L16 IOSTANDARD LVDS_25} [get_ports {mipi_phy_if_0_data_hs_p[1]}]
set_property -dict {PACKAGE_PIN F20 IOSTANDARD LVCMOS33} [get_ports IIC_0_scl_io]
set_property -dict {PACKAGE_PIN F19 IOSTANDARD LVCMOS33} [get_ports IIC_0_sda_io]
# Nominal VGA mode link frequency 145.8333 MHz -> 291.6666 Mb/s per lane.
create_clock -period 6.857 -name pcam_hs_clk [get_ports mipi_phy_if_0_clk_hs_p]
