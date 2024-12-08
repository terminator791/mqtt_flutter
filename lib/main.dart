import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

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
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,
      ),
      themeMode: ThemeMode.system, // Automatic theme switching
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
  bool isConnecting = false;
  String sensorData = '';
  List<FlSpot> temperatureData = [];
  List<FlSpot> humidityData = [];
  List<FlSpot> lightData = [];
  int dataCounter = 0;

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
    setState(() {
      isConnecting = true;
    });

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

    setState(() {
      isConnecting = false;
    });
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
  client.subscribe('iot/sensor', MqttQos.atLeastOnce);
  client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
    final recMess = c[0].payload as MqttPublishMessage;
    final message =
        MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

    try {
      final data = json.decode(message);
      setState(() {
        // Ambil nilai sensor dan konversikan ke double
        double temperature = (data['temperature'] as num).toDouble();
        double humidity = (data['humidity'] as num).toDouble();
        double light = (data['light'] as num).toDouble();

        // Perbarui tampilan data sensor
        sensorData =
            'Temperature: $temperature °C\nHumidity: $humidity %\nLight: $light';

        // Tambahkan data ke riwayat
        dataCounter++;
        temperatureData.add(FlSpot(dataCounter.toDouble(), temperature));
        humidityData.add(FlSpot(dataCounter.toDouble(), humidity));
        lightData.add(FlSpot(dataCounter.toDouble(), light));
      });
    } catch (e) {
      showSnackbar('Error parsing sensor data: $e');
    }
  });
}


  void toggleLED(String ledKey, bool value) {
    final payload = json.encode({ledKey: value ? 1 : 0});
    client.publishMessage(
      'iot/led',
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sensor Data:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Card(
                elevation: 4,
                margin: EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    sensorData.isEmpty ? 'No data yet' : sensorData,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'LED Control:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Wrap(
                spacing: 8.0,
                children: ledStates.entries.map((entry) {
                  return FilterChip(
                    label: Text(entry.key.toUpperCase()),
                    selected: entry.value,
                    onSelected: (value) => toggleLED(entry.key, value),
                  );
                }).toList(),
              ),
              SizedBox(height: 16),
              Text(
                'Sensor History:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Container(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots: temperatureData,
                        isCurved: true,
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              if (!isConnected)
                ElevatedButton.icon(
                  onPressed: connect,
                  icon: isConnecting
                      ? CircularProgressIndicator()
                      : Icon(Icons.cloud_done),
                  label: Text('Connect'),
                  style:
                      ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                )
              else
                ElevatedButton.icon(
                  onPressed: disconnect,
                  icon: Icon(Icons.cloud_off),
                  label: Text('Disconnect'),
                  style:
                      ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
