import 'package:flutter/material.dart';
import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart' as mqtt;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Client',
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
      ),
      home: const MyHomePage(title: 'MQTT Client'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String broker = 'broker.emqx.io';
  int port = 1883;
  String clientIdentifier = 'android';

  late mqtt.MqttClient client;
  late mqtt.MqttConnectionState connectionState;

  StreamSubscription? subscription;

  var text;

  void _subscribeTopic(String topic) {
    if (connectionState == mqtt.MqttConnectionState.connected) {
      client.subscribe("energy_meter/#", mqtt.MqttQos.atLeastOnce);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            // Calculator display
            SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      '$text',
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: connect,
        child: const Icon(Icons.play_arrow),
      ),
    );
  }

  Future<mqtt.MqttClient> connect() async {
    client = mqtt.MqttClient(broker, '');
    client.port = port;
    client.logging(on: true);
    client.keepAlivePeriod = 60;
    client.onDisconnected = _onDisconnected;

    final mqtt.MqttConnectMessage connMess = mqtt.MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
        .startClean()
        // ignore: deprecated_member_use
        .keepAliveFor(60)
        .withWillQos(mqtt.MqttQos.atMostOnce);
    print('[MQTT client] MQTT client connecting....');
    client.connectionMessage = connMess;

    try {
      await client.connect();
    } catch (e) {
      print(e);
      _disconnect();
    }
    // ignore: deprecated_member_use
    if (client.connectionState == mqtt.MqttConnectionState.connected) {
      print('[MQTT client] connected');
      setState(() {
        // ignore: deprecated_member_use
        connectionState = client.connectionState!;
      });
    } else {
      print('[MQTT client] ERROR: MQTT client connection failed - '
          // ignore: deprecated_member_use
          'disconnecting, state is ${client.connectionState}');
      _disconnect();
    }
    subscription = client.updates?.listen(_onMessage);
    _subscribeTopic("energy_meter/#");
    return client;
  }

  void _disconnect() {
    print('[MQTT client] _disconnect()');
    client.disconnect();
    _onDisconnected();
  }

  void _onDisconnected() {
    print('[MQTT client] _onDisconnected');
    setState(() {
      //topics.clear();
      // ignore: deprecated_member_use
      connectionState = client.connectionState!;
      subscription?.cancel();
    });
    print('[MQTT client] MQTT client disconnected');
  }

  void _onMessage(List<mqtt.MqttReceivedMessage> event) {
    print(event.length);
    final mqtt.MqttPublishMessage recMess =
        event[0].payload as mqtt.MqttPublishMessage;
    final String message =
        mqtt.MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

    print('[MQTT client] MQTT message: topic is <${event[0].topic}>, '
        'payload is <-- $message -->');
    // ignore: deprecated_member_use
    print(client.connectionState);
    print('[MQTT client] message with topic: ${event[0].topic}');
    print('[MQTT client] message with message: ${message}');
    setState(() {
      text = message;
    });
  }
}
