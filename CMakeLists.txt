cmake_minimum_required(VERSION 3.10)
project(axi_interconnect_kit LANGUAGES CXX)

option(AXI_KIT_BUILD_TESTS "Build AXI kit unit tests" ON)
option(AXI_KIT_BUILD_DEMOS "Build AXI kit demos" ON)
option(AXI_KIT_BUILD_SINGLE_CYCLE "Build single-cycle RV32 AXI demo" ON)
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

add_library(axi_kit_axi4 STATIC
    axi_interconnect/AXI_Interconnect.cpp
    axi_interconnect/AXI_Router_AXI4.cpp
    sim_ddr/SimDDR.cpp
    mmio/MMIO_Bus_AXI4.cpp
    mmio/UART16550_Device.cpp
)
target_include_directories(axi_kit_axi4 PUBLIC ${AXI_KIT_INCLUDE_DIRS})
target_compile_features(axi_kit_axi4 PUBLIC cxx_std_20)

add_library(axi_kit_axi3 STATIC
    axi_interconnect/AXI_Interconnect_AXI3.cpp
    axi_interconnect/AXI_Router_AXI3.cpp
    sim_ddr/SimDDR_AXI3.cpp
    mmio/MMIO_Bus_AXI3.cpp
    mmio/UART16550_Device.cpp
)
target_include_directories(axi_kit_axi3 PUBLIC ${AXI_KIT_INCLUDE_DIRS})
target_compile_features(axi_kit_axi3 PUBLIC cxx_std_20)

if(AXI_KIT_BUILD_TESTS)
  enable_testing()
  set(AXI_KIT_MMIO_TEST_DEFS
      MMIO_TEST_BASE=0x200000
      MMIO_TEST_SIZE=0x1000
  )
  add_library(axi_kit_axi4_test STATIC
      axi_interconnect/AXI_Interconnect.cpp
      axi_interconnect/AXI_Router_AXI4.cpp
      sim_ddr/SimDDR.cpp
      mmio/MMIO_Bus_AXI4.cpp
      mmio/UART16550_Device.cpp
  )
  target_include_directories(axi_kit_axi4_test PUBLIC ${AXI_KIT_INCLUDE_DIRS})
  target_compile_features(axi_kit_axi4_test PUBLIC cxx_std_20)
  target_compile_definitions(axi_kit_axi4_test PRIVATE ${AXI_KIT_MMIO_TEST_DEFS})

  add_library(axi_kit_axi3_test STATIC
      axi_interconnect/AXI_Interconnect_AXI3.cpp
      axi_interconnect/AXI_Router_AXI3.cpp
      sim_ddr/SimDDR_AXI3.cpp
      mmio/MMIO_Bus_AXI3.cpp
      mmio/UART16550_Device.cpp
  )
  target_include_directories(axi_kit_axi3_test PUBLIC ${AXI_KIT_INCLUDE_DIRS})
  target_compile_features(axi_kit_axi3_test PUBLIC cxx_std_20)
  target_compile_definitions(axi_kit_axi3_test PRIVATE ${AXI_KIT_MMIO_TEST_DEFS})

  add_executable(sim_ddr_test
      sim_ddr/sim_ddr_test.cpp
  )
  target_compile_definitions(sim_ddr_test PRIVATE ${AXI_KIT_MMIO_TEST_DEFS})
  target_link_libraries(sim_ddr_test PRIVATE axi_kit_axi4_test)

  add_executable(axi_interconnect_test
      axi_interconnect/axi_interconnect_test.cpp
  )
  target_compile_definitions(axi_interconnect_test PRIVATE ${AXI_KIT_MMIO_TEST_DEFS})
  target_link_libraries(axi_interconnect_test PRIVATE axi_kit_axi4_test)

  add_executable(mmio_router_axi4_test
      mmio/mmio_router_axi4_test.cpp
  )
  target_compile_definitions(mmio_router_axi4_test PRIVATE ${AXI_KIT_MMIO_TEST_DEFS})
  target_link_libraries(mmio_router_axi4_test PRIVATE axi_kit_axi4_test)

  add_executable(sim_ddr_axi3_test
      sim_ddr/sim_ddr_axi3_test.cpp
  )
  target_compile_definitions(sim_ddr_axi3_test PRIVATE ${AXI_KIT_MMIO_TEST_DEFS})
  target_link_libraries(sim_ddr_axi3_test PRIVATE axi_kit_axi3_test)

  add_executable(axi_interconnect_axi3_test
      axi_interconnect/axi_interconnect_axi3_test.cpp
  )
  target_compile_definitions(axi_interconnect_axi3_test PRIVATE ${AXI_KIT_MMIO_TEST_DEFS})
  target_link_libraries(axi_interconnect_axi3_test PRIVATE axi_kit_axi3_test)

  add_executable(mmio_router_axi3_test
      mmio/mmio_router_axi3_test.cpp
  )
  target_compile_definitions(mmio_router_axi3_test PRIVATE ${AXI_KIT_MMIO_TEST_DEFS})
  target_link_libraries(mmio_router_axi3_test PRIVATE axi_kit_axi3_test)

  add_test(NAME sim_ddr_test COMMAND sim_ddr_test)
  add_test(NAME axi_interconnect_test COMMAND axi_interconnect_test)
  add_test(NAME mmio_router_axi4_test COMMAND mmio_router_axi4_test)
  add_test(NAME sim_ddr_axi3_test COMMAND sim_ddr_axi3_test)
  add_test(NAME axi_interconnect_axi3_test COMMAND axi_interconnect_axi3_test)
  add_test(NAME mmio_router_axi3_test COMMAND mmio_router_axi3_test)
endif()

if(AXI_KIT_BUILD_DEMOS)
  add_executable(axi4_smoke_demo demos/axi4_smoke.cpp)
  target_link_libraries(axi4_smoke_demo PRIVATE axi_kit_axi4)

  add_executable(axi3_smoke_demo demos/axi3_smoke.cpp)
  target_link_libraries(axi3_smoke_demo PRIVATE axi_kit_axi3)
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

  add_library(axi_kit_axi4_sc STATIC
      axi_interconnect/AXI_Interconnect.cpp
      axi_interconnect/AXI_Router_AXI4.cpp
      sim_ddr/SimDDR.cpp
      mmio/MMIO_Bus_AXI4.cpp
      mmio/UART16550_Device.cpp
  )
  target_include_directories(axi_kit_axi4_sc PUBLIC ${AXI_KIT_INCLUDE_DIRS})
  target_compile_features(axi_kit_axi4_sc PUBLIC cxx_std_20)
  target_compile_definitions(axi_kit_axi4_sc PRIVATE
      AXI_KIT_DDR_LATENCY=${AXI_KIT_SINGLE_CYCLE_DDR_LATENCY}
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
      AXI_KIT_DDR_LATENCY=${AXI_KIT_SINGLE_CYCLE_DDR_LATENCY}
      ICACHE_MISS_LATENCY=${AXI_KIT_SINGLE_CYCLE_DDR_LATENCY}
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
      AXI_KIT_DDR_LATENCY=${AXI_KIT_SINGLE_CYCLE_DDR_LATENCY}
      ICACHE_MISS_LATENCY=${AXI_KIT_SINGLE_CYCLE_DDR_LATENCY}
  )
  target_link_libraries(single_cycle_axi4_demo PRIVATE
      axi_kit_single_cycle_core
      axi_kit_axi4_sc
      ${AXI_KIT_SINGLE_CYCLE_DIR}/third_party/softfloat/softfloat.a
      z
      stdc++fs
  )
endif()
