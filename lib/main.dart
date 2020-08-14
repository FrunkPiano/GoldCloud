import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:tobias/tobias.dart' as tobias;
void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
        appBarTheme:const AppBarTheme(
//            color: Colors.white,
          brightness: Brightness.dark,
        ),
      ),
      home: MyHomePage(title: '黄金云仓'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Completer<WebViewController> _controller =
  Completer<WebViewController>();
  WebViewController controller;
  bool isFirstLoad = true;
  bool isLogin = true;
  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: isLogin ? null : PreferredSize(
//        preferredSize:Size.fromHeight(MediaQueryData.fromWindow(window).padding.top),
//        child:SafeArea(
//          top: true,
//          child: Offstage(),
//        ),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
            ),
            value: SystemUiOverlayStyle.dark
        ),
        preferredSize: const Size(0,0),
      ),
      body: Builder(builder: (BuildContext context) {
        return WebView(
          initialUrl: 'http://www.zjbw.vip/gold_cloud/app/login.html',
          javascriptMode: JavascriptMode.unrestricted,
          onWebViewCreated: (WebViewController webViewController) async {
            controller = webViewController;
//            _controller.complete(webViewController);
          },
          // TODO(iskakaushik): Remove this when collection literals makes it to stable.
          // ignore: prefer_collection_literals
          javascriptChannels: <JavascriptChannel>[
            _tokenJavascriptChannel(context),
            _goldJavascriptChannel(context),
          ].toSet(),
          navigationDelegate: (NavigationRequest request) async {
//            if (request.url.startsWith('https://www.youtube.com/')) {
//              print('blocking navigation to $request}');
//              return NavigationDecision.prevent;
//            }

            print('allowing navigation to $request');
            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) async {
            print('Page started loading: $url');
            if (url.startsWith('tel')) {
              if (await canLaunch(url)) {
                await launch(url);
              }
            }
            setState(() {
              isLogin = url.contains('login');
            });



          },
          onPageFinished: (String url) async{
            if(isFirstLoad) {
              String token = await getToken();
              await controller.evaluateJavascript('checkToken(${jsonEncode(token)})');
              isFirstLoad = false;
            }
            print('Page finished loading: $url');
          },
          gestureNavigationEnabled: true,
        );
      }),
       // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  JavascriptChannel _tokenJavascriptChannel(BuildContext context) {
    return JavascriptChannel(
        name: 'Token',
        onMessageReceived: (JavascriptMessage message) {
          controller.evaluateJavascript('checkToken(${jsonEncode(message.message)})');
          _saveToken(message.message);
        });
  }

  JavascriptChannel _goldJavascriptChannel(BuildContext context) {
    return JavascriptChannel(
        name: 'Toast',
        onMessageReceived: (JavascriptMessage message) {
          _handleAliPay(message.message);
        }
    );
  }

  Future<void> _handleAliPay(String order) async {
    Map payResult = await tobias.aliPay(order);
    String resultStr = payResult['result'];
    if (resultStr.length <= 0) {
      String result = await controller.evaluateJavascript('payResultIos(${jsonEncode('999')})');
      print(result);
    } else {
      Map<String, dynamic> payModel = json.decode(resultStr);
      Map<String, dynamic> response = payModel['alipay_trade_app_pay_response'];
      String code = response['code'];
      String result = await controller.evaluateJavascript('payResultIos(${jsonEncode(code)})');
      print(result);
    }
    return;
  }

  Future<void> _saveToken(String token) async {
    print(token);
    SharedPreferences sp = await SharedPreferences.getInstance();
    sp.clear();
    sp.setString("Token", token);
  }

  Future<String> getToken() async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    String token = sp.getString("Token");
    return token;
  }
}
