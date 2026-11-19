import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const VideoDownloaderApp());

class VideoDownloaderApp extends StatelessWidget {
  const VideoDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Video Downloader',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080D18),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C5CFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DownloaderHome(),
    );
  }
}

class DownloaderHome extends StatefulWidget {
  const DownloaderHome({super.key});

  @override
  State<DownloaderHome> createState() => _DownloaderHomeState();
}

class _DownloaderHomeState extends State<DownloaderHome> {
  final _urlController = TextEditingController();
  final _dio = Dio();
  CancelToken? _cancelToken;
  double _progress = 0;
  bool _downloading = false;
  String _status = 'Paste a direct video or file URL to get started.';
  String? _savedPath;
  String? _detectedPlatform;
  String? _platformHelp;
  Uri? _platformUri;

  String? _platformForHost(String host) {
    final h = host.toLowerCase().replaceFirst(RegExp(r'^www\\.'), '');
    if (h == 'facebook.com' || h.endsWith('.facebook.com') || h == 'fb.watch') return 'Facebook';
    if (h == 'instagram.com' || h.endsWith('.instagram.com')) return 'Instagram';
    if (h == 'tiktok.com' || h.endsWith('.tiktok.com') || h == 'vm.tiktok.com') return 'TikTok';
    if (h == 'x.com' || h.endsWith('.x.com') || h == 'twitter.com' || h.endsWith('.twitter.com')) return 'X (Twitter)';
    if (h == 'vimeo.com' || h.endsWith('.vimeo.com')) return 'Vimeo';
    return null;
  }

