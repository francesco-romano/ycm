# This module should not be used outside YCM.

#=============================================================================
# Copyright 2013-2014 iCub Facility, Istituto Italiano di Tecnologia
#   Authors: Daniele E. Domenichelli <daniele.domenichelli@iit.it>
#            Elena Ceseracciu <elena.ceseracciu@iit.it>
#
# Distributed under the OSI-approved BSD License (the "License");
# see accompanying file Copyright.txt for details.
#
# This software is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the License for more information.
#=============================================================================
# (To distribute this file outside of YCM, substitute the full
#  License text for the above reference.)

# Create a target depending on a stamp file::
#
#  _ycm_target(<target> [comment])
#
# <target>  - The target created
# <comment> - The comment printed when the target is completed
#
# Sets _ycm_target_stamp_file

include(CMakeParseArguments)

function(_YCM_TARGET _target)
    set(_ycm_target_stamp_file "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${_target}.dir/complete")
    if(NOT TARGET ${_target})
        set(_comment "${ARGV1}")
        if(NOT _comment STREQUAL "")
            set(_comment COMMENT ${_comment})
        endif()

        add_custom_command(OUTPUT "${_ycm_target_stamp_file}"
                           COMMAND "${CMAKE_COMMAND}" -E touch "${_ycm_target_stamp_file}"
                           WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
                           ${_comment}
                           VERBATIM)
        set_property(SOURCE "${_ycm_target_stamp_file}" PROPERTY SYMBOLIC 1)
        add_custom_target(${_target} ALL DEPENDS "${_ycm_target_stamp_file}")
    endif()
    set(_ycm_target_stamp_file "${_ycm_target_stamp_file}" PARENT_SCOPE)
endfunction()


# Download files from other repositories::
#
#  _ycm_download(<target> <description> <url> <ref> <dir> <files> [download args])
#
# <target>        - The target that will be performing the download.
#                   should be created using _YCM_TARGET. If it does not
#                   exist, it will be created.
# <description>   - A short string that will be appended to comments
# <url>           - the url where the file will be dowloaded. The strings
#                   ```<REF>``` and ```<FILE>``` will be replaced with
#                   the actual ref and filename
# <dir>           - The directory where the files will be downloaded. The
#                   relative hierarchy will be preserved
# <files>         - A list of files followed by the relative sha1sum
#                   (i.e. file1;sha1sum1;file2;sha1sum2)
# [download args] - Optional arguments passed to file(DOWNLOAD)

