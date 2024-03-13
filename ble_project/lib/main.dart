import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ShowStatus.dart';

class BleController extends GetxController {
  FlutterBlue ble = FlutterBlue.instance;
  RxBool scanning = false.obs;
  RxList<ScanResult> scanResultsList = <ScanResult>[].obs;

  Future<void> scanDevices() async {
    if (!scanning.value) {
      if (await Permission.bluetoothScan.request().isGranted &&
          await Permission.bluetoothConnect.request().isGranted) {
        ble.startScan();
        scanning.value = true;

        // 将 scanResultsList 设置为 ble.scanResults 的监听
        ble.scanResults.listen((List<ScanResult> results) {
          scanResultsList.assignAll(results);
        });
      }
    } else {
      ble.stopScan();
      scanning.value = false;
      // 清空 scanResultsList
      clearScanResults();
    }
  }

  void clearScanResults() {
    scanResultsList.clear();
  }

  Stream<List<ScanResult>> get scanResults => scanResultsList.stream;
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late BuildContext myContext;

  @override
  Widget build(BuildContext context) {
    myContext = context;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text("Scritch")),
      body: GetBuilder<BleController>(
        init: BleController(),
        builder: (BleController controller) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder<List<ScanResult>>(
                    stream: controller.scanResults,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final filteredData = snapshot.data!
                            .where((result) => result.device.name.isNotEmpty)
                            .toList();

                        filteredData.sort((a, b) => b.rssi - a.rssi);

                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredData.length,
                          // separatorBuilder: (context, index) => Divider(), // 分隔符
                          itemBuilder: (context, index) {
                            final data = filteredData[index];
                            return Card(
                              elevation: 2,
                              child: ListTile(
                                title: Text(data.device.name),
                                subtitle: Text(data.device.id.id),
                                trailing: Text(data.rssi.toString()),
                                onTap: () {
                                  // 在这里执行连接操作
                                  connectToDevice(data.device);
                                },
                              ),
                            );
                          },
                        );
                      } else {
                        return const Center(child: Text("No device found."));
                      }
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    controller.scanDevices();
                    if (!controller.scanning.value) {
                      controller.clearScanResults();
                    }
                    // Future.delayed(Duration(seconds: 1), () {
                    //   print("Scanning status: ${controller.scanning.value}");
                    // });
                  },
                  child: Obx(() {
                    return Text(controller.scanning.value ? "Stop Scanning" : "Start Scanning");
                  }),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  void connectToDevice(BluetoothDevice device) async {
    try {
      await device.state
          .firstWhere((state) {
        print('Device state: $state');
        return state == BluetoothDeviceState.disconnected;
      });

      await device.connect(); // 这里是示例，具体操作取决于您的库和设备
      Navigator.of(myContext).push(
        MaterialPageRoute(
          builder: (context) => ShowStatus(device: device),
        ),
      );

      print('Connected to ${device.name}');
      List<BluetoothService> services = await device.discoverServices();

      for (var service in services) {
        print('$service');
      }

      // 连接成功后，您可以执行其他操作，或者导航到新的页面等
    } catch (e) {
      print('Connection failed: $e');
      // 处理连接失败的情况，例如显示错误消息
    }
  }
}


