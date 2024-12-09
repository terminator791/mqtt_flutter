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
      title: 'IoT Temperature & Humidity Monitor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
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
  final client = MqttServerClient('192.168.71.120', 'flutter_client');
  final String broker = '192.168.71.120';
  final String username = 'uas24_iqbal';
  final String password = 'uas24_iqbal';
  final int port = 1883;

  bool isConnected = false;
  double temperature = 0.0;
  double humidity = 0.0;
  bool shouldSendData = true;

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
        .withWillTopic('UAS24-IOT/43322016/connect')
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

  void onConnected() {
    setState(() {
      isConnected = true;
    });
    subscribeToSensorTopics();
    showSnackbar('Connected to MQTT broker');
  }

  void onDisconnected() {
    setState(() {
      isConnected = false;
    });
    showSnackbar('Disconnected from MQTT broker');
  }

  void subscribeToSensorTopics() {
    client.subscribe('UAS24-IOT/43322016/SUHU', MqttQos.atLeastOnce);
    client.subscribe('UAS24-IOT/43322016/KELEMBAPAN', MqttQos.atLeastOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final recMess = c[0].payload as MqttPublishMessage;
      final topic = c[0].topic;
      final message = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      setState(() {
        if (topic == 'UAS24-IOT/43322016/SUHU') {
          temperature = double.parse(message);
        } else if (topic == 'UAS24-IOT/43322016/KELEMBAPAN') {
          humidity = double.parse(message);
        }
      });
    });
  }

  void toggleLED(String ledKey, bool value) {
    final payload = json.encode({ledKey: value ? 1 : 0});
    client.publishMessage(
      'UAS24-IOT/43322016/LED',
      MqttQos.atLeastOnce,
      MqttClientPayloadBuilder().addString(payload).payload!,
    );
    setState(() {
      ledStates[ledKey] = value;
    });
    showSnackbar('LED ${ledKey.toUpperCase()} turned ${value ? "ON" : "OFF"}');
  }

  void toggleDataTransmission(bool value) {
    client.publishMessage(
      'UAS24-IOT/43322016/Status',
      MqttQos.atLeastOnce,
      MqttClientPayloadBuilder().addString(value ? '1' : '0').payload!,
    );
    setState(() {
      shouldSendData = value;
    });
    showSnackbar('Data transmission ${value ? "resumed" : "stopped"}');
  }

  void showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('IoT Sensor Monitor'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Sensor Readings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Temperature: ${temperature.toStringAsFixed(1)}°C',
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      'Humidity: ${humidity.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            SwitchListTile(
              title: Text('Data Transmission'),
              subtitle: Text('Enable/Disable sensor data'),
              value: shouldSendData,
              onChanged: toggleDataTransmission,
            ),
            SizedBox(height: 16),
            Text(
              'LED Control',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            ...ledStates.entries.map((entry) {
              return SwitchListTile(
                title: Text('LED ${entry.key.toUpperCase()}'),
                value: entry.value,
                onChanged: (value) => toggleLED(entry.key, value),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}