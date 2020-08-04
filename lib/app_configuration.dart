library app_configuration;

import 'dart:async';
import 'dart:convert';

import 'package:cloud_logger/cloud_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/prefer_universal/io.dart';
import 'package:universal_platform/universal_platform.dart';

/// App configuration contains configurations map to setup for all other services
class AppConfiguration {
  /// Configurations map for the app
  Map<String, dynamic> configurations = new Map();

  /// Logger instance to share across services
  Logger logger;

  /// Shared preferences to save data https://pub.dev/packages/shared_preferences
  SharedPreferences prefs;

  /// Azure monitor logger output
  AzureMonitorOutput _azureOutput;

  /// All global variable and configs are setup here
  ///
  /// `asset` the json file in assets folder
  ///
  /// `configs` other configs to setup
  ///
  /// `isRelease` whether is release mode
  Future<void> initialize(
      {bool isRelease = false,
      String asset,
      Map<String, dynamic> configs}) async {
    if (asset?.isNotEmpty == true) {
      await appendAsset(asset);
    }

    if (configs != null) {
      append(configs);
    }

    prefs = await SharedPreferences.getInstance();
    var outputs = List<LogOutput>();
    _azureOutput = AzureMonitorOutput(configurations);
    if (isRelease) {
      // log to cloud on release
      outputs.add(_azureOutput);

      // In some case, we need to print the console in release as well (e.g. checking log on web release).
      // Let's set `devReleaseMode = true` to turn on the console log
      if (configurations['devReleaseMode'] == true) {
        outputs.add(ConsoleOutput());
      }
    } else {
      // log to console on debug
      outputs.add(ConsoleOutput());
    }

    logger = Logger(
        printer: isRelease ? CloudPrinter() : PrettyPrinter(),
        output: MultipleOutput(outputs));
  }

  /// Collect all crash report files saved in ios & android device
  /// `logDir` the directory contains log files
  /// The log file is a text file with following content: crashName####stacktrace
  Future<void> collectCrashReports(String logDir) async {
    if (UniversalPlatform.isAndroid || UniversalPlatform.isIOS) {
      try {
        final dir = new Directory(logDir);
        if (await dir.exists()) {
          // list all files in log dir
          var files = dir.listSync(recursive: false);
          if (files.isNotEmpty) {
            var systemInfo = await SystemAppInfo.shared.information;
            for (var entry in files) {
              // Only read the text file
              if (!entry.path.endsWith('.txt')) {
                continue;
              }

              var f = File(entry.path);
              var content = await f.readAsString();
              var map = Map<String, dynamic>.from(systemInfo);
              var parts = content.split('####');
              map['logType'] = 'critical';
              map['logName'] = parts.length == 2 ? parts[0] : 'CrashReport';
              map['logContent'] = content;
              await _azureOutput?.save(map, 'AzureMonitor');
              await f.delete();
            }
          }
        }
      } catch (e) {
        print(e);
      }
    }
  }

  /// Send all the cached logs into azure monitor
  Future<void> sendLogsToAzure() async {
    await _azureOutput.sendAllLogs();
  }

  /// Add new configurations into current
  void append(Map<String, dynamic> configs) {
    configurations.addAll(configs);
  }

  /// Add new configurations from json asset file into current
  Future<void> appendAsset(String asset) async {
    String data = await rootBundle.loadString(asset);
    var jsonResult = json.decode(data);
    append(jsonResult);
  }

  /// Record a flutter
  Future<void> recordFlutterError(FlutterErrorDetails details) async {
    logger?.wtf('runZoned error ${details.exception}', details.exception,
        details.stack);
  }

  /// Execute a function in [runZoned] and handle error logging
  ///
  /// [runZoned]:(https://api.flutter.dev/flutter/dart-async/runZoned.html)
  void executeInZoned(Function func) {
    runZoned(() {
      func();
    }, onError: (e, stackTrace) {
      logger?.wtf('runZoned error $e', e, stackTrace);
    });
  }
}
