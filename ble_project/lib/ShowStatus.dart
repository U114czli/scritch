import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';


class ShowStatus extends StatefulWidget {
  final BluetoothDevice device;

  const ShowStatus({Key? key, required this.device}) : super(key: key);

  @override
  _ShowStatus createState() => _ShowStatus();
}

class _ShowStatus extends State<ShowStatus> {
  BluetoothCharacteristic? myCharacteristic;
  late Timer _readTimer;
  late List<int> characteristicValues;
  late FlutterLocalNotificationsPlugin localNotification;

  List<Map<String, dynamic>> dataBuffer = [];
  DateTime? startTime;

  List<int> allValues = []; // 保存所有讀取到的值

  var android;
  var initializationSettings;

  @override
  void initState() {
    super.initState();
    subscribeToCharacteristic();
    _readTimer = Timer.periodic(const Duration(milliseconds: 1000), (Timer timer) {
      readCharacteristicValue();
    });
    characteristicValues = [];
    localNotification = FlutterLocalNotificationsPlugin();

    android = const AndroidInitializationSettings('@mipmap/ic_launcher');
    initializationSettings = InitializationSettings(android: android);

    localNotification.initialize(InitializationSettings(android:android));

    localNotification.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    // initializeNotifications();

  }

  @override
  void dispose() {
    if (myCharacteristic != null) {
      myCharacteristic!.setNotifyValue(false);
    }
    widget.device.disconnect();
    _readTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueDisplayWidget(
      characteristicValues: characteristicValues,
      allValues: allValues,);
  }

  Future<void> readCharacteristicValue() async {
    try {
      if (myCharacteristic != null) {
        List<int>? value = await myCharacteristic!.read();
        print('Read value: $value');
        setState(() {
          characteristicValues = value;
          allValues.addAll(characteristicValues);

          // 將讀取到的值存入 buffer
          addToBuffer(value);
        });

        // 發送通知
        sendNotification(characteristicValues.isNotEmpty ? characteristicValues[0] : -1);
      }
    } catch (e) {
      print('Error reading characteristic value: $e');
    }
  }

  Future<void> subscribeToCharacteristic() async {
    try {
      List<BluetoothService> services = await widget.device.discoverServices();
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.uuid == Guid('00001234-0000-1000-8000-00805f9b34fb')) {
            myCharacteristic = characteristic;
            await myCharacteristic!.setNotifyValue(true);
            return;
          }
        }
      }
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('Characteristic not found. Disconnecting...'),
            actions: <Widget>[
              TextButton(
                onPressed: () async {
                  await widget.device.disconnect();
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('Error subscribing to characteristic: $e');
    }
  }

  // void initializeNotifications() async {
  //   const AndroidInitializationSettings initializationSettingsAndroid =
  //   AndroidInitializationSettings('@mipmap/ic_launcher');
  //   final InitializationSettings initializationSettings = InitializationSettings(
  //     android: initializationSettingsAndroid,
  //     iOS: null,
  //     macOS: null,
  //   );
  //
  //   await localNotifications.initialize(
  //     initializationSettings,
  //     onSelectNotification: selectNotification,
  //   );
  // }

  Future<void> sendNotification(int value) async {
    var androidDetails = const AndroidNotificationDetails(
        'channel id',
        'channel name',
        importance: Importance.defaultImportance,
        onlyAlertOnce: true,
        priority: Priority.defaultPriority
    );

    var details = NotificationDetails(
      android: androidDetails,
    );

    // 檢查讀到的值，發送相應的通知
    String notificationText = 'Unknown Value';

    if (value == 0) {
      notificationText = 'Everything is fine';
    } else if (value == 1) {
      notificationText = 'Stop scratching!';
    }

    localNotification.show(
      0,
      'Scritch',
      notificationText,
      details,
    );

    // localNotification.show(
    //     DateTime.now().millisecondsSinceEpoch >> 10,
    //     '訊息標題',
    //     '訊息內容',
    //     details  //剛才的訊息通知規格變數
    // );
  }

  Future<void> selectNotification(String? payload) async {
    // 點擊通知時的回調
    print('Notification clicked');
  }

  void addToBuffer(List<int>? value) {
    if (value != null && value.isNotEmpty) {
      // 使用 DateFormat 格式化當前時間
      final formattedTime = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

      // 將資料添加到 buffer
      dataBuffer.add({
        "result": value[0] == 1 ? "body" : "neutral",
        "time": formattedTime,
      });
      // print(dataBuffer);

      // 如果 buffer 超過 30 筆，則送出數據並清空 buffer
      if (dataBuffer.length >= 30) {
        sendDataToApi(dataBuffer);
        dataBuffer.clear();
      }
    }
  }

  Future<void> sendDataToApi(List<Map<String, dynamic>> data) async {
    final url = Uri.parse('https://tzuhsun.online/api/1.0/influxdb');

    // 準備要發送的資料
    final payload = {
      "data": data,
      "device": "7414",
    };

    // 將資料轉換為 JSON 格式
    final jsonData = json.encode(payload);

    print(jsonData);

    try {
      // 發送 HTTP POST 請求
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonData,
      );

      // 檢查伺服器回應
      if (response.statusCode == 200) {
        print('Data sent successfully.');

      } else {
        print('Failed to send data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending data: $e');
    }
  }
}

