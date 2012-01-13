/** @file bldlevelx.cmd
 *
 * Requests the BLDLEVEL information for a given file.
 *
 */ G.!Version = '1.0' /*
 *
 * Author: Dmitriy Kuminov
 *
 * This software is in Public Domain.
 *
 * This software is provided AS IS with NO WARRANTY OF ANY KIND, INCLUDING THE
 * WARRANTY OF DESIGN, MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
 *
 *
 * SYNOPSIS
 *
 * This utility the BLDLEVEL command to query the build level information. As an
 * extention to the original command, BLDLEVELX checks if only a file name with
 * no path referring to a DLL (ends with .DLL) or to an EXE (ends with .EXE)
 * is given and if so, it will perform a search for this file in the respective
 * system directories ([BEGIN/END]LIBPATH or PATH, respectively).
 *
 * In addition, BLDLEVELX can print values of individual fields of the build
 * level information which is useful installation scripts.
 *
 * Launch this script with no arguments to get a list of supported options.
 *
 *
 * INSTALLATION
 *
 * Place this script to a directory listed in your PATH environment variable.
 * If you do not like the original name of the script, you may rename it to
 * whatever you find more suitable -- this will not affect its functionality.
 *
 *
 * HISTORY
 *
 * Version 1.0 (2012-01-13)
 *   - Initial release.
 */

'@echo off'
trace off

parse source . . ScriptFile

parse arg aArgs

rc = rxFuncAdd('SysLoadFuncs', 'REXXUTIL', 'SysLoadFuncs')
rc = SysLoadFuncs()

if (aArgs = '') then do
    say 'BLDLEVELX' G.!Version 'by Dmitriy Kuminov'
    say
    say 'Requests the BLDLEVEL information for a given file and prints it to the'
    say 'standard output. If the file name refers to a DLL or an EXE and no path'
    say 'information is given, it will be searched in the respective system'
    say 'directories ([BEGIN/END]LIBPATH or PATH).'
    say
    say 'Usage: 'filespec('N', ScriptFile)' [-f<format>] <file>'
    say
    say 'The <format> specifier will cause only a value of the specified field'
    say 'to be printed and is of the following:'
    say
    say '  n - File Name'
    say '  s - Signature'
    say '  V - Vendor'
    say '  r - Revision'
    say '  d - Date/Time'
    say '  M - Build Machine'
    say '  A - ASD Feature ID'
    say '  v - File Version'
    say '  D - Description'
    say
    exit 0
end

formats.!index = 'nsVrdMAvD'
formats.1.!field = '!filename'
formats.2.!field = '!signature'
formats.3.!field = '!vendor'
formats.4.!field = '!revision'
formats.5.!field = '!datetime'
formats.6.!field = '!buildmachine'
formats.7.!field = '!asdid'
formats.8.!field = '!version'
formats.9.!field = '!description'

format = strip(word(aArgs, 1))
if (left(format, 2) == '-f') then do
    format = substr(format, 3)
    if (pos(substr(format, 1, 1), formats.!index) == 0) then do
        say 'ERROR: Format specifier "'substr(format, 1, 1)'" is not valid.'
        exit 1
    end
    aArgs = subword(aArgs, 2)
end
else format = ''

file = strip(aArgs)
rc = GetBldLevel(file, 'G.!bldlevel')

if (rc \= 0) then do
    select
        when rc = 2 then
            say 'ERROR: Cannot find file "'aArgs'".'
        when rc = 1041 then
            say 'ERROR: Cannot find BLDLEVEL.EXE in PATH.'
        otherwise
            say 'ERROR: Unknown error' rc'.'
    end
    exit rc
end

if (format = '') then do
    say 'File Name:       'G.!bldlevel.!filename

    if (G.!bldlevel.!signature = '') then do
        say 'Signature:       <not found>'
    end
    else do
        say 'Signature:       'G.!bldlevel.!signature
        say 'Vendor:          'G.!bldlevel.!vendor
        say 'Revision:        'G.!bldlevel.!revision
        say 'Date/Time:       'G.!bldlevel.!datetime
        say 'Build Machine:   'G.!bldlevel.!buildmachine
        say 'ASD Feature ID:  'G.!bldlevel.!asdid
        say 'File Version:    'G.!bldlevel.!version
        say 'Description:     'G.!bldlevel.!description
    end
