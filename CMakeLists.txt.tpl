
# This is an #inglued <> template !
#
# The template is processed by http://mustache.github.io/, more info about
# syntax here : http://mustache.github.io/mustache.5.html 
#
# You can access the following variables : 
# * {{org}} : github organization name
# * {{project}} : current project name
# * {{project_srcs}} : current project srcs folder.
# * {{project_lib_type}} : when no .cpp file to link INTERFACE library otherwise empty
# * {{project_lib_cpps}} : space separated list of .cpp file to link to the library 
#
# * {{#deps}} {{/deps}} : all deps direct and transitive 
#   - {{cmake_package_name}} : The cmake package name from the cmake_package_map otherwise: {{org}}
#   - {{cmake_target_name}} : The cmake target name from cmake_package_map otherwise: {{cmake_package_name}}::{{name}}
#   - {{org}} : the github organization name
#   - {{name}} : the dependency repository name
#   - {{ref}} : tag or branch wished for the dep
#   - {{include_path}} : the path you specified in deps/inglued -I
#   - {{include_path_end_backslash}} : same as above but with a guaranteed end slash.
#

cmake_minimum_required(VERSION 3.17.0)

##### PLATFORM deps #####
set(HUNTER_ROOT "{{HUNTER_ROOT}}")
include(HunterGate)
HunterGate(
    URL "unused" 
    SHA1 "unused" 
)
##### PLATFORM deps #####

project({{org}}_{{project}} VERSION "0.0.1")
enable_testing()

# Compile with shipped-with headers or without 
option(INGLUED "Enable use of #inglued shipped with dependencies." ON)
option(TIPI_LIB_ONLY "Only installs the lib, don't build anything else." OFF)

# Compile unit tests
option(UNIT_TESTS "Enable Unit Testing" OFF)


# Warning as errors to ensure {{project}} quality
string(TOUPPER "${CMAKE_CXX_COMPILER_ID}" COMPILER_IN_USE)
if ("${COMPILER_IN_USE}" STREQUAL "GNU" OR "${COMPILER_IN_USE}" MATCHES "CLANG")
	add_definitions(
    -Wall
		#-Werror
		-Wno-unused-local-typedefs
		-Wno-unused-variable
  )
endif()


set(all_cpp_project " {{project_lib_cpps}}")
string(REGEX MATCH [./-]+ project_root_relative ${all_cpp_project})
get_filename_component(project_root ${project_root_relative} ABSOLUTE)
message (" luc luc luc ${project_root}")

if (WIN32)
include("${project_root}/vcpkg_test/win/glib/scripts/buildsystems/vcpkg.cmake")
set(ENV{PKG_CONFIG_PATH} "${project_root}/vcpkg_test/win/glib/installed/x64-windows/lib/pkgconfig")
elseif(UNIX AND NOT APPLE)
include("${project_root}/vcpkg_test/linux/glib/scripts/buildsystems/vcpkg.cmake")
elseif(UNIX AND APPLE) 
include("${project_root}/vcpkg_test/macos/glib/scripts/buildsystems/vcpkg.cmake")
set(ENV{PKG_CONFIG_PATH} "${project_root}/vcpkg_test/macos/glib/installed/x64-osx/lib/pkgconfig")
endif()


find_package(PkgConfig)
pkg_search_module(GLIB2 REQUIRED glib-2.0 IMPORTED_TARGET)
include_directories(${GLIB2_INCLUDE_DIRS})

if (WIN32)
link_directories("${project_root}/vcpkg_test/win/glib/installed/x64-windows/lib")
elseif(UNIX AND NOT APPLE)
link_directories("${project_root}/vcpkg_test/macos/glib/installed/x64-osx/lib")
elseif(UNIX AND APPLE) 
link_directories("${project_root}/vcpkg_test/macos/glib/installed/x64-osx/lib")
endif()


find_package(Threads)

