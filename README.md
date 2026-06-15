# andriodmealflow

Android app

## Publish an app update

Run `publish_github_update.cmd` from the project folder.

It asks for the new version number, increases Android `versionCode`, builds an APK, pushes the version change to GitHub, and uploads the APK to a GitHub Release.

Before first use, install GitHub CLI and login:

```cmd
gh auth login
```
