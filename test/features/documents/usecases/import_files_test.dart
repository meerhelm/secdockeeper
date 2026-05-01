import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/documents/document.dart';
import 'package:secdockeeper/features/documents/document_import_service.dart';
import 'package:secdockeeper/features/documents/usecases/import_files.dart';

class _MockDocumentImportService extends Mock implements DocumentImportService {}

class _FakeFile extends Fake implements File {}

Document _doc() => Document(
      id: 1,
      uuid: 'u',
      originalName: 'n',
      mimeType: null,
      size: 0,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFile());
    registerFallbackValue(Uint8List(0));
  });

  late _MockDocumentImportService importer;

  setUp(() {
    importer = _MockDocumentImportService();
  });

  test('routes inputs with bytes through importBytes', () async {
    when(() => importer.importBytes(
          bytes: any(named: 'bytes'),
          originalName: any(named: 'originalName'),
        )).thenAnswer((_) async => _doc());

    final useCase = ImportFilesUseCase(importer);
    final inputs = <ImportFileInput>[
      (name: 'a.txt', bytes: Uint8List.fromList([1, 2, 3]), path: null),
    ];
    final imported = await useCase(inputs);

    expect(imported, 1);
    verify(() => importer.importBytes(
          bytes: any(named: 'bytes'),
          originalName: 'a.txt',
        )).called(1);
    verifyNever(() => importer.importFile(any()));
  });

  test('routes inputs with only path through importFile', () async {
    when(() => importer.importFile(any())).thenAnswer((_) async => _doc());

    final useCase = ImportFilesUseCase(importer);
    final inputs = <ImportFileInput>[
      (name: 'a.txt', bytes: null, path: '/tmp/a.txt'),
    ];
    final imported = await useCase(inputs);

    expect(imported, 1);
    verify(() => importer.importFile(any())).called(1);
    verifyNever(() => importer.importBytes(
          bytes: any(named: 'bytes'),
          originalName: any(named: 'originalName'),
        ));
  });

  test('skips inputs with neither bytes nor path', () async {
    final useCase = ImportFilesUseCase(importer);
    final inputs = <ImportFileInput>[
      (name: 'orphan', bytes: null, path: null),
    ];
    final imported = await useCase(inputs);

    expect(imported, 0);
    verifyZeroInteractions(importer);
  });

  test('counts only successfully dispatched files', () async {
    when(() => importer.importBytes(
          bytes: any(named: 'bytes'),
          originalName: any(named: 'originalName'),
        )).thenAnswer((_) async => _doc());

    final useCase = ImportFilesUseCase(importer);
    final inputs = <ImportFileInput>[
      (name: 'a.txt', bytes: Uint8List.fromList([1]), path: null),
      (name: 'orphan', bytes: null, path: null),
      (name: 'b.txt', bytes: Uint8List.fromList([2]), path: null),
    ];

    expect(await useCase(inputs), 2);
  });
}
