import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:flutter/material.dart';
import 'package:rinf/rinf.dart';
import 'package:system_theme/system_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'datapicker.dart';
import 'messages/basic.pb.dart';
import 'messages/generated.dart';

const title = "汇丰信用卡账单计算器";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemTheme.fallbackColor = const Color.fromARGB(255, 200, 83, 227);
  await SystemTheme.accentColor.load();

  await initializeRust(assignRustSignal);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLifecycleListener _listener;

  final accentColor = SystemTheme.accentColor.accent;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onExitRequested: () async {
        finalizeRust(); // Shut down the `tokio` Rust runtime.
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: accentColor),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: accentColor, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      // 配置支持的本地化
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'), // 添加中文支持
        Locale('en', 'US'), // 默认支持英语
      ],
      home: Scaffold(
        appBar: AppBar(
          title: const Text(title),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // 垂直居中
            crossAxisAlignment: CrossAxisAlignment.center, // 水平居中
            children: [
              const Column(
                children: [
                  Text(
                    "计算费用区间",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  DatePickerFieldsLayout(),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(30.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton.extended(
                      onPressed: () async {
                        FilePickerResult? result =
                            await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['csv'],
                        );
                        if (result != null && result.files.isNotEmpty) {
                          final Uint8List bytes;
                          if (result.files.first.bytes != null) {
                            bytes = result.files.first.bytes!;
                          } else {
                            final file = File(result.files.first.path!);
                            bytes = await file.readAsBytes();
                          }

                          CsvData().sendSignalToRust(bytes);
                        }
                      },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('计算账单文件'),
                    ),
                  ],
                ),
              ),
              StreamBuilder(
                stream: CalulateResponse.rustSignalStream,
                builder: (context, snapshot) {
                  final rustSignal = snapshot.data;
                  if (rustSignal == null) {
                    return const Text("等待计算结果", style: TextStyle(fontSize: 24));
                  }
                  final response = rustSignal.message;
                  final text = response.result;
                  if (response.status == Status.OK) {
                    return Text(
                      text,
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.green,
                      ),
                    );
                  } else {
                    return Text(
                      text,
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
