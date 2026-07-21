import 'package:flutter/material.dart';
import 'package:jsonld/globals/app_state.dart';
import 'package:jsonld/schema_service.dart';
import 'package:jsonld/globals/themes.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jsonld/schema_entity.dart';
import 'package:jsonld/schema_value.dart';
import 'package:jsonld/models/schema_class.dart';
import 'package:jsonld/models/schema_property.dart';
import 'package:jsonld/globals/download_helper.dart' as dl;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() {
    return _HomePageState();
  }
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
  final Set<String> _collapsedEntityIds = {};
  bool _isFullScreenWorkspace = false;
  List<String> _columnPath = [];
  List<String> _treeInspectPath = [];
  DateTime? _lastBackTime;
  bool _useDoubleBackStrategy = false; // Configurable exit strategy: true for Double-Back, false for Confirmation Dialog!
  final ScrollController _columnScrollController = ScrollController();
  final ScrollController _sidebarScrollController = ScrollController();
  final FocusNode _markupSearchFocusNode = FocusNode();

  final TransformationController _transformationController =
      TransformationController();
  double _canvasScale = 1.0;

  late TabController _tabController;

  final ScrollController _workspaceVerticalController = ScrollController();
  final ScrollController _workspaceHorizontalController = ScrollController();
  final ScrollController _treeVerticalController = ScrollController();
  final ScrollController _treeHorizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _markupSearchFocusNode.addListener(() {
      if (_markupSearchFocusNode.hasFocus) {
        if (_sidebarScrollController.hasClients) {
          _sidebarScrollController.animateTo(
            150.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _transformationController.addListener(_onCanvasTransform);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppState.of(context, listen: false).initSchemaService();
    });
  }

  void _onTabChanged() {
    if (_tabController.index == 2) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    setState(() {});
  }

  void _onCanvasTransform() {
    final double scale = _transformationController.value.getMaxScaleOnAxis();
    if ((scale - _canvasScale).abs() > 0.01) {
      setState(() {
        _canvasScale = scale;
      });
    }
  }

  List<String> _getInheritancePath(String classId) {
    final List<String> path = [];
    final classes = SchemaService.instance.classes;
    String? current = classId;
    final Set<String> visited = {};
    while (current != null && !visited.contains(current)) {
      visited.add(current!);
      final label =
          current!.startsWith('schema:') ? current?.substring(7) : current;
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

  @override
  Widget build(BuildContext context) {
    final appState = AppState.of(context);
    final isWide = MediaQuery.of(context).size.width >= 1100;
    return WillPopScope(
      onWillPop: () async {
        // 1. Check if any textfield or input currently has focus (keyboard visible)
        if (FocusManager.instance.primaryFocus != null &&
            FocusManager.instance.primaryFocus!.context?.widget is EditableText) {
          FocusManager.instance.primaryFocus!.unfocus();
          return false; // Dismiss keyboard, consume back event, do not exit
        }
        if (_markupSearchFocusNode.hasFocus) {
          _markupSearchFocusNode.unfocus();
          return false;
        }

        // 2. If we have active cascading column nodes open, pressing physical back goes back to the previous node
        final bool isWorkspaceActive = isWide || _tabController.index == 1;
        if (_columnPath.isNotEmpty && isWorkspaceActive) {
          setState(() {
            _columnPath.removeLast();
          });
          return false; // Intercept & do not exit app
        }

        // 3. App Exit Flow (Supports both strategies: Double-Back or Confirmation Dialog)
        if (_useDoubleBackStrategy) {
          final now = DateTime.now();
          if (_lastBackTime == null ||
              now.difference(_lastBackTime!) > const Duration(milliseconds: 2000)) {
            _lastBackTime = now;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Press back again to exit.'),
                duration: Duration(milliseconds: 1500),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return false; // Intercept & do not exit
          }
          return true; // Exit
        } else {
          // Confirmation Dialog Strategy
          final bool? shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Exit App'),
              content: const Text('Are you sure you want to exit the app?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Exit'),
                ),
              ],
            ),
          );
          return shouldExit ?? false;
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _isFullScreenWorkspace
            ? null
            : Drawer(
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
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0, vertical: 2.0),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 4.0),
                    child: Card(
                      elevation: 0.0,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.06),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.12),
                          width: 1.0,
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.info_outline,
                              color: Theme.of(context).colorScheme.primary),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 4.0),
                    child: Card(
                      elevation: 0.0,
                      color: Theme.of(context)
                          .colorScheme
                          .secondary
                          .withOpacity(0.06),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.12),
                          width: 1.0,
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondary
                                .withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.privacy_tip_outlined,
                              color: Theme.of(context).colorScheme.secondary),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 4.0),
                    child: Card(
                      elevation: 0.0,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.06),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.12),
                          width: 1.0,
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.gavel_outlined,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        title: const Text(
                          'Terms & Conditions',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18.0),
                        onTap: () {
                          Navigator.pop(context); // close drawer
                          _showTermsAndConditions();
                        },
                      ),
                    ),
                  ),
                  const Divider(indent: 16.0, endIndent: 16.0, height: 24.0),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
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
                          url:
                              'https://www.facebook.com/profile.php?id=100083138576317',
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
      appBar: _isFullScreenWorkspace
          ? null
          : AppBar(
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
                          'Json LD Visual Editor',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18.0,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isWide
                              ? 'Structured Schema.org Metadata Visualizer & Creator'
                              : 'Visual Schema Creator',
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
                      style: TextStyle(
                          fontSize: 12.0, fontWeight: FontWeight.bold),
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
                    appState.theme == darkTheme
                        ? Icons.light_mode
                        : Icons.dark_mode,
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
          : _isFullScreenWorkspace
              ? SafeArea(
                  child: _buildWorkspace(appState),
                )
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
                            child: _buildWorkspace(appState),
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
                            controller: _tabController,
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
                              controller: _tabController,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _buildLeftSidebar(appState),
                                _buildWorkspace(appState),
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

  void _showSubNodeRenameDialog(AppState appState, SchemaEntity targetEntity) {
    _docNameController.text = targetEntity.name;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Sub-node Object'),
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
                targetEntity.name = name;
                final root = appState.rootEntity;
                if (root != null) {
                  appState.persistDocument(root);
                  appState.generateJsonLdOutput();
                  appState.notifyListeners();
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
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
        : (isError
            ? colorScheme.errorContainer
            : (colorScheme.surfaceContainerHighest ??
                Colors.grey.withOpacity(0.15)));
    final Color fgColor = isSaving
        ? colorScheme.onSecondaryContainer
        : (isError
            ? colorScheme.onErrorContainer
            : colorScheme.onSurfaceVariant);
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

  Widget _buildWorkspace(AppState appState) {
    final root = appState.rootEntity;
    if (root == null) {
      return const Center(
          child: Text(
              'No active document. Create one in Documents tab to begin.'));
    }

    if (_showTreeView) {
      return Stack(
        children: [
          _buildTreeViewWorkspace(appState),
          Positioned(
            bottom: 20.0,
            right: 20.0,
            child: FloatingActionButton.small(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 4.0,
              tooltip: _isFullScreenWorkspace ? 'Exit Fullscreen' : 'Fullscreen Workspace',
              onPressed: () {
                setState(() {
                  _isFullScreenWorkspace = !_isFullScreenWorkspace;
                });
              },
              child: Icon(
                _isFullScreenWorkspace ? Icons.fullscreen_exit : Icons.fullscreen,
                size: 20.0,
              ),
            ),
          ),
        ],
      );
    }

    final activeColumns = _resolveActiveColumns(root);
    final isWide = MediaQuery.of(context).size.width >= 1100;

    final mainColumnList = isWide
        ? Scrollbar(
            controller: _columnScrollController,
            thumbVisibility: true,
            child: ListView.separated(
              controller: _columnScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16.0),
              itemCount: activeColumns.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16.0),
              itemBuilder: (context, index) {
                return _buildColumnPane(appState, activeColumns[index],
                    index, activeColumns);
              },
            ),
          )
        : _buildMobileColumnView(appState, activeColumns);

    Widget workspaceBody;

    if (_isFullScreenWorkspace) {
      workspaceBody = Container(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: CustomPaint(
          painter: GraphBackgroundPainter(
            gridColor: Theme.of(context).colorScheme.outline.withOpacity(0.08),
            spacing: 40.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Full Screen Blueprint Status Watermark
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.92),
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.architecture,
                      size: 18.0,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Text(
                              '📐 BLUEPRINT STORYBOARD WORKBENCH  •  PATH: ',
                              style: TextStyle(
                                fontSize: 11.0,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            ...activeColumns.map((col) {
                              final isLast = col == activeColumns.last;
                              return Row(
                                children: [
                                  Text(
                                    col.type.replaceAll('schema:', ''),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: isLast ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                                    ),
                                  ),
                                  if (!isLast)
                                    const Icon(
                                      Icons.chevron_right,
                                      size: 14.0,
                                      color: Colors.grey,
                                    ),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: mainColumnList),
            ],
          ),
        ),
      );
    } else {
      workspaceBody = Container(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Elegant workspace toolbar showing total active depth and full screen toggle
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.view_column_outlined,
                    size: 18.0,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8.0),
                  const Text(
                    'Cascading Column Workspace',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.0,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 12.0),
                    label: const Text(
                      'Documentation',
                      style: TextStyle(fontSize: 11.0),
                    ),
                    onPressed: () async {
                      final focused = activeColumns.last;
                      final cleanType = focused.type.replaceAll('schema:', '');
                      final url =
                          'https://schema.org/docs/search_results.html?q=${cleanType}';
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
                              'Schema.org documentation URL copied! 🔗\n${url}',
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
            // Scrollable Column Path
            Expanded(child: mainColumnList),
          ],
        ),
      );
    }

    return Stack(
      children: [
        workspaceBody,
        Positioned(
          bottom: 20.0,
          right: 20.0,
          child: FloatingActionButton.small(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            elevation: 4.0,
            tooltip: _isFullScreenWorkspace ? 'Exit Fullscreen' : 'Fullscreen Workspace',
            onPressed: () {
              setState(() {
                _isFullScreenWorkspace = !_isFullScreenWorkspace;
              });
            },
            child: Icon(
              _isFullScreenWorkspace ? Icons.fullscreen_exit : Icons.fullscreen,
              size: 20.0,
            ),
          ),
        ),
      ],
    );
  }

  List<_FlatTreeNode> _flattenEntity(
    AppState appState,
    SchemaEntity entity, {
    int depth = 0,
    String keyName = 'Root Document',
    SchemaEntity? parentEntity,
  }) {
    final List<_FlatTreeNode> nodes = [];
    final typeLabel = entity.type.startsWith('schema:') ? entity.type.substring(7) : entity.type;

    // 1. Add the Entity node itself
    nodes.add(_FlatTreeNode(
      id: entity.id,
      depth: depth,
      label: entity.name.isNotEmpty ? entity.name : typeLabel,
      typeLabel: typeLabel,
      isEntity: true,
      entity: entity,
      keyName: keyName,
      parentEntity: parentEntity,
    ));

    // If this entity node is collapsed, don't recurse into properties
    if (_collapsedEntityIds.contains(entity.id)) {
      return nodes;
    }

    // 2. For each active property
    for (final entry in entity.properties.entries) {
      final propKey = entry.key;
      final propLabel = propKey.startsWith('schema:') ? propKey.substring(7) : propKey;
      final values = entry.value;

      final propNodeId = '${entity.id}_prop_$propKey';
      nodes.add(_FlatTreeNode(
        id: propNodeId,
        depth: depth + 1,
        label: propLabel,
        typeLabel: '',
        isProperty: true,
        entity: entity,
        propertyKey: propKey,
        parentEntity: entity,
      ));

      // 3. For each value of the property
      for (final val in values) {
        if (val.value is SchemaEntity) {
          nodes.addAll(_flattenEntity(
            appState,
            val.value as SchemaEntity,
            depth: depth + 2,
            keyName: propLabel,
            parentEntity: entity,
          ));
        }
      }
    }

    return nodes;
  }

  Widget _buildFlatTreeNodeRow(AppState appState, _FlatTreeNode node) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Indentation padding
    final double indent = node.depth * 16.0;

    if (node.isEntity) {
      final isCollapsed = _collapsedEntityIds.contains(node.entity!.id);

      return Padding(
        padding: EdgeInsets.only(left: indent, right: 16.0, top: 4.0, bottom: 4.0),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow ?? Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          child: ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.only(left: 8.0, right: 4.0),
            onTap: () {
              // Find path to this entity from root
              final List<String> path = [];
              SchemaEntity? current = appState.rootEntity;
              bool findPath(SchemaEntity ent) {
                if (ent.id == node.entity!.id) {
                  return true;
                }
                for (final entry in ent.properties.entries) {
                  for (final val in entry.value) {
                    if (val.value is SchemaEntity) {
                      final child = val.value as SchemaEntity;
                      path.add(child.id);
                      if (findPath(child)) {
                        return true;
                      }
                      path.removeLast();
                    }
                  }
                }
                return false;
              }
              if (current != null) {
                findPath(current);
              }
              setState(() {
                _columnPath = path;
                _showTreeView = false; // Smoothly slide into active workspace column pane!
              });
            },
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    isCollapsed ? Icons.chevron_right : Icons.expand_more,
                    size: 18.0,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      if (isCollapsed) {
                        _collapsedEntityIds.remove(node.entity!.id);
                      } else {
                        _collapsedEntityIds.add(node.entity!.id);
                      }
                    });
                  },
                ),
                const SizedBox(width: 4.0),
                Icon(
                  node.depth == 0 ? Icons.hub_outlined : Icons.folder_open_outlined,
                  size: 16.0,
                  color: primaryColor,
                ),
              ],
            ),
            title: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${node.keyName ?? "Document"}: ',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.0),
                  ),
                  TextSpan(
                    text: node.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.0,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${node.entity!.properties.length} fields  •  Tap to Open',
              style: const TextStyle(fontSize: 10.0),
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18.0),
              tooltip: 'Actions',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onSelected: (action) {
                if (action == 'rename') {
                  _showSubNodeRenameDialog(appState, node.entity!);
                } else if (action == 'add_field') {
                  _showAddPropertyDialog(appState, node.entity!);
                } else if (action == 'delete') {
                  _confirmDeleteNested(appState, node.entity!);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 14.0),
                      SizedBox(width: 8.0),
                      Text('Rename Object', style: TextStyle(fontSize: 12.0)),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'add_field',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 14.0),
                      SizedBox(width: 8.0),
                      Text('Add Field', style: TextStyle(fontSize: 12.0)),
                    ],
                  ),
                ),
                if (node.depth > 0)
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 14.0, color: Colors.redAccent),
                        SizedBox(width: 8.0),
                        Text('Delete Object', style: TextStyle(fontSize: 12.0, color: Colors.redAccent)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } else if (node.isProperty) {
      final propKey = node.propertyKey!;
      final values = node.parentEntity!.properties[propKey] ?? [];

      return Padding(
        padding: EdgeInsets.only(left: indent, right: 16.0, top: 2.0, bottom: 2.0),
        child: Container(
          decoration: BoxDecoration(
            color: ((Theme.of(context).colorScheme.surfaceContainerHigh ?? Theme.of(context).colorScheme.surfaceVariant)).withOpacity(0.4),
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
            ),
          ),
          child: ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.only(left: 12.0, right: 4.0),
            onTap: () {
              // Find path to parent entity from root
              final List<String> path = [];
              SchemaEntity? current = appState.rootEntity;
              bool findPath(SchemaEntity ent) {
                if (ent.id == node.parentEntity!.id) {
                  return true;
                }
                for (final entry in ent.properties.entries) {
                  for (final val in entry.value) {
                    if (val.value is SchemaEntity) {
                      final child = val.value as SchemaEntity;
                      path.add(child.id);
                      if (findPath(child)) {
                        return true;
                      }
                      path.removeLast();
                    }
                  }
                }
                return false;
              }
              if (current != null) {
                findPath(current);
              }
              setState(() {
                _columnPath = path;
                _showTreeView = false; // Smoothly slide into active workspace column pane!
              });
            },
            leading: Icon(
              Icons.dns_outlined,
              size: 14.0,
              color: Theme.of(context).colorScheme.secondary,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  node.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (values.isNotEmpty) ...[
                  const SizedBox(height: 2.0),
                  Text(
                    values.map((v) => v.value is SchemaEntity ? '(Object)' : '"${v.value}"').join(', '),
                    style: TextStyle(
                      fontSize: 9.5,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18.0),
              tooltip: 'Actions',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onSelected: (action) {
                if (action == 'add_value') {
                  _onAddValuePressed(appState, node.parentEntity!, propKey);
                } else if (action == 'delete_field') {
                  appState.removePropertyFromEntity(node.parentEntity!, propKey);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'add_value',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 14.0),
                      SizedBox(width: 8.0),
                      Text('Add Value', style: TextStyle(fontSize: 12.0)),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete_field',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 14.0, color: Colors.redAccent),
                      SizedBox(width: 8.0),
                      Text('Delete Field', style: TextStyle(fontSize: 12.0, color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildTreeViewWorkspace(AppState appState) {
    final root = appState.rootEntity;
    if (root == null) {
      return const Center(child: Text('No active document. Create one in Documents tab to begin.'));
    }

    final flatNodes = _flattenEntity(appState, root, depth: 0, keyName: 'Root Document');

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            color: Theme.of(context).colorScheme.surfaceContainer ?? Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                Icon(
                  Icons.account_tree_outlined,
                  size: 18.0,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8.0),
                const Text(
                  'Hierarchical Structure Map',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 12.0),
                  label: const Text(
                    'Documentation',
                    style: TextStyle(fontSize: 11.0),
                  ),
                  onPressed: () async {
                    final cleanType = root.type.replaceAll('schema:', '');
                    final url = 'https://schema.org/docs/search_results.html?q=${cleanType}';
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
                            'Schema.org documentation URL copied! 🔗\n${url}',
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
          // Scrollable Tree List - Spacious panning/dragging viewport with horizontal support
          Expanded(
            child: Scrollbar(
              controller: _treeVerticalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _treeVerticalController,
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  controller: _treeHorizontalController,
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    width: 750.0, // Plentiful space for any nesting level to avoid squeezing!
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: flatNodes.map((node) => _buildFlatTreeNodeRow(appState, node)).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileColumnView(
      AppState appState, List<SchemaEntity> activeColumns) {
    final currentDepth = activeColumns.length - 1;
    final focused = activeColumns.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (currentDepth > 0)
          InkWell(
            onTap: () {
              setState(() {
                _columnPath.removeLast();
              });
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withOpacity(0.4),
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_back,
                    size: 16.0,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    'Back to ${activeColumns[currentDepth - 1].type.replaceAll('schema:', '')}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.0,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child:
              _buildColumnPane(appState, focused, currentDepth, activeColumns),
        ),
      ],
    );
  }

  Widget _buildColumnPane(AppState appState, SchemaEntity entity, int depth,
      List<SchemaEntity> activeColumns) {
    final typeLabel = entity.type.startsWith('schema:')
        ? entity.type.substring(7)
        : entity.type;
    final schemaClass = SchemaService.instance.classes[entity.type];
    final classComment = schemaClass?.comment ?? 'No description available.';

    return Container(
      width: 360.0,
      margin: const EdgeInsets.symmetric(horizontal: 6.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  depth == 0 ? Icons.hub_outlined : Icons.layers_outlined,
                  size: 16.0,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entity.name.isNotEmpty
                            ? entity.name
                            : 'Untitled Object',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'type = ${typeLabel}',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 15.0),
                  tooltip: 'Rename Object',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    if (depth == 0) {
                      _showRenameDialog(appState, appState.selectedDocumentIndex, entity.name);
                    } else {
                      _showSubNodeRenameDialog(appState, entity);
                    }
                  },
                ),
                const SizedBox(width: 8.0),
                if (depth > 0) ...[
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 15.0, color: Colors.redAccent),
                    tooltip: 'Delete nested object',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      _confirmDeleteNested(appState, entity);
                    },
                  ),
                  const SizedBox(width: 8.0),
                ],
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 15.0),
                  tooltip: 'Add Field',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showAddPropertyDialog(appState, entity),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    classComment,
                    style: TextStyle(
                      fontSize: 11.0,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  if (depth == 0) ...[
                    _BaseUriField(appState: appState, entity: entity),
                    const SizedBox(height: 12.0),
                  ],
                  const Divider(),
                  const SizedBox(height: 8.0),
                  if (entity.properties.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 24.0, horizontal: 12.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.playlist_add,
                              size: 32.0,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 8.0),
                            const Text(
                              'No fields configured.',
                              style: TextStyle(
                                fontSize: 12.0,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            TextButton.icon(
                              icon: const Icon(Icons.add, size: 14.0),
                              label: const Text('Add property',
                                  style: TextStyle(fontSize: 11.0)),
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
                      return _buildColumnPropertyRow(appState, entity, propId,
                          values, depth, activeColumns);
                    }).toList(),
                  if (entity.properties.isNotEmpty) ...[
                    const SizedBox(height: 12.0),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 14.0),
                      label: const Text('Add field',
                          style: TextStyle(fontSize: 11.0)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      ),
                      onPressed: () => _showAddPropertyDialog(appState, entity),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnPropertyRow(
    AppState appState,
    SchemaEntity entity,
    String propId,
    List<SchemaValue> values,
    int depth,
    List<SchemaEntity> activeColumns,
  ) {
    final propDef = SchemaService.instance.properties[propId];
    final propName =
        propId.startsWith('schema:') ? propId.substring(7) : propId;
    final comment = propDef?.comment ?? 'Custom user extension field';
    final List<String> ranges = propDef?.ranges ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: (Theme.of(context).colorScheme.surfaceContainer ?? Theme.of(context).colorScheme.surfaceVariant).withOpacity(0.35),
        borderRadius: BorderRadius.circular(4.0),
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.tertiary.withOpacity(0.6),
            width: 3.0,
          ),
          top: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.08)),
          right: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.08)),
          bottom: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Tooltip(
                message: comment,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      propName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.0,
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    Icon(
                      Icons.info_outline,
                      size: 11.0,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 14.0),
                    tooltip: 'Add compliant value',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      _onAddValuePressed(appState, entity, propId);
                    },
                  ),
                  const SizedBox(width: 4.0),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 14.0),
                    tooltip: 'Remove field',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      appState.removePropertyFromEntity(entity, propId);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          ...values.map((v) {
            final isEntity = v.value is SchemaEntity;
            if (isEntity) {
              final childEntity = v.value as SchemaEntity;
              final childTypeLabel = childEntity.type.replaceAll('schema:', '');
              final bool isActiveChild = (depth + 1 < activeColumns.length) &&
                  (activeColumns[depth + 1].id == childEntity.id);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _columnPath = [
                        ..._columnPath.sublist(0, depth),
                        childEntity.id
                      ];
                      _smoothScrollToRight();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: isActiveChild
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.05),
                      borderRadius: BorderRadius.circular(4.0),
                      border: Border.all(
                        color: isActiveChild
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.15),
                        width: isActiveChild ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 14.0,
                          color: isActiveChild
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                childEntity.name.isNotEmpty
                                    ? childEntity.name
                                    : childTypeLabel,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                  color: isActiveChild
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'type = ${childTypeLabel}',
                                style: TextStyle(
                                  fontSize: 9.0,
                                  color: isActiveChild
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer
                                          .withOpacity(0.7)
                                      : Theme.of(context).colorScheme.outline,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (values.length > 1) ...[
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                size: 13.0, color: Colors.red),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              appState.removePropertyValue(
                                  entity, propId, v.id);
                            },
                          ),
                          const SizedBox(width: 8.0),
                        ],
                        Icon(
                          Icons.chevron_right,
                          size: 14.0,
                          color: isActiveChild
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            } else {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildValueEditor(appState, entity, propId, v),
                    ),
                    if (values.length > 1) ...[
                      const SizedBox(width: 4.0),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            size: 14.0, color: Colors.redAccent),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          appState.removePropertyValue(entity, propId, v.id);
                        },
                      ),
                    ],
                  ],
                ),
              );
            }
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildEntityEditorCard(
    AppState appState,
    SchemaEntity entity, {
    bool isRoot = false,
  }) {
    final typeLabel = entity.type.startsWith('schema:')
        ? entity.type.substring(7)
        : entity.type;
    final schemaClass = SchemaService.instance.classes[entity.type];
    final classComment = schemaClass?.comment ?? 'No description available.';
    return Card(
      elevation: isRoot ? 2.0 : 0.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      color: isRoot
          ? Theme.of(context).colorScheme.surfaceContainerLow
          : Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(
          color: isRoot
              ? Theme.of(context).colorScheme.primary.withOpacity(0.25)
              : Theme.of(context).colorScheme.outline.withOpacity(0.12),
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isRoot
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondary.withOpacity(0.6),
                width: 5.0,
              ),
            ),
          ),
          child: Padding(
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
                    Expanded(
                      child: Text(
                        isRoot
                            ? 'Root Entity: @type = ${typeLabel}'
                            : 'Nested Object: @type = ${typeLabel}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    if (isRoot)
                      IconButton(
                        icon: Icon(
                          _isFullScreenWorkspace
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24.0,
                        ),
                        tooltip: _isFullScreenWorkspace
                            ? 'Exit Fullscreen Mode'
                            : 'Enter Fullscreen Mode',
                        onPressed: () {
                          setState(() {
                            _isFullScreenWorkspace = !_isFullScreenWorkspace;
                          });
                        },
                      ),
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
                    return _buildPropertyRow(appState, entity, propId, values);
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
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyRow(
    AppState appState,
    SchemaEntity entity,
    String propId,
    List<SchemaValue> values,
  ) {
    final propDef = SchemaService.instance.properties[propId];
    final propName =
        propId.startsWith('schema:') ? propId.substring(7) : propId;
    final comment = propDef?.comment ?? 'Custom user extension field';
    final List<String> ranges = propDef?.ranges ?? [];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: (Theme.of(context).colorScheme.surfaceContainer ?? Theme.of(context).colorScheme.surfaceVariant).withOpacity(0.35),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8.0,
            runSpacing: 4.0,
            children: [
              Tooltip(
                message: comment,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ranges.isNotEmpty)
                    ...ranges.take(2).map((range) {
                      final isPrim = range == 'schema:Text' ||
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
                              final initialVal =
                                  range == 'schema:Boolean' ? false : '';
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
                            }
                          },
                        ),
                      );
                    }).toList(),
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
            ],
          ),
          ...values.map((v) {
            final isEntity = v.value is SchemaEntity;
            if (isEntity) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (values.length > 1)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 14.0,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'Remove this nested object',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 11.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            appState.removePropertyValue(entity, propId, v.id);
                          },
                        ),
                      ),
                    _buildEntityEditorCard(appState, v.value as SchemaEntity),
                  ],
                ),
              );
            } else {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildValueEditor(appState, entity, propId, v),
                    ),
                    if (values.length > 1) const SizedBox(width: 4.0),
                    if (values.length > 1)
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          size: 18.0,
                          color: Colors.red,
                        ),
                        tooltip: 'Remove value',
                        onPressed: () {
                          appState.removePropertyValue(entity, propId, v.id);
                        },
                      ),
                  ],
                ),
              );
            }
          }).toList(),
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
      appState.addPropertyToEntity(entity, propId, '');
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
          final baseLabel = baseClass.startsWith('schema:')
              ? baseClass.substring(7)
              : baseClass;
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
            final label = option.key.startsWith('schema:')
                ? option.key.substring(7)
                : option.key;
            final query = searchVal.toLowerCase();
            return label.toLowerCase().contains(query) ||
                option.value.toLowerCase().contains(query);
          }).toList();

          return AlertDialog(
            title: const Text('Add Value - Select Compliant Type'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width > 560
                  ? 480.0
                  : MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height > 600
                  ? 440.0
                  : MediaQuery.of(context).size.height * 0.6,
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
                            final isSubclass =
                                option.value != 'Base expected type';
                            final label = clsId.startsWith('schema:')
                                ? clsId.substring(7)
                                : clsId;
                            final comment = SchemaService
                                    .instance.classes[clsId]?.comment ??
                                '';
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4.0),
                              child: ListTile(
                                leading: Icon(
                                  isSubclass
                                      ? Icons.subdirectory_arrow_right
                                      : Icons.playlist_add_circle_outlined,
                                  color:
                                      isSubclass ? Colors.orange : Colors.blue,
                                ),
                                title: Wrap(
                                  spacing: 6.0,
                                  runSpacing: 4.0,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'Create "${label}"',
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6.0, vertical: 2.0),
                                      decoration: BoxDecoration(
                                        color: isSubclass
                                            ? Colors.orange.withOpacity(0.1)
                                            : Colors.blue.withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      child: Text(
                                        option.value,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: isSubclass
                                              ? Colors.orange.shade700
                                              : Colors.blue.shade700,
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
                                  appState.addPropertyToEntity(
                                      entity, propId, nested);
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
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold),
                                ),
                                dense: true,
                                onTap: () {
                                  appState.addPropertyToEntity(
                                    entity,
                                    propId,
                                    primId == 'schema:Boolean' ? false : '',
                                  );
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          }).toList(),
                          Card(
                            margin: const EdgeInsets.symmetric(vertical: 4.0),
                            child: ListTile(
                              leading: const Icon(
                                Icons.translate_outlined,
                                color: Colors.purple,
                              ),
                              title: const Text(
                                'Add JSON-LD Value Object (@value)',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: const Text(
                                'Create a literal value object with language or datatype metadata.',
                                style: TextStyle(fontSize: 11.0),
                              ),
                              dense: true,
                              onTap: () {
                                appState.addPropertyToEntity(
                                  entity,
                                  propId,
                                  {'@value': ''},
                                );
                                Navigator.pop(context);
                              },
                            ),
                          ),
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

  void _showEditValueObjectDialog(
    AppState appState,
    SchemaEntity entity,
    String propId,
    SchemaValue sValue,
    Map mapVal,
  ) {
    final valueController = TextEditingController(text: mapVal['@value']?.toString() ?? '');
    final languageController = TextEditingController(text: mapVal['@language']?.toString() ?? '');
    final typeController = TextEditingController(text: mapVal['@type']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Value Object', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: valueController,
                  decoration: const InputDecoration(
                    labelText: 'Value (@value)',
                    hintText: 'e.g. Plumbing Service',
                  ),
                ),
                const SizedBox(height: 12.0),
                TextField(
                  controller: languageController,
                  decoration: const InputDecoration(
                    labelText: 'Language (@language)',
                    hintText: 'e.g. en, hi, es',
                  ),
                ),
                const SizedBox(height: 12.0),
                TextField(
                  controller: typeController,
                  decoration: const InputDecoration(
                    labelText: 'Datatype Type (@type)',
                    hintText: 'e.g. xsd:date',
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
                final Map<String, dynamic> newMap = {'@value': valueController.text};
                if (languageController.text.trim().isNotEmpty) {
                  newMap['@language'] = languageController.text.trim();
                }
                if (typeController.text.trim().isNotEmpty) {
                  newMap['@type'] = typeController.text.trim();
                }
                appState.updatePropertyValue(entity, propId, sValue.id, newMap);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildValueEditor(
    AppState appState,
    SchemaEntity parentEntity,
    String propId,
    SchemaValue sValue,
  ) {
    if (sValue.value is SchemaEntity) {
      return _buildEntityEditorCard(appState, sValue.value as SchemaEntity);
    }
    if (sValue.value is Map && (sValue.value as Map).containsKey('@value')) {
      final mapVal = sValue.value as Map;
      final valueStr = mapVal['@value']?.toString() ?? '';
      final lang = mapVal['@language']?.toString();
      final type = mapVal['@type']?.toString();
      final displayDetails = [
        if (lang != null) 'Language: $lang',
        if (type != null) 'Type: $type',
      ].join(' • ');

      return Card(
        color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.18),
        elevation: 0.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4.0),
          side: BorderSide(
            color: Theme.of(context).colorScheme.tertiary.withOpacity(0.3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
          child: Row(
            children: [
              Icon(
                Icons.translate_outlined,
                size: 16.0,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      valueStr,
                      style: const TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (displayDetails.isNotEmpty)
                      Text(
                        displayDetails,
                        style: TextStyle(
                          fontSize: 10.0,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 14.0),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  _showEditValueObjectDialog(appState, parentEntity, propId, sValue, mapVal);
                },
              ),
              const SizedBox(width: 4.0),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 14.0, color: Colors.redAccent),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  appState.removePropertyValue(parentEntity, propId, sValue.id);
                },
              ),
            ],
          ),
        ),
      );
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
    final propDef = SchemaService.instance.properties[propId];
    final ranges = propDef?.ranges ?? [];
    final List<SchemaEntity> linkableDocs = [];
    for (var doc in appState.documents) {
      if (doc.id == appState.rootEntity?.id) {
        continue;
      }
      // Check if renamed/valid @id exists
      final clean = doc.name.trim();
      final bool isUntitled = clean.isEmpty ||
          clean == 'Untitled Document' ||
          clean == 'Untitled Object' ||
          clean == 'Schema Document' ||
          clean.startsWith('New ');
      if (isUntitled) {
        continue; // Only link those who have been renamed / has only valid @id assigned
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
        final textVal = sValue.value.toString() ?? '';
        final controller = TextEditingController(text: textVal);
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
        IconData? inputIcon;
        if (ranges.contains('schema:URL')) {
          inputIcon = Icons.link;
        } else if (ranges.contains('schema:Date') ||
            ranges.contains('schema:DateTime')) {
          inputIcon = Icons.calendar_today;
        } else if (ranges.contains('schema:Number')) {
          inputIcon = Icons.pin;
        }
        editorWidget = TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: inputIcon != null ? Icon(inputIcon, size: 14.0) : null,
            hintText: 'Enter value...',
            isDense: true,
            suffixIcon: (ranges.contains('schema:Date') ||
                    ranges.contains('schema:DateTime'))
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
                        final dateStr =
                            picked.toIso8601String().split('T').first;
                        appState.updatePropertyValue(
                          parentEntity,
                          propId,
                          sValue.id,
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
          keyboardType: ranges.contains('schema:Number')
              ? TextInputType.number
              : TextInputType.text,
          onChanged: (newVal) {
            if (ranges.contains('schema:Number')) {
              final parsed = num.tryParse(newVal);
              if (parsed != null) {
                appState.updatePropertyValue(
                  parentEntity,
                  propId,
                  sValue.id,
                  parsed,
                );
                return;
              }
            }
            appState.updatePropertyValue(
              parentEntity,
              propId,
              sValue.id,
              newVal,
            );
          },
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
    final rootName = appState.rootEntity?.name ?? 'document';
    final cleanName =
        rootName.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');
    final docFilename = '${cleanName.isNotEmpty ? cleanName : 'schema'}.jsonld';

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh ??
          Theme.of(context).colorScheme.surface.withOpacity(0.95),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(4.0),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8.0,
                        height: 8.0,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.greenAccent,
                              blurRadius: 4.0,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          docFilename,
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 11.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
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
                onPressed: () async {
                  try {
                    final savedPath = await dl.downloadFile(
                        appState.jsonLdOutput, docFilename);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Saved "${docFilename}" successfully! 💾\nLocation: ${savedPath ?? "Downloads"}'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error saving file: $e'),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
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
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(
                  color: Colors.black,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8.0,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: _buildIDEView(appState.jsonLdOutput),
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
                        fontFamily:
                            Theme.of(context).textTheme.bodyMedium?.fontFamily,
                      ),
                      children: [
                        const TextSpan(
                          text:
                              'This document contains schema.org context fields. You can validate it directly on Google\'s Rich Results Test tool to boost SEO rankings!\n\n',
                        ),
                        WidgetSpan(
                          child: InkWell(
                            onTap: () async {
                              final url = Uri.parse(
                                  'https://search.google.com/test/rich-results');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url,
                                    mode: LaunchMode.externalApplication);
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
                                    color:
                                        Theme.of(context).colorScheme.primary,
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

  Widget _buildIDEView(String code) {
    final cleanCode = code.isEmpty ? '{}' : code;
    final lines = cleanCode.split('\n');
    final lineCount = lines.length;
    final bool isMobile = MediaQuery.of(context).size.width < 1100.0;

    final Widget view = SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Line numbers gutter column
            Container(
              padding: const EdgeInsets.only(right: 12.0, left: 10.0),
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Color(0xFF3C3C3C), width: 1.0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(
                    lineCount,
                    (i) => Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 12.0,
                            height: 1.4,
                            color: Color(0xFF858585),
                          ),
                        )),
              ),
            ),
            const SizedBox(width: 12.0),
            // Code lines column
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines.map((line) {
                return RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12.0,
                      height: 1.4,
                      color: Color(0xFFE4E4E4),
                    ),
                    children: _highlightJsonLine(line),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );

    if (isMobile) {
      return view; // Omit SelectionArea on mobile viewports to prevent virtual keyboard popups entirely!
    } else {
      return SelectionArea(child: view);
    }
  }

  List<TextSpan> _highlightJsonLine(String line) {
    final List<TextSpan> spans = [];
    final keyRegex = RegExp(r'^(\s*)("[^"]+")(\s*:\s*)');
    final match = keyRegex.firstMatch(line);

    if (match != null) {
      // Indentation
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(color: Color(0xFFE4E4E4)),
      ));

      // JSON Key
      final keyStr = match.group(2) ?? '';
      Color keyColor = const Color(0xFF9CDCFE); // Light blue
      if (keyStr.contains('@')) {
        keyColor = const Color(0xFFC586C0); // Magenta for JSON-LD keywords
      }
      spans.add(TextSpan(
        text: keyStr,
        style: TextStyle(color: keyColor, fontWeight: FontWeight.bold),
      ));

      // Separator ':'
      spans.add(TextSpan(
        text: match.group(3),
        style: const TextStyle(color: Color(0xFFE4E4E4)),
      ));

      // JSON Value
      final rest = line.substring(match.end);
      spans.add(_highlightValue(rest));
    } else {
      spans.add(_highlightValue(line));
    }

    return spans;
  }

  TextSpan _highlightValue(String text) {
    final List<TextSpan> children = [];
    int index = 0;

    while (index < text.length) {
      final remaining = text.substring(index);

      // Match string literals
      final stringMatch = RegExp(r'^"[^"]*"').firstMatch(remaining);
      if (stringMatch != null) {
        children.add(TextSpan(
          text: stringMatch.group(0),
          style: const TextStyle(color: Color(0xFFCE9178)), // Warm orange
        ));
        index += stringMatch.end;
        continue;
      }

      // Match boolean/null
      final boolMatch = RegExp(r'^(true|false|null)\b').firstMatch(remaining);
      if (boolMatch != null) {
        children.add(TextSpan(
          text: boolMatch.group(0),
          style: const TextStyle(
            color: Color(0xFF569CD6), // Dark blue
            fontWeight: FontWeight.bold,
          ),
        ));
        index += boolMatch.end;
        continue;
      }

      // Match numbers
      final numMatch = RegExp(r'^\d+(\.\d+)?\b').firstMatch(remaining);
      if (numMatch != null) {
        children.add(TextSpan(
          text: numMatch.group(0),
          style: const TextStyle(color: Color(0xFFB5CEA8)), // Pale green
        ));
        index += numMatch.end;
        continue;
      }

      // Match braces, brackets and commas
      final char = remaining[0];
      if (char == '{' || char == '}' || char == '[' || char == ']') {
        children.add(TextSpan(
          text: char,
          style: const TextStyle(
            color: Color(0xFFFFD700), // Gold
            fontWeight: FontWeight.bold,
          ),
        ));
        index += 1;
        continue;
      }

      // Normal characters
      children.add(TextSpan(
        text: char,
        style: const TextStyle(color: Color(0xFFE4E4E4)),
      ));
      index += 1;
    }

    return TextSpan(children: children);
  }

  List<SchemaEntity> _resolveActiveColumns(SchemaEntity root) {
    final List<SchemaEntity> active = [root];
    for (final targetId in _columnPath) {
      final currentParent = active.last;
      SchemaEntity? foundChild;
      for (final propValues in currentParent.properties.values) {
        for (final val in propValues) {
          if (val.value is SchemaEntity &&
              (val.value as SchemaEntity).id == targetId) {
            foundChild = val.value as SchemaEntity;
            break;
          }
        }
        if (foundChild != null) break;
      }
      if (foundChild != null) {
        active.add(foundChild);
      } else {
        final index = _columnPath.indexOf(targetId);
        if (index != -1) {
          _columnPath = _columnPath.sublist(0, index);
        }
        break;
      }
    }
    return active;
  }

  void _smoothScrollToRight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_columnScrollController.hasClients) {
        _columnScrollController.animateTo(
          _columnScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _confirmChangeRootType(AppState appState, String newType) {
    final typeLabel =
        newType.startsWith('schema:') ? newType.substring(7) : newType;
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
          final recProps =
              allProps.where((p) => recommended.contains(p.id)).toList();
          return AlertDialog(
            title: Text('Configure Properties for ${typeLabel}'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width > 600
                  ? 520.0
                  : MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height > 650
                  ? 480.0
                  : MediaQuery.of(context).size.height * 0.65,
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
                              decoration:
                                  isAdded ? TextDecoration.lineThrough : null,
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
                              final isAlreadyAdded =
                                  entity.properties.containsKey(prop.id);
                              return ListTile(
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        propLabel,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isAlreadyAdded
                                              ? Colors.grey
                                              : null,
                                        ),
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
      final isPrim = r == 'schema:Text' ||
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
            final baseLabel = baseClass.startsWith('schema:')
                ? baseClass.substring(7)
                : baseClass;
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
              final label = option.key.startsWith('schema:')
                  ? option.key.substring(7)
                  : option.key;
              final query = searchVal.toLowerCase();
              return label.toLowerCase().contains(query) ||
                  option.value.toLowerCase().contains(query);
            }).toList();

            return AlertDialog(
              title: Text('Select Input Type for "${prop.label}"'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width > 560
                    ? 480.0
                    : MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height > 600
                    ? 400.0
                    : MediaQuery.of(context).size.height * 0.6,
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
                            final isSubclass =
                                option.value != 'Base expected type';
                            final label = clsId.startsWith('schema:')
                                ? clsId.substring(7)
                                : clsId;
                            final comment = SchemaService
                                    .instance.classes[clsId]?.comment ??
                                '';
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4.0),
                              child: ListTile(
                                leading: Icon(
                                  isSubclass
                                      ? Icons.subdirectory_arrow_right
                                      : Icons.playlist_add_circle_outlined,
                                  color:
                                      isSubclass ? Colors.orange : Colors.blue,
                                ),
                                title: Wrap(
                                  spacing: 6.0,
                                  runSpacing: 4.0,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'Create "${label}"',
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6.0, vertical: 2.0),
                                      decoration: BoxDecoration(
                                        color: isSubclass
                                            ? Colors.orange.withOpacity(0.1)
                                            : Colors.blue.withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      child: Text(
                                        option.value,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: isSubclass
                                              ? Colors.orange.shade700
                                              : Colors.blue.shade700,
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
                                  appState.addPropertyToEntity(
                                      entity, prop.id, nested);
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          }).toList(),
                          Card(
                            margin: const EdgeInsets.symmetric(vertical: 4.0),
                            child: ListTile(
                              leading: const Icon(Icons.edit_note,
                                  color: Colors.green),
                              title: const Text(
                                'Add simple text input field',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold),
                              ),
                              dense: true,
                              onTap: () {
                                appState.addPropertyToEntity(
                                    entity, prop.id, '');
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
      final initialValue = ranges.contains('schema:Boolean') ? false : '';
      appState.addPropertyToEntity(entity, prop.id, initialValue);
    }
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
    showDialog(
      context: context,
      builder: (context) => _CreateDocDialog(appState: appState),
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
          width: MediaQuery.of(context).size.width > 560
              ? 500.0
              : MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height > 550
              ? 350.0
              : MediaQuery.of(context).size.height * 0.5,
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
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _transformationController.removeListener(_onCanvasTransform);
    _transformationController.dispose();
    _importController.dispose();
    _searchClassController.dispose();
    _searchPropertyController.dispose();
    _docNameController.dispose();
    _customPropController.dispose();
    _searchMarkupController.dispose();
    _sidebarScrollController.dispose();
    _markupSearchFocusNode.dispose();
    _workspaceVerticalController.dispose();
    _workspaceHorizontalController.dispose();
    _treeVerticalController.dispose();
    _treeHorizontalController.dispose();
    super.dispose();
  }

  Widget _buildLeftSidebar(AppState appState) {
    final allCategoryClasses = SchemaService.instance.classes.values.toList();
    final lowercaseClassQuery = _classSearchQuery.trim().toLowerCase();

    // Sort starting classes alphabetically for smooth, predictable navigation
    final sortedClasses = List<SchemaClass>.from(allCategoryClasses)
      ..sort((a, b) => a.label.compareTo(b.label));

    final filteredClasses = sortedClasses.where((cls) {
      if (lowercaseClassQuery.isEmpty) {
        return true;
      }
      return cls.label.toLowerCase().contains(lowercaseClassQuery) ||
          cls.id.toLowerCase().contains(lowercaseClassQuery);
    }).toList();

    final lowercaseMarkupQuery = _markupSearchQuery.trim().toLowerCase();
    final filteredDocuments = appState.documents.where((doc) {
      if (lowercaseMarkupQuery.isEmpty) {
        return true;
      }
      return doc.name.toLowerCase().contains(lowercaseMarkupQuery) ||
          doc.type.toLowerCase().contains(lowercaseMarkupQuery);
    }).toList();

    final primaryColor = Theme.of(context).colorScheme.primary;
    final bool isSearchActive = _markupSearchFocusNode.hasFocus || _markupSearchQuery.isNotEmpty;

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow ??
          Theme.of(context).colorScheme.surface.withOpacity(0.5),
      child: CustomScrollView(
        controller: _sidebarScrollController,
        slivers: [
          // 1. Dashboard Gradient Statistics Banner (Maintained as stable sliver to prevent focus loss)
          SliverToBoxAdapter(
            child: Visibility(
              visible: !isSearchActive,
              child: Container(
                margin: const EdgeInsets.all(16.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(4.0),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.18),
                      blurRadius: 8.0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'DASHBOARD METRICS',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Icon(Icons.dashboard_customize_outlined, color: Colors.white70, size: 14.0),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${appState.documents.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Active Documents',
                              style: TextStyle(color: Colors.white70, fontSize: 10.0),
                            ),
                          ],
                        ),
                        Container(width: 1.0, height: 28.0, color: Colors.white24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${allCategoryClasses.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Supported Types',
                              style: TextStyle(color: Colors.white70, fontSize: 10.0),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Active Markups Pinned Search Header (Always stable structural index)
          SliverToBoxAdapter(
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerLow ?? Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.folder_shared_outlined, size: 16.0, color: primaryColor),
                      const SizedBox(width: 8.0),
                      Text(
                        'My Active Markups',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.add_box_outlined, size: 20.0),
                        tooltip: 'Create New Document',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showCreateDocDialog(appState),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  TextField(
                    controller: _searchMarkupController,
                    focusNode: _markupSearchFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Search active markups...',
                      prefixIcon: const Icon(Icons.search, size: 16.0),
                      suffixIcon: isSearchActive
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 14.0),
                              onPressed: () {
                                _searchMarkupController.clear();
                                _markupSearchFocusNode.unfocus();
                                setState(() {
                                  _markupSearchQuery = '';
                                });
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.all(8.0),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(4.0)),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _markupSearchQuery = val;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // 3. Active Markups Sliver List
          filteredDocuments.isEmpty
              ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'No active markups found.',
                        style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12.0),
                      ),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = filteredDocuments[index];
                      final originalIndex = appState.documents.indexOf(doc);
                      final isSelected = appState.selectedDocumentIndex == originalIndex;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border(
                            left: BorderSide(
                              color: isSelected ? primaryColor : Colors.grey.withOpacity(0.3),
                              width: 4.0,
                            ),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.only(left: 12.0, right: 4.0),
                          dense: true,
                          title: Text(
                            doc.name,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12.0,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            doc.type.replaceAll('schema:', ''),
                            style: const TextStyle(fontSize: 10.0),
                          ),
                          onTap: () {
                            appState.selectDocument(originalIndex);
                            setState(() {
                              _columnPath = []; // Reset active workspace cascade columns when selecting new doc
                            });
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 14.0),
                                tooltip: 'Rename',
                                onPressed: () => _showRenameDialog(appState, originalIndex, doc.name),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 14.0),
                                tooltip: 'Duplicate',
                                onPressed: () => appState.duplicateDocument(originalIndex),
                              ),
                              if (appState.documents.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 14.0, color: Colors.redAccent),
                                  tooltip: 'Delete',
                                  onPressed: () => appState.deleteDocument(originalIndex),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: filteredDocuments.length,
                  ),
                ),

          // Divider Break (Conditional rendering inside a stable container)
          SliverToBoxAdapter(
            child: Visibility(
              visible: !isSearchActive,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(),
              ),
            ),
          ),

          // 4. Instantiate New Class Pinned Header
          SliverToBoxAdapter(
            child: Visibility(
              visible: !isSearchActive,
              child: Container(
                color: Theme.of(context).colorScheme.surfaceContainerLow ?? Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.add_circle_outline, size: 16.0, color: primaryColor),
                        const SizedBox(width: 8.0),
                        Text(
                          'Instantiate New Class Type',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    TextField(
                      controller: _searchClassController,
                      decoration: InputDecoration(
                        hintText: 'Search 800+ types (e.g. Recipe)...',
                        prefixIcon: const Icon(Icons.search, size: 16.0),
                        suffixIcon: _classSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 14.0),
                                onPressed: () {
                                  _searchClassController.clear();
                                  setState(() {
                                    _classSearchQuery = '';
                                  });
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.all(8.0),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(4.0)),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _classSearchQuery = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Instantiate Class Types Sliver List (Stable indices, items set to 0 when search active)
          filteredClasses.isEmpty
              ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'No classes found.',
                        style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12.0),
                      ),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final cls = filteredClasses[index];
                      return Visibility(
                        visible: !isSearchActive,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(4.0),
                            border: Border(
                              left: BorderSide(
                                color: Theme.of(context).colorScheme.secondary.withOpacity(0.6),
                                width: 4.0,
                              ),
                            ),
                          ),
                          child: ListTile(
                            title: Text(
                              cls.label,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                            subtitle: Text(
                              cls.comment,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10.5),
                            ),
                            dense: true,
                            trailing: const Icon(Icons.add_circle_outline, size: 14.0),
                            onTap: () {
                              appState.createNewDocument('New ${cls.label} Document', cls.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Created new ${cls.label} document successfully!'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              setState(() {
                                _columnPath = []; // Reset workspace cascade path for new documents
                              });
                            },
                          ),
                        ),
                      );
                    },
                    childCount: isSearchActive ? 0 : filteredClasses.length,
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 24.0)),
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
            const Expanded(
              child: Text(
                'Privacy Policy',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width > 560
              ? 500.0
              : MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height > 600
              ? 400.0
              : MediaQuery.of(context).size.height * 0.6,
          child: const SingleChildScrollView(
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

  void _showTermsAndConditions() {
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
            const Expanded(
              child: Text(
                'Terms & Conditions',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width > 560
              ? 500.0
              : MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height > 600
              ? 400.0
              : MediaQuery.of(context).size.height * 0.6,
          child: const SingleChildScrollView(
            child: Text(
              'Terms & Conditions for JSON LD Visual Editor\n\n'
              'Last updated: July 2026\n\n'
              'Please read these Terms and Conditions ("Terms", "Terms and Conditions") carefully before using the JSON LD Visual Editor application (the "Service") operated by Antinna ("us", "we", or "our").\n\n'
              '1. Acceptance of Terms\n'
              'By accessing or using the Service, you agree to be bound by these Terms. If you disagree with any part of the terms, then you may not access the Service.\n\n'
              '2. Use of Service & Offline Capabilities\n'
              'JSON LD Visual Editor operates as a localized schema builder to organize metadata properties offline. You are entirely responsible for the structure, correctness, and storage of any schemas created or exported from this App. Any external standard specifications are retrieved dynamically from public sources (schema.org) for your convenience.\n\n'
              '3. Intellectual Property\n'
              'The Service and its original content (excluding standard Schema.org concepts and user-generated schemas), features, and functionality are and will remain the exclusive property of Antinna and its licensors. Our trademarks and trade dress may not be used in connection with any product or service without the prior written consent of Antinna.\n\n'
              '4. Third-Party Links\n'
              'Our Service may contain links to third-party web sites or services that are not owned or controlled by Antinna. We have no control over, and assume no responsibility for, the content, privacy policies, or practices of any third-party websites or services.\n\n'
              '5. Limitation of Liability\n'
              'In no event shall Antinna be liable for any indirect, incidental, special, consequential, or punitive damages, including without limitation, loss of profits, data, use, goodwill, or other intangible losses, resulting from your access to or use of or inability to access or use the Service.\n\n'
              '6. Changes to Terms\n'
              'We reserve the right, at our sole discretion, to modify or replace these Terms at any time. We will post any updates within this App.\n\n'
              'Contact Us\n'
              'If you have any questions about these Terms, please contact us via our social channels.',
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

class _BaseUriField extends StatefulWidget {
  final AppState appState;
  final SchemaEntity entity;

  const _BaseUriField({
    Key? key,
    required this.appState,
    required this.entity,
  }) : super(key: key);

  @override
  State<_BaseUriField> createState() => _BaseUriFieldState();
}

class _BaseUriFieldState extends State<_BaseUriField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.entity.baseUri ?? '');
  }

  @override
  void didUpdateWidget(covariant _BaseUriField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entity.baseUri != oldWidget.entity.baseUri &&
        widget.entity.baseUri != _controller.text) {
      _controller.text = widget.entity.baseUri ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(4.0),
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
                Icons.link,
                size: 14.0,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6.0),
              const Text(
                'Document Base URI (@base)',
                style: TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          Text(
            'If empty, defaults to "@context": "https://schema.org". Otherwise, structured context with custom base URI is exported.',
            style: TextStyle(
              fontSize: 9.5,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8.0),
          SizedBox(
            height: 32.0,
            child: TextField(
              controller: _controller,
              style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'e.g. https://example.com/things/',
                hintStyle: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 8.0,
                ),
                border: const OutlineInputBorder(),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 12.0),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            _controller.clear();
                          });
                          widget.entity.baseUri = null;
                          widget.appState.persistDocument(widget.entity);
                          widget.appState.generateJsonLdOutput();
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                widget.entity.baseUri = val.trim().isEmpty ? null : val.trim();
                widget.appState.persistDocument(widget.entity);
                widget.appState.generateJsonLdOutput();
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }
}

class GraphBackgroundPainter extends CustomPainter {
  final Color gridColor;
  final double spacing;

  GraphBackgroundPainter({required this.gridColor, required this.spacing});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FlatTreeNode {
  final String id;
  final int depth;
  final String label;
  final String typeLabel;
  final bool isEntity;
  final bool isProperty;
  final bool isValue;
  final SchemaEntity? entity;
  final String? propertyKey;
  final SchemaValue? schemaValue;
  final String? keyName;
  final SchemaEntity? parentEntity;

  _FlatTreeNode({
    required this.id,
    required this.depth,
    required this.label,
    required this.typeLabel,
    this.isEntity = false,
    this.isProperty = false,
    this.isValue = false,
    this.entity,
    this.propertyKey,
    this.schemaValue,
    this.keyName,
    this.parentEntity,
  });
}

class _TreeNode {
  final String label;
  final String type;
  final int depth;
  final SchemaEntity entity;
  final String? relationLabel;

  _TreeNode({
    required this.label,
    required this.type,
    required this.depth,
    required this.entity,
    this.relationLabel,
  });
}

class _SliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SliverHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overridesMinMax) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _SliverHeaderDelegate oldDelegate) {
    return oldDelegate.minHeight != minHeight ||
        oldDelegate.maxHeight != maxHeight ||
        oldDelegate.child != child;
  }
}

class GridBackgroundPainter extends CustomPainter {
  final Color gridColor;
  final double spacing;

  GridBackgroundPainter({
    required this.gridColor,
    this.spacing = 30.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CreateDocDialog extends StatefulWidget {
  final AppState appState;

  const _CreateDocDialog({Key? key, required this.appState}) : super(key: key);

  @override
  State<_CreateDocDialog> createState() => _CreateDocDialogState();
}

class _CreateDocDialogState extends State<_CreateDocDialog> {
  late final TextEditingController _docNameController;
  late final TextEditingController _classSearchController;
  String _selectedClassId = 'schema:Person';

  @override
  void initState() {
    super.initState();
    _docNameController = TextEditingController();
    _classSearchController = TextEditingController();
  }

  @override
  void dispose() {
    _docNameController.dispose();
    _classSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _classSearchController.text.toLowerCase();
    final allClasses = SchemaService.instance.classes.values.toList();
    allClasses.sort((a, b) => a.label.compareTo(b.label));

    final filteredClasses = allClasses.where((cls) {
      final label = cls.label.toLowerCase();
      final comment = cls.comment.toLowerCase();
      final id = cls.id.toLowerCase();
      return label.contains(query) ||
          comment.contains(query) ||
          id.contains(query);
    }).toList();

    return AlertDialog(
      title: const Text('Create New Schema Document'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width > 560
            ? 500.0
            : MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height > 600
            ? 520.0
            : MediaQuery.of(context).size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Document Name',
              style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6.0),
            TextField(
              controller: _docNameController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g., Company Header Markup',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16.0),
            const Text(
              'Select Starting Class / Schema Type',
              style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6.0),
            TextField(
              controller: _classSearchController,
              onChanged: (val) {
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Search types (e.g. Article, Organization)...',
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20.0),
                border: const OutlineInputBorder(),
                suffixIcon: _classSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16.0),
                        onPressed: () {
                          _classSearchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 10.0),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: filteredClasses.isEmpty
                    ? const Center(
                        child: Text(
                          'No matching Schema.org classes found',
                          style: TextStyle(color: Colors.grey, fontSize: 12.0),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredClasses.length,
                        itemBuilder: (context, idx) {
                          final cls = filteredClasses[idx];
                          final isSelected = cls.id == _selectedClassId;
                          return Container(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                            child: ListTile(
                              dense: true,
                              title: Text(
                                cls.label,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                cls.comment.isNotEmpty
                                    ? cls.comment
                                    : 'No description available',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.0),
                              ),
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check_circle,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      size: 18.0,
                                    )
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedClassId = cls.id;
                                });
                              },
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _docNameController.text.trim();
            widget.appState.createNewDocument(
              name.isEmpty ? 'Untitled Document' : name,
              _selectedClassId,
            );
            Navigator.pop(context);
          },
          child: const Text('Create'),
        ),
      ],
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
