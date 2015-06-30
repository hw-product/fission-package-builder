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
