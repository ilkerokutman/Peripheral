import 'dart:async';
import 'dart:io';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: ThemeMode.dark,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ValueNotifier<BluetoothLowEnergyState> state;
  late final ValueNotifier<bool> advertising;
  late final ValueNotifier<List<String>> logs;
  late final StreamSubscription stateChangedSubscription;
  late final StreamSubscription characteristicReadSubscription;
  late final StreamSubscription characteristicWrittenSubscription;
  late final StreamSubscription characteristicNotifyStateChangedSubscription;
  bool permissionStatus = false;

  Uuid uuid = const Uuid();
  late UUID heethingsId;
  final cUuid1 = UUID.short(200);
  final cUuid2 = UUID.short(201);
  final cUuid3 = UUID.short(202);
  final cUuid4 = UUID.short(203);
  final cUuid5 = UUID.short(204);
  int manSpecificDataId = 0x2e19;
  int sampleInt1 = 0x10;
  int sampleInt2 = 0x20;
  int sampleInt3 = 0x30;

  @override
  void initState() {
    super.initState();
    heethingsId = UUID.fromString(uuid.v5(Uuid.NAMESPACE_URL, 'heethings.com'));

    state = ValueNotifier(BluetoothLowEnergyState.unknown);
    advertising = ValueNotifier(false);
    logs = ValueNotifier([]);
    stateChangedSubscription = PeripheralManager.instance.stateChanged.listen(
      (eventArgs) {
        state.value = eventArgs.state;
      },
    );

    characteristicReadSubscription =
        PeripheralManager.instance.characteristicRead.listen(
      (eventArgs) {
        final central = eventArgs.central;
        final characteristic = eventArgs.characteristic;
        final value = eventArgs.value;
        setState(() {
          logs.value.insert(
              0,
              "READ: ${DateTime.now().toIso8601String()}\n"
              "C:$central, c: $characteristic, v: $value");
        });
      },
    );

    characteristicWrittenSubscription =
        PeripheralManager.instance.characteristicWritten.listen(
      (eventArgs) {
        final central = eventArgs.central;
        final characteristic = eventArgs.characteristic;
        final value = eventArgs.value;
        setState(() {
          logs.value.insert(
              0,
              "WRITE: ${DateTime.now().toIso8601String()}\n"
              "C:$central, c: $characteristic, v: $value");
        });
      },
    );

    characteristicNotifyStateChangedSubscription =
        PeripheralManager.instance.characteristicNotifyStateChanged.listen(
      (eventArgs) async {
        final central = eventArgs.central;
        final characteristic = eventArgs.characteristic;
        final state = eventArgs.state;
        setState(() {
          logs.value.insert(
              0,
              "NOTIFY: ${DateTime.now().toIso8601String()}\n"
              "C:$central, c: $characteristic, s: $state");
        });

        if (state) {
          final elements = List.generate(2000, (index) => index % 256);
          final value = Uint8List.fromList(elements);
          await PeripheralManager.instance.writeCharacteristic(
            characteristic,
            value: value,
            central: central,
          );
        }
      },
    );

    _initialize();
  }

  void _initialize() async {
    await PeripheralManager.instance.setUp();
    state.value = await PeripheralManager.instance.getState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          ValueListenableBuilder(
            valueListenable: state,
            builder: (context, state, child) => ValueListenableBuilder(
              valueListenable: advertising,
              builder: (context, advertising, child) => TextButton(
                onPressed: state == BluetoothLowEnergyState.poweredOn
                    ? () async {
                        if (advertising) {
                          await stopAdvertising();
                        } else {
                          await startAdvertising();
                        }
                      }
                    : null,
                child: Text(advertising ? 'END' : 'BEGIN'),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          ListTile(
            title: Text('ID'),
            subtitle: Text('$heethingsId'),
          ),
          ListTile(
            title: Text('ManufacturerSpecificData: ID'),
            subtitle: Text('$manSpecificDataId'),
          ),
          ListTile(
            title: Text('AdvertisementData'),
            subtitle: Text('$sampleInt1\n$sampleInt2\n$sampleInt3'),
            isThreeLine: true,
          ),
          Divider(),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: logs,
              builder: (context, logs, child) => ListView.builder(
                itemBuilder: (context, i) => Text(logs[i]),
                itemCount: logs.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> startAdvertising() async {
    await PeripheralManager.instance.clearServices();
    final elements = List.generate(1000, (index) => index % 256);
    final value = Uint8List.fromList(elements);
    final service = GattService(
      uuid: heethingsId,
      characteristics: [
        GattCharacteristic(
            uuid: cUuid1,
            properties: [GattCharacteristicProperty.read],
            value: value,
            descriptors: []),
        GattCharacteristic(
            uuid: cUuid2,
            properties: [
              GattCharacteristicProperty.write,
              GattCharacteristicProperty.writeWithoutResponse,
            ],
            value: Uint8List.fromList([]),
            descriptors: []),
        GattCharacteristic(
            uuid: cUuid3,
            properties: [
              GattCharacteristicProperty.notify,
              GattCharacteristicProperty.indicate
            ],
            value: Uint8List.fromList([]),
            descriptors: []),
        GattCharacteristic(
            uuid: cUuid4,
            properties: [GattCharacteristicProperty.notify],
            value: Uint8List.fromList([]),
            descriptors: []),
        GattCharacteristic(
            uuid: cUuid5,
            properties: [GattCharacteristicProperty.indicate],
            value: Uint8List.fromList([]),
            descriptors: []),
      ],
    );

    await PeripheralManager.instance.addService(service);
    final advertisement = Advertisement(
      name: Platform.isAndroid ? "HEETHINGS" : "HEETHINGS iPadOs",
      manufacturerSpecificData: ManufacturerSpecificData(
        id: manSpecificDataId,
        data: Uint8List.fromList([sampleInt1, sampleInt2, sampleInt3]),
      ),
    );

    await PeripheralManager.instance.startAdvertising(advertisement);
    advertising.value = true;
  }

  Future<void> stopAdvertising() async {
    await PeripheralManager.instance.stopAdvertising();
    advertising.value = false;
  }

  @override
  void dispose() {
    super.dispose();
    stateChangedSubscription.cancel();
    characteristicNotifyStateChangedSubscription.cancel();
    characteristicReadSubscription.cancel();
    characteristicWrittenSubscription.cancel();
    state.dispose();
    advertising.dispose();
    logs.dispose();
  }
}
