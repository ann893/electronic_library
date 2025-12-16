This README explains how to install and start a TeamCity build agent from a ZIP archive.

## Installation and Configuration

Before installing the agent, make sure a relevant Java version is installed on this computer. `JRE_HOME` and `JAVA_HOME` environment variables should respectively point to the proper JRE and JDK directories. See the supported Java versions in the documentation: https://www.jetbrains.com/help/teamcity/supported-platforms-and-environments.html#Build+Agents

Other prerequisites are listed here: https://www.jetbrains.com/help/teamcity/setting-up-and-running-additional-build-agents.html#Necessary+OS+and+environment+permissions

To install the agent, perform the following steps:
1. Extract this archive to a convenient target directory.
2. Go to `<path_to_agent_directory>\conf` and rename the `buildAgent.dist.properties` file to `buildAgent.properties`.
3. Configure the `buildAgent.properties` file to specify your TeamCity server URL and the name of this build agent. Refer to this article for more information: https://www.jetbrains.com/help/teamcity/build-agent-configuration.html

OS-specific settings:
* On Linux, you may also need to give execution permissions to the `bin/agent.sh` shell script.
* On Windows, you may want to install the build agent Windows service instead of using the manual agent startup. This procedure is described here: https://www.jetbrains.com/help/teamcity/setting-up-and-running-additional-build-agents.html#Build+Agent+as+a+Windows+Service

## Start and Stop Agent

To start the agent manually, run the following script:
* on Windows: `<path_to_agent_directory>\bin\agent.bat start`
* on Linux or macOS: `<path_to_agent_directory>\bin\agent.sh start`

To configure the automatic agent start, follow these instructions: https://www.jetbrains.com/help/teamcity/setting-up-and-running-additional-build-agents.html#Automatic+Start

To stop the agent manually, run:
* on Windows: `<path_to_agent_directory>\bin\agent.bat stop`
* on Linux or macOS: `<path_to_agent_directory>\bin\agent.sh stop`

---

More information: https://www.jetbrains.com/help/teamcity/setting-up-and-running-additional-build-agents.html