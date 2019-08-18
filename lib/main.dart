import 'package:flutter/material.dart';
import "package:dart_amqp/dart_amqp.dart";
import 'package:rich_alert/rich_alert.dart';
import 'package:vibration/vibration.dart';

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
  //
  // Note: This is a GlobalKey<FormState>,
  // not a GlobalKey<MyCustomFormState>.
  final _formKey = GlobalKey<FormState>();
  static ConnectionSettings settings = new ConnectionSettings(
      host : "YouHostIp",
      authProvider : new PlainAuthenticator("YourAccount", "YourPassword")
  );
  final  _client = new Client(settings: settings);
  String _msg="",_sendmsg="";

  @override
  void initState() {
    super.initState();

    sendRabbitMq('test');
    initRabbitMq();
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
          TextFormField(
            validator: (value) {
              if (value.isEmpty) {
                return 'Please enter some text';
              }

              sendRabbitMq('$value');

              return null;
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
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


          // Get the payload as a string
          _msg= " [x] Received string: ${message.payloadAsString}";

          // Or unSerialize to json
          //_msg= " ${consumer.queue.name} Received json: ${message.payloadAsJson}";

          // Or just get the raw data as a uInt8List
          //_msg= " [x] Received raw: ${message.payload}";

          // The message object contains helper methods for
          // replying, ack-ing and rejecting
          Vibration.vibrate(duration: 1000);
          showDialog(
              context: context,
              builder: (BuildContext context) {
                return RichAlertDialog( //uses the custom alert dialog
                  alertTitle: richTitle("Alert title"),
                  alertSubtitle: richSubtitle('$_msg'),
                  alertType: RichAlertType.WARNING,
                );
              }
          );

          //message.reply("world");

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

}