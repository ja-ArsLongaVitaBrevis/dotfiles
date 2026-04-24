# Java

> Back to → [dotfiles root](../README.md)

---

## Requirements

- Install [AndroidStudio](https://developer.android.com/studio)
- Install [jenv](https://www.jenv.be/) : Java version manager
  - `jenv` does not install Java versions but manage the ones installed
- Install [Sdkman](https://sdkman.io/install)

## Gradle

Is a tool to compile/run Java projects

We install versions via `Sdkman`.
We `manage versions` via.

To install versions:

- Use `Sdkman`

  - run `sdk list gradle`
  - run `sdk install gradle 7.2`
  - run `sdk use gradle <version>`

To manage versions:

- Use `Sdkman`

  - run `sdk use gradle <version>`

- Set up [Gradle Wrapper](https://docs.gradle.org/current/userguide/gradle_wrapper.html).

## Java versions

We install versions manually via `Oracle Java Downloads`.
We `manage Java versions` via `jenv`.

1. Install the Java version

- Manually [install Oracle Java Downloads](https://www.oracle.com/java/technologies/downloads/)
  - ❗️ make sure you install the `Java SE Development Kit` only
- (try to avoid) [use Homebrew](https://stackoverflow.com/questions/26252591/mac-os-x-and-multiple-java-versions)
- (last resource) Ask chatGPT (😉)

2. Add it to `jenv`:

- In a terminal run `java_get_all_versions`.
  - in the list, find the `path_to_the_binaries` installed.
- In a terminal run `jenv add <path_to_the_binaries>`.
- In a terminal run `jenv versions` (To verify that `jevn` can manage the new version added).
  - the new version should be in the list.
