import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'dart:async'; // 导入dart:async库

class DeviceDetailPage extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceDetailPage({Key? key, required this.device}) : super(key: key);

  @override
  _DeviceDetailPageState createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  BluetoothCharacteristic? myCharacteristic;
  late Timer _readTimer; // 添加定时器变量

  @override
  void initState() {
    super.initState();
    subscribeToCharacteristic();
    // 设置定时器，每隔5秒读取一次Characteristic的值
    _readTimer = Timer.periodic(Duration(milliseconds: 500), (Timer timer) {
      readCharacteristicValue();
    });
  }

  @override
  void dispose() {
    if (myCharacteristic != null) {
      myCharacteristic!.setNotifyValue(false);
    }
    // 在页面销毁时断开连接
    widget.device.disconnect();
    // 取消定时器
    _readTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Device Details'),
      ),
      body: SingleChildScrollView( // 使用SingleChildScrollView包装Column
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Device Name: ${widget.device.name}'),
              Text('Device ID: ${widget.device.id.id}'),
              SizedBox(height: 20),
              Text(
                'Discovered Services:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              FutureBuilder<List<BluetoothService>>(
                future: widget.device.discoverServices(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else if (snapshot.hasData) {
                    List<BluetoothService> services = snapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: services.map((service) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Service UUID: ${service.uuid}'),
                            SizedBox(height: 8),
                            Text(
                              'Characteristics:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: service.characteristics.map((characteristic) {
                                return Text('- ${characteristic.uuid}');
                              }).toList(),
                            ),
                            Divider(),
                          ],
                        );
                      }).toList(),
                    );
                  } else {
                    return Text('No services found.');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 添加读取Characteristic值的方法
  Future<void> readCharacteristicValue() async {
    try {
      if (myCharacteristic != null) {
        List<int>? value = await myCharacteristic!.read();
        print('Read value: $value');
      }
    } catch (e) {
      print('Error reading characteristic value: $e');
      // 处理错误
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
            // myCharacteristic!.value.listen((List<int>? value) {
            //   // 处理接收到的值
            //   print('Received value: ${value}');
            // });
            return; // 订阅成功，退出方法
          }
        }
      }
      // 如果走到这里，说明找不到特定的Characteristic
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('Characteristic not found. Disconnecting...'),
            actions: <Widget>[
              TextButton(
                onPressed: () async {
                  // 断开连接
                  await widget.device.disconnect();
                  Navigator.of(context).pop(); // 关闭对话框
                  Navigator.of(context).pop(); // 返回上一页
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('Error subscribing to characteristic: $e');
      // 处理错误
    }
  }
}
