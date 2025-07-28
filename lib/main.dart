import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BookList App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'BookList'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List items = [];
  bool isLoading = true;
  String? errorMessage;

  Future<void> getData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      var response = await http.get(
        Uri.https('www.googleapis.com', '/books/v1/volumes', {
          'q': 'flutter', // 中括弧を削除
          'maxResults': '40',
          'langRestrict': 'ja',
        }),
      );

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);

        setState(() {
          items = jsonResponse['items'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'データの取得に失敗しました: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'エラーが発生しました: $e';
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    getData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text(errorMessage!))
          : items.isEmpty
          ? const Center(child: Text('本が見つかりませんでした'))
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (BuildContext context, int index) {
                final item = items[index];
                final volumeInfo = item['volumeInfo'] ?? {};
                final imageLinks = volumeInfo['imageLinks'] ?? {};

                return Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: imageLinks['thumbnail'] != null
                            ? Image.network(
                                imageLinks['thumbnail'],
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.book);
                                },
                              )
                            : const Icon(Icons.book),
                        title: Text(volumeInfo['title'] ?? 'タイトルなし'),
                        subtitle: Text(volumeInfo['publishedDate'] ?? '出版日不明'),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
