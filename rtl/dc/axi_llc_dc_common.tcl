proc axi_llc_env_or {name default_value} {
    if {[info exists ::env($name)] && $::env($name) ne ""} {
        return $::env($name)
    }
    return $default_value
}

proc axi_llc_first_existing {paths} {
    foreach p $paths {
        if {[file exists $p]} {
            return $p
        }
    }
    return [lindex $paths 0]
}

proc axi_llc_init_run {default_tag} {
    global dc_dir rtl_root repo_root run_root work_root rpt_root out_root

    set dc_dir [file normalize [file dirname [info script]]]
    set rtl_root [file normalize [file join $dc_dir ..]]
    set repo_root [file normalize [file join $rtl_root ..]]

    set stamp [clock format [clock seconds] -format {%Y%m%d_%H%M%S}]
    set default_run_root [file join $dc_dir runs ${default_tag}_${stamp}]
    set run_root [file normalize [axi_llc_env_or AXI_LLC_DC_RUN_ROOT $default_run_root]]
    set work_root [file join $run_root work]
    set rpt_root [file join $run_root reports]
    set out_root [file join $run_root outputs]

    file mkdir $run_root
    file mkdir $work_root
    file mkdir $rpt_root
    file mkdir $out_root
    file mkdir [file join $out_root ddc]
    file mkdir [file join $out_root netlist]
    file mkdir [file join $out_root db]
    file mkdir [file join $out_root sdc]
    file mkdir [file join $out_root sdf]

    define_design_lib WORK -path [file join $work_root WORK]
}

proc axi_llc_setup_libraries {} {
    global rtl_root run_root std_db data_db meta_db

    set std_default [axi_llc_first_existing [list \
        /centos7/eda-tools/eda-software/standard_cell/smic12/SCC12NSFE_96SDB_7P5TC16_LVT_V1P1D/Liberty/0.8v/scc12nsfe_96sdb_7p5tc16_lvt_ssgs_v0p72_125c_ccs.db \
        /eda-tools/eda-software/standard_cell/smic12/SCC12NSFE_96SDB_7P5TC16_LVT_V1P1D/Liberty/0.8v/scc12nsfe_96sdb_7p5tc16_lvt_ssgs_v0p72_125c_ccs.db]]
    set data_default /nfs_global/S/daiyihao/project/qm-rocky/dev/addr_map_dev/srams_candidatres/llc_data_explore_large_260424/compout/views/sassls0c4l1p4096x256m4b4w1c1p0d0t0s2sdz1rw00/ssgs_ccw0p72v125c/sassls0c4l1p4096x256m4b4w1c1p0d0t0s2sdz1rw00.db
    set meta_default /nfs_global/S/daiyihao/project/qm-rocky/dev/addr_map_dev/srams_candidatres/llc_meta_explore_260423/compout/views/sassls0c4l1p4096x16m16b1w1c1p0d0t0s2sdz1rw00/ssgs_ccw0p72v125c/sassls0c4l1p4096x16m16b1w1c1p0d0t0s2sdz1rw00.db

    set std_db [file normalize [axi_llc_env_or AXI_LLC_DC_STD_DB $std_default]]
    set data_db [file normalize [axi_llc_env_or AXI_LLC_DC_DATA_DB $data_default]]
    set meta_db [file normalize [axi_llc_env_or AXI_LLC_DC_META_DB $meta_default]]

    foreach required_db [list $std_db $data_db $meta_db] {
        if {![file exists $required_db]} {
            puts "=== AXI_LLC_DC_MISSING_DB $required_db ==="
            exit 2
        }
    }

    set_app_var search_path [list $rtl_root [file join $rtl_root include] [file join $rtl_root src] $run_root]
    set_app_var target_library [list $std_db]
    set_app_var synthetic_library [list standard.sldb dw_foundation.sldb]
    set_app_var link_library [concat [list * $std_db $data_db $meta_db] [get_app_var synthetic_library]]
    set hdlin_while_loop_iterations 6000

    puts "=== DC_STAGE read_data_db_start [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}] ==="
    flush stdout
    read_db $data_db
    puts "=== DC_STAGE read_data_db_done [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}] ==="
    flush stdout
    puts "=== DC_STAGE read_meta_db_start [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}] ==="
    flush stdout
    read_db $meta_db
    puts "=== DC_STAGE read_meta_db_done [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}] ==="
    flush stdout
}

proc axi_llc_read_rtl_flist {flist_path} {
    global rtl_root

    set files [list]
    set fp [open $flist_path r]
    while {[gets $fp line] >= 0} {
        set line [string trim $line]
        if {$line eq "" || [string match "#*" $line]} {
            continue
        }
        if {[string match "+incdir+*" $line]} {
            continue
        }
        if {[string match "-f *" $line]} {
            puts "=== AXI_LLC_DC_UNSUPPORTED_NESTED_FLIST $line ==="
            exit 3
        }
        set f [file normalize [file join $rtl_root $line]]
        if {![file exists $f]} {
            puts "=== AXI_LLC_DC_MISSING_RTL $f ==="
            exit 4
        }
        lappend files $f
    }
    close $fp
    return $files
}

