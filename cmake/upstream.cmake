# 上游构建接入点（G1 填写；不填也能构建工具，便于先跑通 A/B 框架）。
#
# 目标：让 A/B 两侧产出"同名、同路径"的可执行文件，这样 test/run_ab.sh
# 才能用同一个 cases/*.sh 分别跑 A 和 B。
#
# 上游是 CMake 时（最常见）：
#   add_subdirectory(${SRC_DIR}/<子目录> ${CMAKE_BINARY_DIR}/upstream EXCLUDE_FROM_ALL)
#   # 打开上游自己的 SIMD 开关，关掉它会改变 A/B 的可比性：
#   set(<UPSTREAM_SIMD_OPTION> ON CACHE BOOL "" FORCE)
#   # 需要时把上游 target 的编译选项换成 ${RVV_FLAGS}
#
# 上游是 autotools/meson 时（二选一）：
#   a) 由 scripts/build.sh 先调上游构建系统，把产物放到 build/<preset>/pkg/bin/，
#      再让 test/run_ab.sh 用 PKG_BIN 指向它（推荐：不改造上游）；
#   b) 把上游源码列表抄进本文件（像 libspeex-rvv 的 SPEEX_SOURCES 那样），
#      换来可控的编译选项与确定性源集合。
#
# 三条纪律：
#   1. A/B 两侧的编译选项必须只有"RVV 内核宏"不同；
#   2. 不要在 baseline 树上打任何补丁 —— 它是唯一可信参照；
#   3. 源文件列表要显式，不要用 file(GLOB)（上游加文件会悄悄改变基线）。
#
# 示例（取消注释并按上游实际情况改写）：
#
# add_subdirectory("${SRC_DIR}/lib" "${CMAKE_BINARY_DIR}/upstream" EXCLUDE_FROM_ALL)
# if(TARGET <upstream_target>)
#   target_compile_options(<upstream_target> PRIVATE ${RVV_FLAGS})
#   set(PKG_TARGET <upstream_target> CACHE INTERNAL "")
# endif()
