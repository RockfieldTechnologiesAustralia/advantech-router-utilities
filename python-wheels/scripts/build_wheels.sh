#!/bin/bash
set -eux
shopt -s nullglob

# PACKAGES is a path to a requirements.txt file. Defaults to a temp file with pydantic-core>=2.
PACKAGES=${PACKAGES:-/tmp/default-requirements.txt}

# If using the default, create the file
if [ "$PACKAGES" = "/tmp/default-requirements.txt" ]; then
  echo "pydantic-core>=2" > "$PACKAGES"
fi

files=(/opt/python3*.tgz)
if [ ${#files[@]} -eq 0 ]; then
  echo "No python3*.tgz files found in /opt"
  exit 1
fi


for f in "${files[@]}"; do
  [[ "$f" == *python3* ]] || { echo "Error: filename must contain 'python3'"; exit 1; }

  ver=$(basename "$f" .tgz | sed 's/.*-//')

  # Suffix contains the router app version, e.g. v3, v4, etc.
  suffix=$(echo "$ver" | sed -E 's/.*\.(v[0-9a-z]+)$/\1/')

  # Find the toolchain directory that matches the suffix
  toolchain_dirs=(/opt/toolchain/gcc-icr-${suffix}-*-linux-gnu*)
  if [ ${#toolchain_dirs[@]} -eq 0 ]; then
    echo "!!! ERROR: No toolchain directory found for suffix=$suffix"
    exit 1
  fi
  toolchain_dir="${toolchain_dirs[0]}"
  echo ">>> Using toolchain directory: $toolchain_dir"

  # Detect architecture from directory name
  arch=$(basename "$toolchain_dir" | sed -E 's/gcc-icr-'${suffix}'-([^-]+)-linux-gnu.*/\1/')
  echo ">>> Detected architecture: $arch"

   # Detect ABI from directory name
  abi=$(basename "$toolchain_dir" | sed -E 's/.*-linux-//')  # gnu, gnueabi, gnueabihf, etc.
  echo ">>> Detected ABI: $abi"
 
  # Check if the linker exists and is executable
  linker="/opt/toolchain/gcc-icr-${suffix}-${arch}-linux-${abi}/bin/${arch}-linux-${abi}-gcc"
  if [ -x "$linker" ]; then
    echo ">>> Linker found: $linker"
  else
    echo "!!! ERROR: Expected linker not found at $linker"
    exit  1
  fi 

  echo "============================================================"
  echo ">>> Starting builds for Python $ver (toolchain suffix=$suffix, arch=$arch, abi=$abi)"
  echo ">>> Extracting $f into /opt/$arch-python-$ver"
  mkdir -p /opt/$arch-python-$ver
  tar -xzf "$f" -C /opt/$arch-python-$ver --strip-components=1

  echo ">>> Setting cross-compilation environment for suffix=$suffix"
  export CC=$linker
  export CXX=/opt/toolchain/gcc-icr-$suffix-$arch-linux-$abi/bin/$arch-linux-$abi-g++
  export SYSROOT=/opt/toolchain/gcc-icr-$suffix-$arch-linux-$abi/sysroot
  export CPPFLAGS="-I${SYSROOT}/usr/include"
  export LDFLAGS="-L${SYSROOT}/usr/lib"
  export LD_LIBRARY_PATH=/opt/$arch-python-$ver/lib
  export PYO3_CROSS_PYTHON_PATH=/opt/$arch-python-$ver/bin/python3
  export CARGO_BUILD_TARGET=$arch-unknown-linux-$abi
  export CARGO_TARGET_${arch^^}_UNKNOWN_LINUX_${abi^^}_LINKER=$CC

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
    rm -rf /src/$suffix/$spec; mkdir -p /src/$suffix/$spec

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
    mkdir -p /src/$suffix/$pkg
    echo ">>> Extracting $tarball into /src/$suffix/$pkg"
    tar -xvf "$tarball" --strip-components=1 -C /src/$suffix/$pkg

    echo ">>> Building wheel for $spec on Python $ver"
    cd /src/$suffix/$pkg

    if [ -f Cargo.toml ]; then
      # Use maturin for Rust-based packages
      echo ">>> Detected Cargo.toml, using maturin for build"
      pymajmin=$(echo "$ver" | cut -d. -f1-2)
      maturin build -i python${pymajmin} --release --target $CARGO_BUILD_TARGET --manylinux off
      mkdir -p /dist/$suffix/$pkg
      cp target/wheels/*.whl /dist/$suffix/$pkg
    else
      # Use standard build process for others
      echo ">>> Using standard build process for $pkg"
      uv build
      mkdir -p /dist/$suffix/$pkg
      cp dist/*.whl /dist/$suffix/$pkg
    fi
    echo ">>> Finished $pkg for Python $ver"
  done < "$PACKAGES"
  echo "============================================================"
done

echo ">>> Build summary: listing all wheels in /dist"
ls -R /dist
