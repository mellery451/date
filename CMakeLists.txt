#[===================================================================[
   date library by Howard Hinnant

   CMake projects that wish to use this library should consider
   something like the following :

     include( FetchContent )
     FetchContent_Declare( date_src
       GIT_REPOSITORY https://github.com/HowardHinnant/date.git
       GIT_TAG        2.4.2  # adjust tag/branch/commit as needed
     )
     FetchContent_MakeAvailable(date_src)
     ...
     target_link_libraries (my_target PRIVATE date::date)

#]===================================================================]

cmake_minimum_required( VERSION 3.1.0 )

cmake_policy( VERSION 3.14 )

project( date VERSION 2.4.1 )

include( GNUInstallDirs )

get_directory_property( has_parent PARENT_DIRECTORY )

# Override by setting on CMake command line.
set( CMAKE_CXX_STANDARD 17 CACHE STRING "The C++ standard whose features are requested." )

option( USE_SYSTEM_TZ_DB "Use the operating system's timezone database" OFF )
option( USE_TZ_DB_IN_DOT "Save the timezone database in the current folder" OFF )
option( BUILD_SHARED_LIBS  "Build a shared version of library" OFF )
option( ENABLE_DATE_TESTING "Enable unit tests" OFF )
option( DISABLE_STRING_VIEW "Disable string view" OFF )
option( COMPILE_WITH_C_LOCALE "define ONLY_C_LOCALE=1" OFF )
option( BUILD_TZ_LIB "build/install of TZ library" OFF )

if( ENABLE_DATE_TESTING AND NOT BUILD_TZ_LIB )
    message(WARNING "Testing requested, bug BUILD_TZ_LIB not ON - forcing the latter")
    set (BUILD_TZ_LIB ON CACHE BOOL "required for testing" FORCE)
endif( )

function( print_option OPT )
    if ( NOT DEFINED PRINT_OPTION_CURR_${OPT} OR ( NOT PRINT_OPTION_CURR_${OPT} STREQUAL ${OPT} ) )
        set( PRINT_OPTION_CURR_${OPT} ${${OPT}} CACHE BOOL "" )
        mark_as_advanced(PRINT_OPTION_CURR_${OPT})
        message( "# date: ${OPT} ${${OPT}}" )
    endif( )
endfunction( )

print_option( USE_SYSTEM_TZ_DB )
print_option( USE_TZ_DB_IN_DOT )
print_option( BUILD_SHARED_LIBS  )
print_option( ENABLE_DATE_TESTING )
print_option( DISABLE_STRING_VIEW )

#[===================================================================[
   date (header only) library
#]===================================================================]
add_library( date INTERFACE )
add_library( date::date ALIAS date )
target_include_directories( date INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include> )
# adding header sources just helps IDEs
target_sources( date INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_LIST_DIR}/include>$<INSTALL_INTERFACE:include>/date/date.h
    # the rest of these are not currently part of the public interface of the library:
    $<BUILD_INTERFACE:${CMAKE_CURRENT_LIST_DIR}/include/date/islamic.h>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_LIST_DIR}/include/date/iso_week.h>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_LIST_DIR}/include/date/julian.h>
)
# public headers will get installed:
set_target_properties( date PROPERTIES PUBLIC_HEADER include/date/date.h )
target_compile_definitions( date INTERFACE
    #To workaround libstdc++ issue https://github.com/HowardHinnant/date/issues/388
    ONLY_C_LOCALE=$<IF:$<BOOL:${COMPILE_WITH_C_LOCALE}>,1,0>
    $<$<BOOL:${DISABLE_STRING_VIEW}>:HAS_STRING_VIEW=0> )

#[===================================================================[
   tz (compiled) library
#]===================================================================]
if( BUILD_TZ_LIB )
    add_library( tz )
    target_sources( tz
      PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_LIST_DIR}/include>$<INSTALL_INTERFACE:include>/date/tz.h
        $<$<BOOL:${IOS}>:$<BUILD_INTERFACE:${CMAKE_CURRENT_LIST_DIR}/include>$<INSTALL_INTERFACE:include>/date/ios.h>
      PRIVATE
        include/date/tz_private.h
        $<$<BOOL:${IOS}>:src/ios.mm>
        src/tz.cpp )
    add_library( date::tz ALIAS tz )
    target_link_libraries( tz PUBLIC date )
    target_include_directories( tz PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include> )
    target_compile_definitions( tz
        PRIVATE
            USE_AUTOLOAD=$<IF:$<BOOL:${USE_SYSTEM_TZ_DB}>,0,1>
            HAS_REMOTE_API=$<IF:$<BOOL:${USE_SYSTEM_TZ_DB}>,0,1>
            $<$<AND:$<BOOL:${WIN32}>,$<BOOL:${BUILD_SHARED_LIBS}>>:DATE_BUILD_DLL=1>
            $<$<BOOL:${USE_TZ_DB_IN_DOT}>:INSTALL=.>
        PUBLIC
            USE_OS_TZDB=$<IF:$<AND:$<BOOL:${USE_SYSTEM_TZ_DB}>,$<NOT:$<BOOL:${WIN32}>>>,1,0>
        INTERFACE
            $<$<AND:$<BOOL:${WIN32}>,$<BOOL:${BUILD_SHARED_LIBS}>>:DATE_USE_DLL=1> )
    set(TZ_HEADERS include/date/tz.h)
    if( IOS )
        list(APPEND TZ_HEADERS include/date/ios.h)
    endif( )
    set_target_properties( tz PROPERTIES
        POSITION_INDEPENDENT_CODE ON
        PUBLIC_HEADER "${TZ_HEADERS}"
        VERSION "${PROJECT_VERSION}"
        SOVERSION "${PROJECT_VERSION}" )
    if( NOT MSVC )
        find_package( Threads )
        target_link_libraries( tz PUBLIC Threads::Threads )
    endif( )
    if( NOT USE_SYSTEM_TZ_DB )
        find_package( CURL REQUIRED )
        target_link_libraries( tz PRIVATE CURL::libcurl )
    endif( )
