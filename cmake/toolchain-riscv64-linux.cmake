# RISC-V 64 Linux (glibc) 交叉工具链。
#
# 依赖（Ubuntu/Debian）：
#   apt install gcc-riscv64-linux-gnu qemu-user
# 工具链前缀不同时覆盖：
#   cmake ... -DRISCV64_PREFIX=riscv64-unknown-linux-gnu-
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR riscv64)

set(RISCV64_PREFIX "riscv64-unknown-linux-gnu-" CACHE STRING "RISC-V 交叉工具链前缀")
find_program(RISCV64_C_COMPILER NAMES "${RISCV64_PREFIX}gcc" "riscv64-linux-gnu-gcc" REQUIRED)
set(CMAKE_C_COMPILER "${RISCV64_C_COMPILER}")
find_program(RISCV64_CXX_COMPILER NAMES "${RISCV64_PREFIX}g++" "riscv64-linux-gnu-g++")
if(RISCV64_CXX_COMPILER)
  set(CMAKE_CXX_COMPILER "${RISCV64_CXX_COMPILER}")
endif()

# 各发行版 sysroot 路径不同；qemu-user 运行时也要同一个路径。
if(EXISTS /usr/riscv64-unknown-linux-gnu)
  set(CMAKE_FIND_ROOT_PATH /usr/riscv64-unknown-linux-gnu)
elseif(EXISTS /usr/riscv64-linux-gnu)
  set(CMAKE_FIND_ROOT_PATH /usr/riscv64-linux-gnu)
endif()

if(DEFINED CMAKE_FIND_ROOT_PATH)
  set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
  set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
  # 交叉编译时让 add_test() 的目标能在构建机上跑起来（ctest 需要模拟器）。
  find_program(QEMU_RISCV64 qemu-riscv64)
  if(QEMU_RISCV64)
    set(CMAKE_CROSSCOMPILING_EMULATOR ${QEMU_RISCV64} -L ${CMAKE_FIND_ROOT_PATH})
  endif()
endif()
