/** @file se.cmd
 *
 * Generic script to set up a project environment
 *
 * Version 1.3 (2011-07-24)
 *
 * Author: Dmitriy Kuminov
 *
 * (Too Simple To Be Copyrighted)
 *
 * This file is provided AS IS with NO WARRANTY OF ANY KIND, INCLUDING THE
 * WARRANTY OF DESIGN, MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
 *
 *
 * SYNOPSIS
 *
 * This script (referred to as SE) attempts to find a file called "env.cmd"
 * starting from the current directory and going up the directory tree until the
 * root of the drive is reached. "env.cmd" may be any valid OS/2 command or REXX
 * file.
 *
 * If "env.cmd" is found, it is called with no arguments and then the command
 * line arguments of SE (if any) are passed on to the shell. If "env.cmd" is not
 * found or fails to execute, an error message is printed and SE terminates.
 *
 * It is also possible to specify a different name of the environment script
 * to search for using the following syntax:
 *
 *      se.cmd @<envsctipt> <cmdline...>
 *
 * If you want to pass arguments to the environment script itself, use one of
 * the following forms (the second one will imply "env.cmd" as the script):
 *
 *      se.cmd @<envsctipt>(<envscriptargs>) <cmdline...>
 *      se.cmd @(<envscriptargs>) <cmdline...>
 *
 * When the environment script is called by SE, the following environment
 * variables are defined:
 *
 *   SE_CMD_RUNNING     Tells the environment script that it is running under
 *                      SE. The value of this variable is the SE version number
 *                      (e.g. "1.1").
 *
 *   SE_CMD_ARGS        Contains the full list of command line arguments
 *                      (excluding the <envscript> specification descrbed above).
 *                      This variable may be modified by the environment script
 *                      and the modified value will be passed to the command
 *                      processor for execution.
 *
 *   SE_CMD_ROOT        Contains the full path to a directory containing the 
 *                      found environment script. This variable may be used to 
 *                      address files relative to the location of the script
 *                      (e.g. other scripts lie the ones containing local
 *                      setup). For simplicity, the value always ends with '\'.
 *
 *   SE_CMD_ENV         Contains the name of the found environment script.
 *                      Together with %SE_CMD_ROOT%, comprises the full path
 *                      to the script.
 *
 *   SE_CMD_CWD         Contains the full path to the directory SE was started  
 *                      from.
 *
 * SE provides a built-in protection against nested invocations which means that
 * any given "env.cmd" residing in a particular directory is executed only once
 * in the current shell. This is done to avoid a possible pollution of the
 * environment with duplicate definitions by scripts that do not care of that on
 * their own.
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
 * Version 1.4 (2014-09-25):
 *   - Strip whitespace around arguments.
 *
 * Version 1.3 (2011-07-24):
 *   - Added SE_CMD_ROOT and SE_CMD_ENV environment variables.
 *
 * Version 1.2 (2010-09-01):
 *   - Fixed a bug with started .CMD scripts being not found in PATH which led
 *     to the "SYS1803: Chaining was attempted from a REXX batch file." error.
 *
 * Version 1.1 (2010-06-09):
 *   - Added SE_CMD_ARGS environment variable.
 *
 * Version 1.0 (2010-03-19):
 *   - Initial release.
 */

'@echo off'
trace off

parse upper source . . ScriptFile

parse arg aArgs

rc = rxFuncAdd('SysLoadFuncs', 'REXXUTIL', 'SysLoadFuncs')
rc = SysLoadFuncs()

EnvCmd = 'env.cmd'
EnvArgs = ''

if (left(arg(1), 1) == '@') then do
    parse value arg(1) with '@'env'('EnvArgs')'
    if (env \== '') then EnvCmd = env
    aArgs = subword(aArgs, 2)
end
if (translate(right(EnvCmd, 4)) \== '.CMD') then
    EnvCmd = EnvCmd'.cmd'

startDir = directory()
dir = startDir
do while 1
    probe = dir'\'EnvCmd
    if (translate(probe) \== ScriptFile &,
        stream(probe, 'C', 'QUERY EXISTS') \== '') then do
        probe_var = probe'_STARTED'
        if (value(probe_var,,'OS2ENVIRONMENT') == '') then do
            if (EnvArgs \== '') then probe = probe EnvArgs
            /*say 'Starting "'probe'"'*/
            call value 'SE_CMD_RUNNING', '1.3', 'OS2ENVIRONMENT'
            call value 'SE_CMD_ARGS', strip(aArgs), 'OS2ENVIRONMENT'
            call value 'SE_CMD_ROOT',,
                filespec('D', probe)||filespec('P', probe), 'OS2ENVIRONMENT'
            call value 'SE_CMD_ENV', filespec('N', probe), 'OS2ENVIRONMENT'
            call value 'SE_CMD_CWD', startDir, 'OS2ENVIRONMENT'
            'call' probe
            aArgs = value('SE_CMD_ARGS',, 'OS2ENVIRONMENT')
            call value 'SE_CMD_CWD',, 'OS2ENVIRONMENT'
            call value 'SE_CMD_ENV',, 'OS2ENVIRONMENT'
            call value 'SE_CMD_ROOT',, 'OS2ENVIRONMENT'
            call value 'SE_CMD_ARGS',, 'OS2ENVIRONMENT'
            call value 'SE_CMD_RUNNING',, 'OS2ENVIRONMENT'
            if (rc \= 0) then do
                say 'ERROR: Executing "'probe'" failed with code 'rc'.'
                exit rc
            end
            call value probe_var, 1, 'OS2ENVIRONMENT'
        end
        leave
    end
    drv = filespec('D', dir)
    path = filespec('P', dir)
    if (path == '') then do
        say 'ERROR: "'EnvCmd'" is not found up the tree.'
        exit 1
    end
    dir = drv||strip(path, 'T', '\')
end

if (aArgs \== '') then do
    /* Start the program */
    prg = word(aArgs, 1)
    isCmd = 0
    realPrg = SysSearchPath('PATH', translate(prg))
    if (realPrg == '') then realPrg = SysSearchPath('PATH', prg'.EXE')
    if (realPrg == '') then realPrg = SysSearchPath('PATH', prg'.COM')
    if (realPrg == '') then realPrg = SysSearchPath('PATH', prg'.CMD')
    if (realPrg \== '') then do
        if (right(realPrg, 4) == '.CMD') then isCmd = 1
    end
    if (isCmd) then 'call' aArgs
    else aArgs
    if (rc == 1041 & pos('|', aArgs) > 0 & pos('2>&1', aArgs) > 0) then do
        /* Piping the command in REXX swallows its STDOUT if the command is
         * not found or invalid leaving the user w/o any feedback. Fix it. */
        say 'SYS1041: The name 'prg' is not recognized as an'
        say 'internal or external command, operable program or batch file.'
        exit 1041
    end
end
exit

