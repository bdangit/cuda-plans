pkg_name=cuda
pkg_origin=bdangit
pkg_description="GPU-accelerated Libraries for Computing on NVIDIA devices"
pkg_version=10.1.105
_driverver=418.39
pkg_maintainer="The Habitat Maintainers <humans@habitat.sh>"
pkg_license=('custom')
pkg_source="https://developer.nvidia.com/compute/${pkg_name}/10.1/Prod/local_installers/${pkg_name}_${pkg_version}_${_driverver}_linux.run"
pkg_filename="${pkg_name}_${pkg_version}_${_driverver}_linux.run"
pkg_shasum=33ac60685a3e29538db5094259ea85c15906cbd0f74368733f4111eab6187c8f
pkg_upstream_url="https://developer.nvidia.com/cuda-zone"

## NOTE: Much of this plan copies what Archlinux did to repackage cuda.
##       ref: https://git.archlinux.org/svntogit/community.git/tree/trunk/PKGBUILD?h=packages/cuda

pkg_deps=(
  bdangit/gcc8-libs
  core/glibc
  core/ncurses
  bdangit/gcc8
  core/jre8
  core/coreutils
  core/busybox-static
)
pkg_build_deps=(
  core/libxml2
  core/patchelf
)

pkg_bin_dirs=(bin)
pkg_lib_dirs=(
  lib64
  lib64/stubs
  targets/x86_64-linux/lib
  targets/x86_64-linux/lib/stubs
  nvvm/lib64
)
pkg_include_dirs=(
  include
  targets/x86_64-linux/include
)
pkg_pconfig_dirs=(lib64/pkgconfig)

do_unpack() {
  sh "${pkg_filename}" --target "${pkg_dirname}" --noexec
}

do_prepare() {
  CUDA_RPATH="${LD_RUN_PATH}:$(pkg_path_for libxml2)/lib"
  patchelf --interpreter "$(pkg_path_for glibc)/lib/ld-linux-x86-64.so.2" \
    --set-rpath "${CUDA_RPATH}" cuda-installer

  mkdir -p /var/log/nvidia
  mkdir -p /usr/local
  mkdir -p /usr/lib64/pkgconfig
}

do_build() {
  return 0
}

