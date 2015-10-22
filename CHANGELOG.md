# v0.2.10
* Update how file contents are parsed

# v0.2.8
* Properly kill ephemeral if it was built

# v0.2.6
* Fetch files are no longer auto extracted

# v0.2.4
* Pull assets from ephemeral to allow for expected upload

# v0.2.2
* Set timeout on the build process request to prevent early termination

# v0.2.0
* Refactor to use remote process

# v0.1.36
* Remove defer when running ephemeral command

# v0.1.34
* Add initial package cloud formatting support
* Generate customized info events during build process

# v0.1.32
* Add formatter for repository-generator service

# v0.1.30
* [bugfix] Update vendored packager cookbook

# v0.1.28
* Update vendored cookbook versions
* Attempt to find better error message

# v0.1.26
* Replace librarian with batali
* Update vendored cookbooks
* Update error extractor to attempt actual command error extraction

# v0.1.24
* Better error extraction from log file
* Provide usable error on config file parse failure

# v0.1.22
* Add missing UUID variable on extraction
* Set package type if not provided
* Rescue out exceptions and force failed state

# v0.1.20
* Update log persist location within execution

# v0.1.18
* Ensure keepalive is always halted
* Best attempt at log storage, log error if fail
* Extract error from general log, not trace

# v0.1.16
* Attempt to use extracted error message for exception message
* Provide better error when packager file fails to load
* Properly store chef run log data

# v0.1.14
* Add service registration

# v0.1.12
* Strip non-integer character prefix on version

# v0.1.10
* Updates to where information is pulled from payloads

# v0.1.8
* Add formatters to support notifications
* Update to support receiving payloads from jackals
* Explicitly restrict message validity to tags

# v0.1.6
* Add keepalive timer to ensure message does not timeout

# v0.1.4
* Include vendor directory within gem
* Fix github status setting within payload

# v0.1.0
* Initial release