  void _analyzeLink() {
    final raw = _urlController.text.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      setState(() { _detectedPlatform = null; _platformUri = null; _platformHelp = 'Enter a valid website link first.'; });
      return;
    }
    final platform = _platformForHost(uri.host);
    setState(() {
      _detectedPlatform = platform ?? 'Direct link / Other website';
      _platformUri = uri;
      _platformHelp = platform == null
          ? 'If this is a direct media or file URL, use Start Download. Website pages may not provide a downloadable file.'
          : '$platform link detected. Use the platform\'s official download or sharing options where available. This app will not bypass login, DRM, or platform restrictions.';
      _status = platform == null ? 'Link analyzed.' : '$platform link detected. Direct page extraction is not available.';
    });
  }

  Future<void> _openPlatform() async {
    final uri = _platformUri;
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _download() async {
    final url = _urlController.text.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      setState(() => _status = 'Please enter a valid direct HTTP or HTTPS link.');
      return;
    }

    setState(() {
      _downloading = true;
      _progress = 0;
      _savedPath = null;
      _status = 'Connecting...';
    });
    _cancelToken = CancelToken();

    try {
      final dir = await getApplicationDocumentsDirectory();
      var name = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'download';
      if (name.isEmpty || !name.contains('.')) {
        name = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      }
      name = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final filePath = '${dir.path}/$name';

      await _dio.download(
        url,
        filePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            if (total > 0) _progress = received / total;
            _status = total > 0
                ? 'Downloading ${(received / 1024 / 1024).toStringAsFixed(1)} MB'
                    ' / ${(total / 1024 / 1024).toStringAsFixed(1)} MB'
                : 'Downloading...';
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _savedPath = filePath;
        _progress = 1;
        _status = 'Download completed successfully.';
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _status = CancelToken.isCancel(e)
          ? 'Download cancelled.'
          : 'Download failed: ${e.message ?? 'Connection error'}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
      _cancelToken = null;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _dio.close();
    super.dispose();
  }

  Widget _feature(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF151D30),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .07)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFAA98FF), size: 25),
            const SizedBox(height: 9),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: .55), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Row(
              children: [
                Container(
                  height: 46, width: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9278FF), Color(0xFF5A42D6)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.downloading_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Video Downloader', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  Text('FAST  •  SIMPLE  •  PRIVATE',
                      style: TextStyle(fontSize: 10, letterSpacing: 1.3, color: Color(0xFFAA98FF))),
                ]),
                const Spacer(),
                const Icon(Icons.settings_outlined, color: Colors.white70),
              ],
            ),
            const SizedBox(height: 34),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF29204F), Color(0xFF171D35), Color(0xFF111827)],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFF8C75FF).withValues(alpha: .25)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('YOUR DOWNLOADS,\nMADE EASY',
                    style: TextStyle(fontSize: 27, height: 1.15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text('Download files from direct links in just a few taps.',
                    style: TextStyle(color: Colors.white.withValues(alpha: .7), height: 1.4)),
                const SizedBox(height: 20),
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: 'Paste direct video or file link',
                    prefixIcon: const Icon(Icons.link_rounded),
                    filled: true,
                    fillColor: const Color(0xFF0B1020),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity, height: 46,
                  child: OutlinedButton.icon(
                    onPressed: _analyzeLink,
                    icon: const Icon(Icons.travel_explore_rounded),
                    label: const Text('ANALYZE LINK'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity, height: 54,
                  child: FilledButton.icon(
                    onPressed: _downloading ? null : _download,
                    icon: Icon(_downloading ? Icons.downloading : Icons.download_rounded),
                    label: Text(_downloading ? 'DOWNLOADING...' : 'START DOWNLOAD',
                        style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: .7)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF795CFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
              ]),
            ),
            if (_platformHelp != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF151D30), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF8C75FF).withValues(alpha: .25))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [const Icon(Icons.public_rounded, color: Color(0xFFAA98FF)), const SizedBox(width: 8), Expanded(child: Text(_detectedPlatform ?? 'Link information', style: const TextStyle(fontWeight: FontWeight.w800))) ]),
                  const SizedBox(height: 8),
                  Text(_platformHelp!, style: const TextStyle(color: Colors.white70, height: 1.4)),
                  if (_platformUri != null && _detectedPlatform != 'Direct link / Other website') ...[
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _openPlatform, icon: const Icon(Icons.open_in_new), label: const Text('Open official page'))),
                  ],
                ]),
              ),
            ],
            const SizedBox(height: 22),
            Row(children: [
              _feature(Icons.bolt_rounded, 'Fast', 'Direct transfer'),
              const SizedBox(width: 10),
              _feature(Icons.shield_outlined, 'Private', 'Saved on device'),
              const SizedBox(width: 10),
              _feature(Icons.pause_circle_outline, 'Control', 'Cancel anytime'),
            ]),
            const SizedBox(height: 25),
            const Text('DOWNLOAD STATUS', style: TextStyle(
              fontWeight: FontWeight.w800, letterSpacing: 1.1, fontSize: 12,
            )),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF151D30),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: .06)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_status, style: TextStyle(color: Colors.white.withValues(alpha: .8))),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: _downloading || _progress > 0 ? _progress : 0,
                    minHeight: 8,
                    backgroundColor: const Color(0xFF30384B),
                    color: const Color(0xFF9A84FF),
                  ),
                ),
                const SizedBox(height: 8),
                Text('${(_progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Color(0xFFAA98FF), fontWeight: FontWeight.bold)),
                if (_downloading) Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _cancelToken?.cancel(),
                    icon: const Icon(Icons.close, size: 17),
                    label: const Text('Cancel'),
                  ),
                ),
                if (_savedPath != null) ...[
                  const SizedBox(height: 8),
                  SelectableText('Saved in app storage: $_savedPath',
                      style: const TextStyle(fontSize: 11, color: Colors.white54)),
                ],
              ]),
            ),
            const SizedBox(height: 22),
            Text(
              'Note: This version recognizes Facebook, Instagram, TikTok, X (Twitter), and Vimeo links, and supports direct HTTP/HTTPS file downloads. '
              'Social-media page extraction is not enabled; use official platform download options. It does not bypass sign-in, '
              'DRM, or platform restrictions. Download only content you have permission to save.',
              style: TextStyle(color: Colors.white.withValues(alpha: .45), fontSize: 11, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
