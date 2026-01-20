#!/bin/bash
echo "entered script"
set -e -u -x
# Build gtsam
if [ -z ${BUILD_TYPE-} ]; then
    BUILD_TYPE=RelWithDebInfo
    # Compiler flags used for both cmake and direct g++ compilation
    EXTRA_CXX_FLAGS="-std=c++17 -O3 -Wall -mtune=haswell -march=haswell -ffunction-sections -pipe -Wno-suggest-override -Wno-nonnull"
    EXTRA_FLAGS="-DCMAKE_CXX_FLAGS='${EXTRA_CXX_FLAGS}'"
fi

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GTSAM_SOURCE_DIR="$SCRIPT_DIR"
BUILD_PATH="$SCRIPT_DIR/build_${BUILD_TYPE}"

# Create build directory if it doesn't exist
mkdir -p $BUILD_PATH

cd $BUILD_PATH

# Use CONDA_PREFIX if available, otherwise use a default
if [ -z ${CONDA_PREFIX-} ]; then
    echo "ERROR: CONDA_PREFIX is not set. Using /usr/local as fallback."
	exit 1
fi

export LD_LIBRARY_PATH="$CONDA_PREFIX/lib/"
export LIBRARY_PATH="$CONDA_PREFIX/lib/"
export CXXFLAGS="${CXXFLAGS-} -Wno-error -Wno-error=suggest-override"
LDFLAGS="${LDFLAGS:-} -Wl,-rpath,$CONDA_PREFIX/lib -L$CONDA_PREFIX/lib"
#export CXXFLAGS=`echo $CXXFLAGS| sed 's/march=nocona/march=skylake/'| sed 's/-mtune=haswell//'`
#export CFLAGS=`echo $CFLAGS| sed 's/march=nocona/march=skylake/'| sed 's/-mtune=haswell//'`

NUM_JOBS=${NUM_JOBS-6}

cmake $GTSAM_SOURCE_DIR \
	-DCMAKE_BUILD_TYPE=$BUILD_TYPE -DCMAKE_INSTALL_PREFIX=./installx -DGTSAM_BUILD_UNSTABLE=OFF \
	-DGTSAM_WITH_TBB=ON -DGTSAM_BUILD_TESTS=OFF -DGTSAM_BUILD_EXAMPLES_ALWAYS=OFF \
	-DGTSAM_USE_QUATERNIONS=OFF \
	-DGTSAM_BUILD_WITH_MARCH_NATIVE=OFF \
	-DGTSAM_BUILD_DOCS=OFF \
	-DGTSAM_FORCE_STATIC_LIB=ON \
	-DGTSAM_FORCE_SHARED_LIB=OFF \
	-DBUILD_STATIC_METIS=ON \
	-DBOOST_ROOT=$CONDA_PREFIX \
	-DTBB_ROOT=$CONDA_PREFIX \
	-DBoost_NO_SYSTEM_PATHS=ON \
	-DBoost_DIR=$CONDA_PREFIX/lib/cmake/Boost \
	-DCMAKE_PREFIX_PATH=$CONDA_PREFIX \
	-DGTSAM_TBB_BOUNDED_MEMORY_GROWTH=ON \
	-DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS:-}" \
	-DCMAKE_SHARED_LINKER_FLAGS="${LDFLAGS:-}" \
	-DCMAKE_MODULE_LINKER_FLAGS="${LDFLAGS:-}" \
	-DGTSAM_BUILD_TIMING_ALWAYS:BOOL=OFF -DGTSAM_ENABLE_TIMING=OFF \
	-DGTSAM_UNSTABLE_BUILD_PYTHON=ON\
	"${EXTRA_FLAGS-}"


make -j $NUM_JOBS

# Build simple_gtsam_deserialize.cpp
echo "Building simple_gtsam_deserialize..."
CXX=${CXX:-g++}
CPP_SOURCE="$SCRIPT_DIR/test_case/simple_gtsam_deserialize.cpp"
UNSTABLE_CPP="$SCRIPT_DIR/gtsam_unstable/slam/ProjectionFactorRollingShutter.cpp"
CPP_OUTPUT="$BUILD_PATH/simple_gtsam_deserialize"

$CXX ${EXTRA_CXX_FLAGS:-} ${CXXFLAGS} \
	-I"$GTSAM_SOURCE_DIR" \
	-I"$GTSAM_SOURCE_DIR/gtsam/3rdparty" \
	-I"$GTSAM_SOURCE_DIR/gtsam/3rdparty/Eigen" \
	-I"$BUILD_PATH" \
	-I"$BUILD_PATH/gtsam" \
	-I"$BUILD_PATH/gtsam_unstable" \
	-I"$CONDA_PREFIX/include" \
	"$CPP_SOURCE" \
	"$UNSTABLE_CPP" \
	-o "$CPP_OUTPUT" \
	-L"$CONDA_PREFIX/lib" \
	-Wl,-Bstatic \
	"$BUILD_PATH/gtsam/libgtsam${BUILD_TYPE}.a" \
	"$BUILD_PATH/gtsam/3rdparty/metis/libmetis/libmetis-gtsam${BUILD_TYPE}.a" \
	"$BUILD_PATH/gtsam/3rdparty/cephes/libcephes-gtsam${BUILD_TYPE}.a" \
	-lboost_serialization -lboost_timer -lboost_chrono -lboost_system \
	-Wl,-Bdynamic \
	-Wl,-rpath,"$CONDA_PREFIX/lib" \
	-pthread \
	-ltbbmalloc -ltbb

echo "Built: $CPP_OUTPUT"

