##########################################################################
# Copyright 2019 Sebastian Merzbach
#
# authors:
#  - Sebastian Merzbach <smerzbach@gmail.com>
#
# file creation date: 2019-03-03
#
# This file is part of smml.
#
# smml is free software: you can redistribute it and/or modify it under
# the terms of the GNU Lesser General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# smml is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
# License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with smml.  If not, see <http://www.gnu.org/licenses/>.
#
##########################################################################

cmake_minimum_required (VERSION 2.4)

project(embree_intersect_mex)

set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR})


### configure build output directory

set (CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/../../mex")


### find external libraries

# adapt this path to your Embree installation folder (e.g. /usr/local)
set(EMBREE_LOCATION ~/local/)
find_package(Embree REQUIRED)

set(matlab_components MAIN_PROGRAM)
find_package(Matlab REQUIRED COMPONENTS ${matlab_components})


### compiler flags

# enable C++ 11 if the compiler supports it (relevant for GCC/Clang only):
set (CMAKE_CXX_STANDARD 11)
if (CMAKE_COMPILER_IS_GNUCXX)
    set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fopenmp -pthread")
    set (CMAKE_LINKER_FLAGS "${CMAKE_LINKER_FLAGS} -fopenmp")
endif ()

# enable OpenMP support
if(NOT TARGET OpenMP::OpenMP_CXX)
    find_package(Threads REQUIRED)
    add_library(OpenMP::OpenMP_CXX IMPORTED INTERFACE)
    set_property(TARGET OpenMP::OpenMP_CXX PROPERTY INTERFACE_COMPILE_OPTIONS ${OpenMP_CXX_FLAGS})
    set_property(TARGET OpenMP::OpenMP_CXX PROPERTY INTERFACE_LINK_LIBRARIES ${OpenMP_CXX_FLAGS} Threads::Threads)
endif()


## set up Matlab MEX library

set(SOURCES
    ${PROJECT_NAME}.cpp
)

include_directories (${MATLAB_INCLUDE_DIRS})
include_directories (${CMAKE_SOURCE_DIR})
include_directories (${EMBREE_INCLUDE_DIR})

matlab_add_mex(
    NAME ${PROJECT_NAME}
    OUTPUT_NAME ${PROJECT_NAME}
    SRC ${SOURCES}
)

target_link_libraries (${PROJECT_NAME} ${EMBREE_LIBRARY})
target_link_libraries (${PROJECT_NAME} ${TBB_LIBRARIES})
target_link_libraries (${PROJECT_NAME} ${MATLAB_LIBRARIES})


