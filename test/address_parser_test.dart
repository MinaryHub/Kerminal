import 'package:flutter_test/flutter_test.dart';
import 'package:kerminal/core/address_parser.dart';

void main() {
  test('plain host with a dot', () {
    final a = parseAddress('example.com')!;
    expect(a.host, 'example.com');
    expect(a.port, 22);
    expect(a.username, isNull);
  });

  test('user@host:port', () {
    final a = parseAddress('admin@10.0.0.5:2222')!;
    expect(a.username, 'admin');
    expect(a.host, '10.0.0.5');
    expect(a.port, 2222);
  });

  test('ssh command with -p', () {
    final a = parseAddress('ssh -p 2200 deploy@web.example.com')!;
    expect(a.username, 'deploy');
    expect(a.host, 'web.example.com');
    expect(a.port, 2200);
  });

  test('IPv6 with and without brackets', () {
    expect(parseAddress('[::1]:2222')!.host, '::1');
    expect(parseAddress('[::1]:2222')!.port, 2222);
    expect(parseAddress('fe80::1')!.host, 'fe80::1');
  });

  test('a bare word is a search term, not an address', () {
    expect(parseAddress('web'), isNull);
    expect(parseAddress('prod db'), isNull);
    expect(parseAddress('localhost')!.host, 'localhost');
  });

  test('invalid input is rejected', () {
    expect(parseAddress(''), isNull);
    expect(parseAddress('host:99999'), isNull);
    expect(parseAddress('host:abc'), isNull);
    expect(parseAddress('@host.com'), isNull);
    expect(parseAddress('ssh -i key host.com'), isNull);
    expect(parseAddress('ssh host.com uptime'), isNull);
  });
}
