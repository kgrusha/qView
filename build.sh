#!/bin/bash

# Default values
CMAKE_ARGS=""

CLEAN=false

# Find a valid macOS SDK and set it for CMake to fix a potential mismatch
if [[ "$(uname)" == "Darwin" ]]; then
    SDK_PATH=$(xcrun --sdk macosx --show-sdk-path 2>/dev/null)
    if [ -n "$SDK_PATH" ]; then
        CMAKE_ARGS="-DCMAKE_OSX_SYSROOT=$SDK_PATH"
    fi
fi

# Parse command-line arguments
for arg in "$@"
do
    case $arg in
        --format)
        clang-format -i **/*.cpp **/*.h **/*.mm
        exit 0
        ;;
        --format-check)
        clang-format -i **/*.cpp **/*.h **/*.mm --dry-run -Werror
        exit 0
        ;;
        --tidy)
        CMAKE_ARGS="$CMAKE_ARGS -DCMAKE_CXX_CLANG_TIDY=clang-tidy"
        shift # Remove --tidy from processing
        ;;
        --tidy-fix)
        CMAKE_ARGS="$CMAKE_ARGS -DCMAKE_CXX_CLANG_TIDY='clang-tidy;-fix-errors'"
        shift # Remove --tidy-fix from processing
        ;;
        --clean)
        CLEAN=true
        shift
        ;;
        *)
        CMAKE_ARGS="$CMAKE_ARGS $arg"
        ;;
    esac
done

# Clean build directory for a fresh configuration
if $CLEAN && [ -d "build" ]; then
    echo "Removing existing build directory."
    rm -rf build
fi

# Homebrew Qt: CMake does not search Cellar paths by default.
if [[ -z "${CMAKE_PREFIX_PATH:-}" ]] && command -v brew >/dev/null 2>&1; then
    for _brew_qt_formula in qt qt@6; do
        _brew_qt="$(brew --prefix "$_brew_qt_formula" 2>/dev/null)"
        if [[ -n "$_brew_qt" ]] && {
            [[ -f "$_brew_qt/lib/cmake/Qt6/Qt6Config.cmake" ]] ||
                [[ -f "$_brew_qt/lib/cmake/Qt5/Qt5Config.cmake" ]]
        }; then
            export CMAKE_PREFIX_PATH="$_brew_qt"
            echo "CMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH (Homebrew $_brew_qt_formula)"
            break
        fi
    done
    unset _brew_qt _brew_qt_formula
fi

# Prefer Ninja when installed (faster incremental builds); CMake default otherwise.
CMAKE_GEN=()
if command -v ninja >/dev/null 2>&1; then
    CMAKE_GEN=(-G Ninja)
fi

echo "Configuring with: cmake -B build${CMAKE_GEN:+ ${CMAKE_GEN[*]}} $CMAKE_ARGS"

# Run CMake configuration.
cmake -B build "${CMAKE_GEN[@]}" $CMAKE_ARGS || exit 1

# Run the build
echo "Building project..."
cmake --build build --parallel || exit 1
