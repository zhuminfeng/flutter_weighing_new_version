cmake_minimum_required(VERSION 3.15)
set(PROJECT_NAME "weighing_system_elinux")
project(${PROJECT_NAME} LANGUAGES C CXX)

set(PLUGIN_NAME "weighing_system_elinux_plugin")
set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# 1. 查找依赖库
find_package(PkgConfig REQUIRED)

# 查找 SQLite3 (StorageManager 需要)
find_library(SQLITE3_LIBRARY sqlite3)
find_path(SQLITE3_INCLUDE_DIR sqlite3.h)

if(SQLITE3_LIBRARY AND SQLITE3_INCLUDE_DIR)
	message(STATUS "Found SQLite3: ${SQLITE3_LIBRARY}")
	add_definitions(-DENABLE_DATABASE)
	include_directories(${SQLITE3_INCLUDE_DIR})
else()
	message(WARNING "SQLite3 not found")
endif()

# Core algorithm sources (C)
set(CORE_SOURCES
  "core/strong_tracking_kalman.c"
  "core/stability_detector.c"
  "core/zero_tracking.c"
  "core/overload_detector.c"
  "core/weight_calculator.c"
  "core/calibration_engine.c"
  "core/filter_engine.c"
)

# C++ sources
set(CXX_SOURCES
  "weighing_system_elinux_plugin.cc"
  "scale/scale_platform.cc"
  "scale/scale_manager.cc"
  "ethercat/ethercat_master.cc"
  "input/ethercat_input.cc"
  "input/shmem_input.cc"
  "input/input_factory.cc"
  "output/output_manager.cc"
  "output/digital_output_mapping.cc"
  "output/digital_io_controller.cc"
  "output/servo_controller.cc"
  "application/app_base.cc"
  "application/liw/liw_application.cc"
  "application/liw/liw_pid_controller.cc"
  "application/filling/filling_application.cc"
  "subsystem/subsystem.cc"
  "subsystem/subsystem_manager.cc"
  "system/system_initializer.cc"
  "storage/database_manager.cc"
  "storage/config_store.cc"
  "storage/calibration_store.cc"
  "storage/weight_record_store.cc"
)

add_library(${PLUGIN_NAME} SHARED
  ${CORE_SOURCES}
  ${CXX_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/core"
  "${CMAKE_CURRENT_SOURCE_DIR}/ethercat"
  "${CMAKE_CURRENT_SOURCE_DIR}/scale"
  "${CMAKE_CURRENT_SOURCE_DIR}/input"
  "${CMAKE_CURRENT_SOURCE_DIR}/output"
  "${CMAKE_CURRENT_SOURCE_DIR}/application"
  "${CMAKE_CURRENT_SOURCE_DIR}/subsystem"
  "${CMAKE_CURRENT_SOURCE_DIR}/system"
  "${CMAKE_CURRENT_SOURCE_DIR}/storage"
  "/home/tronlong/RK3562/EtherCAT/_install/include"  # <- 新增：IgH EtherCAT Include
)
add_library(ext_ethercat SHARED IMPORTED)
set_target_properties(ext_ethercat PROPERTIES
  IMPORTED_LOCATION "/home/tronlong/RK3562/EtherCAT/_install/lib/libethercat.so"
)
target_link_libraries(${PLUGIN_NAME} PRIVATE
  ${SQLITE3_LIBRARY}
  pthread
  rt
  m
  ext_ethercat
)
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)