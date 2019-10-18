# MIT License
#
# Copyright (c) 2019 Mateusz
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# add_compile_failure_test
# Function for registering test, which fails when given source file compiles.
# Params:
#   NAME                test name.
#   SOURCE              source file with main function, which compilation should fail.
#   INCLUDE_DIRECTORIES include directories needed for file compilation.
#   LINK_DIRECTORIES    libraries directories needed for file compilation.
#   LINK_LIBRARIES      libraries needed for file compilation.
#   COMPILE_DEFINITIONS compiler flags and definition.
# For meaning of INCLUDE_DIRECTORIES, LINK_DIRECTORIES, LINK_LIBRARIES
# and COMPILE_DEFINITIONS see CMake try_compile
# command (https://cmake.org/cmake/help/v3.10/command/try_compile.html).
function(add_compile_failure_test)
    set(options "")
    set(oneValueArgs NAME SOURCE )
    set(multiValueArgs INCLUDE_DIRECTORIES LINK_DIRECTORIES LINK_LIBRARIES COMPILE_DEFINITIONS CMAKE_EXTRA)
    cmake_parse_arguments(add_compile_failure_test "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    get_filename_component(FILE_NAME ${add_compile_failure_test_SOURCE} NAME)

    file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${add_compile_failure_test_NAME}/build)
    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/${add_compile_failure_test_NAME}/CMakeLists.txt "
        cmake_minimum_required(VERSION 3.8 FATAL_ERROR)

        project(${add_compile_failure_test_NAME} VERSION 0.0.0.1 LANGUAGES CXX)

        try_compile(
            COMPILATION_STATUS \$\{CMAKE_CURRENT_BINARY_DIR\}
            SOURCES \$\{CMAKE_CURRENT_SOURCE_DIR\}/${FILE_NAME}
            COMPILE_DEFINITIONS \"${add_compile_failure_test_COMPILE_DEFINITIONS}\"
            CMAKE_FLAGS \"-DINCLUDE_DIRECTORIES=${add_compile_failure_test_INCLUDE_DIRECTORIES}\" \"-DLINK_DIRECTORIES=${add_compile_failure_test_LINK_DIRECTORIES}\" \"-DLINK_LIBRARIES=${add_compile_failure_test_LINK_LIBRARIES}\" ${add_compile_failure_test_CMAKE_EXTRA}
            OUTPUT_VARIABLE COMPILATION_OUTPUT
        )

        if(\$\{COMPILATION_STATUS\})
            message(FATAL_ERROR \"Compilation of '${add_compile_failure_test_SOURCE}' should fail: \$\{COMPILATION_OUTPUT\}\")
        else()
            message(STATUS \"Compilation of '${add_compile_failure_test_SOURCE}' resulted: \$\{COMPILATION_OUTPUT\}\")
        endif(\$\{COMPILATION_STATUS\})
    ")

    # To copy test file, when building projects
    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${add_compile_failure_test_NAME}/${FILE_NAME}
        DEPENDS ${add_compile_failure_test_SOURCE}
        COMMAND ${CMAKE_COMMAND} -E copy_if_different ${add_compile_failure_test_SOURCE} ${CMAKE_CURRENT_BINARY_DIR}/${add_compile_failure_test_NAME}/${FILE_NAME}
    )
    add_custom_target(
        ${add_compile_failure_test_NAME} ALL
        DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${add_compile_failure_test_NAME}/${FILE_NAME}
    )

    add_test(
        NAME ${add_compile_failure_test_NAME}
        COMMAND ${CMAKE_COMMAND} ..
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${add_compile_failure_test_NAME}/build
    )
endfunction(add_compile_failure_test)
