# cuda

[GPU-accelerated Libraries](https://developer.nvidia.com/cuda-zone) for Computing on NVIDIA devices.

## Maintainers

* Ben Dang: <me@bdang.it>

## Type of Package

Binary package

## Usage

To compile cuda code (ie. `*.cu`), just add `bdangit/cuda` to your `plan.sh`.  You will then have
access to compiler tools like `nvcc`, `cuda-gdb` and more.  Furthermore, `LD_RUN_PATH`, `CFLAGS`,
`CXXFLAGS`, `CPPFLAGS`, and `LDFLAGS` will be updated with any of the cuda shared/static libraries.

If you require shared libraries during runtime, it is recommended that you add `bdangit/cuda-libs` to
`pkg_deps` and add `bdangit/cuda` to `pkg_build_deps`.

### Example

#### `plan.sh`

```shell
pkg_name=myawesomecudaapp
pkg_origin=myorigin

pkg_deps=(
  bdangit/cuda-libs
  bdangit/gcc8-libs
)
pkg_build_deps=(
  bdangit/cuda
  core/make
)

do_build() {
  nvcc -o myawesomecudaapp source.cu
}
```

#### Runtime

In order for your binary to execute, you must make sure you set `LD_LIBRARY_PATH` to include the
path to `libcuda.so`.  This library comes installed when you install NVIDIA Drivers for your card.

> Note1: The usual path where these are installed are under `/usr/lib64`:

> Note2: There may be other libraries that may be linked during runtime when `LD_LIBRARY_PATH` is
         set to to `/usr/lib{,64}`.  If you have dependency isolation issues, you can choose to
         create a new folder `/path/to/my/special/cuda/drivers`, symlink any of the `libcuda.so*`
         into that path and then set `LD_LIBRARY_PATH` to that new folder.

```shell
$ ls /usr/lib64/libcuda*
/usr/lib64/libcuda.so  /usr/lib64/libcuda.so.1  /usr/lib64/libcuda.so.396.37
```

An example of how you will run your binary:

```shell
LD_LIBRARY_PATH=/usr/lib64 hab pkg exec myorigin/myawesomecudaapp myawesomecudaapp
```

Similarly, this is how you can write a `run` hook to execute your binary if it is a service:

```shell
#!/bin/sh

LD_LIBRARY_PATH=/usr/lib64 exec myawesomecudaapp
```
