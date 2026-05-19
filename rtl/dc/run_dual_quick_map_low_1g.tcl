set dc_dir [file normalize [file dirname [info script]]]
source [file join $dc_dir axi_llc_dc_common.tcl]

axi_llc_init_run dual_quick_map_low_1g
axi_llc_setup_libraries

set top_name [axi_llc_env_or AXI_LLC_DC_TOP axi_llc_subsystem_dual]
set flist_path [file normalize [axi_llc_env_or AXI_LLC_DC_FLIST [file join $rtl_root flist axi_llc_rtl.f]]]
set rtl_files [axi_llc_read_rtl_flist $flist_path]

puts "=== DC_TOP $top_name ==="
puts "=== DC_FLIST $flist_path ==="
puts "=== DC_RTL_FILE_COUNT [llength $rtl_files] ==="
puts "=== DC_QUICK_MAP_LOW 1 ==="

set_svf [file join $out_root ${top_name}.svf]

axi_llc_analyze_elab_link $top_name $rtl_files
axi_llc_check_link_clean
axi_llc_protect_sram_hierarchy
axi_llc_write_link_checkpoint ${top_name}_post_link
axi_llc_apply_1g_constraints
axi_llc_apply_group_template_cell_rules

puts "=== DC_STAGE quick_map_low_start [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}] ==="
flush stdout
compile -map_effort low
puts "=== DC_STAGE quick_map_low_done [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}] ==="
flush stdout

change_names -rules verilog -hierarchy
set_svf -off

puts "=== DC_STAGE quick_reports_start [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}] ==="
flush stdout
redirect -file [file join $rpt_root ${top_name}_quick_map_low_check_timing.rpt] {check_timing}
redirect -file [file join $rpt_root ${top_name}_quick_map_low_timing.rpt] {report_timing -delay max -max_paths 1}
redirect -file [file join $rpt_root ${top_name}_quick_map_low_timing_max20.rpt] {report_timing -delay max -max_paths 20}
redirect -file [file join $rpt_root ${top_name}_quick_map_low_qor.rpt] {report_qor}
redirect -file [file join $rpt_root ${top_name}_quick_map_low_area.rpt] {report_area -hierarchy}
axi_llc_write_mapped_outputs ${top_name}_quick_map_low
puts "=== DC_STAGE quick_reports_done [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}] ==="
flush stdout

puts "=== DC_RUN_ROOT $run_root ==="
quit
