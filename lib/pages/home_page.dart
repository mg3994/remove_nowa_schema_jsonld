import 'package:flutter/material.dart';
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

class _HomePageState extends State<HomePage> {
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

  final ScrollController _workspaceVerticalController = ScrollController();
  final ScrollController _workspaceHorizontalController = ScrollController();
  final ScrollController _treeVerticalController = ScrollController();
  final ScrollController _treeHorizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final appState = AppState.of(context);
    final isWide = MediaQuery.of(context).size.width >= 1100;
    return Scaffold(
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
                     child: Icon(Icons.gavel_outlined, color: Theme.of(context).colorScheme.primary),
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
                    'Json LD Visual Editor',
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
                            ? _buildTreeViewWorkspace(appState)
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
                  return DefaultTabController(
                    length: 3,
                    child: Column(
                      children: [
                        TabBar(
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
                    ),
                  );
                }
              },
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

  Widget _buildWorkspace(AppState appState) {
    final root = appState.rootEntity;
    final path = _getInheritancePath(root!.type);
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                      children: path.map((segment) {
                        final isLast = segment == path.last;
                        return Row(
                          children: [
                            Text(
                              segment,
                              style: TextStyle(
                                fontSize: 11.0,
                                fontWeight: isLast
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isLast
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline,
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
                    final cleanType = root!.type.replaceAll('schema:', '');
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
          const SizedBox(height: 16.0),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      root!.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'Visual Builder • ${root?.type}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.0,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_circle_outline, size: 18.0),
                label: const Text('Add Property'),
                onPressed: () => _showAddPropertyDialog(appState, root!),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Expanded(
            child: Scrollbar(
              controller: _workspaceVerticalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _workspaceVerticalController,
                scrollDirection: Axis.vertical,
                child: Scrollbar(
                  controller: _workspaceHorizontalController,
                  thumbVisibility: true,
                  notificationPredicate: (notif) => notif.depth == 0,
                  child: SingleChildScrollView(
                    controller: _workspaceHorizontalController,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width > 950.0
                            ? MediaQuery.of(context).size.width - 32.0
                            : 950.0,
                      ),
                      child: _buildEntityEditorCard(appState, root!, isRoot: true),
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

  Widget _buildTreeViewWorkspace(AppState appState) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Interactive Entity Graph',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4.0),
          const Text(
            'Hierarchical visualization of your current Schema.org structured document.',
            style: TextStyle(fontSize: 12.0, color: Colors.grey),
          ),
          const SizedBox(height: 16.0),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Scrollbar(
                controller: _treeVerticalController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _treeVerticalController,
                  scrollDirection: Axis.vertical,
                  child: Scrollbar(
                    controller: _treeHorizontalController,
                    thumbVisibility: true,
                    notificationPredicate: (notif) => notif.depth == 0,
                    child: SingleChildScrollView(
                      controller: _treeHorizontalController,
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: MediaQuery.of(context).size.width > 950.0
                              ? MediaQuery.of(context).size.width - 64.0
                              : 950.0,
                        ),
                        child: _buildTreeViewNode(appState.rootEntity!, isRoot: true),
                      ),
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

  Widget _buildTreeViewNode(
    SchemaEntity entity, {
    bool isRoot = false,
    String keyName = 'Root Document',
  }) {
    final typeLabel = entity.type.startsWith('schema:')
        ? entity.type.substring(7)
        : entity.type;
    return Card(
      elevation: 0.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.8,
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(
          isRoot ? Icons.hub : Icons.subdirectory_arrow_right,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6.0,
          runSpacing: 4.0,
          children: [
            Text(
              '${keyName}: ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.0,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 2.0,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                typeLabel,
                style: TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${entity.properties.length} active fields',
          style: const TextStyle(fontSize: 11.0),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: entity.properties.entries.map((entry) {
                final propName = entry.key.startsWith('schema:')
                    ? entry.key.substring(7)
                    : entry.key;
                final values = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: values.map((val) {
                    if (val.value is SchemaEntity) {
                      return _buildTreeViewNode(
                        val.value as SchemaEntity,
                        isRoot: false,
                        keyName: propName,
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4.0,
                        horizontal: 12.0,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_right_alt,
                            size: 14.0,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            '${propName}: ',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.0,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              val.value.toString() ?? '',
                              style: TextStyle(
                                fontSize: 12.0,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
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
      elevation: isRoot ? 1.0 : 0.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: isRoot
              ? Theme.of(context).colorScheme.primary.withOpacity(0.4)
              : Theme.of(context).colorScheme.outline.withOpacity(0.15),
          width: isRoot ? 1.5 : 1.0,
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8.0),
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
    );
  }

  Widget _buildPropertyRow(
    AppState appState,
    SchemaEntity entity,
    String propId,
    List<SchemaValue> values,
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
          ...values
              .map(
                (v) => Padding(
                  padding: const EdgeInsets.only(left: 8.0, bottom: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildValueEditor(appState, entity, propId, v),
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
              width: MediaQuery.of(context).size.width > 560 ? 480.0 : MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height > 600 ? 440.0 : MediaQuery.of(context).size.height * 0.6,
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
                                title: Wrap(
                                  spacing: 6.0,
                                  runSpacing: 4.0,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'Create "${label}"',
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                    ),
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

  Widget _buildValueEditor(
    AppState appState,
    SchemaEntity parentEntity,
    String propId,
    SchemaValue sValue,
  ) {
    if (sValue.value is SchemaEntity) {
      return _buildEntityEditorCard(appState, sValue.value as SchemaEntity);
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
            suffixIcon:
                (ranges.contains('schema:Date') ||
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
                        final dateStr = picked
                            .toIso8601String()
                            .split('T')
                            .first;
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
                onPressed: () async {
                  final rootName = appState.rootEntity?.name ?? 'document';
                  final cleanName = rootName.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');
                  final filename = '${cleanName.isNotEmpty ? cleanName : 'schema'}.jsonld';
                  try {
                    final savedPath = await dl.downloadFile(appState.jsonLdOutput, filename);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Saved "${filename}" successfully! 💾\nLocation: ${savedPath ?? "Downloads"}'),
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
              width: MediaQuery.of(context).size.width > 600 ? 520.0 : MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height > 650 ? 480.0 : MediaQuery.of(context).size.height * 0.65,
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
                width: MediaQuery.of(context).size.width > 560 ? 480.0 : MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height > 600 ? 400.0 : MediaQuery.of(context).size.height * 0.6,
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
                                title: Wrap(
                                  spacing: 6.0,
                                  runSpacing: 4.0,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'Create "${label}"',
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                    ),
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
          width: MediaQuery.of(context).size.width > 560 ? 500.0 : MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height > 550 ? 350.0 : MediaQuery.of(context).size.height * 0.5,
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
    _importController.dispose();
    _searchClassController.dispose();
    _searchPropertyController.dispose();
    _docNameController.dispose();
    _customPropController.dispose();
    _searchMarkupController.dispose();
    _workspaceVerticalController.dispose();
    _workspaceHorizontalController.dispose();
    _treeVerticalController.dispose();
    _treeHorizontalController.dispose();
    super.dispose();
  }

  Widget _buildLeftSidebar(AppState appState) {
    final allCategoryClasses = SchemaService.instance.classes.values.toList();
    final lowercaseClassQuery = _classSearchQuery.trim().toLowerCase();
    final filteredClasses = allCategoryClasses.where((cls) {
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
            const Expanded(
              child: Text(
                'Privacy Policy',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width > 560 ? 500.0 : MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height > 600 ? 400.0 : MediaQuery.of(context).size.height * 0.6,
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
          width: MediaQuery.of(context).size.width > 560 ? 500.0 : MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height > 600 ? 400.0 : MediaQuery.of(context).size.height * 0.6,
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
      return label.contains(query) || comment.contains(query) || id.contains(query);
    }).toList();

    return AlertDialog(
      title: const Text('Create New Schema Document'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width > 560 ? 500.0 : MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height > 600 ? 520.0 : MediaQuery.of(context).size.height * 0.75,
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
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                                      color: Theme.of(context).colorScheme.primary,
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
