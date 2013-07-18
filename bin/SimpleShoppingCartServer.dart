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
  February 2013, incorporated API change (Date -> DateTime)
  February 2013, incorporated dart:io changes
  March 2013, revised for Github uploading
  June 2013, incorporated dart:io changes (dart:uri and HttpRequest.queryParameters removed)
  July 2013, modified main() to ruggedize
  July 2013, modified by Brianoh for various small enhancements - decimal currency,
             Confirm Page, etc.
*/

import "dart:io";
import "dart:utf" as utf;

final String       HOST              = "127.0.0.1";
final int          PORT              = 8080;
final String       REQUEST_PATH      = "/GooSushi";
final bool         LOG_REQUESTS      = false;
final int          MAX_INACTIVE_SECS = 60; // set this parameter in seconds.
final              MENU              = new TodaysMenu().items;  // today's menu
final ShoppingCart CARTBASE          = new ShoppingCart();

void main() {
  try{
    print ('today\'s menu');
    CARTBASE.sortedItemCodes().forEach((itemCode){
      ////print ('itemCode : ${MENU[itemCode].itemCode}, itemName : '
      print ('itemCode : ${MENU[itemCode].itemCode}, itemName : '
      '${MENU[itemCode].itemName}, perItemCost : ${formatCcy(MENU[itemCode].perItemCost)}');
    });

    HttpServer.bind(HOST, PORT).then((HttpServer server) {
      server.sessionTimeout = MAX_INACTIVE_SECS; // set session timeout
      server.listen(
        (HttpRequest request) {
          request.response.done.then((d){
            if (LOG_REQUESTS) print ("${new DateTime.now()} : "
                "sent response to the client for request ${request.uri}");
          }).catchError((e) {
            print ("${new DateTime.now()} : Error occured while sending response: $e");
          });
          if (request.uri.path == REQUEST_PATH) {
            handleRequest(request);
          }
          else {
            request.response.statusCode = HttpStatus.BAD_REQUEST;
            request.response.close();
          }
        });
      print ("${new DateTime.now()} : Serving $REQUEST_PATH on http://${HOST}:${PORT}.");
    });
  } catch(err, st){
    print ("${new DateTime.now()} : Server Error : $err \n $st");
  }
}

// handle request //
void handleRequest(HttpRequest request) {
  final HttpResponse response = request.response;
  String htmlResponse;
  try {
    if (LOG_REQUESTS)
      print ("\n" + createLogMessage(request).toString());
    Session session = new Session(request);
    if (LOG_REQUESTS) print (createSessionLog(session));
    htmlResponse = createHtmlResponse(request, session).toString();
  } catch (err, st) {
    htmlResponse = createErrorPage(err.toString() + st.toString()).toString();
  }
  response.headers.add("Content-Type", "text/html; charset=UTF-8");
  response.write(htmlResponse);
  response.close();
}

// Create HTML response to the request.
StringBuffer createHtmlResponse(HttpRequest request, Session session) {
  if (session.isNew || request.uri.query == null) {
    return createMenuPage();
  }
  if (request.uri.queryParameters.containsKey("menuPage")) {
    StringBuffer sb = createConfirmPage(request, session);
    if (sb.isNotEmpty)
      return sb;
    return createMenuPage();
  }
  if (request.uri.queryParameters["confirmPage"].trim() == "confirmed") {
    StringBuffer sb = createThankYouPage(session);
    session.invalidate();
    return sb;
  }
  if (request.uri.queryParameters["confirmPage"].trim() == "no, re-order") {
    return createMenuPage(cart : session.getAttribute("cart"));
  }
  session.invalidate();
  return createErrorPage("Invalid request received.");
}

/*
 * Shopping cart class.
 */
class ShoppingCart {
  Map<int, ShoppingCartItem> _items;
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

  ClearItems() {_items.clear(); }

  // remove an item from the shopping cart and update the amount
  void removeItem(int itemCode) {
    _items.remove(itemCode);
    _grandTotal = 0.0;
    _items.keys.forEach((key){
        _grandTotal = _items[key].subTotal;
    });
  }

