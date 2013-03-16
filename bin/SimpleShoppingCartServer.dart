/*
  Simple shopping cart application server utilizing newly added
  dart:io#HttpSession abstract class.
  Note: Do not use this code for actual applications.
  Usage:
    1) Run this SimpleShoppingCartServer.dart as server.
    2) Access this server from your browser : http://localhost:8080/GooSushi
  Ref: www.cresc.co.jp/tech/java/Google_Dart/DartLanguageGuide.pdf (in Japanese)
  November 2012, by Cresc Corp.
  January 2013, incorporated API change
  February 2013, incorporated API cange (Date -> DateTime)
  February 2013, incorporated dart:io changes
  March 2013, revised for Github uploading
*/

import "dart:io";
import "dart:utf" as utf;
import "dart:uri" as uri;

final HOST = "127.0.0.1";
final int PORT = 8080;
final REQUEST_PATH = "/GooSushi";
final LOG_REQUESTS = true;
final int MaxInactiveInterval = 60; // set this parameter in seconds.
ShoppingCart cartBase;
Map menu;  // today's menu


void main() {
  try{
    cartBase = new ShoppingCart();
    menu = cartBase.items;
    print('today\'s menu');
    cartBase.sortedItemCodes().forEach((itemCode){
      print('itemCode : ${menu[itemCode].itemCode}, itemName : '
      '${menu[itemCode].itemName}, perItemCost : ${menu[itemCode].perItemCost}');
    });


    HttpServer.bind(HOST, PORT).then((HttpServer server) {
      server.sessionTimeout = MaxInactiveInterval; // set session timeout
      server.listen(
        (HttpRequest request) {
          if (request.uri.path == REQUEST_PATH) {
            requestReceivedHandler(request);
          }
        });
      print("Serving $REQUEST_PATH on http://${HOST}:${PORT}.");
    });

  } on Exception catch(err, st){
    print(err);
    print(st);
  }
}


void requestReceivedHandler(HttpRequest request) {
  HttpResponse response = request.response;
  String htmlResponse;
  try {
    if (LOG_REQUESTS) print(createLogMessage(request).toString());
    Session session = new Session(request);
    if (LOG_REQUESTS) print(createSessionLog(request, session).toString());
    htmlResponse = createHtmlResponse(request, session).toString();
//  if (LOG_REQUESTS) print(createSessionLog(request, session).toString());
  } on Exception catch (err) {
    htmlResponse = createErrorPage(err.toString()).toString();
  }
  response.headers.add("Content-Type", "text/html; charset=UTF-8");
  response.addString(htmlResponse);
  response.close();
}


// Create HTML response to the request.
StringBuffer createHtmlResponse(HttpRequest request, Session session) {
  if (session.isNew || request.uri.query == null) {
    return createMenuPage();
  }
  else if (request.queryParameters.containsKey("menuPage")) {
    return createConfirmPage(request,session);
  }
  else if (request.queryParameters["confirmPage"].trim() == "confirmed") {
    StringBuffer sb = createThankYouPage(session);
    session.invalidate();
    return sb;
  }
  else if (request.queryParameters["confirmPage"].trim() == "no, re-order") {
    return createMenuPage(cart : session.getAttribute("cart"));
  }
  else {
    session.invalidate();
    return createErrorPage("Invalid request received.");
  }
}


/*
 * Session class is a wrapper of the HttpSession
 * Makes it easier to transport Java Servlet code to Dart server
 */
class Session{
  HttpSession session;
  String id;
  bool isNew;

  // constructor
  Session(HttpRequest request){
    session = request.session;
    id = request.session.id;
    isNew = request.session.isNew;
    request.session.onTimeout = (){
    print('${new DateTime.now().toString().slice(0, 19)} : '
      'timeout occured for session ${request.session.id}');
    };
  }

  // getAttribute(String name)
  dynamic getAttribute(String name) {
    if (session.containsKey(name)) {
      return session[name];
    }
    else { return null;
    }
  }

  // setAttribute(String name, dynamic value)
  void setAttribute(String name, dynamic value) {
    session.remove(name);
    session[name] = value;
  }

  // getAttributes()
  Map getAttributes() {
    Map attributes = {};
    for(String x in session.keys) attributes[x] = session[x];
    return attributes;
  }

  // getAttributeNames()
  List getAttributeNames() {
    List names = [];
    for(String x in session.keys) names.add(x);
    return names;
  }

  // removeAttribute()
  void removeAttribute(String name) {
    session.remove(name);
  }

  // invalidate()
  void invalidate() {
    session.destroy();
  }
}


