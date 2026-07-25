import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:jsonld/globals/app_state.dart';
import 'package:jsonld/schema_service.dart';
import 'package:jsonld/globals/themes.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jsonld/schema_entity.dart';
import 'package:jsonld/schema_value.dart';
import 'package:jsonld/models/schema_property.dart';
import 'package:jsonld/globals/download_helper.dart' as dl;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() {
    return _HomePageState();
  }
}

class FlatTreeNode {
  final String id;
  final String label;
  final String typeLabel;
  final int depth;
  final SchemaEntity? entity;
  final bool isProperty;
  final String? propValue;
  final bool isExpanded;

  FlatTreeNode({
    required this.id,
    required this.label,
    required this.typeLabel,
    required this.depth,
    this.entity,
    this.isProperty = false,
    this.propValue,
    this.isExpanded = true,
  });
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<SchemaEntity> _columnStack = [];
  final ScrollController _horizontalScrollController = ScrollController();
  TabController? _mobileTabController;

  final Set<String> _collapsedEntityIds = {};
  int _treeCurrentPage = 0;
  static const int _treeItemsPerPage = 10;

  final TextEditingController _importController = TextEditingController();

  final TextEditingController _searchClassController = TextEditingController();

  final TextEditingController _searchPropertyController =
      TextEditingController();

  final TextEditingController _docNameController = TextEditingController();

  final TextEditingController _customPropController = TextEditingController();

  final TextEditingController _searchMarkupController = TextEditingController();

  String _propertySearchQuery = '';

  String _classSearchQuery = '';

  String _markupSearchQuery = '';

  bool _showTreeView = false;

