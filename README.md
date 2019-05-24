GooSushi
==

**GooSushi** is a Dart 2 compliant sample HTTP server application utilizing HttpSession class. Do not use this code without security and stability enhancement for actual applications. This is a Dart code
 sample and an attachment
to the ["Dart 2 Language Gide"](https://www.cresc.co.jp/tech/java/Google_Dart2/introduction/main_page.html) written in Japanese.

This repository consists of the following source codes.

- **SimpleShoppingCartServer.dart** : GooSushi Simple shopping cart application server utilizing HttpSession class. Can be accessed by `http://localhost:8080/GooSushi`.

- **HttpSessionTest.dart** : Simple server for better understanding of the HttpSession session management mechanism. Can be accessed by `http://localhost:8080/SessionTest`

### Installing ###

1. Download this repository, uncompress and rename the folder to "http\_session".
2. From IDE such as IntelliJ, File > Open and select this folder.

### Try it ###

1. Run the bin/shopping\_cart\_server.dart or / and bin/http\_session\_test.dart as server.
2. Access these servers from your two or more different browsers (Chrome, Firefox, IE..) concurrently as `http://localhost:8080/GooSushi` or  `http://localhost:8080/SessionTest` respectively.

 You can change following parameters:

- final LOG_REQUESTS = false; // Set true to get detailed log.

- final int MaxInactiveInterval = 60; // Set session timeout in seconds.


### License ###
This sample is licensed under [MIT License](http://www.opensource.org/licenses/mit-license.php).
