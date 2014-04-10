#Connect SDK iOS
Connect SDK is an open source framework that unifies device discovery and connectivity by providing one set of methods that work across multiple television platforms and protocols.

For more information, visit our [website](http://www.connectsdk.com/).

* [General information about Connect SDK](http://www.connectsdk.com/discover/)
* [Platform documentation & FAQs](http://www.connectsdk.com/docs/ios/)
* [API documentation](http://www.connectsdk.com/apis/ios/)

##Dependencies
This project has the following dependencies.
- libicucore.dylib
- libz.dylib
- [GoogleCast.framework](https://developers.google.com/cast/docs/downloads)
- Other linker flags: -ObjC
- Automatic Reference Counting (ARC)

##Including Connect SDK in your app

###Use CocoaPods
Add `pod 'ConnectSDK'` to your podfile and run `pod install`.

###Link to your project
1. Clone repository (or download & unzip)
2. Open your project in Xcode
3. Located the Connect SDK Xcode project in the Finder
4. Drag the Connect SDK Xcode project into your project's Xcode library
5. Navigate to your project's settings screen, then navigate to the build phases tab
6. Add ConnectSDK.framework as a Target Dependency
7. Add ConnectSDK.framework in the Link Binary with Libraries section

###Build framework file
1. Close Xcode
2. Install the [iOS Universal Framework](https://github.com/kstenerud/iOS-Universal-Framework) plugin in your Xcode app
3. Open the Xcode project
4. Build project (any target)
5. The .framework package that is built can be used in any iOS project that satisfies the dependencies listed above
6. Be sure to copy the ConnectSDKStrings.strings file into your project

##Contact
* Twitter: [@ConnectSDK](https://www.twitter.com/ConnectSDK)
* Ask a question with the "tv" tag on [Stack Overflow](http://stackoverflow.com/tags/tv)
* General Inquiries: info@connectsdk.com
* Developer Support: support@connectsdk.com
* Partnerships: partners@connectsdk.com

##License
Copyright (c) 2013 LG Electronics.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

> http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
