#!/bin/bash
set -eux
shopt -s nullglob

# PACKAGES is a path to a requirements.txt file. Defaults to a temp file with pydantic-core>=2.
PACKAGES=${PACKAGES:-/tmp/default-requirements.txt}

# If using the default, create the file
if [ "$PACKAGES" = "/tmp/default-requirements.txt" ]; then
  echo "pydantic-core>=2" > "$PACKAGES"
fi

files=(/opt/python3-*.tgz)
if [ ${#files[@]} -eq 0 ]; then
  echo "No python3-*.tgz files found in /opt"
  exit 1
fi


for f in "${files[@]}"; do
  ver=$(basename "$f" .tgz | sed 's/^python3-//')
  suffix=$(echo "$ver" | sed -E 's/.*\.(v[0-9a-z]+)$/\1/')
 
  # Check if the linker exists and is executable
  linker="/opt/toolchain/gcc-icr-${suffix}-armv7-linux-gnueabi/bin/armv7-linux-gnueabi-gcc"
  if [ -x "$linker" ]; then
    echo ">>> Linker found: $linker"
  else
    echo "!!! ERROR: Expected linker not found at $linker"
    exit  1
  fi 

  echo "============================================================"
  echo ">>> Starting builds for Python $ver (toolchain suffix=$suffix)"
  echo ">>> Extracting $f into /opt/armv7-python-$ver"
  mkdir -p /opt/armv7-python-$ver
  tar -xzf "$f" -C /opt/armv7-python-$ver --strip-components=1

  echo ">>> Setting cross-compilation environment for suffix=$suffix"
  export CC=$linker
  export CXX=/opt/toolchain/gcc-icr-$suffix-armv7-linux-gnueabi/bin/armv7-linux-gnueabi-g++
  export SYSROOT=/opt/toolchain/gcc-icr-$suffix-armv7-linux-gnueabi/sysroot
  export CPPFLAGS="-I${SYSROOT}/usr/include"
  export LDFLAGS="-L${SYSROOT}/usr/lib"
  export LD_LIBRARY_PATH=/opt/armv7-python-$ver/lib
  export PYO3_CROSS_PYTHON_PATH=/opt/armv7-python-$ver/bin/python3
  export CARGO_BUILD_TARGET=armv7-unknown-linux-gnueabi
  export CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABI_LINKER=$CC

  # Read requirements.txt line by line
  while IFS= read -r spec || [ -n "$spec" ]; do
    # Remove all whitespace (spaces, tabs, newlines, carriage returns) everywhere
    spec=$(echo "$spec" | tr -d '[:space:]')

    # Remove leading and trailing single/double quotes if present
    spec="${spec%\"}"   # strip trailing double quote
    spec="${spec#\"}"   # strip leading double quote
    spec="${spec%\'}"   # strip trailing single quote
    spec="${spec#\'}"   # strip leading single quote

    # Skip empty lines and comments
    [[ -z "$spec" || "$spec" =~ ^# ]] && continue

    echo ">>> Downloading source for '$spec'"
    rm -rf /src/$spec; mkdir -p /src/$spec

    # Use the full specifier with pip
    env -i PATH="$PATH" HOME="$HOME" python3 -m pip download "$spec" --no-binary :all: --no-deps

    # Extract the package name (strip version specifiers)
    # Normalize hyphens to underscores for filename detection (e.g. pydantic-core vs pydantic_core), then extract
    pkg=$(echo "$spec" | sed 's/[<>=!].*//')
    norm_pkg=${pkg//-/_}

    # Search for tarball matching both hyphen and underscore variants
    shopt -s nullglob
    files=( ${pkg}-*.tar.gz ${norm_pkg}-*.tar.gz )
    tarball="${files[0]}"
    if [ ! -f "$tarball" ]; then
      echo "!!! ERROR: No tarball found for $spec (checked [$pkg] and [$norm_pkg])"
      ls -l
      exit 1
    fi 
    mkdir -p /src/$pkg
    echo ">>> Extracting $tarball into /src/$pkg"
    tar -xvf "$tarball" --strip-components=1 -C /src/$pkg

    echo ">>> Building wheel for $spec on Python $ver"
    cd /src/$pkg

    if [ -f Cargo.toml ]; then
      # Use maturin for Rust-based packages
      echo ">>> Detected Cargo.toml, using maturin for build"
      pymajmin=$(echo "$ver" | cut -d. -f1-2)
      maturin build -i python${pymajmin} --release --target armv7-unknown-linux-gnueabi --manylinux off
      mkdir -p /dist/$ver/$pkg
      cp target/wheels/*.whl /dist/$ver/$pkg/
    else
      # Use standard build process for others
      echo ">>> Using standard build process for $pkg"
      uv build
      mkdir -p /dist/$ver/$pkg
      cp dist/*.whl /dist/$ver/$pkg/
    fi
    echo ">>> Finished $pkg for Python $ver"
  done < "$PACKAGES"
  echo "============================================================"
done

echo ">>> Build summary: listing all wheels in /dist"
ls -R /dist
