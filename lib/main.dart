import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: BlocProvider(
        create: (_) => PersonsBloc(),
        child: const HomePage(),
      ),
    );
  }
}

@immutable
abstract class LoadAction {
  const LoadAction();
}

@immutable
class LoadPersonAction implements LoadAction {
  final PersonUrl url;

  const LoadPersonAction({required this.url}) : super();
}

enum PersonUrl { persons1, persons2 }

extension UrlString on PersonUrl {
  String get urlString {
    switch (this) {
      case PersonUrl.persons1:
        return 'http://10.0.2.2:5500/api/person1.json';
      case PersonUrl.persons2:
        return 'http://10.0.2.2:5500/api/person2.json';
    }
  }
}

@immutable
class Person {
  final String name;
  final int age;

  const Person({required this.name, required this.age});

  Person.fromJson(Map<String, dynamic> json)
      : name = json['name'] as String,
        age = json['age'] as int;
}

Future<Iterable<Person>> getPersons(String url) => HttpClient()
    .getUrl(Uri.parse(url))
    .then((req) => req.close())
    .then((res) => res.transform(utf8.decoder).join())
    .then((str) => json.decode(str) as List<dynamic>)
    .then((list) => list.map((e) => Person.fromJson(e)));

@immutable
class FetchResult {
  final Iterable<Person> persons;
  final bool isRetrievedFromCache;

  const FetchResult(
      {required this.persons, required this.isRetrievedFromCache});
  @override
  String toString() =>
      'FetchResult(Is RetrievedFromCache = $isRetrievedFromCache, persons = $persons)';
}

class PersonsBloc extends Bloc<LoadAction, FetchResult?> {
  final Map<PersonUrl, Iterable<Person>> _cache = {};
  PersonsBloc() : super(null) {
    on<LoadPersonAction>(
      (event, emit) async {
        final url = event.url;
        if (_cache.containsKey(url)) {
          final cachedPersons = _cache[url];
          final result =
              FetchResult(persons: cachedPersons!, isRetrievedFromCache: true);
          emit(result);
        } else {
          final persons = await getPersons(url.urlString);
          _cache[url] = persons;
          final result =
              FetchResult(persons: persons, isRetrievedFromCache: false);
          emit(result);
        }
      },
    );
  }
}

extension Subscript<T> on Iterable<T> {
  T? operator [](int index) => length > index ? elementAt(index) : null;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Home Page'),
        ),
        body: Column(
          children: [
            Row(
              children: [
                TextButton(
                    onPressed: () {
                      context
                          .read<PersonsBloc>()
                          .add(const LoadPersonAction(url: PersonUrl.persons1));
                    },
                    child: const Text('Load json 1')),
                TextButton(
                    onPressed: () {
                      const LoadPersonAction(url: PersonUrl.persons2);
                    },
                    child: const Text('Load json 2'))
              ],
            ),
            BlocBuilder<PersonsBloc, FetchResult?>(
                buildWhen: (previousResult, currentResult) {
              return previousResult?.persons != currentResult?.persons;
            }, builder: (context, fetchResult) {
              final persons = fetchResult?.persons;
              if (persons == null) {
                return const SizedBox();
              }
              return Expanded(
                child: ListView.builder(
                  itemBuilder: (context, index) {
                    final person = persons[index]!;
                    return ListTile(
                      title: Text(person.name),
                    );
                  },
                  itemCount: persons.length,
                ),
              );
            })
          ],
        ));
  }
}