/*
 * Shopping cart class.
 */
class ShoppingCart {
  Map<int, ShoppingCartItem> _items = new Map();
  double _grandTotal;
  DateTime _orderedAt;

  // constructor
  ShoppingCart() {
    _items = new TodaysMenu().items;
    _grandTotal = 0.0;
  }

  // setter and getters
  Map get items =>  _items;
  double get amount => _grandTotal;
  DateTime get orderedAt => _orderedAt;
  void set orderedAt(DateTime time){_orderedAt = time;}

  // methods
  // get cart item with the item code
  ShoppingCartItem getCartItem(int itemCode) => _items[itemCode];

  // remove an item from the shopping cart and update the amount
  void removeItem(int itemCode) {
    _items.remove(itemCode);
    _grandTotal = 0.0;
    _items.keys.forEach(
        (key){
          _grandTotal = _items[key].subTotal;
        });
  }

  // Add an new item and update the amount
  void addItem(ShoppingCartItem newItem) {
    _grandTotal = 0.0;
    _items[newItem.itemCode] = newItem;
    _items.keys.forEach(
        (key){
          _grandTotal += _items[key].subTotal;
        });
  }


  // get List of item keys based on itemCodes
  List sortedItemCodes() {
    List sortedItemCodes = _items.keys.toList(growable: true);
    sortedItemCodes.sort();
    return sortedItemCodes;
  }

}


  /*
   * Bean like class to set and get information about items in the shopping cart.
   */
class ShoppingCartItem {
    int _itemCode;
    String _itemName;
    int _qty;
    double _perItemCost;
    double _subTotal;

  //update items in the shopping cart
    void update(int itemCode, int qty, double perItemCost) {
      this.itemCode = itemCode;
      this.qty =qty;
      this.perItemCost = perItemCost;
    }

  //setter and getter methods
    int get itemCode => _itemCode;
    void set itemCode(int itemCode) {_itemCode = itemCode;}
    double get perItemCost => _perItemCost;
    void set perItemCost(double perItemCost) { _perItemCost = perItemCost;}
    int get qty => _qty;
    void set qty(int qty) { _qty = qty;}
    String get itemName => _itemName;
    void set itemName(String itemName) { _itemName = itemName;}
    double get subTotal => _subTotal;
    void set subTotal(double subTotal) { _subTotal = subTotal; }
}


/*
 * Menu class of the day.
 */
class TodaysMenu {

  Map<int, ShoppingCartItem> _items = new Map();

  Map<int, ShoppingCartItem> get items => _items;

  final todaysMenu = [
    300, "Tai (Japanese red sea bream)", 360,
    290, "Maguro (Tuna)", 360,
    280, "Sake (Salmon)", 360,
    270, "Hamachi (Yellowtail)", 360,
    260, "Kanpachi (Great amberjack)", 360,
    150, "Tobiko (Flying Fish Roe)", 520,
    160, "Ebi (Shrimp)", 240,
    170, "Unagi (Eel)", 520,
    180, "Anago (Conger Eal)", 360,
    190, "Ika (Squid)", 200
  ];


  // constructor
  TodaysMenu() {
    for (var i = 0; i < todaysMenu.length ~/ 3; i++) {
      var cartItem = new ShoppingCartItem();
      cartItem.itemCode=todaysMenu[i * 3];
      cartItem.itemName = todaysMenu[i * 3 + 1];
      cartItem.perItemCost = todaysMenu[i * 3 + 2].toDouble();
      cartItem.qty = 0;
      cartItem.subTotal = 0.0;
      _items[cartItem.itemCode] = cartItem;
    }
  }
}



// Create menu page HTML text.
StringBuffer createMenuPage({ShoppingCart cart: null}) {
  var sb = new StringBuffer("");
  var text1 = '''
<!DOCTYPE html>
<html>
  <head>
    <title>SimpleShoppingCartServer</title>
  </head>
  <body>
    <h1>"Goo!" Sushi</h1>
    <h2>Today's Menu</h2><br>
     <form method="get" action="./GooSushi">
      <table border="1">
        <tr bgcolor="#90ee90"><th align="center">Item</th><th align="center">Price<br>
        (2 pieces)</th><th align="center"></th></tr>''';
  sb.write(text1);
  cartBase.sortedItemCodes().forEach((itemCode){
    var text2 = '''
        <tr><td align="center">${makeSafe(new StringBuffer(menu[itemCode].itemName)).toString()}</td>
        <td align="center">${menu[itemCode].perItemCost}</td>
        <td align="center"><select name="pieces_${menu[itemCode].itemCode}">''';
    sb.write(text2);
    if (cart == null || cart.getCartItem(menu[itemCode].itemCode) == null) {
      text2 = "<option>0<option>1<option>2<option>3<option>4<option>5</select></td></tr>";
    }
    else {
      int pieces = cart.getCartItem(menu[itemCode].itemCode).qty;
      text2 = "";
      for (int i = 0; i < 6; i++) {
        if (i == pieces) {
          text2 = '$text2<option style="color:red" selected>$i';
        }
        else {
          text2 = "$text2<option>$i";
        }
      }
      text2 = "$text2</select></td></tr>";
    }
    sb.write(text2);
  });
  var text3 = '''
      </table><br>
      <input type="submit" name= "menuPage" value="order">
    </form><br>
    Order will be cancelled in ${MaxInactiveInterval} seconds !
  </body>
</html>''';
   sb.write(text3);
   return sb;
}


