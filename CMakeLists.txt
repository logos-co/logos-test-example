cmake_minimum_required(VERSION 3.16)
project(LogosTestExample LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)

# Find Qt packages
find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Core)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Core)

# Find logos-liblogos
if(NOT DEFINED LOGOS_LIBLOGOS_ROOT)
    message(FATAL_ERROR "LOGOS_LIBLOGOS_ROOT must be defined")
endif()

message(STATUS "Using logos-liblogos at: ${LOGOS_LIBLOGOS_ROOT}")

# Include directories
include_directories(
    ${LOGOS_LIBLOGOS_ROOT}/include
)

# Link directories
link_directories(
    ${LOGOS_LIBLOGOS_ROOT}/lib
)

# Set output directories
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

# Create the executable
add_executable(logos-test-example
    src/main.cpp
)

# Link libraries
target_link_libraries(logos-test-example PRIVATE
    Qt${QT_VERSION_MAJOR}::Core
    logos_core
)

# Set RPATH settings for the executable
if(APPLE)
    set_target_properties(logos-test-example PROPERTIES
        INSTALL_RPATH "@executable_path/../lib"
        BUILD_WITH_INSTALL_RPATH TRUE
    )
elseif(UNIX)
    set_target_properties(logos-test-example PROPERTIES
        INSTALL_RPATH "$ORIGIN/../lib"
        BUILD_WITH_INSTALL_RPATH TRUE
    )
endif()

# Install rules
install(TARGETS logos-test-example
    RUNTIME DESTINATION bin
)

