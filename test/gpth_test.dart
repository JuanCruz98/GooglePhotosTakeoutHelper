import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:gpth/date_extractor.dart';
import 'package:gpth/extras.dart';
import 'package:gpth/folder_classify.dart';
import 'package:gpth/grouping.dart';
import 'package:gpth/media.dart';
import 'package:gpth/moving.dart';
import 'package:gpth/utils.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

void main() {
  /// this is 1x1 green jg image, with exif:
  /// DateTime Original: 2022:12:16 16:06:47
  const greenImgBase64 = """
/9j/4AAQSkZJRgABAQAAAQABAAD/4QC4RXhpZgAATU0AKgAAAAgABQEaAAUAAAABAAAASgEbAAUA
AAABAAAAUgEoAAMAAAABAAEAAAITAAMAAAABAAEAAIdpAAQAAAABAAAAWgAAAAAAAAABAAAAAQAA
AAEAAAABAAWQAAAHAAAABDAyMzKQAwACAAAAFAAAAJyRAQAHAAAABAECAwCgAAAHAAAABDAxMDCg
AQADAAAAAf//AAAAAAAAMjAyMjoxMjoxNiAxNjowNjo0NwD/2wBDAAMCAgICAgMCAgIDAwMDBAYE
BAQEBAgGBgUGCQgKCgkICQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/2wBDAQMDAwQD
BAgEBAgQCwkLEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQ
EBD/wAARCAABAAEDAREAAhEBAxEB/8QAFAABAAAAAAAAAAAAAAAAAAAAA//EABQQAQAAAAAAAAAA
AAAAAAAAAAD/xAAUAQEAAAAAAAAAAAAAAAAAAAAI/8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAwD
AQACEQMRAD8AIcgXf//Z""";

  final albumDir = Directory('Vacation');
  final imgFileGreen = File('green.jpg');
  final imgFile1 = File('image-edited.jpg');
  final jsonFile1 = File('image-edited.jpg.json');
  // these names are from good old #8 issue...
  final imgFile2 = File('Urlaub in Knaufspesch in der Schneifel (38).JPG');
  final jsonFile2 = File('Urlaub in Knaufspesch in der Schneifel (38).JP.json');
  final imgFile3 = File('Screenshot_2022-10-28-09-31-43-118_com.snapchat.jpg');
  final jsonFile3 = File('Screenshot_2022-10-28-09-31-43-118_com.snapcha.json');
  final imgFile4 = File('simple_file_20200101-edited.jpg');
  final imgFile4_1 = File('simple_file_20200101-edited(1).jpg');
  final jsonFile4 = File('simple_file_20200101.jpg.json');
  final media = [
    Media({null: imgFile1},
        dateTaken: DateTime(2020, 9, 1), dateTakenAccuracy: 1),
    Media(
      {albumName(albumDir): imgFile1},
      dateTaken: DateTime(2022, 9, 1),
      dateTakenAccuracy: 2,
    ),
    Media({null: imgFile2}, dateTaken: DateTime(2020), dateTakenAccuracy: 2),
    Media({null: imgFile3},
        dateTaken: DateTime(2022, 10, 28), dateTakenAccuracy: 1),
    Media({null: imgFile4}),
    Media({null: imgFile4_1}, dateTaken: DateTime(2019), dateTakenAccuracy: 3),
  ];

  /// Set up test stuff - create test shitty files in wherever pwd is
  /// We don't worry because we'll delete them later
  setUpAll(() {
    albumDir.createSync(recursive: true);
    imgFileGreen.createSync();
    imgFileGreen.writeAsBytesSync(
      base64.decode(greenImgBase64.replaceAll('\n', '')),
    );
    // apparently you don't need to .create() before writing 👍
    imgFile1.writeAsBytesSync([0, 1, 2]);
    imgFile1.copySync('${albumDir.path}/${basename(imgFile1.path)}');
    imgFile2.writeAsBytesSync([3, 4, 5]);
    imgFile3.writeAsBytesSync([6, 7, 8]);
    imgFile4.writeAsBytesSync([9, 10, 11]); // these two...
    imgFile4_1.writeAsBytesSync([9, 10, 11]); // ...are duplicates
    writeJson(File file, int time) =>
        file.writeAsStringSync('{"photoTakenTime": {"timestamp": "$time"}}');
    writeJson(jsonFile1, 1599078832);
    writeJson(jsonFile2, 1683078832);
    writeJson(jsonFile3, 1666942303);
    writeJson(jsonFile4, 1683074444);
  });

  group('DateTime extractors', () {
    test('test json extractor', () async {
      expect((await jsonExtractor(imgFile1))?.millisecondsSinceEpoch,
          1599078832 * 1000);
      expect((await jsonExtractor(imgFile2))?.millisecondsSinceEpoch,
          1683078832 * 1000);
      expect((await jsonExtractor(imgFile3))?.millisecondsSinceEpoch,
          1666942303 * 1000);
      // They *should* fail without tryhard
      // See b38efb5d / #175
      expect((await jsonExtractor(imgFile4))?.millisecondsSinceEpoch, null);
      expect((await jsonExtractor(imgFile4_1))?.millisecondsSinceEpoch, null);
      // Should work *with* tryhard
      expect(
        (await jsonExtractor(imgFile4, tryhard: true))?.millisecondsSinceEpoch,
        1683074444 * 1000,
      );
      expect(
        (await jsonExtractor(imgFile4_1, tryhard: true))
            ?.millisecondsSinceEpoch,
        1683074444 * 1000,
      );
    });
    test('test exif extractor', () async {
      expect(
        (await exifExtractor(imgFileGreen)),
        DateTime.parse('2022-12-16 16:06:47'),
      );
    });
    test('test guess extractor', () async {
      final files = [
        ['Screenshot_20190919-053857_Camera-edited.jpg', '2019-09-19 05:38:57'],
        ['MVIMG_20190215_193501.MP4', '2019-02-15 19:35:01'],
        ['Screenshot_2019-04-16-11-19-37-232_com.jpg', '2019-04-16 11:19:37'],
        ['signal-2020-10-26-163832.jpg', '2020-10-26 16:38:32'],
        ['VID_20220107_113306.mp4', '2022-01-07 11:33:06'],
        ['00004XTR_00004_BURST20190216172030.jpg', '2019-02-16 17:20:30'],
        ['00055IMG_00055_BURST20190216172030_COVER.jpg', '2019-02-16 17:20:30'],
        ['2016_01_30_11_49_15.mp4', '2016-01-30 11:49:15'],
        ['201801261147521000.jpg', '2018-01-26 11:47:52'],
        ['IMG_1_BURST20160623205107_COVER.jpg', '2016-06-23 20:51:07'],
        ['IMG_1_BURST20160520195318.jpg', '2016-05-20 19:53:18'],
        ['1990_06_16_07_30_00.jpg', '1990-06-16 07:30:00'],
        ['1869_12_30_16_59_57.jpg', '1869-12-30 16:59:57'],
      ];
      for (final f in files) {
        expect((await guessExtractor(File(f.first))), DateTime.parse(f.last));
      }
    });
  });
  test('test duplicate removal', () {
    expect(removeDuplicates(media), 1);
    expect(media.length, 5);
    expect(media.firstWhereOrNull((e) => e.firstFile == imgFile4), null);
  });
  test('test extras removal', () {
    final m = [
      Media({null: imgFile1}),
      Media({null: imgFile2}),
    ];
    expect(removeExtras(m), 1);
    expect(m.length, 1);
  });
  test('test album finding', () {
    // sadly, this will still modify [media] some, but won't delete anything
    final copy = media.toList();
    removeDuplicates(copy);

    final countBefore = copy.length;
    findAlbums(copy);
    expect(countBefore - copy.length, 1);

    final albumed = copy.firstWhere((e) => e.files.length > 1);
    expect(albumed.files.keys, [null, 'Vacation']);
    expect(albumed.dateTaken, media[0].dateTaken);
    expect(albumed.dateTaken == media[1].dateTaken, false); // be sure
    expect(copy.where((e) => e.files.length > 1).length, 1);
    // fails because Dart is no Rust :/
    // expect(media.where((e) => e.albums != null).length, 1);
  });
  group('utils test', () {
    test('test Stream.whereType()', () {
      final stream = Stream.fromIterable([1, 'a', 2, 'b', 3, 'c']);
      expect(stream.whereType<int>(), emitsInOrder([1, 2, 3, emitsDone]));
    });
    test('test Stream<FileSystemEntity>.wherePhotoVideo()', () {
      //    check if stream with random list of files is emitting only photos and videos
      //   use standard formats as jpg and mp4 but also rare ones like 3gp and eps
      final stream = Stream.fromIterable(<FileSystemEntity>[
        File('a.jpg'),
        File('lol.json'),
        File('b.mp4'),
        File('c.3gp'),
        File('e.png'),
        File('f.txt'),
      ]);
      expect(
        // looked like File()'s couldn't compare correctly :/
        stream.wherePhotoVideo().map((event) => event.path),
        emitsInOrder(['a.jpg', 'b.mp4', 'c.3gp', 'e.png', emitsDone]),
      );
    });
    test('test findNotExistingName()', () {
      expect(findNotExistingName(imgFileGreen).path, 'green(1).jpg');
      expect(findNotExistingName(File('not-here.jpg')).path, 'not-here.jpg');
    });
    test('test getDiskFree()', () async {
      expect(await getDiskFree('.'), isNotNull);
    });
  });
  group('folder_classify test', () {
    final dirs = [
      Directory('./Photos from 2025'),
      Directory('./Photos from 1969'),
      Directory('./Photos from vacation'),
      Directory('/tmp/very-random-omg'),
    ];
    setUpAll(() async {
      for (var d in dirs) {
        await d.create();
      }
    });
    test('is year/album folder', () async {
      expect(isYearFolder(dirs[0]), true);
      expect(isYearFolder(dirs[1]), true);
      expect(isYearFolder(dirs[2]), false);
      expect(await isAlbumFolder(dirs[2]), true);
      expect(await isAlbumFolder(dirs[3]), false);
    });
    tearDownAll(() async {
      for (var d in dirs) {
        await d.delete();
      }
    });
  });

  /// Delete all shitty files as we promised
  tearDownAll(() {
    albumDir.deleteSync(recursive: true);
    imgFileGreen.deleteSync();
    imgFile1.deleteSync();
    imgFile2.deleteSync();
    imgFile3.deleteSync();
    imgFile4.deleteSync();
    imgFile4_1.deleteSync();
    jsonFile1.deleteSync();
    jsonFile2.deleteSync();
    jsonFile3.deleteSync();
    jsonFile4.deleteSync();
  });
}
