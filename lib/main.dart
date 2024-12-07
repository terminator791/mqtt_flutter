import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:convert';

void main() {
  runApp(MqttApp());
}

class MqttApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MQTT Monitoring & Control',
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: MqttHomePage(),
    );
  }
}

class MqttHomePage extends StatefulWidget {
  @override
  _MqttHomePageState createState() => _MqttHomePageState();
}

class _MqttHomePageState extends State<MqttHomePage> {
  final client = MqttServerClient('172.18.233.54', 'flutter_client');
  final String broker = '172.18.233.54';
  final String username = '43322016';
  final String password = 'iqbal';
  final int port = 1883;

  bool isConnected = false;
  String sensorData = '';
  Map<String, bool> ledStates = {
    'led1': false,
    'led2': false,
    'led3': false,
    'led4': false,
    'led5': false,
  };

  @override
  void initState() {
    super.initState();
    connect();
  }

  Future<void> connect() async {
    client.port = port;
    client.logging(on: true);
    client.setProtocolV311();
    client.keepAlivePeriod = 20;
    client.onDisconnected = onDisconnected;
    client.onConnected = onConnected;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_client')
        .withWillTopic('mqtt/flutter/will')
        .withWillMessage('Client disconnected unexpectedly')
        .authenticateAs(username, password)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    client.connectionMessage = connMessage;

    try {
      await client.connect();
    } catch (e) {
      showSnackbar('Connection failed: $e');
      client.disconnect();
    }
  }

  void disconnect() {
    client.disconnect();
    setState(() {
      isConnected = false;
    });
    showSnackbar('Disconnected from MQTT broker');
  }

  void onConnected() {
    setState(() {
      isConnected = true;
    });
    subscribeToSensorData();
    showSnackbar('Connected to MQTT broker');
  }

  void onDisconnected() {
    setState(() {
      isConnected = false;
    });
    showSnackbar('Disconnected from MQTT broker');
  }

  void subscribeToSensorData() {
    client.subscribe('sensor/data', MqttQos.atLeastOnce);
    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final recMess = c[0].payload as MqttPublishMessage;
      final message =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      try {
        final data = json.decode(message);
        setState(() {
          sensorData =
              'Temperature: ${data['temperature']} °C\nHumidity: ${data['humidity']} %\nLight: ${data['light']}';
        });
      } catch (e) {
        showSnackbar('Error parsing sensor data: $e');
      }
    });
  }

  void toggleLED(String ledKey, bool value) {
    final payload = json.encode({ledKey: value ? 1 : 0});
    client.publishMessage(
      'sensor/led',
      MqttQos.atLeastOnce,
      MqttClientPayloadBuilder().addString(payload).payload!,
    );
    setState(() {
      ledStates[ledKey] = value;
    });
    showSnackbar('LED ${ledKey.toUpperCase()} turned ${value ? "ON" : "OFF"}');
  }

  void showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MQTT Monitoring & Control'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sensor Data:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.teal),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                sensorData.isEmpty ? 'No data yet' : sensorData,
                style: TextStyle(color: Colors.black87),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'LED Control:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Column(
              children: ledStates.entries.map((entry) {
                return SwitchListTile(
                  title: Text('LED ${entry.key.toUpperCase()}'),
                  value: entry.value,
                  onChanged: (value) => toggleLED(entry.key, value),
                );
              }).toList(),
            ),
            SizedBox(height: 16),
            if (!isConnected)
              ElevatedButton.icon(
                onPressed: connect,
                icon: Icon(Icons.cloud_done),
                label: Text('Connect'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: disconnect,
                icon: Icon(Icons.cloud_off),
                label: Text('Disconnect'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
