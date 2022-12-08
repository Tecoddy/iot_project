import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:iot_app/map_view.dart';
import 'package:sliding_clipped_nav_bar/sliding_clipped_nav_bar.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  final FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
  final List<BluetoothDevice> devicesList = <BluetoothDevice>[];
  final Map<Guid, List<int>> readValues = <Guid, List<int>>{};

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _writeController = TextEditingController();
  BluetoothDevice? _connectedDevice;
  List<BluetoothService> _services = [];
  double _value = 125;

  _addDeviceTolist(final BluetoothDevice device) {
    if (!widget.devicesList.contains(device) & (device.name != '')) {
      setState(() {
        widget.devicesList.add(device);
      });
    }
  }

  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.flutterBlue.connectedDevices
        .asStream()
        .listen((List<BluetoothDevice> devices) {
      for (BluetoothDevice device in devices) {
        _addDeviceTolist(device);
      }
    });
    widget.flutterBlue.scanResults.listen((List<ScanResult> results) {
      for (ScanResult result in results) {
        _addDeviceTolist(result.device);
      }
    });
    widget.flutterBlue.startScan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          children: [
            Text("Horizhon",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Container(
              width: 20,
            ),
            Image.asset("images/pngegg.png", width: 150),
          ],
        ),
        actions: [
          IconButton(
              onPressed: () => _connectedDevice = null,
              icon: Icon(Icons.logout))
        ],
      ),
      body: _buildView(),
    );
  }

  ListView _buildListViewOfDevices() {
    List<Widget> containers = <Widget>[];
    containers.add(Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(height: 20),
        Center(
            child: Text("Connectez vous à la carte Arduino :",
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 20))),
        Container(height: 100)
      ],
    ));
    for (BluetoothDevice device in widget.devicesList) {
      containers.add(
        SizedBox(
          height: 50,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(device.name == '' ? '(unknown device)' : device.name),
                    Text(device.id.toString()),
                  ],
                ),
              ),
              TextButton(
                child: const Text(
                  'Connect',
                  style: TextStyle(color: Colors.blue),
                ),
                onPressed: () async {
                  widget.flutterBlue.stopScan();
                  try {
                    await device.connect();
                  } on PlatformException catch (e) {
                    if (e.code != 'already_connected') {
                      rethrow;
                    }
                  } finally {
                    _services = await device.discoverServices();
                  }
                  setState(() {
                    _connectedDevice = device;
                  });
                },
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        ...containers,
      ],
    );
  }

  Widget _buildView() {
    if (_connectedDevice != null) {
      return connectedDevice();
    }
    return _buildListViewOfDevices();
  }

  Widget connectedDevice() {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        body: display(),
        bottomNavigationBar: ClipRRect(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(40), bottom: Radius.circular(40)),
            child: SlidingClippedNavBar.colorful(
                backgroundColor: Colors.blue,
                onButtonPressed: (index) {
                  setState(() {
                    selectedIndex = index;
                  });
                },
                iconSize: 30,
                selectedIndex: selectedIndex,
                barItems: [
                  BarItem(
                    icon: Icons.home,
                    title: 'Navigation',
                    activeColor: Colors.white,
                    inactiveColor: Colors.white,
                  ),
                  BarItem(
                    icon: Icons.settings,
                    title: 'Sensibilité',
                    activeColor: Colors.white,
                    inactiveColor: Colors.white,
                  ),
                ])));
  }

  Widget display() {
    if (selectedIndex == 0) {
      return _buildConnectDeviceView();
    }
    return _params();
  }

  Widget _params() {
    return Container(
      child: Column(children: [
        Container(height: 200),
        Slider(
          min: 50.0,
          max: 255.0,
          value: _value,
          onChanged: (value) {
            setState(() {
              _value = value;
            });
          },
        ),
        Container(height: 100),
        ElevatedButton(
            onPressed: () {
              for (BluetoothService service in _services) {
                for (BluetoothCharacteristic characteristic
                    in service.characteristics) {
                  if (characteristic.properties.write) {
                    characteristic.write([this._value.toInt()]);
                  }
                }
              }
            },
            child: Container(
                width: 75,
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text("Send"),
                  Container(
                    width: 10,
                  ),
                  Icon(
                    Icons.send,
                    color: Colors.white,
                  )
                ])))
      ]),
    );
  }

  Widget _buildConnectDeviceView() {
    for (BluetoothService service in _services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.write) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Stack(
              children: <Widget>[MapView(), crossButtons(characteristic)],
            ),
          );
        }
      }
    }
    return Text("No Write service found");
  }

  Widget crossButtons(BluetoothCharacteristic characteristic) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flex(
              direction: Axis.horizontal,
              children: [
                Center(
                    child: ElevatedButton(
                  onPressed: () {
                    characteristic.write([0]);
                  },
                  child: Icon(Icons.arrow_drop_up),
                  style: ButtonStyle(
                    shape: MaterialStateProperty.all(CircleBorder()),
                    padding: MaterialStateProperty.all(EdgeInsets.all(15)),
                    backgroundColor: MaterialStateProperty.all(
                        Colors.blue), // <-- Button color
                    overlayColor:
                        MaterialStateProperty.resolveWith<Color?>((states) {
                      if (states.contains(MaterialState.pressed))
                        return Colors.red; // <-- Splash color
                    }),
                  ),
                ))
              ],
            ),
          ],
        ),
        Container(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
                child: ElevatedButton(
              onPressed: () {
                characteristic.write([1]);
              },
              child: Icon(Icons.arrow_left),
              style: ButtonStyle(
                shape: MaterialStateProperty.all(CircleBorder()),
                padding: MaterialStateProperty.all(EdgeInsets.all(15)),
                backgroundColor:
                    MaterialStateProperty.all(Colors.blue), // <-- Button color
                overlayColor:
                    MaterialStateProperty.resolveWith<Color?>((states) {
                  if (states.contains(MaterialState.pressed))
                    return Colors.red; // <-- Splash color
                }),
              ),
            )),
            Container(width: 70),
            Center(
                child: ElevatedButton(
              onPressed: () {
                characteristic.write([2]);
              },
              child: Icon(Icons.arrow_right),
              style: ButtonStyle(
                shape: MaterialStateProperty.all(CircleBorder()),
                padding: MaterialStateProperty.all(EdgeInsets.all(15)),
                backgroundColor:
                    MaterialStateProperty.all(Colors.blue), // <-- Button color
                overlayColor:
                    MaterialStateProperty.resolveWith<Color?>((states) {
                  if (states.contains(MaterialState.pressed))
                    return Colors.red; // <-- Splash color
                }),
              ),
            ))
          ],
        ),
        Container(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
                child: ElevatedButton(
              onPressed: () {
                characteristic.write([3]);
              },
              child: Icon(Icons.arrow_drop_down),
              style: ButtonStyle(
                shape: MaterialStateProperty.all(CircleBorder()),
                padding: MaterialStateProperty.all(EdgeInsets.all(15)),
                backgroundColor:
                    MaterialStateProperty.all(Colors.blue), // <-- Button color
                overlayColor:
                    MaterialStateProperty.resolveWith<Color?>((states) {
                  if (states.contains(MaterialState.pressed))
                    return Colors.red; // <-- Splash color
                }),
              ),
            )),
          ],
        ),
        Container(height: 20),
      ],
    );
  }
}
