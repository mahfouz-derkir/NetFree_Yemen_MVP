import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const NetFreeApp());

class NetFreeApp extends StatelessWidget {
  const NetFreeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'NetFree Yemen',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087E8B)),
          scaffoldBackgroundColor: const Color(0xFFF5F8FA),
        ),
        home: const Dashboard(),
      );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<ConnectivityResult> _connectivity = [ConnectivityResult.none];
  bool _checking = false;
  String _status = 'جاهز للفحص';
  double? _downloadMbps;
  double? _uploadMbps;
  int? _latencyMs;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  void initState() {
    super.initState();
    _loadConnectivity();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) setState(() => _connectivity = results);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) setState(() => _connectivity = result);
  }

  String get _connectionLabel {
    if (_connectivity.contains(ConnectivityResult.wifi)) return 'متصل عبر Wi‑Fi';
    if (_connectivity.contains(ConnectivityResult.mobile)) return 'متصل عبر بيانات الهاتف';
    if (_connectivity.contains(ConnectivityResult.ethernet)) return 'متصل عبر Ethernet';
    return 'لا يوجد اتصال بالشبكة';
  }

  Future<void> _speedTest() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _status = 'جارٍ قياس زمن الاستجابة...';
      _downloadMbps = null;
      _uploadMbps = null;
      _latencyMs = null;
    });
    try {
      final client = http.Client();
      final sw = Stopwatch()..start();
      final ping = await client.get(Uri.parse('https://www.cloudflare.com/cdn-cgi/trace'))
          .timeout(const Duration(seconds: 15));
      sw.stop();
      if (ping.statusCode < 200 || ping.statusCode >= 400) {
        throw Exception('تعذر الوصول إلى خادم الاختبار');
      }
      _latencyMs = sw.elapsedMilliseconds;

      if (mounted) setState(() => _status = 'جارٍ قياس سرعة التنزيل...');
      const bytesToFetch = 5 * 1024 * 1024;
      final downloadWatch = Stopwatch()..start();
      final response = await client.get(
        Uri.parse('https://speed.cloudflare.com/__down?bytes=$bytesToFetch'),
      ).timeout(const Duration(seconds: 45));
      downloadWatch.stop();
      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw Exception('فشل اختبار التنزيل');
      }
      final seconds = max(downloadWatch.elapsedMilliseconds / 1000, 0.001);
      _downloadMbps = (response.bodyBytes.length * 8 / seconds) / 1000000;

      if (mounted) setState(() => _status = 'جارٍ قياس سرعة الرفع...');
      final payload = List<int>.generate(1024 * 1024, (i) => (i * 31) % 256);
      final uploadWatch = Stopwatch()..start();
      final uploadResponse = await client.post(
        Uri.parse('https://speed.cloudflare.com/__up'),
        body: payload,
        headers: {'Content-Type': 'application/octet-stream'},
      ).timeout(const Duration(seconds: 45));
      uploadWatch.stop();
      if (uploadResponse.statusCode >= 200 && uploadResponse.statusCode < 400) {
        final upSeconds = max(uploadWatch.elapsedMilliseconds / 1000, 0.001);
        _uploadMbps = (payload.length * 8 / upSeconds) / 1000000;
      }
      client.close();
      if (mounted) setState(() => _status = 'اكتمل الاختبار');
    } catch (e) {
      if (mounted) setState(() => _status = 'تعذر إكمال الاختبار. تحقق من اتصالك ثم أعد المحاولة.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openApnSettings() async {
    // Android system settings deep-link may vary by device/vendor.
    final uri = Uri.parse('android.settings.APN_SETTINGS');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      _info('إعدادات APN', 'افتح الإعدادات > الاتصالات > شبكات الهاتف المحمول > أسماء نقاط الوصول.');
    }
  }

  void _info(String title, String text) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NetFree Yemen'),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _loadConnectivity, icon: const Icon(Icons.refresh), tooltip: 'تحديث'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFF123D50),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.wifi, color: Colors.white, size: 38),
                const SizedBox(height: 12),
                const Text('مساعد الإنترنت', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_connectionLabel, style: const TextStyle(color: Colors.white70)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('اختبار سرعة الاتصال', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_status),
                const SizedBox(height: 12),
                Row(children: [
                  _metric('Ping', _latencyMs == null ? '—' : '$_latencyMs ms'),
                  _metric('تنزيل', _downloadMbps == null ? '—' : '${_downloadMbps!.toStringAsFixed(2)} Mbps'),
                  _metric('رفع', _uploadMbps == null ? '—' : '${_uploadMbps!.toStringAsFixed(2)} Mbps'),
                ]),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _checking ? null : _speedTest,
                    icon: _checking
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.speed),
                    label: Text(_checking ? 'جارٍ الاختبار' : 'ابدأ اختبار السرعة'),
                  ),
                ),
                const Text('يتطلب الاختبار اتصالًا بالإنترنت وقد يستهلك عدة ميغابايتات من باقتك.',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
              ]),
            ),
          ),
          _tile(Icons.settings, 'إعدادات APN', 'فتح إعدادات نقاط الوصول', _openApnSettings),
          _tile(Icons.info_outline, 'إرشادات يمن موبايل', 'استخدم إعدادات APN الرسمية فقط', () {
            _info('إعدادات يمن موبايل',
                'تحقق من إعدادات APN من يمن موبايل أو خدمة العملاء. لا توجد إعدادات APN عامة تضمن إنترنت مجانيًا أو سرعة أعلى.');
          }),
          _tile(Icons.wifi_find, 'فرص الإنترنت المجاني', 'شبكات عامة وعروض رسمية فقط', () {
            _info('الإنترنت المجاني',
                'يمكنك استخدام شبكات Wi‑Fi العامة أو العروض المجانية الرسمية التي تعلنها شركة الاتصالات. لا يستطيع التطبيق إنشاء بيانات خلوية مجانية أو تجاوز اشتراكات الشبكة.');
          }),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('تنبيه: تجنب التطبيقات التي تطلب رقم PIN للشريحة أو كلمات مرور حساباتك.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) => Expanded(
        child: Column(children: [
          Text(value, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
      );

  Widget _tile(IconData icon, String title, String subtitle, VoidCallback action) => Card(
        child: ListTile(
          leading: Icon(icon, size: 28),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_left),
          onTap: action,
        ),
      );
}