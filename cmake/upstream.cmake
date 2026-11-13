# 上游接入：zlib-ng（CMake 原生）→ <build>/pkg/prefix，探针链接该前缀里的 libz。
# A/B 各自独立前缀，唯一变量是源码树；-DZLIB_COMPAT=ON 让探针用标准 <zlib.h>。

set(PKG_ROOT "${CMAKE_BINARY_DIR}/pkg")
set(PKG_PREFIX "${PKG_ROOT}/prefix")

add_custom_target(pkg ALL
  COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/cmake/pkg-build.sh" "${SRC_DIR}" "${PKG_ROOT}"
  COMMENT "构建上游 zlib-ng（${SRC_DIR}）"
  VERBATIM)

add_executable(zlib_harness test/pkg_zlib.c)
add_dependencies(zlib_harness pkg)
target_include_directories(zlib_harness PRIVATE "${PKG_PREFIX}/include")
target_link_directories(zlib_harness PRIVATE "${PKG_PREFIX}/lib")
target_link_libraries(zlib_harness PRIVATE z m)
target_compile_options(zlib_harness PRIVATE ${RVV_FLAGS})

add_test(NAME zlib_harness COMMAND zlib_harness)
