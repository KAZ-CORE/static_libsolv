#!/bin/bash
source conf.sh

case "$arch_build_target" in
    aarch64|aarch64_be|alpha|amdgcn|arc|arceb|arm|armeb|avr|\
    bpfeb|bpfel|csky|ez80|hexagon|hppa|hppa64|kalimba|kvx|lanai|\
    loongarch32|loongarch64|m68k|m88k|microblaze|microblazeel|\
    mips|mipsel|mips64|mips64el|msp430|nvptx|nvptx64|or1k|\
    powerpc|powerpcle|powerpc64|powerpc64le|propeller|riscv32|\
    riscv32be|riscv64|riscv64be|s390x|sh|sheb|sparc|sparc64|\
    spork8|spirv32|spirv64|ve|wasm32|wasm64|\
    x86_16|x86|x86_64|xcore|xtensa|xtensaeb|native)
        ;;
    *)
        echo "Invalid architecture: $arch_build_target"
        exit 1
        ;;
esac

os_build_target="${os_build_target}" \
arch_build_target="${arch_build_target}" \
libc_build_target="${libc_build_target}" \
./get_needs.sh && ./setup_zig.sh || exit 1

rm -rf "${traget_output}"

mkdir -p "${traget_output}" || exit 1
mkdir -p "${headers_output}/solv" || exit 1


if [[ ! -d "${path_libsolv}" ]]; then
    git clone "${addr_repository}" || exit 1
fi


cp "${path_libsolv}"/src/*.h "${headers_output}/solv/" || exit 1
cp "${path_libsolv}"/ext/repo_deb.h "${headers_output}/solv/" || exit 1


path_zlib="$(find .need_build -maxdepth 1 -type d \
    -name "zlib_${arch_build_target}_*" -print -quit)"

path_liblzma="$(find .need_build -maxdepth 1 -type d \
    -name "liblzma_${arch_build_target}_*" -print -quit)"


if [[ -z "${path_zlib}" || ! -f "${path_zlib}/libz_${arch_build_target}.a" ]]; then
    echo "Missing zlib for architecture: ${arch_build_target}"
    exit 1
fi

if [[ -z "${path_liblzma}" || ! -f "${path_liblzma}/liblzma_${arch_build_target}.a" ]]; then
    echo "Missing liblzma for architecture: ${arch_build_target}"
    exit 1
fi


cmake \
  -S "${path_libsolv}" \
  -B "${traget_output}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="${zigfile};cc;-target;${build_target}" \
  -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
  -DENABLE_STATIC=ON \
  -DDISABLE_SHARED=ON \
  -DENABLE_DEBIAN=ON \
  -DENABLE_LZMA_COMPRESSION=ON \
  -DENABLE_ZLIB_COMPRESSION=ON \
  -DZLIB_LIBRARY="${path_zlib}/libz_${arch_build_target}.a" \
  -DZLIB_INCLUDE_DIR="${path_zlib}/headers" \
  -DLZMA_LIBRARY="${path_liblzma}/liblzma_${arch_build_target}.a" \
  -DLZMA_INCLUDE_DIR="${path_liblzma}/headers" \
  -DCMAKE_POSITION_INDEPENDENT_CODE=OFF \
  -DCMAKE_C_FLAGS="-U HAVE_FUNOPEN" \
  || exit 1


cp "${traget_output}/src/solvversion.h" "${headers_output}/solv/" || exit 1


cmake \
  --build "${traget_output}" \
  --target libsolv libsolvext \
  -j"$(nproc)" \
  || exit 1
