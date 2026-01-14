import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme_provider.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'General';
  final List<String> _categories = ['General', 'Account', 'Service', 'Booking'];

  final List<Map<String, String>> _faqList = [
    // General Questions
    {
      'question': 'What is RaknaGo?',
      'answer':
          'RaknaGo is a mobile application that helps you find, book, and pay for parking spots easily. You can search for available parking spots near you, compare prices, and reserve your spot in advance.',
      'category': 'General',
    },
    {
      'question': 'Is the RaknaGo App free?',
      'answer':
          'Yes, downloading and using the RaknaGo app is completely free. You only pay for the parking sessions you book.',
      'category': 'General',
    },
    {
      'question': 'How do I download the app?',
      'answer':
          'You can download RaknaGo from the App Store (iOS) or Google Play Store (Android). Search for "RaknaGo" and tap Install.',
      'category': 'General',
    },
    {
      'question': 'What devices are supported?',
      'answer':
          'RaknaGo is available for iOS (iPhone) and Android devices. The app requires iOS 12.0 or later, or Android 6.0 (Marshmallow) or later.',
      'category': 'General',
    },
    {
      'question': 'How do I update the app?',
      'answer':
          'You can update RaknaGo through the App Store or Google Play Store. Go to your device\'s app store, search for RaknaGo, and tap Update if available.',
      'category': 'General',
    },
    // Account Questions
    {
      'question': 'How do I create an account?',
      'answer':
          'To create an account, open the app and tap "Sign Up". Enter your email address, create a password, and follow the verification steps. You can also sign up using your Google account.',
      'category': 'Account',
    },
    {
      'question': 'How can I log out from RaknaGo?',
      'answer':
          'To log out, go to Account > Logout. Confirm your action and you will be signed out.',
      'category': 'Account',
    },
    {
      'question': 'How to close RaknaGo account?',
      'answer':
          'To close your account, go to Account > Security > Delete Account. Please note this action is permanent and cannot be undone.',
      'category': 'Account',
    },
    {
      'question': 'I forgot my password. How do I reset it?',
      'answer':
          'On the login screen, tap "Forgot Password". Enter your email address and follow the instructions sent to your email to reset your password.',
      'category': 'Account',
    },
    {
      'question': 'How do I change my email address?',
      'answer':
          'Go to Account > Personal Info > Change Email. Enter your new email address and verify it with the confirmation code sent to your new email.',
      'category': 'Account',
    },
    {
      'question': 'How do I update my profile information?',
      'answer':
          'Go to Account > Personal Info. You can update your name, phone number, and street address. Note that gender and date of birth cannot be changed after account creation.',
      'category': 'Account',
    },
    {
      'question': 'How do I change my profile picture?',
      'answer':
          'Go to Account > Personal Info. Tap on your profile picture and select a new image from your gallery.',
      'category': 'Account',
    },
    // Service Questions
    {
      'question': 'How can I make a parking booking?',
      'answer':
          'To book a parking spot: 1) Open the app and search for parking spots near you. 2) Select an available spot. 3) Choose your parking duration. 4) Complete the payment. 5) Receive your booking confirmation.',
      'category': 'Service',
    },
    {
      'question': 'What payment methods are accepted?',
      'answer':
          'RaknaGo accepts various payment methods including credit cards, debit cards, and mobile wallets through Paymob integration.',
      'category': 'Service',
    },
    {
      'question': 'How do I find parking spots near me?',
      'answer':
          'The app uses your location to show nearby parking spots on the map. You can also use the search bar to find spots in a specific area.',
      'category': 'Service',
    },
    {
      'question': 'Can I filter parking spots?',
      'answer':
          'Yes! You can filter parking spots by availability, EV charging availability, and distance from your location using the filter options.',
      'category': 'Service',
    },
    {
      'question': 'What is EV charging?',
      'answer':
          'EV charging spots are parking spaces equipped with electric vehicle charging stations. You can filter for these spots if you need to charge your electric vehicle.',
      'category': 'Service',
    },
    {
      'question': 'How do I cancel a booking?',
      'answer':
          'Go to your Bookings section, select the booking you want to cancel, and tap Cancel. Please note that cancellation policies may apply.',
      'category': 'Service',
    },
    {
      'question': 'Can I extend my parking time?',
      'answer':
          'Yes, you can extend your parking time if the spot is still available. Go to your active booking and tap Extend Time.',
      'category': 'Service',
    },
    {
      'question': 'What amenities are available at parking spots?',
      'answer':
          'Parking spots may offer various amenities such as restaurants, shopping areas, WiFi, and accessibility features. Check the spot details to see available amenities.',
      'category': 'Service',
    },
    // Booking Questions
    {
      'question': 'How do I view my booking history?',
      'answer':
          'Go to the Bookings tab in the app to view all your past and current bookings. You can see details, receipts, and ratings for each booking.',
      'category': 'Booking',
    },
    {
      'question': 'How do I get directions to my booked parking spot?',
      'answer':
          'After booking, tap on the parking spot details and select "Get Directions". This will open your maps app with navigation to the location.',
      'category': 'Booking',
    },
    {
      'question': 'What happens if I arrive late?',
      'answer':
          'Your booking starts at the scheduled time. If you arrive late, you may lose some of your paid time. We recommend arriving on time.',
      'category': 'Booking',
    },
    {
      'question': 'Can I book multiple spots at once?',
      'answer':
          'Currently, you can only book one parking spot at a time. Complete your current booking before making a new one.',
      'category': 'Booking',
    },
    {
      'question': 'How do I rate a parking spot?',
      'answer':
          'After your parking session ends, you can rate the spot from 1 to 5 stars and leave a review in the Bookings section.',
      'category': 'Booking',
    },
    {
      'question': 'What if the parking spot is not available when I arrive?',
      'answer':
          'If the spot is not available, contact our support team immediately. We will help you find an alternative spot or provide a refund.',
      'category': 'Booking',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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
          'Help Center',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF212121),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF1E88E5),
              unselectedLabelColor: isDark
                  ? Colors.grey[400]
                  : Colors.grey[600],
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              indicatorColor: const Color(0xFF1E88E5),
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'FAQ'),
                Tab(text: 'Contact us'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildFAQTab(), _buildContactTab()],
      ),
    );
  }

  Widget _buildFAQTab() {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    return Column(
      children: [
        const SizedBox(height: 16),

        // Category Chips - Horizontal Scroll
        SizedBox(
          height: 45,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isSelected = _selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF1E88E5)
                          : (isDark ? Colors.grey[800] : Colors.white),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: const Color(0xFF1E88E5),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                    ? Colors.white
                                    : const Color(0xFF1E88E5)),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2F38) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: isDark
                  ? Border.all(color: Colors.grey[700]!, width: 1)
                  : null,
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF212121),
              ),
              onChanged: (value) {
                setState(() {}); // Rebuild to filter FAQ list
              },
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                  fontSize: 15,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                  size: 22,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                          size: 22,
                        ),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                          });
                        },
                      )
                    : IconButton(
                        icon: Icon(
                          Icons.mic_none_rounded,
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                          size: 22,
                        ),
                        onPressed: () {},
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // FAQ List
        Expanded(child: _buildFilteredFAQList()),
      ],
    );
  }

  Widget _buildFilteredFAQList() {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    // Filter by category and search
    final filteredList = _faqList.where((faq) {
      final matchesCategory =
          faq['category'] == _selectedCategory ||
          _selectedCategory == 'General';
      final searchQuery = _searchController.text.toLowerCase();
      final matchesSearch =
          searchQuery.isEmpty ||
          faq['question']!.toLowerCase().contains(searchQuery) ||
          faq['answer']!.toLowerCase().contains(searchQuery);
      return matchesCategory && matchesSearch;
    }).toList();

    if (filteredList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 64,
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No questions found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try a different search term or category',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final faq = filteredList[index];
        return _buildFAQItem(faq['question']!, faq['answer']!);
      },
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[600]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
          childrenPadding: const EdgeInsets.only(bottom: 16),
          title: Text(
            question,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : const Color(0xFF212121),
            ),
          ),
          trailing: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF1E88E5),
            size: 24,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Text(
                answer,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[300] : Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTab() {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),

        // Contact us Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.headset_mic_rounded,
                  color: Color(0xFF1E88E5),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Contact us',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF212121),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Contact Options
        _buildContactOption(
          icon: Icons.chat_bubble_outline,
          iconColor: const Color(0xFF25D366),
          title: 'WhatsApp',
          onTap: () => _launchWhatsApp(),
        ),

        _buildContactOption(
          icon: Icons.camera_alt_rounded,
          iconColor: const Color(0xFFE4405F),
          title: 'Instagram',
          onTap: () => _launchInstagram(),
        ),

        _buildContactOption(
          icon: Icons.facebook,
          iconColor: const Color(0xFF1877F2),
          title: 'Facebook',
          onTap: () => _launchFacebook(),
        ),

        _buildContactOption(
          icon: Icons.alternate_email_rounded,
          iconColor: const Color(0xFF1DA1F2),
          title: 'Twitter',
          onTap: () => _launchTwitter(),
        ),

        _buildContactOption(
          icon: Icons.language_rounded,
          iconColor: Colors.grey[700]!,
          title: 'Website',
          onTap: () => _launchWebsite(),
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                  width: 1,
                ),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF212121),
          ),
        ),
      ),
    );
  }

  Future<void> _launchWhatsApp() async {
    // Replace with your WhatsApp number (format: country code + number without +)
    const whatsappNumber = '201234567890'; // Example: Egypt number
    final url = Uri.parse('https://wa.me/$whatsappNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackBar('Could not open WhatsApp');
    }
  }

  Future<void> _launchInstagram() async {
    // Replace with your Instagram username
    const instagramUsername = 'raknago';
    final url = Uri.parse('https://www.instagram.com/$instagramUsername/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackBar('Could not open Instagram');
    }
  }

  Future<void> _launchFacebook() async {
    // Replace with your Facebook page ID or username
    const facebookPage = 'raknago';
    final url = Uri.parse('https://www.facebook.com/$facebookPage');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackBar('Could not open Facebook');
    }
  }

  Future<void> _launchTwitter() async {
    // Replace with your Twitter username
    const twitterUsername = 'raknago';
    final url = Uri.parse('https://twitter.com/$twitterUsername');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackBar('Could not open Twitter');
    }
  }

  Future<void> _launchWebsite() async {
    // Replace with your website URL
    const websiteUrl = 'https://www.raknago.com';
    final url = Uri.parse(websiteUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackBar('Could not open website');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
