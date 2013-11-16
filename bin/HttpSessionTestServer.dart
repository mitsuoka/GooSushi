/*
  Dart code sample : Simple HttpSession test server.
  Note: Do not use this code for actual applications.
  Usage:
    1) Run this HttpSessionTest.dart as server.
    2) Access this server from your browser : http://localhost:8080/SessionTest
  Ref: www.cresc.co.jp/tech/java/Google_Dart/DartLanguageGuide.pdf (in Japanese)
  November 2012, by Cresc Corp.
  January 2013, incorporated API change
  February 2013, incorporated API cange (Date -> DateTime)
  February 2013, incorporated dart:io changes
  June 2013, incorporated Brian's refinements
  June 2013, incorporated dart:io changes (dart:uri and HttpRequest.queryParameters removed)
  Modified July 2013, modified main() to ruggedize
  November 2013, API change (remoteHost -> remoteAddress) incorporated
*/

import "dart:io";

final HOST = "127.0.0.1";
final int PORT = 8080;
final REQUEST_PATH = "/SessionTest";
final LOG_REQUESTS = false;
final int MaxInactiveInterval = 20; // set this parameter in seconds.
                                    // Dart default timeout value is 20 minutes

StringBuffer reqLog, sesLog;

void main() {
  HttpServer.bind(HOST, PORT)
  .then((HttpServer server) {
    server.sessionTimeout = MaxInactiveInterval; // set session timeout
    server.listen(
        (HttpRequest request) {
          request.response.done.then((d){
            if (LOG_REQUESTS) print("${new DateTime.now()} : "
                "sent response to the client for request : ${request.uri}");
          }).catchError((e) {
            print("new DateTime.now()} : Error occured while sending response: $e");
          });
          if (request.uri.path.contains(REQUEST_PATH)) {
            handleRequest(request);
          }
          else {
            request.response.statusCode = HttpStatus.BAD_REQUEST;
            request.response.close();
          }
        });
    print("${new DateTime.now()} : Serving $REQUEST_PATH on http://${HOST}:${PORT}.");
  });
}

void handleRequest(HttpRequest request) {
  HttpResponse response = request.response;
  String responseBody;
  try {
    reqLog = createLogMessage(request);
    if (LOG_REQUESTS)
      print(reqLog.toString());

    Session session = new Session(request); // get session for the request
    sesLog = createSessionLog(session);
    if (LOG_REQUESTS) {
      print(sesLog.toString());
    }

    if (request.uri.queryParameters["command"] == "New Session") {
      session.invalidate(); // note: HttpSession.destroy() is effective from the next request
      session = new Session(request); // get the new session
    }

    if (request.uri.queryParameters["command"] == "New Session"
        || request.uri.queryParameters["command"] == null
        || session.isNew) {
      responseBody = createInitialPage(session);
    } else {
      int iPage = 1;
      if (!(session.isNew) && !(request.uri.queryParameters["command"] == "Start"))
        iPage = session.getAttribute("pageNumber") +1;
      responseBody = createNextPage(session, iPage);
    }
  } catch (err, st) {
    responseBody = createErrorPage(err.toString() + st);
  }
  response.headers.add("Content-Type", "text/html; charset=UTF-8");

  // cookie setting example (accepts multi-byte characters)
  setCookieParameter(response, "testName", "TestValue_√2=1.41", request.uri.path);
  response.write(responseBody);
  response.close(); // flush
}

String createInitialPage(Session session) {
  return '''
   <!DOCTYPE html>
   <html>
     <head>
      <title>HttpSessionTest</title>
     </head>
     <body>
      <h1>Initial Page</h1><br><br>
      <form method="get" action="/SessionTest">
      <input type="submit" name="command" value="Start">
      </form><br>
Available data from the request :
      <pre>${makeSafe(reqLog).toString()}</pre><br>
Session data obtained from the request :
  <pre>${makeSafe(sesLog).toString()}</pre>
Session data for the response :
  <pre>${makeSafe(createSessionLog(session)).toString()}</pre>
     </body>
   </html>''';
}

String createNextPage(Session session, int iPage) {
  session.setAttribute("pageNumber", iPage);
  return '''
  <!DOCTYPE html>
  <html>
    <head>
      <title>HttpSessionTest</title>
    </head>
    <body>
      <h1>Page ${iPage}</h1><br>
      Session will be expired after ${MaxInactiveInterval} seconds.<br>
      <form method="get" action="/SessionTest">
        <input type="submit" name="command" value="Next Page">
        <input type="submit" name="command" value="New Session">
      </form><br>
Available data from the request :
        <pre>${makeSafe(reqLog).toString()}</pre><br>
Session data obtained from the request :
        <pre>${makeSafe(sesLog).toString()}</pre>
Session data for the response :
        <pre>${makeSafe(createSessionLog(session)).toString()}</pre>
    </body>
  </html>''';
}

// Create error page HTML text.
String createErrorPage(String errorMessage) {
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
    </html>''').toString();
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
      print("${new DateTime.now().toString().substring(0, 19)} : "
       "timeout occurred for session ${_id}");
    };
  }

  // getters
  HttpSession get session => _session;
  String get id => _id;
  bool get isNew => _isNew;

  // getAttribute(String name)
  dynamic getAttribute(String name) => _session[name];

  // setAttribute(String name, dynamic value)
  setAttribute(String name, dynamic value) { _session[name] = value; }

  // getAttributes()
  Map getAttributes() {
    Map attributes = {};
    for(String x in _session.keys) attributes[x] = _session[x];
    return attributes;
  }

  // getAttributeNames()
  List getAttributeNames() {
    List names = [];
    for(String x in _session.keys) names.add(x);
    return names;
  }

  // removeAttribute()
  removeAttribute(String name) { _session.remove(name); }

  // invalidate()
  invalidate() { _session.destroy(); }
}

// create log message
StringBuffer createLogMessage(HttpRequest request, [String bodyString]) {
  var sb = new StringBuffer( '''request.headers.host : ${request.headers.host}
request.headers.port : ${request.headers.port}
request.connectionInfo.localPort : ${request.connectionInfo.localPort}
request.connectionInfo.remoteAddress : ${request.connectionInfo.remoteAddress}
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