// Create confirm page HTML text.
StringBuffer createConfirmPage(HttpRequest request, Session session) {
  // create a shopping cart
  var cart = new ShoppingCart();
  request.queryParameters.forEach((String name, String value) {
    int quantity;
    if (name.startsWith("pieces_")) {
      quantity = int.parse(value);
      if (quantity != 0) {
        var cartItem = new ShoppingCartItem();
        cartItem.itemCode = int.parse(name.substring(7));
        cartItem.qty = quantity;
        cartItem.itemName = menu[cartItem.itemCode].itemName;
        cartItem.perItemCost = menu[cartItem.itemCode].perItemCost;
        cartItem.subTotal = cartItem.perItemCost * quantity;
        cart.addItem(cartItem);
      }
    }
  }); // cart completed
  session.setAttribute("cart", cart); // and bind it to the session
  var sb = new StringBuffer("");
  var text1 = '''
<!DOCTYPE html>
<html>
  <head>
    <title>SimpleShoppingCartServer</title>
  </head>
  <body>
    <h1>"Goo!" Sushi</h1>
    <h2>Order Confirmation</h2><br>
     <form method="get" action="./GooSushi">
      <table border="1">
        <tr bgcolor="#90ee90"><th align="center">Item</th><th align="center">Quantity</th><th align="center">Subtotal</th></tr>''';
  sb.write(text1);
  var sumQty = 0;
  cart.sortedItemCodes().forEach((itemCode) {
    ShoppingCartItem cartItem =  cart.items[itemCode];
    var text2 = '''
        <tr><td align="center">${makeSafe(new StringBuffer(cartItem.itemName))}</td>
        <td align="right">${cartItem.qty}</td>
        <td align="right">${formatNumberBy3(cartItem.subTotal)}</td></tr>''';
    sumQty += cartItem.qty;
    sb.write(text2);
  });
  var text3 = '''<tr><td align="center">Grand Total</td>
        <td align="right">${sumQty}</td>
        <td align="right" bgcolor="#fafad2">Yen ${formatNumberBy3(cart.amount)}</td></tr>''';
  sb.write(text3);
  var text4 = '''
      </table><br>
      <input type="submit" name= "confirmPage" value="no, re-order">
      <input type="submit" name= "confirmPage" value=" confirmed ">
    </form><br>
    Order will be cancelled in ${MaxInactiveInterval} seconds !
  </body>
</html>''';
   sb.write(text4);
   return sb;
}

// Create Thank you page HTML text.
StringBuffer createThankYouPage(Session session) {
  var sb = new StringBuffer("");
  var date = new DateTime.now().toString();
  var text1 = '''
<!DOCTYPE html>
<html>
  <head>
    <title>SimpleShoppingCartServer</title>
  </head>
  <body>
    <h1>"Goo!" Sushi</h1>
    <h2>Thank you, enjoy your meal!</h2><br><br>
    Date: ${date.substring(0, date.length-7)}<br>
    Order number: ${session.id}<br>
    Total amount: Yen ${formatNumberBy3(session.getAttribute("cart").amount)}<br><br>
    <form method="get" action="./GooSushi">
      <input type="submit" name= "thankYouPage" value="come again!">
    </form>
  </body>
</html>''';
   sb.write(text1);
   return sb;
}


// Create error page HTML text.
StringBuffer createErrorPage(String errorMessage) {
  return new StringBuffer('''
    <!DOCTYPE html>
    <html>
      <head>
        <title>Error Page</title>
      </head>
      <body>
        <h1> *** Internal Error ***</h1><br>
        <pre>Server error occured: ${makeSafe(new StringBuffer(errorMessage)).toString()}</pre><br>
      </body>
    </html>''');
}


