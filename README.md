GooSushi
==

**GooSushi** is a Dart sample HTTP server application utilizing newly added HttpSession interface. Do not use this code without security and stability enhancement for actual applications. This is a Dart code
 sample and an attachment
to the ["Dart Language Gide"](http://www.cresc.co.jp/tech/java/Google_Dart/DartLanguageGuide.pdf) written in Japanese.

This repository consists of the following source codes.

- **SimpleShoppingCartServer.dart** : GooSushi Simple shopping cart application server utilizing Dart:io#HttpSession abstract class. Can be accessed by `http://localhost:8080/GooSushi`.

- **HttpSessionTest.dart** : Simple server for better understanding of the HttpSession session management mechanism. Can be accessed by `http://localhost:8080/SessionTest`

このサンプルは[「プログラミング言語Dartの基礎」](http://www.cresc.co.jp/tech/java/Google_Dart/DartLanguageGuide_about.html)の
添付資料です。詳細は「HTTPサーバ (HttpServer)」の章の「セッション管理」及び「ショッピング・カートのアプリケーション・サーバ」の節をご覧ください。

### Installing ###

1. Download this repository, uncompress and rename the folder to "http_session".
2. From Dart Editor, File > Open Existion Folder and select this http_session folder.

### Try it ###

1. Run the bin/SimpleShoppingCartServer.dart or / and bin/HttpSessionTest.dart as server.
2. Access these servers from your two or more different browsers (Chrome, Firefox, IE..) concurrently as `http://localhost:8080/GooSushi` or  `http://localhost:8080/SessionTest` respectively.

 You can change following parameters:

- final LOG_REQUESTS = false; : Set true to get detailed log. 

- final int MaxInactiveInterval = 60; Set session timeout in seconds.


### License ###
This sample is licensed under [MIT License][MIT].
[MIT]: http://www.opensource.org/licenses/mit-license.php