function(_YCM_DOWNLOAD _target _desc _url _ref _dir _files)
    _ycm_target(${_target} "Files from ${_desc} (ref ${_ref}) downloaded")

    # loop over a list of file and sha1
    list(LENGTH _files _size)
    foreach(_i RANGE 1 ${_size} 2)
        math(EXPR _j "${_i} - 1")
        list(GET _files ${_j} _file)
        list(GET _files ${_i} _sha1)

        string(REPLACE "<REF>" "${_ref}" _src "${_url}")
        string(REPLACE "<FILE>" "${_file}" _src "${_src}")

        set(_dest "${_dir}/${_file}")
        set(_orig_dest "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${_target}.dir/downloads/${_file}")
        set(_offline_dest "${CMAKE_SOURCE_DIR}/downloads/${_target}/${_file}")

        if(EXISTS "${_offline_dest}")
            execute_process(COMMAND ${CMAKE_COMMAND} -E copy_if_different "${_offline_dest}" "${_orig_dest}")
        endif()

        if(NOT CMAKE_MINIMUM_REQUIRED_VERSION VERSION_LESS 2.8.12)
            # Just a reminder to remove this when we change cmake minimum required version
            message(AUTHOR_WARNING "CMake minimum required version greater than 2.8.12. You can remove this.")
        endif()
        if(CMAKE_VERSION VERSION_LESS 2.8.12)
            string(REGEX REPLACE "[/\\.]" "_" _clean_filename "${_file}")
            string(REGEX REPLACE "^([0-9])" "_\\1" _clean_filename "${_clean_filename}")
        else()
            string(MAKE_C_IDENTIFIER "${_file}" _clean_filename)
        endif()

        set(_download_script "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${_target}.dir/ycm_download_${_clean_filename}.cmake")
        set(_download_script_real "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${_target}.dir/ycm_download_${_clean_filename}_real.cmake")
        set(_sha1sum_file "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${_target}.dir/ycm_download_${_clean_filename}.sha1sum")

        file(WRITE "${_sha1sum_file}.tmp" "${_sha1}\n")
        execute_process(COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${_sha1sum_file}.tmp" "${_sha1sum_file}")
        file(REMOVE "${_sha1sum_file}.tmp")

        file(WRITE "${_download_script_real}"
"cmake_minimum_required(VERSION ${CMAKE_VERSION})
if(EXISTS \"${_orig_dest}\")
    file(SHA1 \"${_orig_dest}\" _sha1)
    if(\"\${_sha1}\" STREQUAL \"${_sha1}\")
        message(STATUS \"Using file ${_file} previously downloaded from ${_desc} (ref ${_ref})\")
        return()
    endif()
endif()
file(DOWNLOAD \"${_src}\" \"${_orig_dest}\"
     EXPECTED_HASH SHA1=${_sha1} ${ARGN}
     STATUS _status)
list(GET _status 0 _status_0)
if(NOT _status EQUAL 0)
    file(REMOVE \"${_orig_dest}\")
    list(GET _status 1 _status_1)
    message(FATAL_ERROR \"Downloading ${_src} - ERROR \${_status_0}: \${_status_1}\")
endif()
")

        # We need to wrap the download in another script because cmake
        # will not remove the faulty/empty file, and the next execution
        # will not be downloaded again, because the timestamp will be
        # accepted.
        file(WRITE ${_download_script}
"cmake_minimum_required(VERSION ${CMAKE_VERSION})
execute_process(COMMAND \"${CMAKE_COMMAND}\" -P \"${_download_script_real}\"
                WORKING_DIRECTORY \"${CMAKE_CURRENT_SOURCE_DIR}\"
                RESULT_VARIABLE _res_var
                ERROR_VARIABLE _error_var
                ERROR_STRIP_TRAILING_WHITESPACE)
if(NOT \"\${_res_var}\" STREQUAL \"0\")
    file(REMOVE \"${_orig_dest}\")
    if(_error_var MATCHES \"da39a3ee5e6b4b0d3255bfef95601890afd80709\")
        # This is the sha1sum of an empty file. This usually means there was a
        # network problem, but the default message is misleading.
        # We print a different error instead.
        message(FATAL_ERROR \"Cannot download file ${_src}\\nNetwork problem.\")
    else()
        message(FATAL_ERROR \"Cannot download file ${_src}\\n\${_error_var}\")
    endif()
endif()
")
        if(WIN32)
            # On Windows we change files end of lines to the windows ones
            file(APPEND ${_download_script}
"file(READ \"${_orig_dest}\" _tmp)
string(REPLACE \"/r/n\" \"/n\" _tmp \"\${_tmp}\")
file(WRITE \"${_dest}\" \"\${_tmp}\")
")
        else()
            file(APPEND "${_download_script}" "execute_process(COMMAND \"${CMAKE_COMMAND}\" -E copy_if_different \"${_orig_dest}\" \"${_dest}\")\n")
        endif()

        if(YCM_MAINTAINER_MODE)
            file(APPEND "${_download_script}" "execute_process(COMMAND \"${CMAKE_COMMAND}\" -E copy_if_different \"${_orig_dest}\" \"${_offline_dest}\")\n")
        endif()

        add_custom_command(OUTPUT "${_dest}" "${_dir}"
                           COMMAND "${CMAKE_COMMAND}" -P "${_download_script}"
                           WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
                           DEPENDS "${_sha1sum_file}"
                           COMMENT "Downloading file ${_file} from ${_desc} (ref ${_ref})")

        add_custom_command(APPEND
                           OUTPUT "${_ycm_target_stamp_file}"
                           DEPENDS "${_dest}")

        set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_MAKE_CLEAN_FILES ${_dest})
    endforeach()
endfunction()



# Install and copy in the build folder at build time::
#
#  _ycm_install(<target> [install() arguments])
#
# <target>        - The target that will be performing the copy in the
#                   build folder. Should be created using
#                   ```_YCM_TARGET```. If it does not exist, it will be
#                   created.
# [install() arguments] - Arguments that will be passed to install()
#
# The accepted arguments are the same that are accepted by CMake
# install() command (not everything is supported yet)

function(_YCM_INSTALL _target)
    _ycm_target(${_target} "Files from ${_target} installed in CMake build directory")

    # All the arguments except for _target are passed to install()
    install(${ARGN})

    # Parse arguments
    set(_options )
    set(_oneValueArgs DESTINATION
                      RENAME
                      COMPONENT)
    set(_multiValueArgs FILES
                        DIRECTORY
                        PROGRAMS
                        PERMISSIONS)
    cmake_parse_arguments(_INSTALL "${_options}" "${_oneValueArgs}" "${_multiValueArgs}" "${ARGN}")

    # Prepare arguments for file(COPY)
    set(copyARGN "${ARGN}")
    list(REMOVE_AT copyARGN 0)

    # Get relative installation destination
    string(REGEX REPLACE "^${CMAKE_INSTALL_PREFIX}/" "" _INSTALL_DESTINATION_RELATIVE "${_INSTALL_DESTINATION}")

    # Remove COMPONENT argument
    if(DEFINED _INSTALL_COMPONENT)
        string(REGEX REPLACE ";COMPONENT;${_INSTALL_COMPONENT}(;|$)" "\\1" copyARGN "${copyARGN}")
    endif()

    if(_INSTALL_FILES)
        list(INSERT copyARGN 0 INSTALL TYPE FILE FILES)
        list(LENGTH _INSTALL_FILES _length)
        if(_length GREATER 1)
            string(SHA1 _clean_filename "${_INSTALL_FILES}")
            string(SUBSTRING "${_clean_filename}" 0 8 _clean_filename)
            set(_clean_filename "_${_clean_filename}_${_length}_files")
        else()
            set(_clean_filename ${_INSTALL_FILES})
            if(IS_ABSOLUTE "${_clean_filename}")
                string(REPLACE "${CMAKE_CURRENT_BINARY_DIR}/" "" _clean_filename "${_clean_filename}")
                string(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}/" "" _clean_filename "${_clean_filename}")
            endif()
        endif()
    elseif(_INSTALL_DIRECTORY)
        list(INSERT copyARGN 0 INSTALL TYPE FILE FILES)
        set(_clean_filename ${_INSTALL_DIRECTORY})
        if(IS_ABSOLUTE "${_clean_filename}")
            string(REPLACE "${CMAKE_CURRENT_BINARY_DIR}/" "" _clean_filename "${_clean_filename}")
            string(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}/" "" _clean_filename "${_clean_filename}")
        endif()
    else()
        message(FATAL_ERROR "Not yet supported")
    endif()

    if(NOT CMAKE_MINIMUM_REQUIRED_VERSION VERSION_LESS 2.8.12)
        # Just a reminder to remove this when we change cmake minimum required version
        message(AUTHOR_WARNING "CMake minimum required version greater than 2.8.12. You can remove this.")
    endif()
    if(CMAKE_VERSION VERSION_LESS 2.8.12)
        string(REGEX REPLACE "[/\\.]" "_" _clean_filename "${_clean_filename}")
        string(REGEX REPLACE "^([0-9])" "_\\1" _clean_filename "${_clean_filename}")
    else()
        string(MAKE_C_IDENTIFIER "${_clean_filename}" _clean_filename)
    endif()

    # Fix DESTINATION for the build directory
    string(REGEX REPLACE ";DESTINATION;${_INSTALL_DESTINATION}(;|$)" ";DESTINATION;${CMAKE_BINARY_DIR}/${_INSTALL_DESTINATION_RELATIVE}\\1" copyARGN "${copyARGN}")

    # Escape white spaces in filenames
    string(REPLACE " " "\\ " copyARGN "${copyARGN}")

    # Escape brackets
    string(REPLACE "(" "\\(" copyARGN "${copyARGN}")
    string(REPLACE ")" "\\)" copyARGN "${copyARGN}")

    # On Windows replace slashes in filenames with escaped backslashes
    if(WIN32)
        string(REPLACE "/" "\\\\" copyARGN "${copyARGN}")
    endif()

    # If available, use the new "MESSAGE_NEVER" argument for install command
    if(NOT CMAKE_MINIMUM_REQUIRED_VERSION VERSION_LESS 3.1)
        # Just a reminder to remove this when we change cmake minimum required version
        message(AUTHOR_WARNING "CMake minimum required version greater than 3.1. You can remove this.")
    endif()
    # FIXME change this to CMake 3.1 as soon as it is released
    if(NOT CMAKE_VERSION VERSION_LESS 3.0.20140628)
        list(APPEND copyARGN MESSAGE_NEVER)
    endif()

    # Write copy script
    set(_ycm_install_script "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${_target}.dir/ycm_install_${_clean_filename}.cmake")
    set(_ycm_install_stamp_file "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${_target}.dir/ycm_install_${_clean_filename}-complete")

    file(WRITE "${_ycm_install_script}"
"cmake_minimum_required(VERSION ${CMAKE_VERSION})
set(_DESTDIR \$ENV{DESTDIR})
set(ENV{DESTDIR} )
file(${copyARGN})
set(ENV{DESTDIR} \${_DESTDIR})
")

    # Add custom command
    add_custom_command(OUTPUT "${_ycm_install_stamp_file}"
                       COMMAND "${CMAKE_COMMAND}" -P "${_ycm_install_script}"
                       WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
                       COMMENT "")
    set_property(SOURCE "${_ycm_install_stamp_file}" PROPERTY SYMBOLIC 1)

    # Set file level dependencies for the
    add_custom_command(APPEND
                       OUTPUT "${_ycm_target_stamp_file}"
                       DEPENDS "${_ycm_install_stamp_file}")

    # Generate a list of output and dependencies
    foreach(_file IN LISTS _INSTALL_FILES _INSTALL_DIRECTORY _INSTALL_PROGRAMS)
        list(APPEND _depends "${_file}")
        if(_INSTALL_RENAME)
            set(_out "${_INSTALL_DESTINATION_RELATIVE}/${_INSTALL_RENAME}")
        else()
            get_filename_component(_out "${_file}" NAME)
            set(_out "${_INSTALL_DESTINATION_RELATIVE}/${_out}")
        endif()
        list(APPEND _output "${_out}")

        # Xcode generator requires at least one COMMAND, otherwise it will not
        # generate a target.
        # On the other hand MSVC does not like empty commands, therefore we add
        # an empty echo command to make everyone happy.
        add_custom_command(OUTPUT  "${_out}"
                           DEPENDS "${_file}"
                           COMMAND "${CMAKE_COMMAND}" -E echo_append
                           COMMENT "")

        add_custom_command(APPEND
                           OUTPUT "${_ycm_install_stamp_file}"
                           DEPENDS "${_out}")

        set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_MAKE_CLEAN_FILES "${_out}")
    endforeach()
endfunction()
