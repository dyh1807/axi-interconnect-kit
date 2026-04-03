cmake_minimum_required(VERSION 3.10)
project(axi_interconnect_kit LANGUAGES CXX)

option(AXI_KIT_BUILD_TESTS "Build AXI kit unit tests" ON)
option(AXI_KIT_BUILD_DEMOS "Build AXI kit demos" ON)
option(AXI_KIT_BUILD_SINGLE_CYCLE "Build single-cycle RV32 AXI demo" ON)
set(AXI_KIT_AXI4_UPSTREAM_WRITE_BYTES 64 CACHE STRING
    "AXI4 upstream write payload bytes (must be <=64)")
set(AXI_KIT_SIM_DDR_BEAT_BYTES 4 CACHE STRING
    "SimDDR AXI beat bytes (must be 4, 8, 16, or 32)")
set(AXI_KIT_SINGLE_CYCLE_DDR_LATENCY 8 CACHE STRING
    "SimDDR latency for single_cycle_axi4_demo")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(AXI_KIT_INCLUDE_DIRS
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/axi_interconnect/include
    ${CMAKE_CURRENT_SOURCE_DIR}/sim_ddr/include
    ${CMAKE_CURRENT_SOURCE_DIR}/mmio/include
)

set(AXI_KIT_AXI4_SOURCES
    axi_interconnect/AXI_LLC.cpp
    axi_interconnect/AXI_Interconnect.cpp
    axi_interconnect/AXI_Router_AXI4.cpp
    sim_ddr/SimDDR.cpp
    mmio/MMIO_Bus_AXI4.cpp
    mmio/UART16550_Device.cpp
)

set(AXI_KIT_AXI4_COMMON_DEFS
    AXI_KIT_MAX_WRITE_TRANSACTION_BYTES=${AXI_KIT_AXI4_UPSTREAM_WRITE_BYTES}
    AXI_KIT_SIM_DDR_BEAT_BYTES=${AXI_KIT_SIM_DDR_BEAT_BYTES}
)

add_library(axi_kit_axi4 STATIC
    ${AXI_KIT_AXI4_SOURCES}
)
target_include_directories(axi_kit_axi4 PUBLIC ${AXI_KIT_INCLUDE_DIRS})
target_compile_features(axi_kit_axi4 PUBLIC cxx_std_20)
target_compile_definitions(axi_kit_axi4 PUBLIC ${AXI_KIT_AXI4_COMMON_DEFS})

