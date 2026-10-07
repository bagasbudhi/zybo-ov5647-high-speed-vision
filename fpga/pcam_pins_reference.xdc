# Pcam port map for Zybo Z7 Rev. B, transcribed from Digilent's Zybo-Z7-Master.xdc.
# REFERENCE ONLY: this file is not included by build.tcl. Use after the top
# level port names, exact sensor clock/GPIO wiring, IP D-PHY configuration,
# I/O bank VREF and external clock constraints have been checked on hardware.
# https://github.com/Digilent/Zybo-Z7-10-Pmod-VGA/blob/master/src/constraints/Zybo-Z7-Master.xdc

# set_property INTERNAL_VREF 0.6 [get_iobanks 35]
# set_property -dict {PACKAGE_PIN J19 IOSTANDARD HSUL_12} [get_ports dphy_clk_lp_n]
# set_property -dict {PACKAGE_PIN H20 IOSTANDARD HSUL_12} [get_ports dphy_clk_lp_p]
# set_property -dict {PACKAGE_PIN M18 IOSTANDARD HSUL_12} [get_ports {dphy_data_lp_n[0]}]
# set_property -dict {PACKAGE_PIN L19 IOSTANDARD HSUL_12} [get_ports {dphy_data_lp_p[0]}]
# set_property -dict {PACKAGE_PIN L20 IOSTANDARD HSUL_12} [get_ports {dphy_data_lp_n[1]}]
# set_property -dict {PACKAGE_PIN J20 IOSTANDARD HSUL_12} [get_ports {dphy_data_lp_p[1]}]
# set_property -dict {PACKAGE_PIN H18 IOSTANDARD LVDS_25} [get_ports dphy_hs_clock_clk_n]
# set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVDS_25} [get_ports dphy_hs_clock_clk_p]
# set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVDS_25} [get_ports {dphy_data_hs_n[0]}]
# set_property -dict {PACKAGE_PIN M19 IOSTANDARD LVDS_25} [get_ports {dphy_data_hs_p[0]}]
# set_property -dict {PACKAGE_PIN L17 IOSTANDARD LVDS_25} [get_ports {dphy_data_hs_n[1]}]
# set_property -dict {PACKAGE_PIN L16 IOSTANDARD LVDS_25} [get_ports {dphy_data_hs_p[1]}]
# set_property -dict {PACKAGE_PIN G19 IOSTANDARD LVCMOS33} [get_ports cam_clk]
# set_property -dict {PACKAGE_PIN G20 IOSTANDARD LVCMOS33 PULLUP true} [get_ports cam_gpio]
# set_property -dict {PACKAGE_PIN F20 IOSTANDARD LVCMOS33} [get_ports cam_scl]
# set_property -dict {PACKAGE_PIN F19 IOSTANDARD LVCMOS33} [get_ports cam_sda]

# For 291.667 Mb/s per lane the high-speed clock is about 145.833 MHz.
# The actual sensor PLL mode and D-PHY recovered clock must be confirmed.
# create_clock -period 6.857 -name dphy_hs_clock_clk_p [get_ports dphy_hs_clock_clk_p]
