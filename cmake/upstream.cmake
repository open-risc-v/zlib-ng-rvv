# 上游接入：zlib-ng（CMake 原生）→ <build>/pkg/prefix，探针链接该前缀里的 libz。
# -DZLIB_COMPAT=ON 让探针用标准 <zlib.h>。
# 交叉编译时由 scripts/cross-baseline.sh 预先建好前缀并传 -DPKG_PREFIX，此文件就不再加 pkg 目标。

set(PKG_ROOT "${CMAKE_BINARY_DIR}/pkg")
if(NOT DEFINED PKG_PREFIX)
  set(PKG_PREFIX "${PKG_ROOT}/prefix")
  add_custom_target(pkg ALL
    COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/cmake/pkg-build.sh" "${SRC_DIR}" "${PKG_ROOT}"
    COMMENT "构建上游 zlib-ng（${SRC_DIR}）"
    VERBATIM)
  set(HAVE_PKG_TARGET TRUE)
endif()

add_executable(zlib_harness test/pkg_zlib.c)
if(HAVE_PKG_TARGET)
  add_dependencies(zlib_harness pkg)
endif()
target_include_directories(zlib_harness PRIVATE "${PKG_PREFIX}/include")
target_link_directories(zlib_harness PRIVATE "${PKG_PREFIX}/lib")
target_link_libraries(zlib_harness PRIVATE z m)
target_compile_options(zlib_harness PRIVATE ${RVV_FLAGS})

add_test(NAME zlib_harness COMMAND zlib_harness)
