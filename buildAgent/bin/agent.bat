@echo off
:: ---------------------------------------------------------------------
:: TeamCity build agent start/stop script
:: ---------------------------------------------------------------------
:: Environment variables:
::
:: TEAMCITY_AGENT_MEM_OPTS     Set agent memory options (JVM options)
::
:: TEAMCITY_AGENT_OPTS         Set additional agent JVM options
::
:: TEAMCITY_LAUNCHER_MEM_OPTS  Set agent launcher memory options (JVM options)
::
:: TEAMCITY_LAUNCHER_OPTS      Set agent launcher JVM options
::
:: TEAMCITY_AGENT_PREPARE_SCRIPT    name of a script to execute before start/stop
::
:: ---------------------------------------------------------------------
setlocal

SET TEAMCITY_AGENT_CURRENT_DIR=%CD%
cd /d %~dp0

set QUIET=0
IF ""%1"" == ""status"" if ""%2"" == ""short"" set QUIET=1
:: Fail fast if command is not supported
IF ""%1"" == ""start"" goto command_ok
IF ""%1"" == ""stop"" goto command_ok
IF ""%1"" == ""status"" goto command_ok
IF ""%1"" == ""configure"" goto command_ok
IF ""%1"" == ""probe"" goto command_ok
IF ""%1"" == ""publishParameters"" goto command_ok
IF ""%1"" == ""startExecutor"" goto command_ok
IF ""%1"" == ""executor"" goto command_ok
IF ""%1"" == ""finishExecutor"" goto command_ok
goto command_unknown

:command_ok
IF not "%TEAMCITY_AGENT_CONFIG_FILE%" == "" goto config_file_set
SET TEAMCITY_AGENT_CONFIG_FILE=..\conf\buildAgent.properties

:config_file_set
IF not "%TEAMCITY_AGENT_LOG_DIR%" == "" goto log_dir_set
SET TEAMCITY_AGENT_LOG_DIR=../logs/

:log_dir_set
IF not "%TEAMCITY_AGENT_MEM_OPTS%" == "" goto agent_mem_opts_set
SET TEAMCITY_AGENT_MEM_OPTS_ACTUAL=-Xmx384m
:: uncomment for debugging OOM errors:
:: SET TEAMCITY_AGENT_MEM_OPTS_ACTUAL=-Xmx384m -XX:+HeapDumpOnOutOfMemoryError
goto agent_mem_opts_set_done

:agent_mem_opts_set
SET TEAMCITY_AGENT_MEM_OPTS_ACTUAL=%TEAMCITY_AGENT_MEM_OPTS%

:agent_mem_opts_set_done
SET TEAMCITY_AGENT_OPTS_ACTUAL=%TEAMCITY_AGENT_OPTS% -ea -XX:+DisableAttachMechanism --add-opens=java.base/java.lang=ALL-UNNAMED -XX:+IgnoreUnrecognizedVMOptions %TEAMCITY_AGENT_MEM_OPTS_ACTUAL% -Dlog4j2.configurationFile=file:../conf/teamcity-agent-log4j2.xml -Dteamcity_logs=%TEAMCITY_AGENT_LOG_DIR%

IF not "%TEAMCITY_LAUNCHER_MEM_OPTS%" == "" goto launcher_mem_opts_set
SET TEAMCITY_LAUNCHER_MEM_OPTS_ACTUAL=-Xms16m -Xmx64m
goto launcher_mem_opts_set_done

:launcher_mem_opts_set
SET TEAMCITY_LAUNCHER_MEM_OPTS_ACTUAL=%TEAMCITY_LAUNCHER_MEM_OPTS%

:launcher_mem_opts_set_done
SET TEAMCITY_LAUNCHER_OPTS_ACTUAL=%TEAMCITY_LAUNCHER_OPTS% -ea %TEAMCITY_LAUNCHER_MEM_OPTS_ACTUAL%

IF NOT "%QUIET%"=="1" ECHO Looking for installed Java...
set "java_hint="
IF NOT EXIST ..\conf\teamcity-agent.jvm goto findJava
set /p java_hint=< ..\conf\teamcity-agent.jvm
call :dirname "%java_hint%" java_bin_dir
call :dirname "%java_bin_dir%" java_hint
set "java_bin_dir="

:findJava

