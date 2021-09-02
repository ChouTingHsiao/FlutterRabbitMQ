import 'package:flutter/material.dart';
import "package:dart_amqp/dart_amqp.dart";
import 'package:rich_alert/rich_alert.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appTitle = 'Form Validation Demo';

    return MaterialApp(
      title: appTitle,
      home: Scaffold(
        appBar: AppBar(
          title: Text(appTitle),
        ),
        body: MyCustomForm(),
      ),
    );
  }
}

// Create a Form widget.
class MyCustomForm extends StatefulWidget {
  @override
  MyCustomFormState createState() {
    return MyCustomFormState();
  }
}

// Create a corresponding State class.
// This class holds data related to the form.
class MyCustomFormState extends State<MyCustomForm> {
  // Create a global key that uniquely identifies the Form widget
  // and allows validation of the form.
  // Note: This is a GlobalKey<FormState>,
  // not a GlobalKey<MyCustomFormState>.
  final _formKey = GlobalKey<FormState>();

  static ConnectionSettings settings = new ConnectionSettings(
      host : "You Host",
      authProvider : new PlainAuthenticator("Your Account", "Your Password")
  );

  final  _client = new Client(settings: settings);

  final flutterLocalNotificationsPlugin = new FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();

    initRabbitMq();
    initNotification();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Build a Form widget using the _formKey created above.
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            //left add 8 pixel
            padding: const EdgeInsets.only(left: 8.0,top:0.0,right:8.0,bottom:0.0),
            child: TextFormField(
              validator: (value) {
                if (value.isEmpty) {
                  return 'Please enter some text';
                }

                sendRabbitMq('$value');

                return null;
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0,horizontal: 16.0),
            child: RaisedButton(
              onPressed: () {
                // Validate returns true if the form is valid, or false
                // otherwise.
                if (_formKey.currentState.validate()) {
                  // If the form is valid.

                  Scaffold.of(context)
                      .showSnackBar(SnackBar(content: Text('Processing Data')));
                }
              },
              child: Text('Submit'),
            ),
          ),
        ],
      ),
    );
  }

  void initRabbitMq() {

    _client.channel()
        .then((Channel channel) => channel.exchange("logs", ExchangeType.FANOUT))
        .then((Exchange exchange) => exchange.bindPrivateQueueConsumer(null))
        .then((Consumer consumer) => consumer.listen((AmqpMessage message) {

          notification("Received : ${message.payloadAsString}");

    }));

  }

  void sendRabbitMq(String msg) {
    
    Client _client2 = new Client(settings: settings);

    _client2
        .channel()
        .then((Channel channel) => channel.exchange("logs", ExchangeType.FANOUT))
        .then((Exchange exchange) {
      Vibration.vibrate(duration: 1000);
      exchange.bindPrivateQueueConsumer(null);
      exchange.publish(msg, null);
      return _client2.close();
    });

  }

  void initNotification(){

    var initializationSettingsAndroid =
    new AndroidInitializationSettings('ic_launcher');
    var initializationSettingsIOS = new IOSInitializationSettings();
    var initializationSettings = new InitializationSettings(
        initializationSettingsAndroid, initializationSettingsIOS);
    flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: onSelectNotification);

  }

  Future onSelectNotification(String payload) async {
    showDialog(
      context: context,
      builder: (_) {
        return new AlertDialog(
          title: Text("PayLoad"),
          content: Text("Payload : $payload"),
        );
      },
    );
  }

  Future notification(String msg) async{

    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'your channel id', 'your channel name', 'your channel description',
        importance: Importance.Max, priority: Priority.High, ticker: 'ticker');
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
        0, 'RabbitMQ',msg, platformChannelSpecifics,
        payload: 'item x');

  }

}