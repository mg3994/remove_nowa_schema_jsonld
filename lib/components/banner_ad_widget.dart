import 'package:flutter/material.dart';
import 'package:nowa_mobile_ads/nowa_mobile_ads.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

@NowaGenerated()
class BannerAdWidget extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const BannerAdWidget({
    super.key,
    this.webImageUrl,
    this.webAdUrl,
    this.webTitle,
    this.webSubtitle,
    this.iframeUrl,
    this.width,
    this.height,
  });

  final String? webImageUrl;

  final String? webAdUrl;

  final String? webTitle;

  final String? webSubtitle;

  final String? iframeUrl;

  final double? width;

  final double? height;

  @override
  State<BannerAdWidget> createState() {
    return _BannerAdWidgetState();
  }
}

@NowaGenerated()
class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;

  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadAd();
    }
  }

  void _loadAd() {
    String adUnitId = '';
    if (defaultTargetPlatform == TargetPlatform.android) {
      adUnitId = 'ca-app-pub-3940256099942544/6300978111';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      adUnitId = 'ca-app-pub-3940256099942544/2934735716';
    }
    if (adUnitId.isEmpty) {
      return;
    }
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: ${error}');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _launchWebAd() async {
    final urlStr = widget.webAdUrl ?? 'https://hireflutter.uk/';
    final url = Uri.parse(urlStr);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _configureIframe(dynamic element, String url) {
    try {
      element.src = url;
      element.style.border = 'none';
      element.style.width = '100%';
      element.style.height = '100%';
    } catch (e) {
      debugPrint('Error configuring iframe element: ${e}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      final double defaultHeight = widget.height ?? 90.0;
      final double? defaultWidth = widget.width;
      if (widget.iframeUrl != null && widget.iframeUrl!.isNotEmpty) {
        return Container(
          width: defaultWidth ?? double.infinity,
          height: defaultHeight,
          alignment: Alignment.center,
          color: Theme.of(context).colorScheme.surface,
          child: HtmlElementView.fromTagName(
            tagName: 'iframe',
            onElementCreated: (element) {
              _configureIframe(element, widget.iframeUrl!);
            },
          ),
        );
      }
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      final imageUrl = widget.webImageUrl ??
          'https://raw.githubusercontent.com/mg3994/dust-pan/main/images/hire_flutter_uk.png';
      final title = widget.webTitle ?? 'Want to read Something Interesting?';
      final subtitle = widget.webSubtitle ?? 'Head to Our Blog.';
      return Container(
        width: defaultWidth ?? double.infinity,
        height: defaultHeight,
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0),
          gradient: LinearGradient(
            colors: isDark
                ? [
                    theme.colorScheme.surfaceContainerHigh ??
                        const Color(0xFF1E1E2E),
                    theme.colorScheme.surfaceContainerLowest ??
                        const Color(0xFF151521),
                  ]
                : [
                    theme.colorScheme.primaryContainer.withOpacity(0.4),
                    theme.colorScheme.surface,
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.15),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8.0,
              offset: const Offset(0.0, 4.0),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _launchWebAd,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        imageUrl,
                        width: 74.0,
                        height: 74.0,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 74.0,
                          height: 74.0,
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          child: Icon(
                            Icons.ads_click,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0,
                                  vertical: 2.0,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: theme.colorScheme.outline
                                        .withOpacity(0.5),
                                    width: 1.0,
                                  ),
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: Text(
                                  'AD',
                                  style: TextStyle(
                                    fontSize: 8.0,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.outline,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: Text(
                                  title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 11.0,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withOpacity(0.8),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16.0),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        elevation: 0.0,
                      ),
                      onPressed: _launchWebAd,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Read Blog',
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 4.0),
                          Icon(Icons.open_in_new, size: 12.0),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final ad = _bannerAd;
    if (ad != null && _isLoaded) {
      return Container(
        color: Theme.of(context).colorScheme.surface,
        alignment: Alignment.center,
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      );
    }
    return const SizedBox.shrink();
  }
}