proc axi_llc_analyze_elab_link {top_name rtl_files} {
    global rtl_root rpt_root

    puts "=== DC_STAGE analyze_start [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}] ==="
    flush stdout
    analyze -vcs "+incdir+$rtl_root/include" -format verilog $rtl_files
    puts "=== DC_STAGE analyze_done [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}] ==="
    flush stdout

    puts "=== DC_STAGE elaborate_start [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}] ==="
    flush stdout
    elaborate $top_name
    current_design $top_name
    redirect -file [file join $rpt_root link.rpt] {link}
    uniquify
    puts "=== DC_STAGE elaborate_done [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}] ==="
    flush stdout
}

proc axi_llc_check_link_clean {} {
    global rpt_root

    redirect -file [file join $rpt_root check_design_post_link.rpt] {check_design}
    redirect -file [file join $rpt_root report_reference_post_link.rpt] {report_reference}
    redirect -file [file join $rpt_root report_design_post_link.rpt] {report_design}

    set combined ""
    foreach report_file [list \
        [file join $rpt_root link.rpt] \
        [file join $rpt_root check_design_post_link.rpt] \
        [file join $rpt_root report_reference_post_link.rpt] \
        [file join $rpt_root report_design_post_link.rpt]] {
        set fp [open $report_file r]
        append combined [read $fp]
        close $fp
    }

    if {[regexp {UID-341|LINK-5|LBR-1|Unable to resolve reference|Cannot find the design|unresolved references} $combined]} {
        puts "=== LINK_SANITY_FAIL ==="
        exit 5
    }
    puts "=== LINK_SANITY_PASS ==="
}

proc axi_llc_apply_1g_constraints {} {
    set clock_name clk_1g
    set clock_period 1.0

    create_clock -period $clock_period -name $clock_name [get_ports clk]
    set_clock_uncertainty 0.05 [get_clocks $clock_name]

    set non_clock_inputs [remove_from_collection [all_inputs] [get_ports {clk rst_n}]]
    if {[sizeof_collection $non_clock_inputs] > 0} {
        set_input_delay 0.05 -clock $clock_name $non_clock_inputs
    }
    if {[sizeof_collection [all_outputs]] > 0} {
        set_output_delay 0.05 -clock $clock_name [all_outputs]
    }

    set_fix_multiple_port_nets -all -buffer_constants [current_design]
}

proc axi_llc_apply_hierarchy_guards {} {
    set macro_cells [get_cells -hierarchical -quiet *u_macro*]
    if {[sizeof_collection $macro_cells] > 0} {
        set_ungroup $macro_cells false
        set_boundary_optimization $macro_cells false
        set_dont_touch $macro_cells true
    }

    set protect_cells [get_cells -hierarchical -quiet [list \
        compat \
        compat/core \
        compat/core/data_store \
        compat/core/meta_store \
        bridge]]
    if {[sizeof_collection $protect_cells] > 0} {
        set_ungroup $protect_cells false
        set_boundary_optimization $protect_cells false
    }
}

proc axi_llc_write_link_checkpoint {stem} {
    global out_root
    write_file -format ddc -hierarchy -output [file join $out_root ddc ${stem}.ddc]
}

proc axi_llc_write_reports {stem} {
    global rpt_root
    redirect -file [file join $rpt_root ${stem}_timing.rpt] {report_timing -delay max -max_paths 1}
    redirect -file [file join $rpt_root ${stem}_timing_max80.rpt] {report_timing -delay max -max_paths 80}
    redirect -file [file join $rpt_root ${stem}_qor.rpt] {report_qor}
    redirect -file [file join $rpt_root ${stem}_area.rpt] {report_area -hierarchy}
    redirect -file [file join $rpt_root ${stem}_references.rpt] {report_reference}
    redirect -file [file join $rpt_root ${stem}_cell.rpt] {report_cell [get_cells -hier *]}
    redirect -file [file join $rpt_root ${stem}_constraint.rpt] {report_constraint -all_violators -verbose}
    redirect -file [file join $rpt_root ${stem}_power.rpt] {report_power -analysis_effort high -verbose}
    redirect -file [file join $rpt_root ${stem}_check_design.rpt] {check_design}
}

proc axi_llc_write_mapped_outputs {stem} {
    global out_root
    write_file -format ddc -hierarchy -output [file join $out_root ddc ${stem}.ddc]
    write_file -format verilog -hierarchy -output [file join $out_root netlist ${stem}.v]
    write -format db -hierarchy -output [file join $out_root db ${stem}.db]
    write_sdc [file join $out_root sdc ${stem}.sdc]
    write_sdf -version 1.0 [file join $out_root sdf ${stem}.sdf]
}
