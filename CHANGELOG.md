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
