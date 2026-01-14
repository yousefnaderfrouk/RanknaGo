import 'package:flutter/material.dart';
import '../theme_provider.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
          'Privacy Policy',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF212121),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Introduction
            Builder(
              builder: (context) {
                final themeProvider = ThemeProvider.of(context);
                final isDark = themeProvider?.isDarkMode ?? false;
                return Text(
                  'At ParkSpot, we respect and protect the privacy of our users. This Privacy Policy outlines the types of personal information we collect, how we use it, and how we protect your information.',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    height: 1.6,
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // Section 1: Information We Collect
            _buildSectionTitle(context, 'Information We Collect'),
            const SizedBox(height: 12),
            _buildParagraph(
              context,
              'When you use our app, we may collect the following types of personal information:',
            ),
            const SizedBox(height: 12),
            _buildBulletPoint(
              context,
              'Device Information: We may collect information about the type of device you use, its operating system, and other technical details to help us improve our app.',
            ),
            const SizedBox(height: 8),
            _buildBulletPoint(
              context,
              'Usage Information: We may collect information about how you use our app, such as which features you use and how often you use them.',
            ),
            const SizedBox(height: 8),
            _buildBulletPoint(
              context,
              'Personal Information: We may collect personal information, such as your name, email address, or phone number, if you choose to provide it to us.',
            ),

            const SizedBox(height: 32),

            // Section 2: How We Use Your Information
            _buildSectionTitle(context, 'How We Use Your Information'),
            const SizedBox(height: 12),
            _buildParagraph(
              context,
              'We use your information for the following purposes:',
            ),
            const SizedBox(height: 12),
            _buildBulletPoint(
              context,
              'To provide and maintain our services: We use your information to operate and improve the ParkSpot app.',
            ),
            const SizedBox(height: 8),
            _buildBulletPoint(
              context,
              'To communicate with you: We may use your contact information to send you updates, notifications, and respond to your inquiries.',
            ),
            const SizedBox(height: 8),
            _buildBulletPoint(
              context,
              'To personalize your experience: We may use your information to customize the app based on your preferences and usage patterns.',
            ),
            const SizedBox(height: 8),
            _buildBulletPoint(
              context,
              'To ensure security: We use your information to detect and prevent fraud, abuse, and other harmful activities.',
            ),

            const SizedBox(height: 32),

            // Section 3: Information Sharing
            _buildSectionTitle(context, 'Information Sharing'),
            const SizedBox(height: 12),
            _buildParagraph(
              context,
              'We do not sell, trade, or rent your personal information to third parties. We may share your information with:',
            ),
            const SizedBox(height: 12),
            _buildBulletPoint(
              context,
              'Service Providers: We may share your information with third-party service providers who help us operate our app and provide services to you.',
            ),
            const SizedBox(height: 8),
            _buildBulletPoint(
              context,
              'Legal Requirements: We may disclose your information if required by law or in response to valid requests by public authorities.',
            ),
            const SizedBox(height: 8),
            _buildBulletPoint(
              context,
              'Business Transfers: In the event of a merger, acquisition, or sale of assets, your information may be transferred to the new owner.',
            ),

            const SizedBox(height: 32),

            // Section 4: Data Security
            _buildSectionTitle(context, 'Data Security'),
            const SizedBox(height: 12),
            _buildParagraph(
              context,
              'We take the security of your personal information seriously and implement appropriate technical and organizational measures to protect it from unauthorized access, disclosure, alteration, or destruction.',
            ),
            const SizedBox(height: 12),
            _buildParagraph(
              context,
              'However, no method of transmission over the internet or electronic storage is 100% secure. While we strive to protect your information, we cannot guarantee its absolute security.',
            ),

            const SizedBox(height: 32),

            // Section 5: Your Rights
            _buildSectionTitle(context, 'Your Rights'),
            const SizedBox(height: 12),
            _buildParagraph(
              context,
              'You have the following rights regarding your personal information:',
            ),
            const SizedBox(height: 12),
            _buildBulletPoint(
              context,
              'Access: You can request access to the personal information we hold about you.',
            ),
            const SizedBox(height: 8),
            _buildBulletPoint(
              context,
              'Correction: You can request that we correct any inaccurate or incomplete information.',
            ),
            const SizedBox(height: 8),
            _buildBulletPoint(
              context,
              'Deletion: You can request that we delete your personal information, subject to certain legal obligations.',
            ),
            const SizedBox(height: 8),
            _buildBulletPoint(
              context,
              'Objection: You can object to the processing of your personal information in certain circumstances.',
            ),

            const SizedBox(height: 32),

            // Section 6: Cookies and Tracking
            _buildSectionTitle(context, 'Cookies and Tracking Technologies'),
            const SizedBox(height: 12),
            _buildParagraph(
              context,
              'We may use cookies and similar tracking technologies to enhance your experience on our app. Cookies are small files stored on your device that help us remember your preferences and improve our services.',
            ),
            const SizedBox(height: 12),
            _buildParagraph(
              context,
              'You can control the use of cookies through your device settings. However, disabling cookies may affect the functionality of certain features in the app.',
            ),

            const SizedBox(height: 32),

            // Section 7: Children's Privacy
            _buildSectionTitle(context, 'Children\'s Privacy'),
            const SizedBox(height: 12),
            _buildParagraph(
              context,
              'Our app is not intended for children under the age of 13. We do not knowingly collect personal information from children under 13. If we become aware that we have collected personal information from a child under 13, we will take steps to delete such information.',
            ),

            const SizedBox(height: 32),

            // Section 8: Changes to This Policy
            _buildSectionTitle(context, 'Changes to This Privacy Policy'),
            const SizedBox(height: 12),
            _buildParagraph(
              context,
              'We may update this Privacy Policy from time to time to reflect changes in our practices or legal requirements. We will notify you of any significant changes by posting the new Privacy Policy on this page and updating the "Last Updated" date.',
            ),
            const SizedBox(height: 12),
            _buildParagraph(
              context,
              'We encourage you to review this Privacy Policy periodically to stay informed about how we are protecting your information.',
            ),

            const SizedBox(height: 32),

            // Section 9: Contact Us
            _buildSectionTitle(context, 'Contact Us'),
            const SizedBox(height: 12),
            _buildParagraph(
              context,
              'If you have any questions or concerns about this Privacy Policy or our data practices, please contact us at:',
            ),
            const SizedBox(height: 16),

            // Contact Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E88E5).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.email_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'support@parkspot.com',
                    style: TextStyle(fontSize: 15, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Address',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ParkSpot Inc.\n123 Main Street, Suite 100\nNew York, NY 10001\nUnited States',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Last Updated
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Last Updated: January 20, 2024',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : const Color(0xFF212121),
      ),
    );
  }

  Widget _buildParagraph(BuildContext context, String text) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        color: isDark ? Colors.grey[300] : Colors.grey[700],
        height: 1.6,
      ),
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFF1E88E5),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}