endif( )

#[===================================================================[
   installation
#]===================================================================]
set( version_config "${CMAKE_CURRENT_BINARY_DIR}/dateConfigVersion.cmake" )

include( CMakePackageConfigHelpers )
write_basic_package_version_file( "${version_config}"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion )

install( TARGETS date
    EXPORT dateConfig
    PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/date )
export( TARGETS date NAMESPACE date:: FILE dateConfig.cmake )

if( BUILD_TZ_LIB )
    install( TARGETS tz
        EXPORT dateConfig
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/date
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} )  # This is for Windows
    export( TARGETS tz NAMESPACE date:: APPEND FILE dateConfig.cmake )
endif( )

if( WIN32 AND NOT CYGWIN)
    set( CONFIG_LOC CMake )
else( )
    set( CONFIG_LOC "${CMAKE_INSTALL_LIBDIR}/cmake/date" )
endif( )
install( EXPORT dateConfig
  NAMESPACE date::
  DESTINATION ${CONFIG_LOC} )

#[===================================================================[
   testing
#]===================================================================]
if( ENABLE_DATE_TESTING )
    set (CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/test ${CMAKE_MODULE_PATH})
    include(compile_fail)

    enable_testing( )

    add_custom_target( testit
        COMMAND ${CMAKE_CTEST_COMMAND} -C $<CONFIG>
        --build-generator ${CMAKE_GENERATOR}
        $<$<BOOL:${CMAKE_VERBOSE_MAKEFILE}>:-V>)
    add_dependencies( testit tz )
    get_property( IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG )
    if( IS_MULTICONFIG STREQUAL "NOTFOUND" )
        if( ${CMAKE_GENERATOR} STREQUAL "Xcode" OR ${CMAKE_GENERATOR} MATCHES "^Visual Studio" )
            set (IS_MULTICONFIG TRUE)
        endif ()
    endif ()
    get_target_property( TZ_LIBDIR tz BINARY_DIR )
    if( IS_MULTICONFIG )
        add_custom_target( copytz
            COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:tz> ${TZ_LIBDIR})
        add_dependencies( testit copytz )
    endif( )

    file( GLOB_RECURSE ALL_TEST_SOURCES
        LIST_DIRECTORIES false
        RELATIVE "${PROJECT_SOURCE_DIR}/test"
        "${PROJECT_SOURCE_DIR}/test/*.cpp" )
    foreach( TEST_SRC ${ALL_TEST_SOURCES} )
        get_filename_component( TEST_NAME ${TEST_SRC} NAME_WE )
        get_filename_component( TEST_EXT ${TEST_SRC} EXT )
        get_filename_component( TEST_PREFIX ${TEST_SRC} DIRECTORY )
        string( REPLACE "/" "_"  TEST_PREFIX "${TEST_PREFIX}" )
        string( REPLACE "\\" "_"  TEST_PREFIX "${TEST_PREFIX}" )
        set( TEST_SRC_FULL "${PROJECT_SOURCE_DIR}/test/${TEST_SRC}" )

        if( ${TEST_EXT} STREQUAL ".fail.cpp" )
            set( TEST_NAME "${TEST_PREFIX}_fail_${TEST_NAME}" )
            add_compile_failure_test( NAME ${TEST_NAME}_test
                SOURCE ${TEST_SRC_FULL}
                INCLUDE_DIRECTORIES "${PROJECT_SOURCE_DIR}/include/date" "${PROJECT_SOURCE_DIR}/include"
                LINK_DIRECTORIES "${TZ_LIBDIR}"
                LINK_LIBRARIES tz
                CMAKE_EXTRA "-DCMAKE_CXX_STANDARD=14"
            )
            add_dependencies( testit ${TEST_NAME}_test )
        else( )
            set( TEST_NAME "${TEST_PREFIX}_pass_${TEST_NAME}" )
            add_executable( ${TEST_NAME}_bin EXCLUDE_FROM_ALL ${TEST_SRC_FULL} )
            add_test( ${TEST_NAME}_test ${TEST_NAME}_bin )
            target_link_libraries( ${TEST_NAME}_bin tz )
            # HACK: because the test sources don't all use
            # fully-qualified includes:
            target_include_directories( ${TEST_NAME}_bin PRIVATE include/date )
            add_dependencies( testit ${TEST_NAME}_bin )
        endif( )
    endforeach( )
endif( )