IF not "%TEAMCITY_JRE%" == "" IF not "%FORCE_USE_TEAMCITY_JRE%" == "" (
  set "FJ_SKIP_ALL_EXCEPT_ARGS=1"
  CALL "%cd%\findJava.bat" "1.8" "%TEAMCITY_JRE%" 1>nul 2>nul
  set "FJ_SKIP_ALL_EXCEPT_ARGS="
  IF ERRORLEVEL 0 GOTO java_search_done
)

set "FJ_MIN_UNSUPPORTED_JAVA_VERSION=22"
:: First search only among specified directories
set "FJ_SKIP_ALL_EXCEPT_ARGS=1"
CALL "%cd%\findJava.bat" "1.8" "%TEAMCITY_JRE%" "%java_hint%" "%cd%\..\jre" "%cd%\..\..\jre" 1>nul 2>nul
set "FJ_SKIP_ALL_EXCEPT_ARGS="
IF ERRORLEVEL 0 GOTO java_search_done

set "FJ_LOOK_FOR_X86_JAVA=1"
:: Then in all other possible locations for 32bit java 1.8+, arguments are required there as it's covered in previous attempt
CALL "%cd%\findJava.bat" "1.8" 1>nul 2>nul
set "FJ_LOOK_FOR_X86_JAVA="
IF ERRORLEVEL 0 GOTO java_search_done
:: Then in all other possible locations for any bitness
CALL "%cd%\findJava.bat" "1.8" "%TEAMCITY_JRE%" "%java_hint%" "%cd%\..\jre" "%cd%\..\..\jre"
IF ERRORLEVEL 0 GOTO java_search_done
IF NOT "%QUIET%"=="1" ECHO Java not found. Cannot start TeamCity agent. Please ensure JDK or JRE is installed and JAVA_HOME environment variable points to it.
GOTO done
:java_search_done
set "java_hint="

IF NOT "%QUIET%"=="1" ECHO Java executable is found: '%FJ_JAVA_EXEC%'

SET TEAMCITY_AGENT_JAVA_EXEC=%FJ_JAVA_EXEC%
:: Cleanup env
SET "FJ_JAVA_EXEC="
SET "FJ_JAVA_VERSION="
SET "FJ_MIN_UNSUPPORTED_JAVA_VERSION="

:run
set TEAMCITY_LAUNCHER_CLASSPATH=..\launcher\lib\launcher.jar

if EXIST ..\lib\latest\launcher.jar set TEAMCITY_LAUNCHER_CLASSPATH = ..\lib\latest\launcher.jar

if "%TEAMCITY_AGENT_PREPARE_SCRIPT%" == "" goto skip_prepare
call "%TEAMCITY_AGENT_PREPARE_SCRIPT%" %*
:skip_prepare

SET QUIET=
IF ""%1"" == ""start"" goto start
IF ""%1"" == ""stop"" goto stop
IF ""%1"" == ""status"" goto status
IF ""%1"" == ""configure"" goto configure
IF ""%1"" == ""probe"" goto probe
IF ""%1"" == ""startExecutor"" goto startExecutor
IF ""%1"" == ""publishParameters"" goto publishParameters
IF ""%1"" == ""executor"" goto executor
IF ""%1"" == ""finishExecutor"" goto finishExecutor

:command_unknown
echo Error parsing command line.
echo ----------------------------------------
echo Usage: agent.bat start or agent.bat stop[ force]
echo start      - starts the agent in new console window
echo stop       - stops the agent after the currently running build (if any) is finished
echo stop force - stops the agent cancelling the build
echo probe      - starts build agent only to probe configuration parameters and store them
echo publishParameters - to publish the details of the agent within this system back to the TeamCity server
echo startExecutor BUILD_FILE - to run all build start stages before the execution of the first container is reached (executor mode)
echo executor BUILD_FILE [BUILD_STEP] - to run a single build or build step and exit after that (executor mode)
echo finishExecutor BUILD_FILE - to run all build finish stages after the execution of last container is reached (executor mode)

echo ----------------------------------------
goto done

:start

IF EXIST ..\lib\latest\launcher.jar goto start_upgrade
goto start_run
:start_upgrade

del /Q ..\lib\launcher.jar
move ..\lib\latest\launcher.jar ..\lib\launcher.jar