if(AXI_KIT_BUILD_TESTS)
  enable_testing()
  set(AXI_KIT_MMIO_TEST_DEFS
      MMIO_TEST_BASE=0x200000
      MMIO_TEST_SIZE=0x1000
  )
  function(add_axi_kit_write_resp_latency_test target_name latency_value)
    add_library(${target_name}_lib STATIC
        ${AXI_KIT_AXI4_SOURCES}
    )
    target_include_directories(${target_name}_lib PUBLIC ${AXI_KIT_INCLUDE_DIRS})
    target_compile_features(${target_name}_lib PUBLIC cxx_std_20)
    target_compile_definitions(${target_name}_lib PUBLIC
        ${AXI_KIT_AXI4_COMMON_DEFS}
        AXI_KIT_SIM_DDR_WRITE_RESP_LATENCY=${latency_value}
    )
    target_compile_definitions(${target_name}_lib PRIVATE
        ${AXI_KIT_MMIO_TEST_DEFS}
    )

    add_executable(${target_name}
        sim_ddr/sim_ddr_write_resp_latency_test.cpp
    )
    target_compile_definitions(${target_name} PRIVATE
        ${AXI_KIT_MMIO_TEST_DEFS}
        SIM_DDR_WRITE_RESP_TEST_LATENCY=${latency_value}
    )
    target_link_libraries(${target_name} PRIVATE ${target_name}_lib)
    add_test(NAME ${target_name} COMMAND ${target_name})
  endfunction()

  function(add_axi_kit_write_queue_test target_name beat_bytes)
    add_library(${target_name}_lib STATIC
        ${AXI_KIT_AXI4_SOURCES}
    )
    target_include_directories(${target_name}_lib PUBLIC ${AXI_KIT_INCLUDE_DIRS})
    target_compile_features(${target_name}_lib PUBLIC cxx_std_20)
    target_compile_definitions(${target_name}_lib PUBLIC
        AXI_KIT_MAX_WRITE_TRANSACTION_BYTES=${AXI_KIT_AXI4_UPSTREAM_WRITE_BYTES}
        AXI_KIT_SIM_DDR_BEAT_BYTES=${beat_bytes}
        AXI_KIT_SIM_DDR_WRITE_QUEUE_DEPTH=2
        AXI_KIT_SIM_DDR_WRITE_ACCEPT_GAP=0
        AXI_KIT_SIM_DDR_WRITE_DATA_FIFO_DEPTH=2
        AXI_KIT_SIM_DDR_WRITE_DRAIN_GAP=2
    )
    target_compile_definitions(${target_name}_lib PRIVATE
        ${AXI_KIT_MMIO_TEST_DEFS}
    )

    add_executable(${target_name}
        sim_ddr/sim_ddr_write_queue_test.cpp
    )
    target_compile_definitions(${target_name} PRIVATE
        ${AXI_KIT_MMIO_TEST_DEFS}
        SIM_DDR_WRITE_QUEUE_TEST_QUEUE_DEPTH=2
        SIM_DDR_WRITE_QUEUE_TEST_ACCEPT_GAP=0
        SIM_DDR_WRITE_QUEUE_TEST_DATA_FIFO_DEPTH=2
        SIM_DDR_WRITE_QUEUE_TEST_DRAIN_GAP=2
    )
    target_link_libraries(${target_name} PRIVATE ${target_name}_lib)
    add_test(NAME ${target_name} COMMAND ${target_name})
  endfunction()

  add_library(axi_kit_axi4_test STATIC
      ${AXI_KIT_AXI4_SOURCES}
  )
  target_include_directories(axi_kit_axi4_test PUBLIC ${AXI_KIT_INCLUDE_DIRS})
  target_compile_features(axi_kit_axi4_test PUBLIC cxx_std_20)
  target_compile_definitions(axi_kit_axi4_test PUBLIC ${AXI_KIT_AXI4_COMMON_DEFS})
  target_compile_definitions(axi_kit_axi4_test PRIVATE ${AXI_KIT_MMIO_TEST_DEFS})

  add_library(axi_kit_axi4_test_32b STATIC
      ${AXI_KIT_AXI4_SOURCES}
  )
  target_include_directories(axi_kit_axi4_test_32b PUBLIC ${AXI_KIT_INCLUDE_DIRS})
  target_compile_features(axi_kit_axi4_test_32b PUBLIC cxx_std_20)
  target_compile_definitions(axi_kit_axi4_test_32b PUBLIC
      AXI_KIT_MAX_WRITE_TRANSACTION_BYTES=${AXI_KIT_AXI4_UPSTREAM_WRITE_BYTES}
      AXI_KIT_SIM_DDR_BEAT_BYTES=32
  )
  target_compile_definitions(axi_kit_axi4_test_32b PRIVATE ${AXI_KIT_MMIO_TEST_DEFS})

  add_library(axi_kit_axi4_test_32b_wstall STATIC
      ${AXI_KIT_AXI4_SOURCES}
  )
  target_include_directories(axi_kit_axi4_test_32b_wstall PUBLIC ${AXI_KIT_INCLUDE_DIRS})
  target_compile_features(axi_kit_axi4_test_32b_wstall PUBLIC cxx_std_20)
  target_compile_definitions(axi_kit_axi4_test_32b_wstall PUBLIC
      AXI_KIT_MAX_WRITE_TRANSACTION_BYTES=${AXI_KIT_AXI4_UPSTREAM_WRITE_BYTES}
      AXI_KIT_SIM_DDR_BEAT_BYTES=32
      AXI_KIT_SIM_DDR_WRITE_ACCEPT_GAP=1
  )
  target_compile_definitions(axi_kit_axi4_test_32b_wstall PRIVATE ${AXI_KIT_MMIO_TEST_DEFS})

  add_executable(sim_ddr_test
      sim_ddr/sim_ddr_test.cpp
  )
  target_compile_definitions(sim_ddr_test PRIVATE ${AXI_KIT_MMIO_TEST_DEFS})
  target_link_libraries(sim_ddr_test PRIVATE axi_kit_axi4_test)

  add_executable(sim_ddr_32b_test
      sim_ddr/sim_ddr_32b_test.cpp
  )
  target_compile_definitions(sim_ddr_32b_test PRIVATE ${AXI_KIT_MMIO_TEST_DEFS})
  target_link_libraries(sim_ddr_32b_test PRIVATE axi_kit_axi4_test_32b)

  add_axi_kit_write_resp_latency_test(sim_ddr_write_resp_latency_0_test 0)
  add_axi_kit_write_resp_latency_test(sim_ddr_write_resp_latency_1_test 1)
  add_axi_kit_write_resp_latency_test(sim_ddr_write_resp_latency_2_test 2)
  add_axi_kit_write_queue_test(sim_ddr_write_queue_test 4)
  add_axi_kit_write_queue_test(sim_ddr_write_queue_32b_test 32)

  add_executable(axi_interconnect_test
      axi_interconnect/axi_interconnect_test.cpp
  )
  target_compile_definitions(axi_interconnect_test PRIVATE ${AXI_KIT_MMIO_TEST_DEFS})
  target_link_libraries(axi_interconnect_test PRIVATE axi_kit_axi4_test)

  add_executable(axi_interconnect_aw_latch_test
      axi_interconnect/axi_interconnect_aw_latch_test.cpp
  )
  target_compile_definitions(axi_interconnect_aw_latch_test PRIVATE ${AXI_KIT_MMIO_TEST_DEFS})
  target_link_libraries(axi_interconnect_aw_latch_test PRIVATE axi_kit_axi4_test)

  add_executable(axi_interconnect_32b_test
      axi_interconnect/axi_interconnect_32b_test.cpp
  )
  target_compile_definitions(axi_interconnect_32b_test PRIVATE ${AXI_KIT_MMIO_TEST_DEFS})
  target_link_libraries(axi_interconnect_32b_test PRIVATE axi_kit_axi4_test_32b)

  add_executable(axi_interconnect_32b_wstall_test
      axi_interconnect/axi_interconnect_32b_wstall_test.cpp
  )
  target_compile_definitions(axi_interconnect_32b_wstall_test PRIVATE ${AXI_KIT_MMIO_TEST_DEFS})
  target_link_libraries(axi_interconnect_32b_wstall_test PRIVATE axi_kit_axi4_test_32b_wstall)

  add_executable(axi_llc_test
      axi_interconnect/axi_llc_test.cpp
  )
  target_compile_definitions(axi_llc_test PRIVATE ${AXI_KIT_MMIO_TEST_DEFS})
  target_link_libraries(axi_llc_test PRIVATE axi_kit_axi4_test)

  add_executable(axi_interconnect_llc_axi4_test
      axi_interconnect/axi_interconnect_llc_axi4_test.cpp
  )
  target_compile_definitions(axi_interconnect_llc_axi4_test PRIVATE ${AXI_KIT_MMIO_TEST_DEFS})
  target_link_libraries(axi_interconnect_llc_axi4_test PRIVATE axi_kit_axi4_test)

  add_executable(mmio_router_axi4_test
      mmio/mmio_router_axi4_test.cpp
  )
  target_compile_definitions(mmio_router_axi4_test PRIVATE ${AXI_KIT_MMIO_TEST_DEFS})
  target_link_libraries(mmio_router_axi4_test PRIVATE axi_kit_axi4_test)

  add_test(NAME sim_ddr_test COMMAND sim_ddr_test)
  add_test(NAME sim_ddr_32b_test COMMAND sim_ddr_32b_test)
  add_test(NAME axi_interconnect_test COMMAND axi_interconnect_test)
  add_test(NAME axi_interconnect_aw_latch_test COMMAND axi_interconnect_aw_latch_test)
  add_test(NAME axi_interconnect_32b_test COMMAND axi_interconnect_32b_test)
  add_test(NAME axi_interconnect_32b_wstall_test COMMAND axi_interconnect_32b_wstall_test)
  add_test(NAME axi_llc_test COMMAND axi_llc_test)
  add_test(NAME axi_interconnect_llc_axi4_test COMMAND axi_interconnect_llc_axi4_test)
  add_test(NAME mmio_router_axi4_test COMMAND mmio_router_axi4_test)
