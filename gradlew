#!/usr/bin/env sh

# Gradle wrapper shell script
# Minimal stub for Unix systems

DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -x "$DIR/gradle/wrapper/gradle-wrapper.jar" ]; then
  java -jar "$DIR/gradle/wrapper/gradle-wrapper.jar" "$@"
else
  echo "gradle-wrapper.jar not found. Please regenerate the Gradle wrapper using 'gradle wrapper'."
  exit 1
fi
