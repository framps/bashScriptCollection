![](https://img.shields.io/github/last-commit/framps/bashScriptCollection.svg?style=flat)

# bashScriptCollection
A collection of bashscripts I wrote which may or may not be useful for others :-)

1. bashCommandParser.sh - Parses command flags `-x` and `-x+` as true and `-x-` as false and accepts `--log_options_with_args`
2. caffeine.sh - Deactivates gnome screensaver if specific programs are active and running. I use this tool on my Mint 18.1 running Mate
3. executeSeafileAPIRequests.sh - Execute some seafile API requests. Can be used to test throtteling of seafile API requests
4. figlet_variation.sh - Display text in any possible figlet fonts
5. loginAndGetDataFromFritz.sh - bash prototype to login into AVM fritzbox and retrieve some data. [See here](https://github.com/framps/pythonScriptCollection) for a Python version and [here](https://github.com/framps/golang_tutorial/tree/master/loginFritz) for a go version.
6. units.sh - Converts a number in gibibits. Example: 1024 -> 1K, 1073741825 -> 1T
7. watchFileChange.sh - Watch a file for any changes and start actions if file changes
8. relaySMS.sh - Tiny SMS relay server script which reads all SMS received with gammu-smsd and forwards them to another phonenumber or sends them to an email or tiggers any other activity
9. checkMyExternalDNS.sh - Checks whether the IP update on an external DDNS executed by a router was successful or has to be updated
10. backupRestoreTestWebhostingSite.sh - Create website backups and restore the created backup into another website and DB to backup and test the backup
