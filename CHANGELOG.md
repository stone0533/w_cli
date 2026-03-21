## 1.0.16

- Updated version number to 1.0.16
- Fixed parameter name in setup_project.sh call
- Changed --project-name to --name to match script expectations

## 1.0.15

- Updated version number to 1.0.15
- Fixed script path resolution issue for global installation
- Added symbolic link handling for script path resolution
- Improved .pub-cache directory traversal logic
- Enhanced error messages for resource file not found errors

## 1.0.14

- Updated version number to 1.0.14
- Removed deprecated w.dart file
- Added additional tests for script path resolution
- Improved error messages with detailed suggestions
- Enhanced resource file extraction logic

## 1.0.13

- Updated version number to 1.0.13
- Fixed issue with --clean and --uat options not being recognized for build command
- Updated ArgParser configuration for build command options
- Improved command parsing and option handling

## 1.0.12

- Updated version number to 1.0.12
- Improved log output by using real-time streaming for script execution
- Added current version display after update command
- Removed unnecessary script path print statements
- Enhanced error handling for script execution

## 1.0.11

- Updated version number to 1.0.11
- Added automatic execution permission for scripts
- Fixed command format to use `ww create project name` instead of `ww create project:name`
- Improved error handling for script execution

## 1.0.10

- Updated version number to 1.0.10
- Cleaned up code by removing unused handleSetupCommand function
- Updated README.md with correct installation instructions and command format
- Ensured project structure documentation is up-to-date

## 1.0.9

- Improved getScriptPath function with enhanced path discovery
- Added support for finding script files in current working directory
- Added support for traversing parent directories to find script files
- Enhanced error messages with all attempted paths
- Improved script path resolution for different installation environments

## 1.0.8

- Improved handleUpdateCommand function with better logging and error handling
- Added detailed output for version checking and update process
- Added verification step to confirm update success
- Added reminder to restart terminal for changes to take effect
- Simplified files configuration in pubspec.yaml using glob patterns
- Changed files pattern to bin/** and lib/** to ensure all files are included
- Ensure script files are properly included in published package

## 1.0.7

- Fixed files configuration in pubspec.yaml to explicitly include all script files
- Added specific entries for lib/sh directory and individual script files
- Ensure all script files are properly included in published package

## 1.0.6

- Fixed files configuration in pubspec.yaml to include lib directory
- Ensure script files are properly included in published package
- Updated files pattern to use directory paths instead of glob patterns

## 1.0.5

- Fixed script path resolution issue for global installation
- Added direct .pub-cache path resolution for script files
- Improved error messages with all attempted paths
- Enhanced path discovery for different installation environments

## 1.0.4

- Improved handleUpdateCommand function with better error handling
- Added exit code checking for update command
- Enhanced user feedback for update success and failure cases
- Added helpful error messages and suggestions

## 1.0.3

- Fixed script path resolution issue when running from global installation
- Improved getScriptPath function to handle different installation environments
- Added multiple path resolution strategies to find script files

## 1.0.2

- Changed command name from `w` to `ww` to avoid conflict with system `w` command
- Added `executables` field to pubspec.yaml to define command name
- Updated documentation and help messages to use `ww` command

## 1.0.1

- Added `files` field to pubspec.yaml to include sh directory in published package
- Fixed path resolution for scripts when running from global installation

## 1.0.0

- Initial version.
- Added `w create project` command for project initialization
- Added `w generate api` command for API code generation
- Added `w update` command for updating the tool
- Added `w build` command for building Flutter apps
- Added support for project initialization with setup_project.sh
- Updated command structure for better organization
