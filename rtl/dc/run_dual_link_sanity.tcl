set dc_dir [file normalize [file dirname [info script]]]
source [file join $dc_dir axi_llc_dc_common.tcl]

axi_llc_init_run dual_link_sanity
axi_llc_setup_libraries

set top_name [axi_llc_env_or AXI_LLC_DC_TOP axi_llc_subsystem_dual]
set flist_path [file normalize [axi_llc_env_or AXI_LLC_DC_FLIST [file join $rtl_root flist axi_llc_rtl.f]]]
set rtl_files [axi_llc_read_rtl_flist $flist_path]

puts "=== DC_TOP $top_name ==="
puts "=== DC_FLIST $flist_path ==="
puts "=== DC_RTL_FILE_COUNT [llength $rtl_files] ==="

axi_llc_analyze_elab_link $top_name $rtl_files
axi_llc_check_link_clean
axi_llc_write_link_checkpoint ${top_name}_link_sanity

puts "=== DC_RUN_ROOT $run_root ==="
quit