endif()

if(AXI_KIT_BUILD_DEMOS)
  add_executable(axi4_smoke_demo demos/axi4_smoke.cpp)
  target_link_libraries(axi4_smoke_demo PRIVATE axi_kit_axi4)
endif()

if(AXI_KIT_BUILD_SINGLE_CYCLE)
  set(AXI_KIT_SINGLE_CYCLE_COMPILE_OPTS
      -O3
      -march=native
      -funroll-loops
      -mtune=native
  )

  set(AXI_KIT_SINGLE_CYCLE_DIR
      ${CMAKE_CURRENT_SOURCE_DIR}/demos/single_cycle
  )

  set(AXI_KIT_SINGLE_CYCLE_INCLUDE_DIRS
      ${AXI_KIT_INCLUDE_DIRS}
      ${AXI_KIT_SINGLE_CYCLE_DIR}/include
  )
  set(AXI_KIT_SINGLE_CYCLE_SOFTFLOAT_LIB
      ${AXI_KIT_SINGLE_CYCLE_DIR}/third_party/softfloat/softfloat.a
  )

  if(EXISTS "${AXI_KIT_SINGLE_CYCLE_SOFTFLOAT_LIB}")
    add_library(axi_kit_axi4_sc STATIC
        ${AXI_KIT_AXI4_SOURCES}
    )
    target_include_directories(axi_kit_axi4_sc PUBLIC ${AXI_KIT_INCLUDE_DIRS})
    target_compile_features(axi_kit_axi4_sc PUBLIC cxx_std_20)
    target_compile_definitions(axi_kit_axi4_sc PRIVATE
        ${AXI_KIT_AXI4_COMMON_DEFS}
        CONFIG_SIM_DDR_LATENCY=${AXI_KIT_SINGLE_CYCLE_DDR_LATENCY}
    )

    add_library(axi_kit_single_cycle_core STATIC
        ${AXI_KIT_SINGLE_CYCLE_DIR}/src/sc_axi4_sim_api.cpp
        ${AXI_KIT_SINGLE_CYCLE_DIR}/src/single_cycle_cpu.cpp
    )
    target_include_directories(axi_kit_single_cycle_core PUBLIC
        ${AXI_KIT_SINGLE_CYCLE_INCLUDE_DIRS}
    )
    target_compile_options(axi_kit_single_cycle_core PRIVATE
        ${AXI_KIT_SINGLE_CYCLE_COMPILE_OPTS}
    )
    target_compile_definitions(axi_kit_single_cycle_core PRIVATE
        CONFIG_SIM_DDR_LATENCY=${AXI_KIT_SINGLE_CYCLE_DDR_LATENCY}
    )
    target_link_libraries(axi_kit_single_cycle_core PUBLIC axi_kit_axi4_sc)

    add_executable(single_cycle_axi4_demo
        ${AXI_KIT_SINGLE_CYCLE_DIR}/src/main.cpp
    )
    target_include_directories(single_cycle_axi4_demo PRIVATE
        ${AXI_KIT_SINGLE_CYCLE_INCLUDE_DIRS}
    )
    target_compile_options(single_cycle_axi4_demo PRIVATE
        ${AXI_KIT_SINGLE_CYCLE_COMPILE_OPTS}
    )
    target_compile_definitions(single_cycle_axi4_demo PRIVATE
        CONFIG_SIM_DDR_LATENCY=${AXI_KIT_SINGLE_CYCLE_DDR_LATENCY}
    )
    target_link_libraries(single_cycle_axi4_demo PRIVATE
        axi_kit_single_cycle_core
        axi_kit_axi4_sc
        ${AXI_KIT_SINGLE_CYCLE_SOFTFLOAT_LIB}
        z
        stdc++fs
    )
  else()
    message(STATUS "single_cycle softfloat archive not present; skipping single_cycle demo targets")
  endif()
endif()