do_install() {
  ./cuda-installer --silent \
    --toolkit --toolkitpath="${pkg_prefix}/" \
    --defaultroot="${pkg_prefix}" \
    --no-man-page

  mv /usr/lib64/pkgconfig/*.pc "${pkg_prefix}/lib64/pkgconfig"

  # Needs gcc8
  ln -s "$(pkg_path_for bdangit/gcc8)/bin/gcc" "${pkg_prefix}/bin/gcc"
  ln -s "$(pkg_path_for bdangit/gcc8)/bin/g++" "${pkg_prefix}/bin/g++"

  # Install profile and ld.so.config files
  mkdir -p "${pkg_prefix}/etc/profile.d"
  cat <<EOF > "${pkg_prefix}/etc/profile.d/cuda.sh"
export PATH=\$PATH:${pkg_prefix}/bin
EOF
  chmod 0755 "${pkg_prefix}/etc/profile.d/cuda.sh"

  mkdir -p "${pkg_prefix}/etc/ld.so.conf.d"
  cat <<EOF > "${pkg_prefix}/etc/ld.so.conf.d/cuda.conf"
${pkg_prefix}/lib64
${pkg_prefix}/nvvm/lib64
EOF
  chmod 0644 "${pkg_prefix}/etc/ld.so.conf.d/cuda.conf"

  # Remove docs and manpages
  rm -fr "${pkg_prefix}/doc"

  # Remove included copy of java and link to system java
  rm -fr "${pkg_prefix}/jre"
  sed "s|../jre/bin/java|$(pkg_path_for jre8)/bin/java|g" \
    -i "${pkg_prefix}/libnsight/nsight.ini" \
    -i "${pkg_prefix}/libnvvp/nvvp.ini"

  # Fix interpreters
  fix_interpreter "${pkg_prefix}/bin/computeprof" core/busybox-static bin/sh
  fix_interpreter "${pkg_prefix}/bin/nvvp" core/busybox-static bin/sh
  fix_interpreter "${pkg_prefix}/bin/nsight" core/busybox-static bin/sh
  fix_interpreter "${pkg_prefix}/bin/nsight_ee_plugins_manage.sh" core/busybox-static bin/sh

  # Let the patching begin
  # We create a RUN_PATH that does not include all the runtime deps.
  CUDA_RUN_PATH="${pkg_prefix}/lib64:${pkg_prefix}/nvvm/lib64:$(pkg_path_for gcc-libs)/lib:$(pkg_path_for glibc)/lib"

  # Patch Bins
  _cuda_bins=(
    nvvm/bin/cicc
    libnvvp/nvvp
    libnsight/nsight
    extras/demo_suite/bandwidthTest
    extras/demo_suite/busGrind
    extras/demo_suite/deviceQuery
    extras/demo_suite/nbody
    extras/demo_suite/oceanFFT
    extras/demo_suite/randomFog
    extras/demo_suite/vectorAdd
    bin/bin2c
    bin/cudafe++
    bin/cuobjdump
    bin/fatbinary
    bin/nvcc
    bin/nvdisasm
    bin/nvlink
    bin/nvprof
    bin/nvprune
    bin/ptxas
    bin/cuda-gdbserver
    bin/cuda-memcheck
    bin/gpu-library-advisor
  )
  for bin in "${_cuda_bins[@]}"; do
    build_line "patch ${pkg_prefix}/${bin}"
    patchelf --interpreter "$(pkg_path_for glibc)/lib/ld-linux-x86-64.so.2" \
      --set-rpath "${CUDA_RUN_PATH}" "${pkg_prefix}/${bin}"
  done

  # Patch Cuda-gdb
  # note: libncurses 6.1 is "designed to be source-compatible with 5.0 through 6.0"
  build_line "patch ${pkg_prefix}/bin/cuda-gdb"
  patchelf --interpreter "$(pkg_path_for glibc)/lib/ld-linux-x86-64.so.2" "${pkg_prefix}/bin/cuda-gdb"
  patchelf --replace-needed libncurses.so.5 libncurses.so.6 "${pkg_prefix}/bin/cuda-gdb"
  patchelf --set-rpath "${CUDA_RUN_PATH}:$(pkg_path_for ncurses)/lib" "${pkg_prefix}/bin/cuda-gdb"

  # Patch libraries
  _cublas_libs=(
    libcublas
    libcublasLt
    libnvblas
    stubs/libcublas
    stubs/libcublasLt
  )
  for lib in "${_cublas_libs[@]}"; do
    file="${pkg_prefix}/lib64/${lib}.so"
    build_line "patch ${file}"
    patchelf --set-rpath "${CUDA_RUN_PATH}" "${file}"
  done

  _cuda_libs=(
    libOpenCL
    libaccinj64
    libcudart
    libcufft
    libcufftw
    libcuinj64
    libcurand
    libcusolver
    libcusparse
    libnppc
    libnppial
    libnppicc
    libnppicom
    libnppidei
    libnppif
    libnppig
    libnppim
    libnppist
    libnppisu
    libnppitc
    libnpps
    libnvToolsExt
    libnvgraph
    libnvjpeg
    libnvrtc-builtins
    libnvrtc
  )
  for lib in "${_cuda_libs[@]}"; do
    file="${pkg_prefix}/targets/x86_64-linux/lib/${lib}.so"
    build_line "patch ${file}"
    patchelf --set-rpath "${CUDA_RUN_PATH}" "${file}"
  done

  _cuda_stubs_libs=(
    libcuda
    libcufft
    libcufftw
    libcurand
    libcusolver
    libcusparse
    libnppc
    libnppial
    libnppicc
    libnppicom
    libnppidei    
    libnppif
    libnppig
    libnppim
    libnppist
    libnppisu
    libnppitc
    libnpps
    libnvgraph
    libnvidia-ml
    libnvjpeg
    libnvrtc
  )
  for lib in "${_cuda_stubs_libs[@]}"; do
    file="${pkg_prefix}/targets/x86_64-linux/lib/stubs/${lib}.so"
    build_line "patch ${file}"
    patchelf --set-rpath "${CUDA_RUN_PATH}" "${file}"
  done

  build_line "patch ${pkg_prefix}/nvvm/lib64/libnvvm.so"
  patchelf --set-rpath "${CUDA_RUN_PATH}" "${pkg_prefix}/nvvm/lib64/libnvvm.so"

  build_line "patch ${pkg_prefix}/extras/CUPTI/lib64/libcupti.so"
  patchelf --set-rpath "${CUDA_RUN_PATH}" "${pkg_prefix}/extras/CUPTI/lib64/libcupti.so"
}

do_strip() {
  return 0
}

do_check() {
  return 0
}
