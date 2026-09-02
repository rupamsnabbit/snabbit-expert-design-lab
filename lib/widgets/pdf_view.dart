import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:snabbit_runner/services/debug/network_inspector.dart';

class PdfViewPage extends StatefulWidget {
  final String url;

  const PdfViewPage({super.key, required this.url});

  @override
  State<PdfViewPage> createState() => _PdfViewPageState();
}

class _PdfViewPageState extends State<PdfViewPage> {
  late Future<File> _pdfFile;
  File? _file;

  @override
  void initState() {
    super.initState();
    _pdfFile = downloadPdf(widget.url);
  }

  Future<File> downloadPdf(String url) async {
    // Raw Dio (external URL — no Snabbit auth headers). Attach the debug
    // network inspector so the download still shows up in Chucker.
    final dio = Dio();
    DebugNetworkInspector.instance.attach(dio);
    final response = await dio.get(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/downloaded.pdf');
    await file.writeAsBytes(response.data);
    _file = file;
    return file;
  }

  @override
  void dispose() {
    super.dispose();
    _file?.delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Viewer'),
      ),
      body: FutureBuilder<File>(
        future: _pdfFile,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (snapshot.hasData) {
              return PDFView(
                filePath: snapshot.data!.path,
              );
            } else {
              return const Center(child: Text('No file found'));
            }
          } else {
            return const Center(child: CupertinoActivityIndicator());
          }
        },
      ),
    );
  }
}

//
//terms of use
// https://snabbit-assets.s3.ap-south-1.amazonaws.com/maestroserve_com_termsofuse.pdf
//
//partner agreement
//https://snabbit-assets.s3.ap-south-1.amazonaws.com/Maestro+Agreement+-+Clickwrap+(Clean+Version)+SP+23.05.2024.pdf
//
