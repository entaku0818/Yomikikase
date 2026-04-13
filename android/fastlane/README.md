fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android build_debug

```sh
[bundle exec] fastlane android build_debug
```

Build debug APK

### android build_release

```sh
[bundle exec] fastlane android build_release
```

Build release AAB

### android upload_metadata_only

```sh
[bundle exec] fastlane android upload_metadata_only
```

Upload metadata only to Google Play (no binary)

### android upload_internal

```sh
[bundle exec] fastlane android upload_internal
```

Upload to Google Play Internal Testing

### android promote_to_production

```sh
[bundle exec] fastlane android promote_to_production
```

Promote Internal to Production

### android test

```sh
[bundle exec] fastlane android test
```

Run unit tests

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
