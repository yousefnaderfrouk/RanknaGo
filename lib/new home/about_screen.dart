import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme_provider.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _developerInfo;
  Map<String, dynamic>? _aboutInfo;

  @override
  void initState() {
    super.initState();
    _loadAboutData();
  }

  Future<void> _loadAboutData() async {
    try {
      final settingsDoc = await _firestore
          .collection('settings')
          .doc('app')
          .get();
      if (settingsDoc.exists) {
        final data = settingsDoc.data();
        setState(() {
          _developerInfo = data?['developerInfo'];
          _aboutInfo = data?['aboutInfo'];
        });
      }
    } catch (e) {
      // Error loading data
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : const Color(0xFF212121),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'About ${_aboutInfo?['appName'] ?? 'RaknaGo'}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF212121),
          ),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 40),

          // App Icon and Version
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E88E5).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_parking_rounded,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '${_aboutInfo?['appName'] ?? 'RaknaGo'} v${_aboutInfo?['appVersion'] ?? '1.0.0'}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF212121),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Menu Items
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildMenuItem(
                  context,
                  title: 'Job Vacancy',
                  onTap: () => _showJobVacancyDialog(context),
                ),
                _buildDivider(),
                _buildMenuItem(
                  context,
                  title: 'Developer',
                  onTap: () => _showDeveloperDialog(context),
                ),
                _buildDivider(),
                _buildMenuItem(
                  context,
                  title: 'Partner',
                  onTap: () => _showPartnerDialog(context),
                ),
                _buildDivider(),
                _buildMenuItem(
                  context,
                  title: 'Accessibility',
                  onTap: () => _showAccessibilityDialog(context),
                ),
                _buildDivider(),
                _buildMenuItem(
                  context,
                  title: 'Terms of Use',
                  onTap: () => _showTermsOfUseDialog(context),
                ),
                _buildDivider(),
                _buildMenuItem(
                  context,
                  title: 'Feedback',
                  onTap: () => _showFeedbackDialog(context),
                ),
                _buildDivider(),
                _buildMenuItem(
                  context,
                  title: 'Rate us',
                  onTap: () => _showRateUsDialog(context),
                ),
                _buildDivider(),
                _buildMenuItem(
                  context,
                  title: 'Visit Our Website',
                  onTap: () {
                    final website =
                        _aboutInfo?['website'] ?? 'https://raknago.com';
                    _launchURL(website);
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  context,
                  title: 'Follow us on Social Media',
                  onTap: () => _showSocialMediaDialog(context),
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String title,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : const Color(0xFF212121),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: isDark ? Colors.grey[400] : Colors.grey[400],
      ),
    );
  }

  Widget _buildDivider() {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
    );
  }

  // ==================== DIALOGS ====================

  void _showJobVacancyDialog(BuildContext context) {
    final jobVacancy = _aboutInfo?['jobVacancy'] ?? {};
    final title = jobVacancy['title'] ?? 'Join Our Team!';
    final description =
        jobVacancy['description'] ??
        'We\'re always looking for talented individuals to join our team.';
    final jobs = jobVacancy['jobs'] as List<dynamic>? ?? [];
    final contactEmail = jobVacancy['contactEmail'] ?? 'jobs@raknago.com';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.work_outline_rounded, color: Color(0xFF1E88E5)),
            SizedBox(width: 12),
            Text('Job Vacancy'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(description, style: const TextStyle(fontSize: 14)),
              if (jobs.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...jobs.map((job) {
                  final jobTitle = job['title'] ?? '';
                  final jobDetails = job['details'] ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildJobCard(jobTitle, jobDetails),
                  );
                }).toList(),
              ],
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      color: Color(0xFF1E88E5),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Send your CV to: $contactEmail',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
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
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _launchURL('mailto:$contactEmail');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Apply Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(String title, String details) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.work_outline,
              color: Color(0xFF1E88E5),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeveloperDialog(BuildContext context) {
    final developerName = _developerInfo?['name'] ?? 'ParkSpot Team';
    final developerEmail = _developerInfo?['email'] ?? 'dev@parkspot.com';
    final developerPhone = _developerInfo?['phone'] ?? '';
    final developerWebsite = _developerInfo?['website'] ?? 'www.parkspot.com';
    final developerLocation = _developerInfo?['location'] ?? 'New York, USA';
    final socialMedia = _developerInfo?['socialMedia'] ?? {};

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.code_rounded, color: Color(0xFF1E88E5)),
            SizedBox(width: 12),
            Text('Developer'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.code_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Developed by',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                developerName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    if (developerEmail.isNotEmpty)
                      _buildInfoRow(
                        Icons.email_outlined,
                        developerEmail,
                        onTap: () => _launchURL('mailto:$developerEmail'),
                      ),
                    if (developerEmail.isNotEmpty && developerPhone.isNotEmpty)
                      const SizedBox(height: 12),
                    if (developerPhone.isNotEmpty)
                      _buildInfoRow(
                        Icons.phone_outlined,
                        developerPhone,
                        onTap: () => _launchURL('tel:$developerPhone'),
                      ),
                    if ((developerEmail.isNotEmpty ||
                            developerPhone.isNotEmpty) &&
                        developerWebsite.isNotEmpty)
                      const SizedBox(height: 12),
                    if (developerWebsite.isNotEmpty)
                      _buildInfoRow(
                        Icons.language_rounded,
                        developerWebsite,
                        onTap: () {
                          final url = developerWebsite.startsWith('http')
                              ? developerWebsite
                              : 'https://$developerWebsite';
                          _launchURL(url);
                        },
                      ),
                    if ((developerEmail.isNotEmpty ||
                            developerPhone.isNotEmpty ||
                            developerWebsite.isNotEmpty) &&
                        developerLocation.isNotEmpty)
                      const SizedBox(height: 12),
                    if (developerLocation.isNotEmpty)
                      _buildInfoRow(
                        Icons.location_on_outlined,
                        developerLocation,
                      ),
                    if (socialMedia.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text(
                        'Social Media',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (socialMedia['facebook']?.isNotEmpty ?? false)
                        _buildSocialMediaRow(
                          'Facebook',
                          Icons.facebook,
                          const Color(0xFF1877F2),
                          socialMedia['facebook'],
                        ),
                      if (socialMedia['instagram']?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 8),
                        _buildSocialMediaRow(
                          'Instagram',
                          Icons.camera_alt_rounded,
                          const Color(0xFFE4405F),
                          socialMedia['instagram'],
                        ),
                      ],
                      if (socialMedia['twitter']?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 8),
                        _buildSocialMediaRow(
                          'Twitter',
                          Icons.alternate_email_rounded,
                          const Color(0xFF1DA1F2),
                          socialMedia['twitter'],
                        ),
                      ],
                      if (socialMedia['linkedin']?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 8),
                        _buildSocialMediaRow(
                          'LinkedIn',
                          Icons.business_rounded,
                          const Color(0xFF0A66C2),
                          socialMedia['linkedin'],
                        ),
                      ],
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
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialMediaRow(
    String name,
    IconData icon,
    Color color,
    String url,
  ) {
    return InkWell(
      onTap: () => _launchURL(url),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 14))),
            Icon(Icons.open_in_new, size: 16, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {VoidCallback? onTap}) {
    final widget = Row(
      children: [
        Icon(icon, color: const Color(0xFF1E88E5), size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        if (onTap != null)
          Icon(Icons.open_in_new, size: 16, color: Colors.grey[600]),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: widget,
        ),
      );
    }

    return widget;
  }

  void _showPartnerDialog(BuildContext context) {
    final partnerInfo = _aboutInfo?['partnerInfo'] ?? {};
    final title = partnerInfo['title'] ?? 'Become a Partner';
    final description =
        partnerInfo['description'] ??
        'Join our growing network of parking providers and charging station operators.';
    final benefits =
        partnerInfo['benefits'] as List<dynamic>? ??
        [
          'Increase your revenue',
          'Reach more customers',
          'Easy management tools',
          '24/7 support',
        ];
    final contactEmail = partnerInfo['contactEmail'] ?? 'partners@raknago.com';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.handshake_rounded, color: Color(0xFF1E88E5)),
            SizedBox(width: 12),
            Text('Partner'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(description, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 20),
              ...benefits.map((benefit) {
                final benefitText = benefit is String
                    ? benefit
                    : benefit['text'] ?? '';
                return _buildPartnerBenefit(benefitText);
              }).toList(),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      color: Colors.white,
                      size: 30,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Contact us at:',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contactEmail,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _launchURL('mailto:$contactEmail');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Contact'),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF1E88E5),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  void _showAccessibilityDialog(BuildContext context) {
    final accessibilityInfo = _aboutInfo?['accessibilityInfo'] ?? {};
    final title = accessibilityInfo['title'] ?? 'Our Commitment';
    final description =
        accessibilityInfo['description'] ??
        'RaknaGo is committed to ensuring digital accessibility for people with disabilities. We are continually improving the user experience for everyone.';
    final features =
        accessibilityInfo['features'] as List<dynamic>? ??
        [
          'Screen reader support',
          'High contrast mode',
          'Adjustable font sizes',
          'Voice commands',
          'Keyboard navigation',
        ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.accessibility_new_rounded, color: Color(0xFF1E88E5)),
            SizedBox(width: 12),
            Text('Accessibility'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 20),
              const Text(
                'Features:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...features.map((feature) {
                final featureText = feature is String
                    ? feature
                    : feature['text'] ?? '';
                return _buildAccessibilityFeature(featureText);
              }).toList(),
            ],
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

  Widget _buildAccessibilityFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF1E88E5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  void _showTermsOfUseDialog(BuildContext context) {
    final termsInfo = _aboutInfo?['termsInfo'] ?? {};
    final lastUpdated = termsInfo['lastUpdated'] ?? 'January 20, 2024';
    final sections =
        termsInfo['sections'] as List<dynamic>? ??
        [
          {
            'title': '1. Acceptance of Terms',
            'content':
                'By accessing and using RaknaGo, you accept and agree to be bound by the terms and provision of this agreement.',
          },
          {
            'title': '2. Use License',
            'content':
                'Permission is granted to temporarily use RaknaGo for personal, non-commercial transitory viewing only.',
          },
          {
            'title': '3. Disclaimer',
            'content':
                'The materials on RaknaGo are provided on an \'as is\' basis. RaknaGo makes no warranties, expressed or implied.',
          },
        ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.description_outlined, color: Color(0xFF1E88E5)),
            SizedBox(width: 12),
            Text('Terms of Use'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Last Updated: $lastUpdated',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ...sections.map((section) {
                final sectionTitle = section['title'] ?? '';
                final sectionContent = section['content'] ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sectionTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        sectionContent,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.feedback_outlined, color: Color(0xFF1E88E5)),
            SizedBox(width: 12),
            Text('Feedback'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'We\'d love to hear from you! Your feedback helps us improve ParkSpot.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: feedbackController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Share your thoughts...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E88E5),
                    width: 2,
                  ),
                ),
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
              if (feedbackController.text.isNotEmpty) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(child: Text('Thank you for your feedback!')),
                      ],
                    ),
                    backgroundColor: Colors.green[400],
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showRateUsDialog(BuildContext context) {
    int rating = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.star_rounded, color: Color(0xFF1E88E5)),
              SizedBox(width: 12),
              Text('Rate Us'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'How would you rate your experience with ParkSpot?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        rating = index + 1;
                      });
                    },
                    child: Icon(
                      index < rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: Colors.orange,
                      size: 45,
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: rating > 0
                  ? () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Thank you for rating us $rating stars!',
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green[400],
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSocialMediaDialog(BuildContext context) {
    final socialMedia = _aboutInfo?['socialMedia'] ?? {};
    final facebook = socialMedia['facebook'] ?? '';
    final instagram = socialMedia['instagram'] ?? '';
    final twitter = socialMedia['twitter'] ?? '';
    final linkedin = socialMedia['linkedin'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.share_rounded, color: Color(0xFF1E88E5)),
            SizedBox(width: 12),
            Text('Follow Us'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (facebook.isNotEmpty)
              _buildSocialButton(
                'Facebook',
                Icons.facebook,
                const Color(0xFF1877F2),
                () => _launchURL(facebook),
              ),
            if (facebook.isNotEmpty && instagram.isNotEmpty)
              const SizedBox(height: 12),
            if (instagram.isNotEmpty)
              _buildSocialButton(
                'Instagram',
                Icons.camera_alt_rounded,
                const Color(0xFFE4405F),
                () => _launchURL(instagram),
              ),
            if (instagram.isNotEmpty && twitter.isNotEmpty)
              const SizedBox(height: 12),
            if (twitter.isNotEmpty)
              _buildSocialButton(
                'Twitter',
                Icons.alternate_email_rounded,
                const Color(0xFF1DA1F2),
                () => _launchURL(twitter),
              ),
            if (twitter.isNotEmpty && linkedin.isNotEmpty)
              const SizedBox(height: 12),
            if (linkedin.isNotEmpty)
              _buildSocialButton(
                'LinkedIn',
                Icons.business_rounded,
                const Color(0xFF0A66C2),
                () => _launchURL(linkedin),
              ),
            if (facebook.isEmpty &&
                instagram.isEmpty &&
                twitter.isEmpty &&
                linkedin.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'No social media links available',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
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

  Widget _buildSocialButton(
    String name,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Text(
              name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
