import 'dart:io';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdftron_flutter/pdftron_flutter.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseStorage storage = FirebaseStorage.instance;
  String downloading = '';
  String downloadingProgress = '';
  String root;
  Box box;
  String _version = '';

  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    initPlatformState();
    getApplicationDocumentsDirectory().then((dir) {
      root = dir.path;
      root = dir.path;
      Hive.init('$root/hive');
      Hive.openBox('testBox').then((openBox) {
        box = openBox;
        setState(() {});
      });
    });
  }

  Future<void> initPlatformState() async {
    String version;
    try {
      PdftronFlutter.initialize(
          "");
      version = await PdftronFlutter.version;
    } on PlatformException {
      version = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _version = version;
    });
  }

  void downloadFilesFrom(DocumentSnapshot doc) async {
    setState(() {
      downloading = doc.documentID;
    });
    String docPath = "$root/files/${doc.documentID}";
    String mainDoc = doc.data["rootDoc"]["name"];
    String mainDocRef = doc.data["rootDoc"]["path"];

    int docCount = doc.data["additionalDocs"].length + 1;
    int downloadingCount = 1;
    setState(() {
      downloadingProgress = "Downloading $downloadingCount/$docCount";
    });

    //Time to download

    Directory docDir = await Directory(docPath).create(recursive: true);
    print(docDir.path);
    String mainDocPath = "$docPath/$mainDoc";

    await _downloadFile(
        await FirebaseStorage.instance.getReferenceFromUrl(mainDocRef),
        mainDocPath);

    List<dynamic> docs = doc.data["additionalDocs"];

    for (var i = 0; i < docs?.length ?? 0; i++) {
      setState(() {
        downloadingProgress = "Downloading ${++downloadingCount}/$docCount";
      });
      String filePath = "$docPath/${docs[i]["name"]}";
      Uri uri = Uri.parse(filePath);
      await Directory(uri.pathSegments
              .sublist(0, uri.pathSegments.length - 1)
              .join("/"))
          .create(recursive: true);
      await _downloadFile(
          await FirebaseStorage.instance.getReferenceFromUrl(docs[i]["path"]),
          filePath);
    }
    box.put(doc.documentID, mainDocPath);
    setState(() {
      downloading = '';
      downloadingProgress = '';
    });

    print("Dir:");
    listDir(docDir);
  }

  void listDir(Directory dir) {
    List contents = dir.listSync();
    for (var fileOrDir in contents) {
      if (fileOrDir is File) {
        print("Path: ${fileOrDir.path}");
      } else if (fileOrDir is Directory) {
        print("Dir: ${fileOrDir.path}");
        listDir(fileOrDir);
      }
    }
  }

  Future<void> _downloadFile(StorageReference ref, String pathToSave) async {
    print(ref.path);
    final File tempFile = File(pathToSave);
    if (tempFile.existsSync()) {
      await tempFile.delete();
    }
    await tempFile.create();

    final StorageFileDownloadTask task = ref.writeToFile(tempFile);
    await task.future;
    final String name = await ref.getName();
    final String bucket = await ref.getBucket();
    final String path = await ref.getPath();
    _scaffoldKey.currentState.hideCurrentSnackBar();
    _scaffoldKey.currentState.showSnackBar(SnackBar(
      content: Text(
        'Success!\nDownloaded $name \nFrom bucket: $bucket\n'
        'From path: $path \n',
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("PDF Demo"),
      ),
      backgroundColor: Colors.grey.shade200,
      body: StreamBuilder<QuerySnapshot>(
        stream: Firestore.instance.collection('books').snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) return new Text('Error: ${snapshot.error}');
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return new Text('Loading...');
            default:
              if (box == null) return new Text('Loading...');

              return new ListView(
                children:
                    snapshot.data.documents.map((DocumentSnapshot document) {
                  String pathToDocument = box.get(document.documentID);
                  return Container(
                    color: Colors.white,
                    margin: const EdgeInsets.all(8.0),
                    child: new ListTile(
                      title: new Text(document['name']),
                      subtitle: new Text(downloading == document.documentID
                          ? downloadingProgress
                          : pathToDocument == null
                              ? 'Not Downloaded'
                              : 'Downloaded'),
                      trailing: Container(
                        width: 72,
                        height: 24,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            if (downloading == '' && pathToDocument == null)
                              GestureDetector(
                                child: Icon(Icons.file_download),
                                onTap: () => downloadFilesFrom(document),
                              ),
                            if (downloading == '' && pathToDocument != null)
                              GestureDetector(
                                child: Icon(Icons.refresh),
                                onTap: () => downloadFilesFrom(document),
                              ),
                            if (downloading == document.documentID)
                              Container(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(),
                              ),
                            SizedBox(width: 24),
                            if (pathToDocument != null)
                              GestureDetector(
                                child: Icon(Icons.picture_as_pdf),
                                onTap: () {
                                  var config = Config();
                                  config.multiTabEnabled = true;
                                  print(pathToDocument);
                                  PdftronFlutter.openDocument(pathToDocument, config: config);
                                  // if (Platform.isAndroid) {
                                  //     PdftronFlutter.openDocument(pathToDocument, config: config);
                                  // } else {
                                  //     PdftronFlutter.openDocument(pathToDocument);
                                  // }
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
          }
        },
      ),
    );
  }
}