:start_run
"%TEAMCITY_AGENT_JAVA_EXEC%" %TEAMCITY_LAUNCHER_OPTS_ACTUAL% -cp %TEAMCITY_LAUNCHER_CLASSPATH% jetbrains.buildServer.agent.Check %TEAMCITY_AGENT_OPTS_ACTUAL% jetbrains.buildServer.agent.AgentMain -file %TEAMCITY_AGENT_CONFIG_FILE%
IF ERRORLEVEL 1 goto done

IF not "%TEAMCITY_AGENT_START_EXEC%" == "" goto start_cmd
SET TEAMCITY_AGENT_START_EXEC=start /min

:start_cmd
%TEAMCITY_AGENT_START_EXEC% "TeamCity Build Agent" "%TEAMCITY_AGENT_JAVA_EXEC%" %TEAMCITY_LAUNCHER_OPTS_ACTUAL% -cp %TEAMCITY_LAUNCHER_CLASSPATH% jetbrains.buildServer.agent.Launcher %TEAMCITY_AGENT_OPTS_ACTUAL% jetbrains.buildServer.agent.AgentMain -file %TEAMCITY_AGENT_CONFIG_FILE%
goto done

:stop
"%TEAMCITY_AGENT_JAVA_EXEC%" %TEAMCITY_LAUNCHER_OPTS_ACTUAL% -cp %TEAMCITY_LAUNCHER_CLASSPATH% jetbrains.buildServer.agent.Stop %TEAMCITY_AGENT_OPTS_ACTUAL% -file %TEAMCITY_AGENT_CONFIG_FILE% %2
goto done

:status
set TEAMCITY_CONFIGURATOR_JAR=..\lib\agent-configurator.jar
"%TEAMCITY_AGENT_JAVA_EXEC%" %TEAMCITY_LAUNCHER_OPTS_ACTUAL% -jar %TEAMCITY_CONFIGURATOR_JAR% %* --agent-config-file %TEAMCITY_AGENT_CONFIG_FILE%
goto done

:configure
set TEAMCITY_CONFIGURATOR_JAR=..\lib\agent-configurator.jar
"%TEAMCITY_AGENT_JAVA_EXEC%" %TEAMCITY_LAUNCHER_OPTS_ACTUAL% -jar %TEAMCITY_CONFIGURATOR_JAR% %* --agent-config-file %TEAMCITY_AGENT_CONFIG_FILE%
goto done

:probe
"%TEAMCITY_AGENT_JAVA_EXEC%" %TEAMCITY_LAUNCHER_OPTS_ACTUAL% -cp %TEAMCITY_LAUNCHER_CLASSPATH% jetbrains.buildServer.agent.Launcher %TEAMCITY_AGENT_OPTS_ACTUAL% jetbrains.buildServer.agent.AgentMain -file %TEAMCITY_AGENT_CONFIG_FILE% -probe
goto done

:startExecutor
"%TEAMCITY_AGENT_JAVA_EXEC%" %TEAMCITY_AGENT_OPTS_ACTUAL% -cp "../lib/*" jetbrains.buildServer.agent.AgentMain -file %TEAMCITY_AGENT_CONFIG_FILE% -startExecutor
goto done

:publishParameters
"%TEAMCITY_AGENT_JAVA_EXEC%" %TEAMCITY_AGENT_OPTS_ACTUAL% -cp "../lib/*" jetbrains.buildServer.agent.AgentMain -file %TEAMCITY_AGENT_CONFIG_FILE% -publishParameters
goto done

:executor
"%TEAMCITY_AGENT_JAVA_EXEC%" %TEAMCITY_AGENT_OPTS_ACTUAL% -cp "../lib/*" jetbrains.buildServer.agent.AgentMain -file %TEAMCITY_AGENT_CONFIG_FILE% -executor %2
goto done

:finishExecutor
"%TEAMCITY_AGENT_JAVA_EXEC%" %TEAMCITY_AGENT_OPTS_ACTUAL% -cp "../lib/*" jetbrains.buildServer.agent.AgentMain -file %TEAMCITY_AGENT_CONFIG_FILE% -finishExecutor
goto done

:dirname file varName
    setlocal ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION
    SET _dir=%~dp1
    SET _dir=%_dir:~0,-1%
    endlocal & set %2=%_dir%
goto:eof

:done

set "TEAMCITY_AGENT_JAVA_EXEC="
cd /d %TEAMCITY_AGENT_CURRENT_DIR%
