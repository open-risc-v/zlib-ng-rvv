cmake_minimum_required(VERSION 3.20)
project(zlib-ng-rvv C)
enable_testing()

# ---------------------------------------------------------------------------
# 本骨架只构建"与上游无关"的部分：探测工具 + 内核差分框架。
# 上游的构建在 G1 通过 cmake/upstream.cmake 接入（见 references/adapt-build-system.md）。
# A/B 两侧用同一个 CMakeLists，靠 SRC_DIR 切换 src/ 或 baseline/。
# ---------------------------------------------------------------------------
set(SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src" CACHE PATH
    "要构建的源码树：src/（移植版）或 baseline/（只读参照）")
option(_USE_RVV    "为目标机加 -march=\${RVV_MARCH}" OFF)
option(RVV_KERNELS "启用 rvv/ 下的内核覆盖（需要 _USE_RVV）。OFF = 仅编译器自动向量化" ON)
set(RVV_MARCH "rv64gcv" CACHE STRING "-march 值；X60/X100 常用 rv64gcv_zba_zbb_zbc_zbs_zicond")
set(PKG_CMAKE_ARGS "" CACHE STRING "传给上游构建的额外参数（空格分隔）")

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

set(RVV_FLAGS "")
if(_USE_RVV)
  set(RVV_FLAGS "-march=${RVV_MARCH}")
  add_compile_definitions(_USE_RVV)
endif()
if(RVV_KERNELS)
  add_compile_definitions(RVV_KERNELS)
endif()

# ---- 1. 工具 ----
add_executable(cpu_probe test/cpu_probe.c)
add_executable(diff_kernels test/diff_kernels.c test/rvv_diff.c)
foreach(t cpu_probe diff_kernels)
  target_compile_options(${t} PRIVATE ${RVV_FLAGS})
  target_link_libraries(${t} PRIVATE m)
endforeach()
add_test(NAME diff_kernels COMMAND diff_kernels)

# ---- 2. 上游接入（G1 填写） ----
include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/upstream.cmake" OPTIONAL)
