# ChangeLog

## Version 0.1.2

 - `Reactor` -- Reduced object allocations.
- `Connection::Error.translate` -- Handle `Errno::ENOTSOCK` errors.

## Version 0.1.1

- `Connection`
    - `#_write` -- Use `String#byteslice` instead of `String#slice` and
        `String#bytesize` instead of `String#size`.
    - `Error.translate` -- Translate `Errno::ECONNABORTED` as `Error::Reset`.

## Version 0.1.0

- Cleaned up connection handling structure for JRuby support.
- `Connection`
    - `PeerInfo` now not included by default and only available for servers.

## Version 0.1.0.beta5 _(September 4, 2014)_

- `Tasks::OneOff#call`: Ensure that the task is marked as done even if an
    exception is raised.

## Version 0.1.0.beta4 _(September 4, 2014)_

- `Reactor`
    - `#running?`: Return `false` if the Reactor thread is dead.
    - Added `#on_error`, for exception handling callbacks.
- All tasks can now receive arguments.

## Version 0.1.0.beta3 _(August 20, 2014)_

- `Connection::TLS#socket_accept`: Return `nil` on error.

## Version 0.1.0.beta2 _(July 8, 2014)_

- Added version and serial number to the default SSL context.

## Version 0.1.0.beta1 _(May 10, 2014)_

 - Initial release.
