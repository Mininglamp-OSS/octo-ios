# Adaptive Cards

![logo](assets/adaptive-card-200.png)

[Adaptive Cards](https://adaptivecards.io) are a new way for developers to exchange content in a common and consistent way. Get started today by putting Adaptive Cards into Microsoft Teams, Outlook Actionable Messages, Cortana Skills, or Windows Timeline -- or render cards inside your own apps by using our SDKs.

## Adaptive Cards is now a semi private repo
* Pull requests and issue creations will no longer be accepted and will be closed. Please send all issues with Adaptive Cards to
[Microoft Teams docs repo (msteams-docs)](https://github.com/MicrosoftDocs/msteams-docs/issues)
* Source code will still be avilable to the public.
* Packages will still be posted to the public.

## Dive in

* [Documentation](https://adaptivecards.io/documentation/)
* [Schema Explorer](https://adaptivecards.io/explorer/)
* [Sample Cards](https://adaptivecards.io/samples/)
* [Designer](https://adaptivecards.io/designer/)

## Install and Build

Adaptive Cards are designed to render anywhere that your users are. The following native platform renderers are under development right now.

PS: Latest Build Status is against `main` branch.

|Platform|Latest Release|Source|Docs|Latest Build Status|
|---|---|---|---|---|
| Android | [![Maven Central](https://img.shields.io/maven-central/v/io.adaptivecards/adaptivecards-android.svg)](https://search.maven.org/#search%7Cga%7C1%7Ca%3A%22adaptivecards-android%22) | [Source](https://github.com/Microsoft/AdaptiveCards-Mobile/tree/main/source/android) | [Docs](https://docs.microsoft.com/en-us/adaptive-cards/display/libraries/android) | ![Build status](https://img.shields.io/azure-devops/build/Microsoft/56cf629e-8f3a-4412-acbc-bf69366c552c/37913/main.svg)
| iOS | [![CocoaPods](https://img.shields.io/cocoapods/v/AdaptiveCards.svg)](https://cocoapods.org/pods/AdaptiveCards) | [Source](https://github.com/Microsoft/AdaptiveCards-Mobile/tree/main/source/ios) | [Docs](https://docs.microsoft.com/en-us/adaptive-cards/display/libraries/ios) |  ![Build status](https://img.shields.io/azure-devops/build/Microsoft/56cf629e-8f3a-4412-acbc-bf69366c552c/37917/main.svg) |

## Code format

We require the C++ code inside this project to follow the clang-format. If you change them, please make sure your changed files are formatted correctly.

Make sure clang-format version 12.0.0 and above version is used.

### IDE integration
ClangFormat describes a set of tools that are built on top of LibFormat. It can support your workflow in a variety of ways including a standalone tool and editor integrations. For details, refer to https://clang.llvm.org/docs/ClangFormat.html

### Format with script
Two scripts are provided to help you format files.
- Windows user only: use FormatSource.ps1. This script use clang-format.exe which is built into Visual Studio by default.

	Execute below command in the root folder of the project

	```
	PowerShell.exe -ExecutionPolicy Bypass scripts\FormatSource.ps1 -ModifiedOnly $False
	```

If it's the first time to run the script, make sure clang-format version 12.0.0 or above in the output. Otherwise you may need to upgrade Visual Studio or use your own clang-format binaries.
```
[clang-format] Version is:
clang-format version 12.0.0
```

- Both Windows and MAC users: Use clang-format npmjs package

	Execute below command in source/nodejs

	```
	npm run format
	``` 

Make sure `npm install` is run before.

### Use Git pre-commit hook
`git pre-commit hook` is an optional process. When you run `git commit`, it will automatically do the format check and auto fix the format if error detected.

First make sure clang-format binary is installed in your dev enviroment.
Then modify scripts/hooks/pre-commit to make sure clangFormat is point to the correct path.
And finally setup the git hook.

Two ways to setup the hook:
1. Copy `scripts/hooks/pre-commit` to `.git/hooks`
2. `git config --local core.hooksPath scripts/hooks`

## End User License Agreement for our binary packages
Consumption of the AdaptiveCards binary packages are subject to the Microsoft EULA (End User License Agreement). Please see the relevant terms as listed below:
- [Android/iOS](https://github.com/microsoft/AdaptiveCards-Mobile/blob/main/source/EULA-Non-Windows.txt)

NOTE: All of the source code, itself, made available in this repo as well as our NPM packages, continue to be governed by the open source [MIT license](https://github.com/microsoft/AdaptiveCards-Mobile/blob/main/LICENSE).

## Community
* Engage with Adaptive Cards users and developers on [StackOverflow](http://stackoverflow.com/questions/tagged/adaptive-cards). 
* Join the [#adaptivecards](https://twitter.com/hashtag/adaptivecards?f=tweets&vertical=default) discussion on Twitter.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see 
the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.