{{#platform_deps}}
  hunter_add_package({{pkg_name}} COMPONENTS {{#components}}{{component}} {{/components}})
{{/platform_deps}}

{{#platform_deps}}
  find_package({{pkg_name}} {{pkg_find_mode}} REQUIRED {{#components}}{{component}} {{/components}})
{{/platform_deps}}



{{#deps}}
  find_package({{cmake_package_name}} {{pkg_find_mode}} REQUIRED)
{{/deps}}



# Define library
add_library({{project}} {{project_lib_type}} {{project_lib_cpps}})
add_library({{org}}_{{project}}::{{project}} ALIAS {{project}})

target_include_directories({{project}} BEFORE {{project_lib_type_inc}} 
  {{#project_srcs}}$<BUILD_INTERFACE:${CMAKE_CURRENT_LIST_DIR}/{{project_src}}> 
  {{/project_srcs}}
  $<INSTALL_INTERFACE:${include_install_dir}/>)



#{{#deps}}
#target_include_directories({{project}} {{project_lib_type_inc}} 
# deps/{{org}}/{{name}}/{{include_path}})
#{{/deps}}

target_link_libraries({{project}} {{project_lib_type}} 
${GLIB2_LIBRARIES}
  {{#platform_deps}}
    {{#components_link}}{{pkg_name}}::{{component}} {{/components_link}}
  {{/platform_deps}}
  {{#deps}}
    {{cmake_target_name}}
  {{/deps}}
  {{#components_link_target}}{{component}} {{/components_link_target}}
  ${CMAKE_THREAD_LIBS_INIT}
)

set(include_install_dir "include")

if (NOT TIPI_LIB_ONLY)

{{#executables}}
  # {{cmake_target_name}}
  add_executable({{cmake_target_name}} {{cpp_files}})
  set_target_properties({{cmake_target_name}} PROPERTIES OUTPUT_NAME {{output_name}})
  target_link_libraries({{cmake_target_name}} ${GLIB2_LIBRARIES} {{org}}_{{project}}::{{project}})

{{/executables}}

{{#html_executables}}
  # {{cmake_target_name}}
  
  # install shell file in build output
  configure_file({{shell_html_file}} 
    ${CMAKE_CURRENT_BINARY_DIR}/{{html_file_name}} COPYONLY)

  ## compile c++ into wasm (add_library?) with suffix wasm
  add_library({{cmake_target_name}}_impl SHARED {{preprocessed_html_file}} {{cpp_files}})
  target_include_directories({{cmake_target_name}}_impl PRIVATE {{original_src_dir}}) # Fake #include "" location
  set_target_properties({{cmake_target_name}}_impl PROPERTIES 
    SUFFIX ".js"
    LINKER_LANGUAGE CXX
    LANGUAGE CXX )
  target_link_libraries({{cmake_target_name}}_impl {{org}}_{{project}}::{{project}})

{{/html_executables}}


endif()

if (NOT TIPI_LIB_ONLY)
{{#subdirs}}
  add_subdirectory({{subdir}})
{{/subdirs}}
endif()

{{#insource_subdirs}}
  add_subdirectory({{subdir}} {{bindir}})
{{/insource_subdirs}}

# Installing

# Layout. This works for all platforms:
#   * <prefix>/lib/cmake/<PROJECT-NAME>
#   * <prefix>/lib/
#   * <prefix>/include/
set(config_install_dir "lib/cmake/${PROJECT_NAME}")

set(generated_dir "${CMAKE_CURRENT_BINARY_DIR}/generated")

# Configuration
set(version_config "${generated_dir}/${PROJECT_NAME}ConfigVersion.cmake")
set(project_config "${generated_dir}/${PROJECT_NAME}Config.cmake")
set(targets_export_name "${PROJECT_NAME}Targets")
set(namespace "${PROJECT_NAME}::")

# Include module with fuction 'write_basic_package_version_file'
include(CMakePackageConfigHelpers)

# Configure '<PROJECT-NAME>ConfigVersion.cmake'
# Note: PROJECT_VERSION is used as a VERSION
write_basic_package_version_file(
    "${version_config}" COMPATIBILITY SameMajorVersion
)

# Configure '<PROJECT-NAME>Config.cmake'
# Use variables:
#   * targets_export_name
#   * PROJECT_NAME
configure_package_config_file(
    "cmake/modules/Config.cmake.in"
    "${project_config}"
    INSTALL_DESTINATION "${config_install_dir}"
)


# Targets:
install(
    TARGETS {{project}}
    EXPORT "${targets_export_name}"
    LIBRARY DESTINATION "lib"
    ARCHIVE DESTINATION "lib"
    RUNTIME DESTINATION "bin"
    INCLUDES DESTINATION "${include_install_dir}"
)

# Headers:
{{#project_srcs}}
install(
    DIRECTORY {{project_src}}/
    DESTINATION "${include_install_dir}"
    FILES_MATCHING PATTERN "*.[ih]*"
    {{#exclude_dirs}} PATTERN "{{exclude_dir}}/*" EXCLUDE 
    {{/exclude_dirs}}
)
{{/project_srcs}}



# Config
#   * <prefix>/lib/cmake/{{project}}/{{project}}Config.cmake
#   * <prefix>/lib/cmake/{{project}}/{{project}}ConfigVersion.cmake
#   * <prefix>/lib/cmake/{{project}}/{{project}}Targets.cmake
install(
    FILES "${project_config}" "${version_config}"
    DESTINATION "${config_install_dir}"
)
install(
    EXPORT "${targets_export_name}"
    NAMESPACE "${namespace}"
    DESTINATION "${config_install_dir}"
)