  // Add an new item and update the amount
  void addItem(ShoppingCartItem newItem) {
    _grandTotal = 0.0;
    _items[newItem.itemCode] = newItem;
    _items.keys.forEach((key){
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
    void update(int itemCode, int iQty, double perItemCost) {
      this.itemCode = itemCode;
      this.iQty = iQty;
      this.perItemCost = perItemCost;
    }

  //setter and getter methods
    int get itemCode => _itemCode;
    void set itemCode(int itemCode) {_itemCode = itemCode;}
    double get perItemCost => _perItemCost;
    void set perItemCost(double perItemCost) { _perItemCost = perItemCost;}
    int get iQty => _qty;
    void set iQty(int iQty) { _qty = iQty;}
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

  final List lMenu = [
    300, "Tai (Japanese red sea bream)", 3.60,
    290, "Maguro (Tuna)", 3.60,
    280, "Sake (Salmon)", 3.60,
    270, "Hamachi (Yellowtail)", 3.60,
    260, "Kanpachi (Great amberjack)", 3.60,
    150, "Tobiko (Flying Fish Roe)", 5.20,
    160, "Ebi (Shrimp)", 2.40,
    170, "Unagi (Eel)", 5.20,
    180, "Anago (Conger Eal)", 3.60,
    190, "Ika (Squid)", 2.00
  ];

  // constructor
  TodaysMenu() {
    for (var i = 0; i < lMenu.length ~/ 3; i++) {
      var cartItem = new ShoppingCartItem();
      cartItem.itemCode = lMenu[i * 3];
      cartItem.itemName = lMenu[i * 3 + 1];
      cartItem.perItemCost = lMenu[i * 3 + 2].toDouble();
      cartItem.iQty = 0;
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
  CARTBASE.sortedItemCodes().forEach((itemCode){
    var text2 = '''
        <tr><td align="center">${makeSafe(MENU[itemCode].itemName)}</td>
        <td align="center">${formatCcy(MENU[itemCode].perItemCost)}</td>
        <td align="center"><select name="pieces_${MENU[itemCode].itemCode}">''';
    sb.write(text2);
    if (cart == null || cart.getCartItem(MENU[itemCode].itemCode) == null) {
      text2 = "<option>0<option>1<option>2<option>3<option>4<option>5</select></td></tr>";
    } else {
      int pieces = cart.getCartItem(MENU[itemCode].itemCode).iQty;
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
    Order will be cancelled in ${MAX_INACTIVE_SECS} seconds !
  </body>
</html>''';
   sb.write(text3);
   return sb;
}

// Create confirm page HTML text.
StringBuffer createConfirmPage(HttpRequest request, Session session) {
  // create a shopping cart
  var sb = new StringBuffer("");
  int iTotItems = 0;

  ShoppingCart cart = new ShoppingCart();
  cart.ClearItems();
  request.uri.queryParameters.forEach((String sName, String sValue) {
    int iQuantity;
    if (sName.startsWith("pieces_")) {
      iQuantity = int.parse(sValue);
      if (iQuantity != 0) {
        var cartItem = new ShoppingCartItem();
        cartItem.itemCode = int.parse(sName.substring(7));
        cartItem.iQty = iQuantity;
        cartItem.itemName = MENU[cartItem.itemCode].itemName;
        cartItem.perItemCost = MENU[cartItem.itemCode].perItemCost;
        cartItem.subTotal = multCcy(cartItem.perItemCost, iQuantity, 2);
        cart.addItem(cartItem);
        iTotItems++;
      }
    }
  }); // cart completed
  if (iTotItems < 1)  // nothing selected
    return sb;
  session.setAttribute("cart", cart); // and bind it to the session
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
        <tr bgcolor="#90ee90"><th align="center">Item</th>
          <th align="center">Quantity</th><th align="center">Subtotal</th>
        </tr>''';
  sb.write(text1);
  int iTotQty = 0;
  cart.sortedItemCodes().forEach((itemCode) {
    ShoppingCartItem cartItem =  cart.items[itemCode];
    var text2 = '''
        <tr><td align="center">${makeSafe(cartItem.itemName)}</td>
        <td align="right">${cartItem.iQty}</td>
        <td align="right">${formatCcy(cartItem.subTotal)}</td></tr>''';
    iTotQty += cartItem.iQty;
    sb.write(text2);
  });
  var text3 = '''<tr><td align="center">Grand Total</td>
        <td align="right">${iTotQty}</td>
        <td align="right" bgcolor="#fafad2">\$${formatCcy(cart.amount)}</td></tr>''';
  sb.write(text3);
  var text4 = '''
      </table><br>
      <input type="submit" name= "confirmPage" value="no, re-order">
      <input type="submit" name= "confirmPage" value=" confirmed ">
    </form><br>
    Order will be cancelled in ${MAX_INACTIVE_SECS} seconds !
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
    Total amount: \$${formatCcy(session.getAttribute("cart").amount)}<br><br>
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
        <pre>Server rejected this request: '''
          '''${makeSafe(errorMessage)}</pre><br>
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
  request.uri.queryParameters.forEach((key, value){
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
    if (str[i] == "\n") {
      sb.write("\n  ");
    } else {
      sb.write(str[i]);
    }
  }
  sb.write('''\nrequest.session.id : ${request.session.id}
  request.session.isNew : ${request.session.isNew}''');
  if (request.method == "POST") {
    var enctype = request.headers["content-type"];
    if (enctype[0].contains("text")) {
      sb.write("request body string : ${bodyString.replaceAll('+', ' ')}");
    } else if (enctype[0].contains("urlencoded")) {
      sb.write("request body string (URL decoded): ${Uri.decodeFull(bodyString)}");
    }
  }
  sb.write("\n");
  return sb;
}

// Create session log message
StringBuffer createSessionLog(Session session) {
  var sb = new StringBuffer("");
  sb.write('''  session.isNew : ${session.isNew}
  session.id : ${session.id}
  session.getAttributeNames : ${session.getAttributeNames()}
  session.getAttributes : ${session.getAttributes()}
''');
  return sb;
}

// make safe string buffer data as HTML text
StringBuffer makeSafe(String sData) {
  StringBuffer sbData = new StringBuffer();
  for (int i = 0; i < sData.length; i++){
    if (sData[i] == '&') { sbData.write('&amp;');
    } else if (sData[i] == '"') { sbData.write('&quot;');
    } else if (sData[i] == "'") { sbData.write('&#39;');
    } else if (sData[i] == '<') { sbData.write('&lt;');
    } else if (sData[i] == '>') { sbData.write('&gt;');
    } else { sbData.write(sData[i]);
    }
  }
  return sbData;
}

/*
 * Session class is a wrapper of the HttpSession
 * Makes it easier to transport Java server code to Dart server
 */
class Session{
  HttpSession _session;
  String _id;
  bool _isNew;

  Session(HttpRequest request){
    _session = request.session;
    _id = request.session.id;
    _isNew = request.session.isNew;
    request.session.onTimeout = (){
      print ("${new DateTime.now().toString().substring(0, 19)} : "
       "timeout occurred for session ${_id}");
    };
  }

  // getters
  HttpSession get session => _session;
  String      get id => _id;
  bool        get isNew => _isNew;

  // getAttribute(String name)
  dynamic getAttribute(String name) => _session[name];

  // getAttributes()
  Map getAttributes() {
    Map attributes = {};
    for(String x in _session.keys) attributes[x] = _session[x];
    return attributes;
  }

  // getAttributeNames()
  List getAttributeNames() {
    List names = [];
    for(String x in _session.keys)
      names.add(x);
    return names;
  }

  // setAttribute(String name, dynamic value)
  setAttribute(String name, dynamic value) { _session[name] = value; }

  // removeAttribute()
  removeAttribute(String name) { _session.remove(name); }

  // invalidate()
  invalidate() { _session.destroy(); }
}

/*
 * Doubles can store currency accurately but cannot handle arithmetic.
 */
double multCcy(double dAmt, int iQty, int iDecimals) {
  int iScale= 1;
  for (int i = 0; i<iDecimals; i++, iScale*=10);
  int iAmt = (dAmt * iScale).toInt();
  return (iAmt * iQty) / iScale;
}

/*
 * function to format money with separators.
 */
String formatCcy(double dMoney, {int iDecimals: 2, String sDecSep: '.', String sThouSep: ','}) {
  String sNumber = dMoney.toStringAsFixed(iDecimals);
  List lsNumber  = sNumber.split('.');
  if (lsNumber.length < 2)
    lsNumber.add("0");
  // format the thousands //
  StringBuffer sbMoney = new StringBuffer();
  int iLgth = lsNumber[0].length;
  for (int iPos = 0; iPos < iLgth; iPos++) {
    if ((iPos != 0) && (iLgth -(iPos)) % 3 == 0)
      sbMoney.write(sThouSep);
    sbMoney.write(lsNumber[0][iPos]);
  }
  if (iDecimals == 0 && lsNumber[1] == "0")
    return lsNumber[0].toString();

  while (lsNumber[1].length < iDecimals)
    lsNumber[1] += '0';
  return sbMoney.toString() + sDecSep +lsNumber[1];
}

// Set cookie parameter to the response header.
// (Name and value will be URI encoded.)
void setCookieParameter(HttpResponse response, String name, String value, [String path = null]) {
  if (path == null) {
    response.headers.add("Set-Cookie",
        "${Uri.encodeComponent(name)}=${Uri.encodeComponent(value)}");
  }
  else { response.headers.add("Set-Cookie",
    "${Uri.encodeComponent(name)}=${Uri.encodeComponent(value)};Path=${path}");
  }
}