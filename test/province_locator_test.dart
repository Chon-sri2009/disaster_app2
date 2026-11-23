import 'package:disaster_app2/services/province_locator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

// Hand-made bundle in the asset's shape ([lon, lat] rings). TH-01 is a 10x10 degree square
// with a 2x2 hole; TH-02 sits in that hole (an enclave) and also has a second, separate ring.
const fixture = '''
{"source": "test", "provinces": [
  {"code": "TH-01", "nameTh": "หนึ่ง", "nameEn": "One", "rings": [
    [[100, 10], [110, 10], [110, 20], [100, 20]],
    [[104, 14], [106, 14], [106, 16], [104, 16]]
  ]},
  {"code": "TH-02", "nameTh": "สอง", "nameEn": "Two", "rings": [
    [[104, 14], [106, 14], [106, 16], [104, 16]],
    [[120, 10], [121, 10], [121, 11], [120, 11]]
  ]}
]}
''';

void main() {
  final b = ProvinceBoundaries.parse(fixture);

  test('a point inside a province gives its code', () {
    expect(b.codeAt(LatLng(12, 102)), 'TH-01');
    expect(b.byCode('TH-01')!.nameEn, 'One');
    expect(b.byCode('TH-01')!.rings.first.first, LatLng(10, 100));
  });

  test('a hole is outside its province (even-odd)', () {
    expect(b.codeAt(LatLng(15, 105)), 'TH-02');
  });

  test('every ring of a multi-part province counts', () {
    expect(b.codeAt(LatLng(10.5, 120.5)), 'TH-02');
  });

  test('outside every province is null; unknown code is null', () {
    expect(b.codeAt(LatLng(30, 102)), isNull);
    expect(b.codeAt(LatLng(15, 115)), isNull);
    expect(b.byCode('TH-99'), isNull);
  });

  test('a bundle that fails to load answers null, never throws', () async {
    final failed = await ProvinceBoundaries.load(
      read: () async => throw Exception('missing asset'),
    );
    expect(failed.codeAt(LatLng(12, 102)), isNull);
    expect(failed.byCode('TH-01'), isNull);
    final broken = await ProvinceBoundaries.load(read: () async => '{"x": 1');
    expect(broken.codeAt(LatLng(12, 102)), isNull);
    final badShape = await ProvinceBoundaries.load(
      read: () async => '{"provinces": [{"code": 5}]}',
    );
    expect(badShape.codeAt(LatLng(12, 102)), isNull);
  });

  test('the real bundled asset locates known places', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final real = await ProvinceBoundaries.load();
    expect(real.codeAt(LatLng(13.7563, 100.5018)), 'TH-10'); // Bangkok
    expect(real.codeAt(LatLng(7.89, 98.39)), 'TH-83'); // Phuket
    expect(real.codeAt(LatLng(10.0, 101.0)), isNull); // Gulf of Thailand
    // On the 102E line, where a lon/lat mix-up or a seam bug would show.
    expect(real.codeAt(LatLng(14.97, 102.00)), 'TH-30'); // Nakhon Ratchasima
    expect(real.byCode('TH-10'), isNotNull);
  });
}
