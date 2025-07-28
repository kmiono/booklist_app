import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
      home: const BookListApp(),
    );
  }
}

class BookListApp extends StatefulWidget {
  const BookListApp({super.key});

  @override
  State<BookListApp> createState() => _BookListAppState();
}

class _BookListAppState extends State<BookListApp> {
  int _currentIndex = 0;
  final List<Widget> _pages = [const BookListPage(), const FavoritesPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.book), label: '本リスト'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'お気に入り'),
        ],
      ),
    );
  }
}

class BookListPage extends StatefulWidget {
  const BookListPage({super.key});

  @override
  State<BookListPage> createState() => _BookListPageState();
}

class _BookListPageState extends State<BookListPage> {
  List items = [];
  bool isLoading = true;
  String? errorMessage;
  Set<String> favoriteIds = {};

  @override
  void initState() {
    super.initState();
    getData();
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      favoriteIds = prefs.getStringList('favorites')?.toSet() ?? {};
    });
  }

  Future<void> toggleFavorite(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (favoriteIds.contains(bookId)) {
        favoriteIds.remove(bookId);
      } else {
        favoriteIds.add(bookId);
      }
    });
    await prefs.setStringList('favorites', favoriteIds.toList());
  }

  Future<void> getData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      var response = await http.get(
        Uri.https('www.googleapis.com', '/books/v1/volumes', {
          'q': 'flutter',
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('BookList'),
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
                final bookId = item['id'] ?? '';

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
                        trailing: IconButton(
                          icon: Icon(
                            favoriteIds.contains(bookId)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: favoriteIds.contains(bookId)
                                ? Colors.red
                                : null,
                          ),
                          onPressed: () => toggleFavorite(bookId),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List favoriteItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteIds = prefs.getStringList('favorites') ?? [];

    if (favoriteIds.isEmpty) {
      setState(() {
        favoriteItems = [];
        isLoading = false;
      });
      return;
    }

    // お気に入りの本の詳細情報を取得
    List loadedFavorites = [];
    for (String bookId in favoriteIds) {
      try {
        var response = await http.get(
          Uri.https('www.googleapis.com', '/books/v1/volumes/$bookId'),
        );

        if (response.statusCode == 200) {
          var bookData = jsonDecode(response.body);
          loadedFavorites.add(bookData);
        }
      } catch (e) {
        print('Error loading book $bookId: $e');
      }
    }

    setState(() {
      favoriteItems = loadedFavorites;
      isLoading = false;
    });
  }

  Future<void> removeFavorite(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteIds = prefs.getStringList('favorites') ?? [];
    favoriteIds.remove(bookId);
    await prefs.setStringList('favorites', favoriteIds);

    setState(() {
      favoriteItems.removeWhere((item) => item['id'] == bookId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('お気に入り'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : favoriteItems.isEmpty
          ? const Center(child: Text('お気に入りの本がありません'))
          : ListView.builder(
              itemCount: favoriteItems.length,
              itemBuilder: (BuildContext context, int index) {
                final item = favoriteItems[index];
                final volumeInfo = item['volumeInfo'] ?? {};
                final imageLinks = volumeInfo['imageLinks'] ?? {};
                final bookId = item['id'] ?? '';

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
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => removeFavorite(bookId),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