  @override
  void initState() {
    super.initState();
    _mobileTabController = TabController(length: 3, vsync: this);
    _mobileTabController!.addListener(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppState.of(context, listen: false).initSchemaService();
    });
  }

  List<String> _getInheritancePath(String classId) {
    final List<String> path = [];
    final classes = SchemaService.instance.classes;
    String? current = classId;
    final Set<String> visited = {};
    while (current != null && !visited.contains(current)) {
      visited.add(current!);
      final label = current!.startsWith('schema:')
          ? current?.substring(7)
          : current;
      path.insert(0, label!);
      final cls = classes[current!];
      current = (cls != null && cls!.subClassOf.isNotEmpty)
          ? cls?.subClassOf.first
          : null;
    }
    return path;
  }

  List<String> _getRecommendedProperties(String classId) {
    if (classId.contains('Person')) {
      return [
        'schema:name',
        'schema:jobTitle',
        'schema:email',
        'schema:telephone',
        'schema:address',
        'schema:url',
        'schema:image',
        'schema:worksFor',
      ];
    } else if (classId.contains('Organization')) {
      return [
        'schema:name',
        'schema:logo',
        'schema:url',
        'schema:foundingDate',
        'schema:email',
        'schema:telephone',
        'schema:address',
      ];
    } else if (classId.contains('LocalBusiness')) {
      return [
        'schema:name',
        'schema:logo',
        'schema:url',
        'schema:address',
        'schema:telephone',
        'schema:priceRange',
        'schema:areaServed',
      ];
    } else if (classId.contains('Service')) {
      return [
        'schema:name',
        'schema:areaServed',
        'schema:provider',
      ];
    } else if (classId.contains('GeoCircle')) {
      return [
        'schema:geoMidpoint',
        'schema:geoRadius',
      ];
    } else if (classId.contains('GeoCoordinates')) {
      return [
        'schema:latitude',
        'schema:longitude',
      ];
    } else if (classId.contains('Product')) {
      return [
        'schema:name',
        'schema:image',
        'schema:description',
        'schema:brand',
        'schema:offers',
        'schema:sku',
      ];
    } else if (classId.contains('Event')) {
      return [
        'schema:name',
        'schema:startDate',
        'schema:endDate',
        'schema:location',
        'schema:description',
        'schema:organizer',
        'schema:offers',
      ];
    } else if (classId.contains('WebSite')) {
      return ['schema:name', 'schema:url', 'schema:description'];
    } else if (classId.contains('PostalAddress')) {
      return [
        'schema:streetAddress',
        'schema:addressLocality',
        'schema:addressRegion',
        'schema:postalCode',
        'schema:addressCountry',
      ];
    } else if (classId.contains('Offer')) {
      return [
        'schema:price',
        'schema:priceCurrency',
        'schema:availability',
        'schema:url',
      ];
    }
    return ['schema:name', 'schema:description', 'schema:url', 'schema:image'];
  }

  Future<bool?> _showExitConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App?'),
        content: const Text('Are you sure you want to exit the JSON LD Visual Editor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppState.of(context);
    final isWide = MediaQuery.of(context).size.width >= 1100;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final primaryFocus = FocusManager.instance.primaryFocus;
        if (primaryFocus != null && primaryFocus.context?.widget is EditableText) {
          primaryFocus.unfocus();
          return;
        }

        final shouldExit = await _showExitConfirmationDialog() ?? false;
        if (shouldExit && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
      drawer: Drawer(
        child: Column(
          children: [
             Container(
               padding: const EdgeInsets.fromLTRB(16.0, 48.0, 16.0, 24.0),
              decoration: BoxDecoration(
                 gradient: LinearGradient(
                   colors: [
                     Theme.of(context).colorScheme.primary,
                     Theme.of(context).colorScheme.secondary,
                   ],
                   begin: Alignment.topLeft,
                   end: Alignment.bottomRight,
                 ),
                 boxShadow: [
                   BoxShadow(
                     color: Colors.black.withOpacity(0.15),
                     blurRadius: 10,
                     offset: const Offset(0, 4),
                   ),
                 ],
              ),
               child: Stack(
                children: [
                   Row(
                     children: [
                       Container(
                         decoration: BoxDecoration(
                           borderRadius: BorderRadius.circular(16.0),
                           boxShadow: [
                             BoxShadow(
                               color: Colors.black.withOpacity(0.2),
                               blurRadius: 6,
                               offset: const Offset(0, 2),
                             ),
                           ],
                         ),
                         child: ClipRRect(
                           borderRadius: BorderRadius.circular(16.0),
                           child: Image.asset(
                              'assets/json_ld.png',
                             width: 68.0,
                             height: 68.0,
                             fit: BoxFit.cover,
                           ),
                        ),
                       ),
                       const SizedBox(width: 16.0),
                       Expanded(
                         child: Column(
                           mainAxisAlignment: MainAxisAlignment.center,
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             const Text(
                               'JSON LD',
                               style: TextStyle(
                                 fontWeight: FontWeight.bold,
                                 fontSize: 22.0,
                                 color: Colors.white,
                                 letterSpacing: 1.2,
                               ),
                             ),
                             const Text(
                               'Visual Editor',
                               style: TextStyle(
                                 fontSize: 15.0,
                                 fontWeight: FontWeight.w300,
                                 color: Colors.white70,
                               ),
                             ),
                             const SizedBox(height: 6.0),
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                               decoration: BoxDecoration(
                                 color: Colors.white.withOpacity(0.2),
                                 borderRadius: BorderRadius.circular(12.0),
                               ),
                               child: const Text(
                                 'v1.0.0 • by Antinna',
                                 style: TextStyle(
                                   fontSize: 9.0,
                                   fontWeight: FontWeight.bold,
                                   color: Colors.white,
                                 ),
                               ),
                             ),
                           ],
                        ),
                       ),
                     ],
                   ),
                   Positioned(
                     top: 0,
                     right: 0,
                     child: Material(
                       color: Colors.white.withOpacity(0.2),
                       shape: const CircleBorder(),
                       child: IconButton(
                         icon: const Icon(
                           Icons.close,
                           color: Colors.white,
                           size: 18.0,
                        ),
                         onPressed: () {
                           _scaffoldKey.currentState?.closeDrawer();
                         },
                       ),
                    ),
                  ),
                ],
              ),
            ),
             const SizedBox(height: 16.0),
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
               child: Card(
                 elevation: 0.0,
                 color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
                 shape: RoundedRectangleBorder(
                   borderRadius: BorderRadius.circular(12.0),
                   side: BorderSide(
                     color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                     width: 1.0,
                   ),
                 ),
                 child: ListTile(
                   leading: Container(
                     padding: const EdgeInsets.all(8.0),
                     decoration: BoxDecoration(
                       color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                       shape: BoxShape.circle,
                     ),
                     child: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                   ),
                   title: const Text(
                     'About App',
                     style: TextStyle(fontWeight: FontWeight.bold),
                   ),
                   trailing: const Icon(Icons.chevron_right, size: 18.0),
                   onTap: () {
                     Navigator.pop(context); // close drawer
                     _showAboutApp();
                   },
                 ),
               ),
            ),
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
               child: Card(
                 elevation: 0.0,
                 color: Theme.of(context).colorScheme.secondary.withOpacity(0.06),
                 shape: RoundedRectangleBorder(
                   borderRadius: BorderRadius.circular(12.0),
                   side: BorderSide(
                     color: Theme.of(context).colorScheme.secondary.withOpacity(0.12),
                     width: 1.0,
                   ),
                 ),
                 child: ListTile(
                   leading: Container(
                     padding: const EdgeInsets.all(8.0),
                     decoration: BoxDecoration(
                       color: Theme.of(context).colorScheme.secondary.withOpacity(0.12),
                       shape: BoxShape.circle,
                     ),
                     child: Icon(Icons.privacy_tip_outlined, color: Theme.of(context).colorScheme.secondary),
                   ),
                   title: const Text(
                     'Privacy Policy',
                     style: TextStyle(fontWeight: FontWeight.bold),
                   ),
                   trailing: const Icon(Icons.chevron_right, size: 18.0),
                   onTap: () {
                     Navigator.pop(context); // close drawer
                     _showPrivacyPolicy();
                   },
                 ),
               ),
            ),
             const Divider(indent: 16.0, endIndent: 16.0, height: 24.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Connect with Antinna',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.0,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                children: [
                  const SocialCard(
                    platform: 'GitHub',
                    profileName: 'Antinna',
                    imageAsset: 'assets/antinna_copyrights.png',
                    url: 'https://github.com/antinna',
                  ),
                  const SocialCard(
                    platform: 'YouTube',
                    profileName: 'Antinna',
                    imageAsset: 'assets/antinna_copyrights.png',
                    url: 'https://www.youtube.com/antinna',
                  ),
                  const SocialCard(
                    platform: ' X (Twitter)',
                    profileName: 'antinna_yt',
                    imageAsset: 'assets/antinna_copyrights.png',
                    url: 'https://x.com/antinna_yt',
                  ),
                  const SocialCard(
                    platform: 'Instagram',
                    profileName: 'antinna.yt',
                    imageAsset: 'assets/antinna_copyrights.png',
                    url: 'https://www.instagram.com/antinna.yt/',
                  ),
                  const SocialCard(
                    platform: 'Facebook',
                    profileName: 'Antinna Profile',
                    imageAsset: 'assets/antinna_copyrights.png',
                    url: 'https://www.facebook.com/profile.php?id=100083138576317',
                  ),
                  const SocialCard(
                    platform: 'Substack',
                    profileName: 'Antinna Newsletter',
                    imageAsset: 'assets/antinna_copyrights.png',
                    url: 'https://antinna.substack.com/',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
         automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.hub_outlined, size: 28.0),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              tooltip: 'Open Settings & Socials',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Schema.org Visual Editor',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isWide
                        ? 'Fully compliant with current https://schema.org JSON-LD specification'
                        : 'Visual Schema IDE',
                    style: TextStyle(
                      fontSize: 10.0,
                      fontWeight: FontWeight.normal,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            if (isWide) ...[
              const SizedBox(width: 16.0),
              _buildStatusBadge(appState),
              const SizedBox(width: 8.0),
              _buildAutosaveBadge(appState),
            ],
          ],
        ),
        actions: [
          Row(
            children: [
              const Text(
                'Tree View',
                style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
              ),
              Switch(
                value: _showTreeView,
                onChanged: (val) {
                  setState(() {
                    _showTreeView = val;
                  });
                },
              ),
            ],
          ),
          const SizedBox(width: 12.0),
          IconButton(
            icon: Icon(
              appState.theme == darkTheme ? Icons.light_mode : Icons.dark_mode,
            ),
            tooltip: 'Toggle Dark/Light Mode',
            onPressed: () {
              appState.changeTheme(
                appState.theme == darkTheme ? lightTheme : darkTheme,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Active Document',
            onPressed: _confirmReset,
          ),
          const SizedBox(width: 16.0),
        ],
      ),
      body: appState.rootEntity == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 320.0,
                        child: _buildLeftSidebar(appState),
                      ),
                      const VerticalDivider(width: 1.0, thickness: 1.0),
                      Expanded(
                        child: _showTreeView
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: 320.0,
                                    child: _buildTreeViewWorkspace(appState),
                                  ),
                                  const VerticalDivider(width: 1.0, thickness: 1.0),
                                  Expanded(
                                    child: _buildWorkspace(appState),
                                  ),
                                ],
                              )
                            : _buildWorkspace(appState),
                      ),
                      const VerticalDivider(width: 1.0, thickness: 1.0),
                      SizedBox(
                        width: 440.0,
                        child: _buildRightSidebar(appState),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      TabBar(
                        controller: _mobileTabController,
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant,
                        tabs: const [
                          Tab(
                            icon: Icon(Icons.folder_shared_outlined),
                            text: 'Documents',
                          ),
                          Tab(
                            icon: Icon(Icons.edit_note_outlined),
                            text: 'Workspace',
                          ),
                          Tab(
                            icon: Icon(Icons.code_outlined),
                            text: 'JSON-LD',
                          ),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _mobileTabController,
                          children: [
                            _buildLeftSidebar(appState),
                            _showTreeView
                                ? _buildTreeViewWorkspace(appState)
                                : _buildWorkspace(appState),
                            _buildRightSidebar(appState),
                          ],
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
    );
  }

  Widget _buildAutosaveBadge(AppState appState) {
    final status = appState.saveStatus;
    final isSaving = status == 'Saving...';
    final isError = status.contains('Error');
    final colorScheme = Theme.of(context).colorScheme;

    final Color bgColor = isSaving
        ? colorScheme.secondaryContainer
        : (isError ? colorScheme.errorContainer : (colorScheme.surfaceContainerHighest ?? Colors.grey.withOpacity(0.15)));
    final Color fgColor = isSaving
        ? colorScheme.onSecondaryContainer
        : (isError ? colorScheme.onErrorContainer : colorScheme.onSurfaceVariant);
    final IconData icon = isSaving
        ? Icons.sync_outlined
        : (isError ? Icons.error_outline : Icons.cloud_done_outlined);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: fgColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSaving)
            const SizedBox(
              width: 10.0,
              height: 10.0,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            )
          else
            Icon(
              icon,
              size: 14.0,
              color: fgColor,
            ),
          const SizedBox(width: 6.0),
          Text(
            status,
            style: TextStyle(
              fontSize: 10.0,
              fontWeight: FontWeight.bold,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(AppState appState) {
    final bool loaded = SchemaService.instance.isFullSchemaLoaded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: loaded
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: loaded
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Theme.of(context).colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            loaded ? Icons.verified : Icons.cloud_download,
            size: 14.0,
            color: loaded
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 6.0),
          Text(
            loaded
                ? 'Dynamic Specs Active (${SchemaService.instance.classes.length} Classes, ${SchemaService.instance.properties.length} Props, ${SchemaService.instance.enumerationValues.length} Enums)'
                : 'Downloading Specs...',
            style: TextStyle(
              fontSize: 10.0,
              fontWeight: FontWeight.bold,
              color: loaded
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_horizontalScrollController.hasClients) {
        _horizontalScrollController.animateTo(
          _horizontalScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildWorkspace(AppState appState) {
    final root = appState.rootEntity;
    if (root == null) {
      return const Center(child: Text('No active document'));
    }

    // Auto-initialize or reset the cascading column stack if root changes
    if (_columnStack.isEmpty || _columnStack.first.id != root.id) {
      _columnStack = [root];
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth > 1100.0;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Breadcrumbs
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_tree,
                  size: 16.0,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _columnStack.map((segment) {
                        final isLast = segment.id == _columnStack.last.id;
                        final index = _columnStack.indexOf(segment);
                        return Row(
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _columnStack = _columnStack.sublist(0, index + 1);
                                });
                              },
                              child: Text(
                                segment.name,
                                style: TextStyle(
                                  fontSize: 11.0,
                                  fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                                  color: isLast
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ),
                            if (!isLast)
                              const Icon(
                                Icons.chevron_right,
                                size: 12.0,
                                color: Colors.grey,
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 12.0),
                  label: const Text(
                    'Documentation',
                    style: TextStyle(fontSize: 11.0),
                  ),
                  onPressed: () async {
                    final cleanType = _columnStack.last.type.replaceAll('schema:', '');
                    final url =
                        'https://schema.org/docs/search_results.html?q=$cleanType';
                    final uri = Uri.parse(url);
                    try {
                      final launched = await launchUrl(uri);
                      if (!launched) {
                        throw Exception('Launch failed');
                      }
                    } catch (e) {
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Schema.org documentation URL copied! 🔗\n$url',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),
          // Content Layout
          Expanded(
            child: isWide
                ? Scrollbar(
                    controller: _horizontalScrollController,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _horizontalScrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: _columnStack.length,
                      itemBuilder: (context, colIndex) {
                        final entity = _columnStack[colIndex];
                        return Container(
                          width: 360.0,
                          margin: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Column Header Card
                              Card(
                                margin: EdgeInsets.zero,
                                elevation: 0.0,
                                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                  side: BorderSide(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        colIndex == 0 ? Icons.settings_ethernet : Icons.layers_outlined,
                                        color: Theme.of(context).colorScheme.primary,
                                        size: 16.0,
                                      ),
                                      const SizedBox(width: 8.0),
                                      Expanded(
                                        child: Text(
                                          entity.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13.0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (colIndex > 0)
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 16.0),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            setState(() {
                                              _columnStack = _columnStack.sublist(0, colIndex);
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              // Column Content
                              Expanded(
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  elevation: 1.0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    side: BorderSide(
                                      color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12.0),
                                    child: SingleChildScrollView(
                                      child: _buildEntityEditorCard(appState, entity, isRoot: colIndex == 0, colIndex: colIndex),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Navigation Bar on mobile/narrow viewports
                      if (_columnStack.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _columnStack.removeLast();
                              });
                            },
                            child: Card(
                              margin: EdgeInsets.zero,
                              color: Theme.of(context).colorScheme.surfaceContainerHigh,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.arrow_back, size: 16.0),
                                    SizedBox(width: 8.0),
                                    Text(
                                      'Back to parent entity',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Card(
                          margin: EdgeInsets.zero,
                          elevation: 1.0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12.0),
                            child: SingleChildScrollView(
                              child: _buildEntityEditorCard(
                                appState,
                                _columnStack.last,
                                isRoot: _columnStack.length == 1,
                                colIndex: _columnStack.length - 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  bool _findEntityPath(SchemaEntity current, String targetId, List<SchemaEntity> path) {
    path.add(current);
    if (current.id == targetId) {
      return true;
    }
    for (var properties in current.properties.values) {
      for (var val in properties) {
        if (val.value is SchemaEntity) {
          if (_findEntityPath(val.value as SchemaEntity, targetId, path)) {
            return true;
          }
        }
      }
    }
    path.removeLast();
    return false;
  }

  void _navigateToEntityNode(AppState appState, SchemaEntity target) {
    final List<SchemaEntity> path = [];
    final root = appState.rootEntity;
    if (root != null && _findEntityPath(root, target.id, path)) {
      setState(() {
        _columnStack = path;
        final double screenWidth = MediaQuery.of(context).size.width;
        if (screenWidth <= 1100.0) {
          _showTreeView = false; // For mobile, collapse tree view to reveal focused column card
        }
      });
      _scrollToEnd();
    }
  }

  List<FlatTreeNode> _flattenTree(SchemaEntity entity, int depth, Set<String> collapsedIds, {String keyName = 'Root Document'}) {
    final List<FlatTreeNode> nodes = [];
    final isCollapsed = collapsedIds.contains(entity.id);

    nodes.add(FlatTreeNode(
      id: entity.id,
      label: keyName,
      typeLabel: entity.type.startsWith('schema:') ? entity.type.substring(7) : entity.type,
      depth: depth,
      entity: entity,
      isExpanded: !isCollapsed,
    ));

    if (!isCollapsed) {
      entity.properties.forEach((propId, values) {
        final propName = propId.startsWith('schema:') ? propId.substring(7) : propId;
        for (var val in values) {
          if (val.value is SchemaEntity) {
            nodes.addAll(_flattenTree(val.value as SchemaEntity, depth + 1, collapsedIds, keyName: propName));
          } else {
            nodes.add(FlatTreeNode(
              id: val.id,
              label: propName,
              typeLabel: '',
              depth: depth + 1,
              isProperty: true,
              propValue: val.value.toString(),
            ));
          }
        }
      });
    }
    return nodes;
  }

  Widget _buildTreeViewWorkspace(AppState appState) {
    final root = appState.rootEntity;
    if (root == null) return const SizedBox();

    final allNodes = _flattenTree(root, 0, _collapsedEntityIds);

    // Pagination calculations
    final maxPages = (allNodes.length / _treeItemsPerPage).ceil();
    if (_treeCurrentPage >= maxPages && _treeCurrentPage > 0) {
      _treeCurrentPage = maxPages - 1;
    }

    final startIndex = _treeCurrentPage * _treeItemsPerPage;
    final endIndex = (startIndex + _treeItemsPerPage < allNodes.length)
        ? startIndex + _treeItemsPerPage
        : allNodes.length;

    final paginatedNodes = allNodes.isNotEmpty
        ? allNodes.sublist(startIndex, endIndex)
        : <FlatTreeNode>[];

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.hub,
                color: Theme.of(context).colorScheme.primary,
                size: 20.0,
              ),
              const SizedBox(width: 8.0),
              Text(
                'Document Outline Map',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          // Flat list
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: allNodes.isEmpty
                    ? const Center(child: Text('No active structured fields.'))
                    : ListView.builder(
                        itemCount: paginatedNodes.length,
                        itemBuilder: (context, idx) {
                          final node = paginatedNodes[idx];
                          final isEntity = !node.isProperty;
                          final double indent = (node.depth * 16.0).clamp(0.0, 160.0);

                          return InkWell(
                            onTap: () {
                              if (isEntity && node.entity != null) {
                                setState(() {
                                  if (_collapsedEntityIds.contains(node.entity!.id)) {
                                    _collapsedEntityIds.remove(node.entity!.id);
                                  } else {
                                    _collapsedEntityIds.add(node.entity!.id);
                                  }
                                });
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.only(
                                left: 8.0 + indent,
                                right: 8.0,
                                top: 8.0,
                                bottom: 8.0,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.08),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Expand/Collapse/Property bullet
                                  if (isEntity)
                                    Icon(
                                      node.isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                                      size: 16.0,
                                      color: Theme.of(context).colorScheme.primary,
                                    )
                                  else
                                    Icon(
                                      Icons.arrow_right_alt,
                                      size: 14.0,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                  const SizedBox(width: 4.0),
                                  // Label
                                  Expanded(
                                    child: RichText(
                                      overflow: TextOverflow.ellipsis,
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontSize: 12.0,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: '${node.label}: ',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          if (isEntity)
                                            TextSpan(
                                              text: '@type=${node.typeLabel}',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                            )
                                          else
                                            TextSpan(
                                              text: node.propValue ?? '',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.outline,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Explore Focus Button for entities
                                  if (isEntity && node.entity != null)
                                    IconButton(
                                      icon: const Icon(Icons.explore_outlined, size: 16.0),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Focus in workspace',
                                      onPressed: () => _navigateToEntityNode(appState, node.entity!),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8.0),
          // Pagination controls
          if (maxPages > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 18.0),
                  onPressed: _treeCurrentPage > 0
                      ? () {
                          setState(() {
                            _treeCurrentPage--;
                          });
                        }
                      : null,
                ),
                Text(
                  'Page ${_treeCurrentPage + 1} of $maxPages • Nodes ${startIndex + 1}-${endIndex} of ${allNodes.length}',
                  style: TextStyle(
                    fontSize: 11.0,
                    color: Theme.of(context).colorScheme.outline,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 18.0),
                  onPressed: _treeCurrentPage < maxPages - 1
                      ? () {
                          setState(() {
                            _treeCurrentPage++;
                          });
                        }
                      : null,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEntityEditorCard(
    AppState appState,
    SchemaEntity entity, {
    bool isRoot = false,
    required int colIndex,
  }) {
    final typeLabel = entity.type.startsWith('schema:')
        ? entity.type.substring(7)
        : entity.type;
    final schemaClass = SchemaService.instance.classes[entity.type];
    final classComment = schemaClass?.comment ?? 'No description available.';
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isRoot ? Icons.settings_ethernet : Icons.layers_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 20.0,
              ),
              const SizedBox(width: 8.0),
              Text(
                isRoot
                    ? 'Root Entity: @type = ${typeLabel}'
                    : 'Nested Object: @type = ${typeLabel}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              if (!isRoot)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 20.0,
                  ),
                  tooltip: 'Delete nested object',
                  onPressed: () => _confirmDeleteNested(appState, entity),
                ),
            ],
          ),
          const SizedBox(height: 6.0),
          Text(
            classComment,
            style: TextStyle(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12.0),
          const Divider(),
          const SizedBox(height: 8.0),
          if (entity.properties.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.playlist_add,
                      size: 40.0,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 8.0),
                    const Text(
                      'No properties configured.',
                      style: TextStyle(
                        fontSize: 13.0,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16.0),
                      label: const Text('Add property'),
                      onPressed: () =>
                          _showAddPropertyDialog(appState, entity),
                    ),
                  ],
                ),
              ),
            )
          else
            ...entity.properties.entries.map((entry) {
              final propId = entry.key;
              final values = entry.value;
              return _buildPropertyRow(appState, entity, propId, values, colIndex);
            }).toList(),
          if (entity.properties.isNotEmpty) ...[
            const SizedBox(height: 12.0),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16.0),
              label: Text('Add field to ${typeLabel}'),
              onPressed: () => _showAddPropertyDialog(appState, entity),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPropertyRow(
    AppState appState,
    SchemaEntity entity,
    String propId,
    List<SchemaValue> values,
    int colIndex,
  ) {
    final propDef = SchemaService.instance.properties[propId];
    final propName = propId.startsWith('schema:')
        ? propId.substring(7)
        : propId;
    final comment = propDef?.comment ?? 'Custom user extension field';
    final List<String> ranges = propDef?.ranges ?? [];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: comment,
                  child: Row(
                    children: [
                      Text(
                        propName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(width: 4.0),
                      Icon(
                        Icons.info_outline,
                        size: 13.0,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ],
                  ),
                ),
              ),
              if (ranges.isNotEmpty) ...[
                const SizedBox(width: 8.0),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: ranges.take(2).map((range) {
                    final isPrim =
                        range == 'schema:Text' ||
                        range == 'schema:URL' ||
                        range == 'schema:Number' ||
                        range == 'schema:Boolean' ||
                        range == 'schema:Integer' ||
                        range == 'schema:Date' ||
                        range == 'schema:DateTime';
                    final shortLabel = range.startsWith('schema:')
                        ? range.substring(7)
                        : range;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: ActionChip(
                        padding: EdgeInsets.zero,
                        label: Text(
                          isPrim ? shortLabel : '+${shortLabel}',
                          style: TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold,
                            color: isPrim
                                ? Theme.of(
                                    context,
                                  ).colorScheme.onSecondaryContainer
                                : Colors.white,
                          ),
                        ),
                        backgroundColor: isPrim
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : Theme.of(context).colorScheme.primary,
                        onPressed: () {
                          if (isPrim) {
                            final initialVal = range == 'schema:Boolean'
                                ? false
                                : '';
                            appState.addPropertyToEntity(
                              entity,
                              propId,
                              initialVal,
                            );
                          } else {
                            final nested = SchemaEntity(
                              id: 'nest_${DateTime.now().microsecondsSinceEpoch}',
                              type: range,
                              properties: {},
                            );
                            appState.addPropertyToEntity(
                              entity,
                              propId,
                              nested,
                            );
                            setState(() {
                              _columnStack = _columnStack.sublist(0, colIndex + 1);
                              _columnStack.add(nested);
                            });
                            _scrollToEnd();
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 16.0),
                tooltip: 'Add compliant value',
                onPressed: () {
                  _onAddValuePressed(appState, entity, propId);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16.0),
                tooltip: 'Remove field',
                onPressed: () {
                  appState.removePropertyFromEntity(entity, propId);
                },
              ),
            ],
          ),
          ...values
              .map(
                (v) => Padding(
                  padding: const EdgeInsets.only(left: 8.0, bottom: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildValueEditor(appState, entity, propId, v, colIndex),
                      ),
                      if (values.length > 1)
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 16.0,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            appState.removePropertyValue(entity, propId, v.id);
                          },
                        ),
                    ],
                  ),
                ),
              )
              .toList(),
          const Divider(height: 16.0, thickness: 0.5),
        ],
      ),
    );
  }

  void _onAddValuePressed(
    AppState appState,
    SchemaEntity entity,
    String propId,
  ) {
    final propDef = SchemaService.instance.properties[propId];
    final ranges = propDef?.ranges ?? [];
    if (ranges.isEmpty) {
      final bool isMapContainer = _isPropertyMapContainer(entity, propId);
      appState.addPropertyToEntity(entity, propId, isMapContainer ? {'en': ''} : '');
      return;
    }
    final primitives = ranges
        .where(
          (r) =>
              r == 'schema:Text' ||
              r == 'schema:URL' ||
              r == 'schema:Number' ||
              r == 'schema:Boolean' ||
              r == 'schema:Integer' ||
              r == 'schema:Date' ||
              r == 'schema:DateTime',
        )
        .toList();
    final classes = ranges.where((r) => !primitives.contains(r)).toList();

    // Collect all subclasses for each expected range class
    final Map<String, List<String>> classToSubclasses = {};
    for (var baseClass in classes) {
      final subs = _getSubclassesOf(baseClass);
      classToSubclasses[baseClass] = subs;
    }

    final List<MapEntry<String, String>> typeOptions = [];
    // Direct base classes
    for (var baseClass in classes) {
      typeOptions.add(MapEntry(baseClass, 'Base expected type'));
    }
    // Subclasses
    for (var baseClass in classes) {
      final subs = classToSubclasses[baseClass] ?? [];
      for (var sub in subs) {
        if (!classes.contains(sub)) {
          final baseLabel = baseClass.startsWith('schema:') ? baseClass.substring(7) : baseClass;
          typeOptions.add(MapEntry(sub, 'Subtype of $baseLabel'));
        }
      }
    }

    // Deduplicate
    final Set<String> seenIds = {};
    final List<MapEntry<String, String>> uniqueTypeOptions = [];
    for (var entry in typeOptions) {
      if (!seenIds.contains(entry.key)) {
        seenIds.add(entry.key);
        uniqueTypeOptions.add(entry);
      }
    }

    String searchVal = '';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filteredOptions = uniqueTypeOptions.where((option) {
            final label = option.key.startsWith('schema:') ? option.key.substring(7) : option.key;
            final query = searchVal.toLowerCase();
            return label.toLowerCase().contains(query) || option.value.toLowerCase().contains(query);
          }).toList();

          return AlertDialog(
            title: const Text('Add Value - Select Compliant Type'),
            content: SizedBox(
              width: 480.0,
              height: 440.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'To ensure 100% Schema.org semantic compliance, choose an expected type, a more specific subtype, or a simple value:',
                    style: TextStyle(fontSize: 12.0),
                  ),
                  const SizedBox(height: 12.0),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search types & subclasses...',
                      prefixIcon: Icon(Icons.search, size: 20.0),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        searchVal = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12.0),
                  Expanded(
                    child: ListView(
                      children: [
                        if (filteredOptions.isNotEmpty) ...[
                          const Text(
                            'Structured Objects & Subclasses:',
                            style: TextStyle(
                              fontSize: 11.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey,
                            ),
                          ),
                          const SizedBox(height: 6.0),
                          ...filteredOptions.map((option) {
                            final clsId = option.key;
                            final isSubclass = option.value != 'Base expected type';
                            final label = clsId.startsWith('schema:') ? clsId.substring(7) : clsId;
                            final comment = SchemaService.instance.classes[clsId]?.comment ?? '';
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4.0),
                              child: ListTile(
                                leading: Icon(
                                  isSubclass ? Icons.subdirectory_arrow_right : Icons.playlist_add_circle_outlined,
                                  color: isSubclass ? Colors.orange : Colors.blue,
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      'Create "${label}"',
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 6.0),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                      decoration: BoxDecoration(
                                        color: isSubclass ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                      child: Text(
                                        option.value,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: isSubclass ? Colors.orange.shade700 : Colors.blue.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: comment.isNotEmpty
                                    ? Text(
                                        comment,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11.0),
                                      )
                                    : null,
                                dense: true,
                                onTap: () {
                                  final nested = SchemaEntity(
                                    id: 'nest_${DateTime.now().microsecondsSinceEpoch}',
                                    type: clsId,
                                    properties: {},
                                  );
                                  appState.addPropertyToEntity(entity, propId, nested);
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          }).toList(),
                        ],
                        if (primitives.isNotEmpty) ...[
                          const SizedBox(height: 12.0),
                          const Text(
                            'Simple Values:',
                            style: TextStyle(
                              fontSize: 11.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey,
                            ),
                          ),
                          const SizedBox(height: 6.0),
                          ...primitives.map((primId) {
                            final label = primId.startsWith('schema:')
                                ? primId.substring(7)
                                : primId;
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4.0),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.edit_note,
                                  color: Colors.green,
                                ),
                                title: Text(
                                  'Add "${label}" Field',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                                dense: true,
                                onTap: () {
                                   final bool isMapContainer = _isPropertyMapContainer(entity, propId);
                                  appState.addPropertyToEntity(
                                    entity,
                                    propId,
                                     isMapContainer ? {'en': ''} : (primId == 'schema:Boolean' ? false : ''),
                                  );
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          }).toList(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCascadingNestedEntityLinkCard(
    AppState appState,
    SchemaEntity childEntity,
    SchemaEntity parentEntity,
    int parentColIndex,
  ) {
    final nextColOpen = _columnStack.length > parentColIndex + 1 &&
        _columnStack[parentColIndex + 1].id == childEntity.id;

    final typeLabel = childEntity.type.startsWith('schema:')
        ? childEntity.type.substring(7)
        : childEntity.type;

    return Card(
      elevation: 0.0,
      margin: EdgeInsets.zero,
      color: nextColOpen
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.35)
          : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(
          color: nextColOpen
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: nextColOpen ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: () {
          setState(() {
            _columnStack = _columnStack.sublist(0, parentColIndex + 1);
            _columnStack.add(childEntity);
          });
          _scrollToEnd();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: Row(
            children: [
              Icon(
                Icons.subdirectory_arrow_right,
                color: nextColOpen
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 16.0,
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      childEntity.name.isNotEmpty ? childEntity.name : 'Untitled Nested',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: nextColOpen
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '@type: $typeLabel',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: nextColOpen
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
                size: 16.0,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValueEditor(
    AppState appState,
    SchemaEntity parentEntity,
    String propId,
    SchemaValue sValue,
    int colIndex,
  ) {
    if (sValue.value is SchemaEntity) {
      return _buildCascadingNestedEntityLinkCard(appState, sValue.value as SchemaEntity, parentEntity, colIndex);
    }
    if (sValue.value is Map && (sValue.value as Map).containsKey('@id')) {
      final mapVal = sValue.value as Map;
      final docName = mapVal['docName'] ?? 'Linked Relation';
      return Card(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.25),
        elevation: 0.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: BorderSide(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
          child: Row(
            children: [
              Icon(
                Icons.link,
                size: 16.0,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  'Relation: ${docName}',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.link_off,
                  size: 16.0,
                  color: Colors.redAccent,
                ),
                tooltip: 'Disconnect relation',
                onPressed: () {
                  appState.updatePropertyValue(
                    parentEntity,
                    propId,
                    sValue.id,
                    '',
                  );
                },
              ),
            ],
          ),
        ),
      );
    }
    if (sValue.value is Map && !(sValue.value as Map).containsKey('@value')) {
      final mapVal = Map<String, dynamic>.from(sValue.value as Map);
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.language_outlined,
                  size: 16.0,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8.0),
                const Text(
                  'Structured Map Container',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add_circle_outline, size: 12.0),
                  label: const Text('Add Key', style: TextStyle(fontSize: 10.0)),
                  onPressed: () {
                    _showAddMapKeyDialog(appState, parentEntity, propId, sValue, mapVal);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            if (mapVal.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('No keys defined in map container.', style: TextStyle(fontSize: 11.0, fontStyle: FontStyle.italic)),
              )
            else
              ...mapVal.entries.map((entry) {
                final key = entry.key;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Container(
                        width: 50.0,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$key:',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 32.0,
                          child: _MapValueTextField(
                            appState: appState,
                            parentEntity: parentEntity,
                            propId: propId,
                            sValue: sValue,
                            mapVal: mapVal,
                            mapKey: key,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 14.0, color: Colors.redAccent),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          final newMap = Map<String, dynamic>.from(mapVal);
                          newMap.remove(key);
                          appState.updatePropertyValue(parentEntity, propId, sValue.id, newMap);
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      );
    }

    final propDef = SchemaService.instance.properties[propId];
    final ranges = propDef?.ranges ?? [];
    final List<SchemaEntity> linkableDocs = [];
    for (var doc in appState.documents) {
      if (doc.id == appState.rootEntity?.id) {
        continue;
      }
      for (var rangeId in ranges) {
        if (SchemaService.instance.isSubclassOf(doc.type, rangeId)) {
          linkableDocs.add(doc);
          break;
        }
      }
    }
    final enumOptions = SchemaService.instance.getEnumOptions(ranges);
    Widget editorWidget;
    if (enumOptions.isNotEmpty) {
      final currentValStr = sValue.value.toString() ?? '';
      final List<String> dropdownItems = List.from(enumOptions);
      if (currentValStr.isNotEmpty && !dropdownItems.contains(currentValStr)) {
        dropdownItems.add(currentValStr);
      }
      if (currentValStr.isEmpty && dropdownItems.isNotEmpty) {
        sValue.value = dropdownItems.first;
      }
      editorWidget = DropdownButtonFormField<String>(
        initialValue: sValue.value.toString(),
        isExpanded: true,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: 10.0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
          ),
        ),
        items: dropdownItems.map((opt) {
          final label = opt.startsWith('schema:') ? opt.substring(7) : opt;
          return DropdownMenuItem<String>(
            value: opt,
            child: Text(label, style: const TextStyle(fontSize: 13.0)),
          );
        }).toList(),
        onChanged: (newVal) {
          if (newVal != null) {
            appState.updatePropertyValue(
              parentEntity,
              propId,
              sValue.id,
              newVal,
            );
          }
        },
      );
    } else {
      final isBoolean =
          ranges.contains('schema:Boolean') || sValue.value is bool;
      if (isBoolean) {
        final bool val = sValue.value is bool ? sValue.value as bool : false;
        editorWidget = Row(
          children: [
            Switch(
              value: val,
              onChanged: (newVal) {
                appState.updatePropertyValue(
                  parentEntity,
                  propId,
                  sValue.id,
                  newVal,
                );
              },
            ),
            const SizedBox(width: 8.0),
            Text(
              val ? 'True' : 'False',
              style: const TextStyle(fontSize: 13.0),
            ),
          ],
        );
      } else {
        IconData? inputIcon;
        if (ranges.contains('schema:URL')) {
          inputIcon = Icons.link;
        } else if (ranges.contains('schema:Date') ||
            ranges.contains('schema:DateTime')) {
          inputIcon = Icons.calendar_today;
        } else if (ranges.contains('schema:Number')) {
          inputIcon = Icons.pin;
        }
        editorWidget = _PrimitiveTextField(
          appState: appState,
          parentEntity: parentEntity,
          propId: propId,
          sValue: sValue,
          ranges: ranges,
          inputIcon: inputIcon,
        );
      }
    }
    if (linkableDocs.isNotEmpty) {
      return Row(
        children: [
          Expanded(child: editorWidget),
          const SizedBox(width: 8.0),
          PopupMenuButton<SchemaEntity>(
            icon: Icon(
              Icons.link,
              color: Theme.of(context).colorScheme.primary,
              size: 20.0,
            ),
            tooltip: 'Link to a semantically compliant open markup document',
            onSelected: (doc) {
              appState.updatePropertyValue(parentEntity, propId, sValue.id, {
                '@id': doc.id,
                'docName': doc.name,
              });
            },
            itemBuilder: (context) => linkableDocs.map((doc) {
              final typeLabel = doc.type.startsWith('schema:')
                  ? doc.type.substring(7)
                  : doc.type;
              return PopupMenuItem<SchemaEntity>(
                value: doc,
                child: Row(
                  children: [
                    Icon(
                      Icons.insert_drive_file_outlined,
                      size: 14.0,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      '${doc.name} (${typeLabel})',
                      style: const TextStyle(fontSize: 12.0),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      );
    }
    return editorWidget;
  }

  void _addPropertyValuePlaceholder(
    AppState appState,
    SchemaEntity entity,
    String propId,
  ) {
    final propDef = SchemaService.instance.properties[propId];
    final ranges = propDef?.ranges ?? [];
    if (ranges.contains('schema:Boolean')) {
      appState.addPropertyToEntity(entity, propId, false);
    } else {
      appState.addPropertyToEntity(entity, propId, '');
    }
  }

  Widget _buildRightSidebar(AppState appState) {
    return Container(
      color:
          Theme.of(context).colorScheme.surfaceContainerHigh ??
          Theme.of(context).colorScheme.surface.withOpacity(0.95),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'JSON-LD Output',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 16.0),
                tooltip: 'Copy JSON-LD',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: appState.jsonLdOutput));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('JSON-LD copied to clipboard! 📋'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.download, size: 16.0),
                tooltip: 'Download .jsonld file',
                onPressed: () {
                  final rootName = appState.rootEntity?.name ?? 'document';
                  final cleanName = rootName.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');
                  final filename = '${cleanName.isNotEmpty ? cleanName : 'schema'}.jsonld';
                  dl.downloadFile(appState.jsonLdOutput, filename);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Downloading "${filename}"... 💾'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.file_upload, size: 16.0),
                tooltip: 'Import JSON-LD Schema',
                onPressed: () => _showImportDialog(appState),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.settings_suggest_outlined,
                  size: 16.0,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8.0),
                const Text(
                  'Format Version',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                SizedBox(
                  height: 28.0,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: appState.selectedLdVersion,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      items: const [
                        DropdownMenuItem<String>(
                          value: '1.0',
                          child: Text('JSON-LD 1.0 (Legacy)'),
                        ),
                        DropdownMenuItem<String>(
                          value: '1.1',
                          child: Text('JSON-LD 1.1 (Modern)'),
                        ),
                        DropdownMenuItem<String>(
                          value: '1.2',
                          child: Text('JSON-LD 1.2 (Strict)'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'yaml-ld',
                          child: Text('YAML-LD Format'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          appState.generateJsonLdOutputWithVersion(val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12.0),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).colorScheme.surfaceContainerLowest ??
                    Colors.black87,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: SingleChildScrollView(
                child: SelectionArea(
                  child: Text(
                    appState.jsonLdOutput.isEmpty
                        ? '{}'
                        : appState.jsonLdOutput,
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12.5,
                      height: 1.4,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12.0),
          Card(
            elevation: 0.0,
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 15.0,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8.0),
                      const Text(
                        'Google Rich Results Validator',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6.0),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.3,
                        color: Colors.grey,
                        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                      ),
                      children: [
                        const TextSpan(
                          text: 'This document contains schema.org context fields. You can validate it directly on Google\'s Rich Results Test tool to boost SEO rankings!\n\n',
                        ),
                        WidgetSpan(
                          child: InkWell(
                            onTap: () async {
                              final url = Uri.parse('https://search.google.com/test/rich-results');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.open_in_new,
                                  size: 11.0,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 4.0),
                                Text(
                                  'https://search.google.com/test/rich-results',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmChangeRootType(AppState appState, String newType) {
    final typeLabel = newType.startsWith('schema:')
        ? newType.substring(7)
        : newType;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Root Schema Type?'),
        content: Text(
          'Are you sure you want to change the root type to "${typeLabel}"? This will reset your current visual inputs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              appState.setRootEntity(
                SchemaEntity(
                  id: 'root_${DateTime.now().millisecondsSinceEpoch}',
                  type: newType,
                  properties: {},
                  name: appState.rootEntity?.name ?? 'Schema Document',
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _confirmReset() {
    final appState = AppState.of(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Editor?'),
        content: const Text('This will reset the active document properties.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final current = appState.rootEntity;
              appState.setRootEntity(
                SchemaEntity(
                  id: current!.id,
                  type: current!.type,
                  properties: {},
                  name: current!.name,
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteNested(AppState appState, SchemaEntity targetEntity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Nested Object?'),
        content: const Text(
          'Are you sure you want to delete this nested entity and all its properties?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteValueRecursively(appState.rootEntity!, targetEntity);
              appState.generateJsonLdOutput();
              appState.notifyListeners();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  bool _deleteValueRecursively(SchemaEntity root, SchemaEntity target) {
    for (var entry in root.properties.entries) {
      final propId = entry.key;
      final list = entry.value;
      for (var i = 0; i < list.length; i++) {
        if (list[i].value == target) {
          list.removeAt(i);
          if (list.isEmpty) {
            root.properties.remove(propId);
          }
          return true;
        } else if (list[i].value is SchemaEntity) {
          final found = _deleteValueRecursively(
            list[i].value as SchemaEntity,
            target,
          );
          if (found) {
            return true;
          }
        }
      }
    }
    return false;
  }

  void _showAddPropertyDialog(AppState appState, SchemaEntity entity) {
    final typeLabel = entity.type.startsWith('schema:')
        ? entity.type.substring(7)
        : entity.type;
    final allProps = SchemaService.instance.getPropertiesForClass(entity.type);
    final recommended = _getRecommendedProperties(entity.type);
    _propertySearchQuery = '';
    _searchPropertyController.clear();
    _customPropController.clear();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filteredProps = allProps.where((prop) {
            final label = prop.label.toLowerCase();
            final comment = prop.comment.toLowerCase();
            final query = _propertySearchQuery.toLowerCase();
            return label.contains(query) || comment.contains(query);
          }).toList();
          final recProps = allProps
              .where((p) => recommended.contains(p.id))
              .toList();
          return AlertDialog(
            title: Text('Configure Properties for ${typeLabel}'),
            content: SizedBox(
              width: 520.0,
              height: 480.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_propertySearchQuery.isEmpty && recProps.isNotEmpty) ...[
                    const Text(
                      '💡 Recommended for SEO:',
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Wrap(
                      spacing: 6.0,
                      runSpacing: 6.0,
                      children: recProps.map((prop) {
                        final isAdded = entity.properties.containsKey(prop.id);
                        return ActionChip(
                          padding: EdgeInsets.zero,
                          label: Text(
                            prop.label,
                            style: TextStyle(
                              fontSize: 10.0,
                              fontWeight: FontWeight.bold,
                              decoration: isAdded
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withOpacity(0.4),
                          onPressed: () {
                            Navigator.pop(context);
                            _onPropertySelected(appState, entity, prop);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12.0),
                    const Divider(),
                  ],
                  TextField(
                    controller: _searchPropertyController,
                    decoration: const InputDecoration(
                      hintText: 'Search hundreds of properties...',
                      prefixIcon: Icon(Icons.search, size: 20.0),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        _propertySearchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12.0),
                  Expanded(
                    child: filteredProps.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.extension_off_outlined,
                                  size: 36.0,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 8.0),
                                const Text(
                                  'No standard properties found.',
                                  style: TextStyle(fontStyle: FontStyle.italic),
                                ),
                                const SizedBox(height: 12.0),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.add, size: 16.0),
                                  label: const Text('Add Custom User Field'),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showCustomPropCreationDialog(
                                      appState,
                                      entity,
                                    );
                                  },
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredProps.length,
                            itemBuilder: (context, index) {
                              final prop = filteredProps[index];
                              final propLabel = prop.label;
                              final isAlreadyAdded = entity.properties
                                  .containsKey(prop.id);
                              return ListTile(
                                title: Row(
                                  children: [
                                    Text(
                                      propLabel,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isAlreadyAdded
                                            ? Colors.grey
                                            : null,
                                      ),
                                    ),
                                    if (isAlreadyAdded) ...[
                                      const SizedBox(width: 8.0),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6.0,
                                          vertical: 1.0,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(
                                            8.0,
                                          ),
                                        ),
                                        child: const Text(
                                          'Added',
                                          style: TextStyle(fontSize: 10.0),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  '${prop.comment}\nExpected: ${prop.ranges.map((r) => r.startsWith('schema:') ? r.substring(7) : r).join(', ')}',
                                  style: const TextStyle(fontSize: 11.0),
                                ),
                                dense: true,
                                trailing: const Icon(Icons.add, size: 16.0),
                                onTap: () {
                                  Navigator.pop(context);
                                  _onPropertySelected(appState, entity, prop);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              if (filteredProps.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.add_circle_outline, size: 14.0),
                  label: const Text('Add Custom Field'),
                  onPressed: () {
                    Navigator.pop(context);
                    _showCustomPropCreationDialog(appState, entity);
                  },
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<String> _getSubclassesOf(String classId) {
    final List<String> subclasses = [];
    final classes = SchemaService.instance.classes;
    classes.forEach((id, cls) {
      if (id != classId && SchemaService.instance.isSubclassOf(id, classId)) {
        subclasses.add(id);
      }
    });
    subclasses.sort((a, b) => a.compareTo(b));
    return subclasses;
  }

  void _onPropertySelected(
    AppState appState,
    SchemaEntity entity,
    SchemaProperty prop,
  ) {
    final ranges = prop.ranges;
    final nonPrimitiveClasses = ranges.where((r) {
      final isPrim =
          r == 'schema:Text' ||
          r == 'schema:URL' ||
          r == 'schema:Number' ||
          r == 'schema:Boolean' ||
          r == 'schema:Integer' ||
          r == 'schema:Date' ||
          r == 'schema:DateTime';
      return !isPrim;
    }).toList();

    if (nonPrimitiveClasses.isNotEmpty) {
      // Collect all subclasses for each of the nonPrimitiveClasses
      final Map<String, List<String>> classToSubclasses = {};
      final Set<String> allSubclassIds = {};
      for (var baseClass in nonPrimitiveClasses) {
        final subs = _getSubclassesOf(baseClass);
        classToSubclasses[baseClass] = subs;
        allSubclassIds.addAll(subs);
      }

      final List<MapEntry<String, String>> typeOptions = [];
      // First add the direct expected classes
      for (var baseClass in nonPrimitiveClasses) {
        typeOptions.add(MapEntry(baseClass, 'Base expected type'));
      }
      // Then add the subclasses that are not already listed as direct expected classes
      for (var baseClass in nonPrimitiveClasses) {
        final subs = classToSubclasses[baseClass] ?? [];
        for (var sub in subs) {
          if (!nonPrimitiveClasses.contains(sub)) {
            final baseLabel = baseClass.startsWith('schema:') ? baseClass.substring(7) : baseClass;
            typeOptions.add(MapEntry(sub, 'Subtype of $baseLabel'));
          }
        }
      }

      // Deduplicate options if a class is subclass of multiple parent classes
      final Set<String> seenIds = {};
      final List<MapEntry<String, String>> uniqueTypeOptions = [];
      for (var entry in typeOptions) {
        if (!seenIds.contains(entry.key)) {
          seenIds.add(entry.key);
          uniqueTypeOptions.add(entry);
        }
      }

      String searchVal = '';
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredOptions = uniqueTypeOptions.where((option) {
              final label = option.key.startsWith('schema:') ? option.key.substring(7) : option.key;
              final query = searchVal.toLowerCase();
              return label.toLowerCase().contains(query) || option.value.toLowerCase().contains(query);
            }).toList();

            return AlertDialog(
              title: Text('Select Input Type for "${prop.label}"'),
              content: SizedBox(
                width: 480.0,
                height: 400.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'This property supports structured objects. Select an expected type or a more specific subtype:',
                      style: TextStyle(fontSize: 12.0),
                    ),
                    const SizedBox(height: 12.0),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search types & subclasses...',
                        prefixIcon: Icon(Icons.search, size: 20.0),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          searchVal = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12.0),
                    Expanded(
                      child: ListView(
                        children: [
                          ...filteredOptions.map((option) {
                            final clsId = option.key;
                            final isSubclass = option.value != 'Base expected type';
                            final label = clsId.startsWith('schema:') ? clsId.substring(7) : clsId;
                            final comment = SchemaService.instance.classes[clsId]?.comment ?? '';
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4.0),
                              child: ListTile(
                                leading: Icon(
                                  isSubclass ? Icons.subdirectory_arrow_right : Icons.playlist_add_circle_outlined,
                                  color: isSubclass ? Colors.orange : Colors.blue,
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      'Create "${label}"',
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 6.0),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                      decoration: BoxDecoration(
                                        color: isSubclass ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                      child: Text(
                                        option.value,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: isSubclass ? Colors.orange.shade700 : Colors.blue.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: comment.isNotEmpty
                                    ? Text(
                                        comment,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11.0),
                                      )
                                    : null,
                                dense: true,
                                onTap: () {
                                  final nested = SchemaEntity(
                                    id: 'nest_${DateTime.now().microsecondsSinceEpoch}',
                                    type: clsId,
                                    properties: {},
                                  );
                                  appState.addPropertyToEntity(entity, prop.id, nested);
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          }).toList(),
                          Card(
                            margin: const EdgeInsets.symmetric(vertical: 4.0),
                            child: ListTile(
                              leading: const Icon(Icons.edit_note, color: Colors.green),
                              title: const Text(
                                'Add simple text input field',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                              ),
                              dense: true,
                              onTap: () {
                                appState.addPropertyToEntity(entity, prop.id, '');
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        ),
      );
    } else {
      final bool isMapContainer = _isPropertyMapContainer(entity, prop.id);
      final initialValue = isMapContainer ? {'en': ''} : (ranges.contains('schema:Boolean') ? false : '');
      appState.addPropertyToEntity(entity, prop.id, initialValue);
    }
  }

  bool _isPropertyMapContainer(SchemaEntity entity, String propId) {
    final propName = propId.startsWith('schema:') ? propId.substring(7) : propId;
    final ctx = entity.customContext;
    if (ctx != null && ctx.containsKey(propName)) {
      final termMapping = ctx[propName];
      if (termMapping is Map && termMapping.containsKey('@container')) {
        return true;
      }
    }
    return false;
  }

  void _showAddMapKeyDialog(
    AppState appState,
    SchemaEntity entity,
    String propId,
    SchemaValue sValue,
    Map<String, dynamic> mapVal,
  ) {
    final keyController = TextEditingController();
    final valueController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Key to Structured Map', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyController,
                decoration: const InputDecoration(
                  labelText: 'Key / Language code',
                  hintText: 'e.g. gb, ar, es, indexLabel',
                ),
              ),
              const SizedBox(height: 12.0),
              TextField(
                controller: valueController,
                decoration: const InputDecoration(
                  labelText: 'Initial Value',
                  hintText: 'Enter value text...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final keyText = keyController.text.trim();
                if (keyText.isNotEmpty) {
                  final newMap = Map<String, dynamic>.from(mapVal);
                  newMap[keyText] = valueController.text;
                  appState.updatePropertyValue(entity, propId, sValue.id, newMap);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showCustomPropCreationDialog(AppState appState, SchemaEntity entity) {
    _customPropController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Extension Property'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter the key name for your custom metadata extension property. It will be added to the output document.',
              style: TextStyle(fontSize: 12.0),
            ),
            const SizedBox(height: 12.0),
            TextField(
              controller: _customPropController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g., internalId, promoCode, seoCategory',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = _customPropController.text.trim();
              if (text.isNotEmpty) {
                final propId = text.contains(':') ? text : 'schema:${text}';
                appState.addPropertyToEntity(entity, propId, '');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Custom field "${text}" added!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Add Field'),
          ),
        ],
      ),
    );
  }

  void _showCreateDocDialog(AppState appState) {
    _docNameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Schema Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Give your document a descriptive name. The document will start with a default Person type, which you can easily change inside the builder.',
              style: TextStyle(fontSize: 12.0),
            ),
            const SizedBox(height: 12.0),
            TextField(
              controller: _docNameController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g., Company Header Markup',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _docNameController.text.trim();
              appState.createNewDocument(name, 'schema:Person');
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(AppState appState, int index, String currentName) {
    _docNameController.text = currentName;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: _docNameController,
          autofocus: true,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _docNameController.text.trim();
              if (name.isNotEmpty) {
                appState.renameDocument(index, name);
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(AppState appState) {
    _importController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import JSON-LD Schema'),
        content: SizedBox(
          width: 500.0,
          height: 350.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Paste valid JSON-LD structured data below. The visual editor will parse it and construct editable nodes automatically!',
                style: TextStyle(fontSize: 13.0),
              ),
              const SizedBox(height: 12.0),
              Expanded(
                child: TextField(
                  controller: _importController,
                  maxLines: null,
                  minLines: 10,
                  style: const TextStyle(fontFamily: 'Courier', fontSize: 12.0),
                  decoration: const InputDecoration(
                    hintText:
                        '{\n  "@context": "https://schema.org",\n  "@type": "Person",\n  "name": "Jane Doe"\n}',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final success = appState.importJsonLd(_importController.text);
              if (success) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Schema imported successfully! 🚀'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Failed to parse JSON. Please verify standard JSON format.',
                    ),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mobileTabController?.dispose();
    _horizontalScrollController.dispose();
    _importController.dispose();
    _searchClassController.dispose();
    _searchPropertyController.dispose();
    _docNameController.dispose();
    _customPropController.dispose();
    _searchMarkupController.dispose();
    super.dispose();
  }

  Widget _buildLeftSidebar(AppState appState) {
    final allCategoryClasses = SchemaService.instance.classes.values.toList();
    final filteredClasses = allCategoryClasses.where((cls) {
      if (_classSearchQuery.isEmpty) {
        return true;
      }
      return cls.label.toLowerCase().contains(
            _classSearchQuery.toLowerCase(),
          ) ||
          cls.id.toLowerCase().contains(_classSearchQuery.toLowerCase());
    }).toList();
    final filteredDocuments = appState.documents.where((doc) {
      if (_markupSearchQuery.isEmpty) {
        return true;
      }
      return doc.name.toLowerCase().contains(
            _markupSearchQuery.toLowerCase(),
          ) ||
          doc.type.toLowerCase().contains(_markupSearchQuery.toLowerCase());
    }).toList();
    return Container(
      color:
          Theme.of(context).colorScheme.surfaceContainerLow ??
          Theme.of(context).colorScheme.surface.withOpacity(0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Row(
              children: [
                Text(
                  'My Active Markups',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_box_outlined, size: 20.0),
                  tooltip: 'Create New Document',
                  onPressed: () => _showCreateDocDialog(appState),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 4.0,
            ),
            child: TextField(
              controller: _searchMarkupController,
              decoration: InputDecoration(
                hintText: 'Search active markups...',
                prefixIcon: const Icon(Icons.search, size: 16.0),
                suffixIcon: _markupSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14.0),
                        onPressed: () {
                          _searchMarkupController.clear();
                          setState(() {
                            _markupSearchQuery = '';
                          });
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.all(8.0),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8.0)),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _markupSearchQuery = val;
                });
              },
            ),
          ),
          Container(
            height: 140.0,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: filteredDocuments.isEmpty
                ? const Center(
                    child: Text(
                      'No active markups found.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 12.0,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredDocuments.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocuments[index];
                      final originalIndex = appState.documents.indexOf(doc);
                      final isSelected =
                          appState.selectedDocumentIndex == originalIndex;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        elevation: 0.0,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHigh,
                        child: ListTile(
                          contentPadding: const EdgeInsets.only(
                            left: 12.0,
                            right: 6.0,
                          ),
                          dense: true,
                          title: Text(
                            doc.name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12.0,
                              color: isSelected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            doc.type.replaceAll('schema:', ''),
                            style: const TextStyle(fontSize: 10.0),
                          ),
                          onTap: () => appState.selectDocument(originalIndex),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 14.0,
                                ),
                                tooltip: 'Rename',
                                onPressed: () => _showRenameDialog(
                                  appState,
                                  originalIndex,
                                  doc.name,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 14.0),
                                tooltip: 'Duplicate',
                                onPressed: () =>
                                    appState.duplicateDocument(originalIndex),
                              ),
                              if (appState.documents.length > 1)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 14.0,
                                    color: Colors.redAccent,
                                  ),
                                  tooltip: 'Delete',
                                  onPressed: () =>
                                      appState.deleteDocument(originalIndex),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: Text(
              'Instantiate New Class Type',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchClassController,
              decoration: InputDecoration(
                hintText: 'Search 800+ types (e.g. Recipe)...',
                prefixIcon: const Icon(Icons.search, size: 18.0),
                suffixIcon: _classSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16.0),
                        onPressed: () {
                          _searchClassController.clear();
                          setState(() {
                            _classSearchQuery = '';
                          });
                        },
                      )
                    : null,
                isDense: true,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8.0)),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _classSearchQuery = val;
                });
              },
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: filteredClasses.isEmpty
                ? const Center(
                    child: Text(
                      'No classes found.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 12.0,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    itemCount: filteredClasses.length,
                    itemBuilder: (context, index) {
                      final cls = filteredClasses[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        elevation: 0.0,
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: ListTile(
                          title: Text(
                            cls.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                          subtitle: Text(
                            cls.comment,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10.5),
                          ),
                          dense: true,
                          trailing: const Icon(
                            Icons.add_circle_outline,
                            size: 14.0,
                          ),
                          onTap: () {
                            appState.createNewDocument(
                              'New ${cls.label} Document',
                              cls.id,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Created new ${cls.label} document successfully!',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAboutApp() {
    showAboutDialog(
      context: context,
      applicationName: 'JSON LD Visual Editor',
      applicationVersion: '1.0.0',
      applicationIcon: Image.asset(
        'assets/json_ld.png',
        width: 48.0,
        height: 48.0,
      ),
      applicationLegalese: '© 2026 Antinna. All rights reserved.',
      children: [
        const SizedBox(height: 12.0),
        const Text(
          'JSON LD Visual Editor is a professional visual Schema IDE and utility designed to easily construct, edit, and validate Schema.org structured data offline. Generate microdata, boost your website SEO, and manage markup documents instantly.',
          style: TextStyle(fontSize: 13.0, height: 1.4),
        ),
      ],
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Image.asset(
              'assets/json_ld.png',
              width: 28.0,
              height: 28.0,
            ),
            const SizedBox(width: 8.0),
            const Text('Privacy Policy'),
          ],
        ),
        content: const SizedBox(
          width: 500.0,
          height: 400.0,
          child: SingleChildScrollView(
            child: Text(
              'Privacy Policy for JSON LD Visual Editor\n\n'
              'Last updated: July 2026\n\n'
              'Antinna ("us", "we", or "our") operates the JSON LD Visual Editor application. This Privacy Policy informs you of our policies regarding the collection, use, and disclosure of personal data when you use our App.\n\n'
              '1. Information Collection and Use\n'
              'We do not collect, store, transmit, or share any personally identifiable information (PII) or personal data. The JSON LD Visual Editor runs completely offline on your device. All files, documents, and specifications you create, edit, or import are stored locally on your device\'s private database and are never sent to any external servers.\n\n'
              '2. External Connections\n'
              'Our application makes secure external network requests to schema.org to dynamically fetch the latest semantic schema specifications. No personal details, unique identifiers, or usage statistics are transmitted during this synchronization.\n\n'
              '3. Links to Other Sites\n'
              'Our application contains links to external social media sites (including GitHub, YouTube, Instagram, X/Twitter, Facebook, and search.google.com) that are not operated by us. We strongly advise you to review the Privacy Policy of every site you visit.\n\n'
              '4. Children\'s Privacy\n'
              'Our Service does not address anyone under the age of 13. We do not knowingly collect personally identifiable information from children.\n\n'
              '5. Changes to This Privacy Policy\n'
              'We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy within this App.\n\n'
              'Contact Us\n'
              'If you have any questions about this Privacy Policy, please contact us via our social channels.',
              style: TextStyle(fontSize: 12.0, height: 1.4),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _PrimitiveTextField extends StatefulWidget {
  final AppState appState;
  final SchemaEntity parentEntity;
  final String propId;
  final SchemaValue sValue;
  final List<String> ranges;
  final IconData? inputIcon;

  const _PrimitiveTextField({
    Key? key,
    required this.appState,
    required this.parentEntity,
    required this.propId,
    required this.sValue,
    required this.ranges,
    this.inputIcon,
  }) : super(key: key);

  @override
  State<_PrimitiveTextField> createState() => _PrimitiveTextFieldState();
}

class _PrimitiveTextFieldState extends State<_PrimitiveTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.sValue.value.toString());
  }

  @override
  void didUpdateWidget(covariant _PrimitiveTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String newVal = widget.sValue.value.toString();
    if (newVal != _controller.text) {
      final currentSelection = _controller.selection;
      _controller.text = newVal;
      if (currentSelection.isValid) {
        final start = math.min(currentSelection.start, newVal.length);
        final end = math.min(currentSelection.end, newVal.length);
        _controller.selection = TextSelection(baseOffset: start, extentOffset: end);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showDatePickerIcon = widget.ranges.contains('schema:Date') ||
        widget.ranges.contains('schema:DateTime');

    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        prefixIcon: widget.inputIcon != null ? Icon(widget.inputIcon, size: 14.0) : null,
        hintText: 'Enter value...',
        isDense: true,
        suffixIcon: showDatePickerIcon
            ? IconButton(
                icon: const Icon(Icons.date_range, size: 14.0),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    final dateStr = picked.toIso8601String().split('T').first;
                    widget.appState.updatePropertyValue(
                      widget.parentEntity,
                      widget.propId,
                      widget.sValue.id,
                      dateStr,
                    );
                  }
                },
              )
            : null,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        ),
      ),
      keyboardType: widget.ranges.contains('schema:Number')
          ? TextInputType.number
          : TextInputType.text,
      onChanged: (newVal) {
        if (widget.ranges.contains('schema:Number')) {
          final parsed = num.tryParse(newVal);
          if (parsed != null) {
            widget.appState.updatePropertyValue(
              widget.parentEntity,
              widget.propId,
              widget.sValue.id,
              parsed,
            );
            return;
          }
        }
        widget.appState.updatePropertyValue(
          widget.parentEntity,
          widget.propId,
          widget.sValue.id,
          newVal,
        );
      },
    );
  }
}

class _MapValueTextField extends StatefulWidget {
  final AppState appState;
  final SchemaEntity parentEntity;
  final String propId;
  final SchemaValue sValue;
  final Map<String, dynamic> mapVal;
  final String mapKey;

  const _MapValueTextField({
    Key? key,
    required this.appState,
    required this.parentEntity,
    required this.propId,
    required this.sValue,
    required this.mapVal,
    required this.mapKey,
  }) : super(key: key);

  @override
  State<_MapValueTextField> createState() => _MapValueTextFieldState();
}

class _MapValueTextFieldState extends State<_MapValueTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.mapVal[widget.mapKey]?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _MapValueTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String newVal = widget.mapVal[widget.mapKey]?.toString() ?? '';
    if (newVal != _controller.text) {
      final currentSelection = _controller.selection;
      _controller.text = newVal;
      if (currentSelection.isValid) {
        final start = math.min(currentSelection.start, newVal.length);
        final end = math.min(currentSelection.end, newVal.length);
        _controller.selection = TextSelection(baseOffset: start, extentOffset: end);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: const TextStyle(fontSize: 12.0),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        border: OutlineInputBorder(),
      ),
      onChanged: (val) {
        final newMap = Map<String, dynamic>.from(widget.mapVal);
        newMap[widget.mapKey] = val;
        widget.appState.updatePropertyValue(
          widget.parentEntity,
          widget.propId,
          widget.sValue.id,
          newMap,
        );
      },
    );
  }
}

class SocialCard extends StatelessWidget {
  final String platform;
  final String profileName;
  final String imageAsset;
  final String url;

  const SocialCard({
    super.key,
    required this.platform,
    required this.profileName,
    required this.imageAsset,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.0,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.8,
        ),
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6.0),
          child: Image.asset(
            imageAsset,
            width: 32.0,
            height: 32.0,
            fit: BoxFit.cover,
          ),
        ),
        title: Text(
          platform,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0),
        ),
        subtitle: Text(
          profileName,
          style: const TextStyle(fontSize: 11.0, color: Colors.grey),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.open_in_new, size: 14.0),
        onTap: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      ),
    );
  }
}