end
else do
    i = pos(substr(format, 1, 1), formats.!index)
    val = value('G.!bldlevel.'formats.i.!field)
    say val
end

exit 0

/**
 * Requests the build level information for a file using the BLDLEVEL utility
 * and returns it in a stem. If a file is a DLL (has the .DLL extension) or an
 * EXE (has the .EXE extension) and does not contain a path specification,
 * it is searched in the standard library directories (as listedn in
 * [BEGIN/END]LIBPATH) or executable directories (as listed in PATH)
 * respectively.
 *
 * On success, the stem variable will get the following fields filled in with
 * the information from the respective fields of the BLDLEVEL output:
 *
 * .!signature
 * .!vendor
 * .!revision
 * .!datetime
 * .!buildmachine
 * .!asdid
 * .!version
 * .!description
 *
 * In addition, the field .!filename will receive the name of the queried file
 * including the resolved absolute path. Note that all fields except .!filename
 * may be empty when this function succeeds. In particular, an empty .!signature
 * field means that the build level information is not available for the given
 * file at all. Empty values in other fields mean that the respective field
 * is missing.
 *
 * On failure, the stem variable is not touched at all.
 *
 * @param aFile     File name to request the information for.
 * @param aStem     Stem variable to store build level into (no dot at the end).
 * @return          0 on success, non-zero error code on failure.
 */
GetBldLevel: procedure expose G.

    parse arg aFile, aStem

    path = filespec('D', aFile)||filespec('P', aFile)
    name = filespec('N', aFile)

    if (path = '') then do
        /* search for the file in system paths */
        search_path = ''
        ext = translate(right(name, 4))
        if (ext == '.DLL') then do
            config_sys = SysBootDrive()'\CONFIG.SYS'
            do while lines(config_sys)
                line = strip(linein(config_sys))
                if (left(line, 8) == 'LIBPATH=') then do
                    search_path = substr(line, 9)
                    leave
                end
            end
            call lineout config_sys
            search_path = SysQueryExtLibPath('B')';'search_path';'SysQueryExtLibPath('E')
        end
        else if (ext == '.EXE') then do
            search_path = value('PATH',, 'OS2ENVIRONMENT')
        end

        if (search_path \= '') then do
            call value 'BLDLEVELX_SEARCH_PATH', search_path, 'OS2ENVIRONMENT'
            real_file = SysSearchPath('BLDLEVELX_SEARCH_PATH', aFile)
            call value 'BLDLEVELX_SEARCH_PATH',, 'OS2ENVIRONMENT'
        end
        else do
            real_file = aFile
        end
    end
    else do
        /* use the given file as is */
        real_file = aFile
    end

    if (real_file = '') then return 2
    real_file = stream(real_file, 'C', 'QUERY EXISTS')
    if (real_file = '') then return 2

    queue_name = rxqueue('Create')
    call rxqueue 'Set', queue_name

    'bldlevel.exe' real_file '2>nul | RXQUEUE' queue_name

    if (rc = 0) then do
        call value aStem'.!signature', ''
        call value aStem'.!vendor', ''
        call value aStem'.!revision', ''
        call value aStem'.!datetime', ''
        call value aStem'.!buildmachine', ''
        call value aStem'.!asdid', ''
        call value aStem'.!version', ''
        call value aStem'.!description', ''

        do queued()
            parse pull key':'value
            value = strip(value)
            select
                when key = 'Signature' then call value aStem'.!signature', value
                when key = 'Vendor' then call value aStem'.!vendor', value
                when key = 'Revision' then call value aStem'.!revision', value
                when key = 'Date/Time' then call value aStem'.!datetime', value
                when key = 'Build Machine' then call value aStem'.!buildmachine', value
                when key = 'ASD Feature ID' then call value aStem'.!asdid', value
                when key = 'File Version' then call value aStem'.!version', value
                when key = 'Description' then call value aStem'.!description', value
                otherwise nop
            end
        end
    end

    call rxqueue 'Delete', queue_name

    call value aStem'.!filename', real_file

    return 0
