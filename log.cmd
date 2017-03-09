/** @file log.cmd
 *
 * Command output logger.
 *
 * Version 1.2
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
 * Start this script without arguments to get help on usage.
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
 * Version 1.2 (2017-03-09):
 *   - Log elapsed seconds and exit code at termination.
 * Version 1.1 (2014-06-04):
 *   - Always create log file in current directory.
 *   - Log current date/time at start.
 * Version 1.0 (2013-07-08):
 *   - Initial release.
 */

'@echo off'
trace off

parse upper source . . ScriptFile

parse arg aArgs

rc = rxFuncAdd('SysLoadFuncs', 'REXXUTIL', 'SysLoadFuncs')
rc = SysLoadFuncs()

if (aArgs == '') then do
    say 'Command output logger. Logs both standard output and standard error streams'
    say 'to a file called <command>-<timestamp>.log as well as to the console.'
    say
    say 'Usage: log <command> <arguments>'
    exit 1
end

tee_exe = SysSearchPath('PATH', 'TEE.EXE')
if (tee_exe == '') then do
    say 'ERROR: Log requires the "tee" command but TEE.EXE is not found.'
    exit 1
end

prg = word(aArgs, 1)
isCmd = 0
realPrg = SysSearchPath('PATH', translate(prg))
if (realPrg == '') then realPrg = SysSearchPath('PATH', prg'.EXE')
if (realPrg == '') then realPrg = SysSearchPath('PATH', prg'.COM')
if (realPrg == '') then realPrg = SysSearchPath('PATH', prg'.CMD')
if (realPrg \== '') then do
    if (right(realPrg, 4) == '.CMD') then isCmd = 1
end

parse value date('S')||time('L') with ts':'ts1':'ts2'.'ts3
ts = ts||ts1||ts2||strip(ts3,'T','0')
log_file = filespec('N',prg)'-'ts'.log'

call SysFileDelete log_file
call lineout log_file, '['date('N')' 'time('N')', 'aArgs']'
call lineout log_file, ''
call lineout log_file

call time 'R'

tail = '2>&1 | tee -a 'log_file

if (isCmd) then 'call' aArgs tail
else aArgs tail
if (rc == 1041) then do
    /* Piping the command in REXX swallows its STDOUT if the command is
     * not found or invalid leaving the user w/o any feedback. Fix it. */
    msg = 'SYS1041: The name 'prg' is not recognized as an'||'0D0A'x||,
          'internal or external command, operable program or batch file.'
    say msg
    call lineout log_file, msg
end

elapsed = strip(time('E'), 'T', '0')
call lineout log_file, ''
call lineout log_file, '['date('N')' 'time('N')', exit code 'rc', took 'elapsed' s]'

exit rc
