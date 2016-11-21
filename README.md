# GlueMotor
GlueMotor is a simple idea that allows you to control hobby servo motors from audio jack (headphone jack) with very simple straight connection. <a href="http://makezine.com/projects/make-34/smartphone-servo/">Here is a good article about GlueMotor in Make: magazine</a> (actually, I wrote that) available for more detailed information.

*Important notice: GlueMotor may not work with some servo motors that have higher control signal threshold level. Also some Android devices that have not enough audio output level may not work.*

## Supported platforms
Currently this project supports 3 different platforms:
- Android
- iOS
  - Objective-C
  - Swift (will be published later, maybe, probably, any demands??)
- JavaScript
  - JavaScript stand alone code
  - MOONBlock™ hack.js code (<a href="http://www.moonblock.jp/docs/">"MOONBlock"</a> is a trademark of Ubiquitous Entertainment Inc.)

## How to build the sample projects
- Android: open the Android/ folder with Android Studio
- iOS: open the project file under the iOS/Objective-C/ folder with Xcode

Each project includes "GlueMotorCore" class that is the core module of GlueMotor. For your own project, just copy the "GlueMotorCore" class file(s) into your project.

## Requirements
In terms of using the GlueMotor application, you need to create your own cable. Please refer to <a href="http://www.gluemotor.com/">GlueMotor Web Site</a> or <a href="http://makezine.com/projects/make-34/smartphone-servo/">Make: magazine article</a> for more details.

There is a commercial product exist based on the GlueMotor idea, such as <a href="http://prod.kyohritsu.com/WR-S2ESi.html">"PuchiRobo-S2"</a> from Kyohritsu Electronic Industry Co., Ltd. in Japan. Just in case here is a link to <a href="http://eleshop.jp/shop/g/g402233/">the online store.</a>

## Published Applications
GlueMotor application for Android and iOS are available in App Store:
- Android: <a href="https://play.google.com/store/apps/details?id=com.ktlaboratory.GlueMotor">GlueMotor for Android devices</a>
- iOS: <a href="https://itunes.apple.com/us/app/gluemotor2/id662820229?mt=8">GlueMotor2 for iOS devices</a>
- iOS4 or older: <a href="http://itunes.apple.com/app/id526429691?mt=8">GlueMotor for iOS4 and older devices</a>

## License
This project is published under MIT License. Please refer to the license.txt in this project.

## 
<a href="http://www.gluemotor.com/">![GlueMotor logo](http://www.gluemotor.com/_/rsrc/1336958877866/home/GlueMotor_Logo.png)</a>

*Copyright 2016 (c) by Kazuhisa Terasaki all rights reserved.*