// create log message
StringBuffer createLogMessage(HttpRequest request, [String bodyString]) {
  var sb = new StringBuffer( '''request.headers.host : ${request.headers.host}
request.headers.port : ${request.headers.port}
request.connectionInfo.localPort : ${request.connectionInfo.localPort}
request.connectionInfo.remoteHost : ${request.connectionInfo.remoteHost}
request.connectionInfo.remotePort : ${request.connectionInfo.remotePort}
request.method : ${request.method}
request.persistentConnection : ${request.persistentConnection}
request.protocolVersion : ${request.protocolVersion}
request.contentLength : ${request.contentLength}
request.uri : ${request.uri}
request.uri.path : ${request.uri.path}
request.uri.query : ${request.uri.query}
request.uri.queryParameters :
''');
  request.queryParameters.forEach((key, value){
    sb.write("  ${key} : ${value}\n");
  });
  sb.write('''request.cookies :
''');
  request.cookies.forEach((value){
    sb.write("  ${value.toString()}\n");
  });
  sb.write('''request.headers.expires : ${request.headers.expires}
request.headers :
  ''');
  var str = request.headers.toString();
  for (int i = 0; i < str.length - 1; i++){
    if (str[i] == "\n") { sb.write("\n  ");
    } else { sb.write(str[i]);
    }
  }
  sb.write('''\nrequest.session.id : ${request.session.id}
requset.session.isNew : ${request.session.isNew}''');
  if (request.method == "POST") {
    var enctype = request.headers["content-type"];
    if (enctype[0].contains("text")) {
      sb.write("request body string : ${bodyString.replaceAll('+', ' ')}");
    } else if (enctype[0].contains("urlencoded")) {
      sb.write("request body string (URL decoded): ${uri.decodeUri(bodyString)}");
    }
  }
  sb.write("\n");
  return sb;
}


// Create session log message
StringBuffer createSessionLog(HttpRequest request, Session session) {
  var sb = new StringBuffer("");
  sb.write('''  session.isNew : ${session.isNew}
  session.id : ${session.id}
  session.getAttributeNames : ${session.getAttributeNames()}
  session.getAttributes : ${session.getAttributes()}
''');
  return sb;
}


// make safe string buffer data as HTML text
StringBuffer makeSafe(StringBuffer b) {
  var s = b.toString();
  b = new StringBuffer();
  for (int i = 0; i < s.length; i++){
    if (s[i] == '&') { b.write('&amp;');
    } else if (s[i] == '"') { b.write('&quot;');
    } else if (s[i] == "'") { b.write('&#39;');
    } else if (s[i] == '<') { b.write('&lt;');
    } else if (s[i] == '>') { b.write('&gt;');
    } else { b.write(s[i]);
    }
  }
  return b;
}


// function to format a number with separators. returns formatted number.
// original JS Author: Robert Hashemian (http://www.hashemian.com/)
// modified for Dart, 2012, by Cresc
// num - the number to be formatted
// decpoint - the decimal point character. if skipped, "." is used
// sep - the separator character. if skipped, "," is used
String formatNumberBy3(num number, {String decpoint: '.', String sep: ','}) {
  // need a string for operations
  String numstr = number.toString();
  // separate the whole number and the fraction if possible
  var a = numstr.split(decpoint);
  var x = a[0]; // decimal
  var y;
  bool nfr = false; // no fraction flag
  if (a.length == 1) { nfr = true;
    } else { y = a[1];
  } // fraction
  var z = "";
  var p = x.length;
  if (p > 3) {
    for (int i = p-1; i >= 0; i--) {
      z = '$z${x[i]}';
      if ((i > 0) && ((p-i) % 3 == 0) && (x[i-1].codeUnitAt(0) >= '0'.codeUnitAt(0))
          && (x[i-1].codeUnitAt(0) <= '9'.codeUnitAt(0))) { z = '$z,';
      }
    }
    // reverse z to get back the number
    x = '';
    for (int i = z.length - 1; i>=0; i--) x = '$x${z[i]}';
  }
    // add the fraction back in, if it was there
    if (nfr) return x; else return '$x$decpoint$y';
}


// Set cookie parameter to the response header.
// (Name and value will be URI encoded.)
void setCookieParameter(HttpResponse response, String name, String value, [String path = null]) {
  if (path == null) {
    response.headers.add("Set-Cookie",
        "${uri.encodeUriComponent(name)}=${uri.encodeUriComponent(value)}");
  }
  else { response.headers.add("Set-Cookie",
    "${uri.encodeUriComponent(name)}=${uri.encodeUriComponent(value)};Path=${path}");
  }
}