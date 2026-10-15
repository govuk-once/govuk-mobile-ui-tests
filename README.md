# User Interaction Tests

We're looking at [Maestro](https://maestro.mobile.dev/) for our end-to-end, integration and other 'user interaction' tests. We want:

- to create tests once that can then be run on iOS and Android.
- to keep all all of these tests in a single repository.
- there to be no 'hooks' into the app codebase.
- to add the tests as part of an individual developer's workflow and/or as part of our existing Continious Integration (CI) system.
- to be able to flexibly combine tests for specific purposes and needs.

Instructions for installing Maestro can be found [here](https://maestro.mobile.dev/getting-started/installing-maestro).

## Getting started

### Java

To use Maestro, you'll need a Java JDK installed.

For Android, if you're using Android Studio - it is most likely already installed.

For iOS, Xcode does not install or require Java. However, Mac OS X comes with the Java runtime already installed, but you will also require the JDK, use these commands to check...

```shell
java -version   # runtime
javac -version  # JDK
```

If the JDK (`javac`) is not installed, or is not working correctly - the JDK can be installed via [homebrew](https://formulae.brew.sh/formula/openjdk) or using a tool such as [asdf](https://asdf-vm.com/).

Next we need to build the app you want to test, and deploy it on a running simulator.

### iOS

You can do this entirely within Xcode in the normal way using a simulator of your choosing, or via the Xcode CLI - using the default or a custom simulator as follows...

```shell
# Build the debug image...
xcrun xcodebuild -scheme 'GovUK' \
-project 'GovUK.xcodeproj' \
-configuration Debug \
-sdk 'iphonesimulator' \
-destination 'generic/platform=iOS Simulator' \
-derivedDataPath \
build

# Install the debug image on the simulator...
xcrun simctl install Booted /Users/<your-login-id>/govuk-app/govuk-mobile-ios-app/build/Build/Products/Debug-iphonesimulator/govuk_ios.app

# -- or --

# Using maestro iOS default...
maestro start-device --platform ios
```

### Android

As with iOS, you can do this entirely within Android Studio in the normal way using a simulator of your choosing, or via the command line - using the default or a custom simulator as follows...

```shell
# Build the debug image...
./gradlew assembleDebug

# Start maestro android default...
maestro start-device --platform android

# Install the debug image on the simulator...
adb install app/build/outputs/apk/debug/app-debug.apk
```

## Running the tests

Now that you have a running simulator that has your app installed on it, you can run the tests.

Note that we are passing in an environment variable below as the `appId` that is required by Maestro to identify the app to start. This differs between the iOS and Android implementation of the GOV.UK app.

```shell
cd /dir/where/your/tests/are

maestro test filename.yaml
```

You can also run tests by tag(s). For example:

```shell
maestro test --include-tags=<tag-name>(,tag-name) flows
```

## Other useful Maestro commands

Maestro comes with some very useful tools to help you debug, identify issues and generally assist with test creation and maintenance.

```shell
# A GUI that visualises what Maestro can, and can not, access within your app...
maestro studio

# Prints out a JSON formatted listing of your apps structure. Also, useful in identifying why Maestro maybe unable to find specific elements within your app...
maestro hierarchy

# Continuous mode, useful for interactively creating a test...
maestro test -c filename.yaml
```
