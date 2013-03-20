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
*/

import "dart:io";
import "dart:utf" as utf;
import "dart:uri" as uri;

final HOST = "127.0.0.1";
final int PORT = 8080;
final REQUEST_PATH = "/SessionTest";
final LOG_REQUESTS = false;
final int MaxInactiveInterval = 20; // set this parameter in seconds. Dart default timeout value is 20 minutes

StringBuffer reqLog, sesLog;

void main() {
  HttpServer.bind(HOST, PORT)
  .then((HttpServer server) {
    server.sessionTimeout = MaxInactiveInterval; // set session timeout
    server.listen(
        (HttpRequest request) {
          if (request.uri.path == REQUEST_PATH) {
            requestReceivedHandler(request);
          }
        });
    print("Serving $REQUEST_PATH on http://${HOST}:${PORT}.");
  });
}

void requestReceivedHandler(HttpRequest request) {
  HttpResponse response = request.response;
  String responseBody;
  Session session;
  try {
    reqLog = createLogMessage(request);
    if (LOG_REQUESTS) print(reqLog.toString());
    session = new Session(request); // get session for the request
    if (request.queryParameters["command"] == "New Session") {
      session.invalidate(); // note: HttpSession.destroy() is effective from the next request
      session = new Session(request);  // therefore this call has no effect
    }
    sesLog = createSessionLog(request, session);
    if (LOG_REQUESTS) print(sesLog.toString());
    responseBody = createHtmlResponse(request, session);
  } on Exception catch (err) {
    responseBody = createErrorPage(err.toString());
  }
  response.headers.add("Content-Type", "text/html; charset=UTF-8");
  // cookie setting example (accepts multi-byte characters)
  setCookieParameter(response, "testName", "TestValue_√2=1.41", request.uri.path);
  response.write(responseBody);
  response.close(); // flush
}

String createHtmlResponse(HttpRequest request, Session session) {
  if (request.queryParameters["command"] == "New Session" || request.queryParameters["command"] == null) {
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
        <pre>${makeSafe(createSessionLog(request, session)).toString()}</pre>
      </body>
    </html>''';
  }
  int pageNumber;
  if (session.isNew || request.queryParameters["command"] == "Start") { pageNumber = 1;
  } else if (request.queryParameters["command"] == "Next Page") {
    pageNumber = session.getAttribute("pageNumber") + 1;
//    pageNumber = Math.parseInt(session.getAttribute("pageNumber").toString()) + 1;
  }
  session.setAttribute("pageNumber", pageNumber);
  return '''
  <!DOCTYPE html>
  <html>
    <head>
      <title>HttpSessionTest</title>
    </head>
    <body>
      <h1>Page ${pageNumber}</h1><br>
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
        <pre>${makeSafe(createSessionLog(request, session)).toString()}</pre>
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
        <pre>Server error occurｒed: ${makeSafe(new StringBuffer(errorMessage)).toString()}</pre><br>
      </body>
    </html>''').toString();
}

/*
 * Session class is a wrapper of the HttpSession
 * Makes it easier to transport Java server code to Dart server
 */
class Session{
  HttpSession session;
  String id;
  bool isNew;
  Session(HttpRequest request){
    session = request.session;
    id = request.session.id;
    isNew = request.session.isNew;
    request.session.onTimeout = (){
    print("${new DateTime.now().toString().slice(0, 19)} : timeout occured for session ${request.session.id}");
    };
  }

  // getAttribute(String name)
  dynamic getAttribute(String name) {
    if (session.containsKey(name)) {
      return session[name];
    }
    else {
      return null;
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