class ValueDisplayWidget extends StatelessWidget {
  final List<int> characteristicValues;
  final List<int> allValues;

  const ValueDisplayWidget({
    Key? key,
    required this.characteristicValues,
    required this.allValues,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double scratchingPercentage = calculateScratchingPercentage();

    String statusMessage = ''; // 預設訊息為空字串
    if (characteristicValues.isNotEmpty) {
      if (characteristicValues[0] == 0) {
      } else if (characteristicValues[0] == 1) {
        statusMessage = 'Stop scratching!'; // 設置為 "Stop scratching!"
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Scritch'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: characteristicValues.isNotEmpty
                    ? characteristicValues[0] == 0
                    ? Colors.green
                    : Colors.red
                    : Colors.transparent,
                shape: BoxShape.rectangle,
              ),
            ),
            SizedBox(height: 20),
            Text(
              statusMessage,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            // 圓餅圖
            Container(
              width: 200, // 這裡可以根據需求調整大小
              height: 200,
              child: PieChart(
                PieChartData(
                  borderData: FlBorderData(
                    show: false, // 這裡設定為 false 來隱藏周圍的邊框
                  ),
                  sections: [
                    PieChartSectionData(
                      showTitle: true,
                      titlePositionPercentageOffset: 0.5, // 調整標題位置
                      color: Colors.red,
                      value: scratchingPercentage,
                      title: '${scratchingPercentage.toStringAsFixed(2)}%',
                      titleStyle: TextStyle(color: Colors.black), // 設定字體顏色
                    ),
                    PieChartSectionData(
                      showTitle: true,
                      titlePositionPercentageOffset: 0.5, // 調整標題位置
                      color: Colors.green,
                      value: 100 - scratchingPercentage,
                      title: '${(100 - scratchingPercentage).toStringAsFixed(2)}%',
                      titleStyle: TextStyle(color: Colors.black), // 設定字體顏色
                    ),
                  ],
                  sectionsSpace: 0,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // @override
  // Widget build(BuildContext context) {
  //   String statusMessage = ''; // 預設訊息為空字串
  //   double scratchingPercentage = calculateScratchingPercentage();
  //
  //   String titleText = scratchingPercentage == 0.0
  //       ? 'Not Scratching'
  //       : 'Scratching: ${scratchingPercentage.toStringAsFixed(2)}%';
  //
  //   if (characteristicValues.isNotEmpty) {
  //     if (characteristicValues[0] == 0) {
  //     } else if (characteristicValues[0] == 1) {
  //       statusMessage = 'Stop scratching!'; // 設置為 "Stop scratching!"
  //     }
  //   }
  //
  //   return Scaffold(
  //     appBar: AppBar(
  //       title: Text(titleText),
  //     ),
  //     body: Center(
  //       child: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: [
  //           Container(
  //             width: 150,
  //             height: 150,
  //             decoration: BoxDecoration(
  //               color: characteristicValues.isNotEmpty
  //                   ? characteristicValues[0] == 0
  //                   ? Colors.green
  //                   : Colors.red
  //                   : Colors.transparent,
  //               shape: BoxShape.rectangle,
  //             ),
  //           ),
  //           SizedBox(height: 20),
  //           Text(
  //             statusMessage,
  //             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  double calculateScratchingPercentage() {
    if (allValues.isEmpty) {
      return 0.0;
    }

    int scratchingCount = allValues.where((value) => value == 1).length;
    return (scratchingCount / allValues.length) * 100.0;
  }
}
