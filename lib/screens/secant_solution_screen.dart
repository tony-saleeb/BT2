import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' show pow;
import '../util/number_formatter.dart';

class SecantSolutionScreen extends StatefulWidget {
  final List<Map<String, dynamic>> results;
  final String function;
  final double xMinus1;
  final double x0;
  final double es;
  final int maxIterations;
  final bool useError;
  final int decimalPlaces;

  const SecantSolutionScreen({
    super.key,
    required this.results,
    required this.function,
    required this.xMinus1,
    required this.x0,
    required this.es,
    required this.maxIterations,
    required this.useError,
    required this.decimalPlaces,
  });

  @override
  State<SecantSolutionScreen> createState() => _SecantSolutionScreenState();
}

class _SecantSolutionScreenState extends State<SecantSolutionScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final _tabScrollController = ScrollController();
  final _tableScrollController = ScrollController();
  int _currentTabIndex = 0;
  bool _shouldRound = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (_currentTabIndex != _tabController.index) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });

      if (_tabScrollController.hasClients) {
        final tabWidth = 138.0; // 130 + 8 padding
        final screenWidth = MediaQuery.of(context).size.width;
        final tabPosition = tabWidth * _currentTabIndex;
        final scrollOffset = tabPosition - (screenWidth / 2) + (tabWidth / 2);

        _tabScrollController.animateTo(
          scrollOffset.clamp(
            0.0,
            _tabScrollController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _tabScrollController.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  String _formatNumber(double? number) {
    if (number == null) return "--";
    
    String formattedNumber;
    if (_shouldRound) {
      formattedNumber = number.toStringAsFixed(widget.decimalPlaces);
    } else {
      // Convert to string with higher precision to avoid rounding issues
      String numStr = number.toStringAsFixed(15);
      
      // Find decimal point position
      int decimalPos = numStr.indexOf('.');
      if (decimalPos == -1) return numStr;
      
      // Keep only the needed decimal places without rounding
      if (decimalPos + widget.decimalPlaces + 1 <= numStr.length) {
        formattedNumber = numStr.substring(0, decimalPos + widget.decimalPlaces + 1);
      } else {
        formattedNumber = numStr;
      }
    }
    
    // Remove trailing zeros and decimal point if needed
    if (formattedNumber.contains('.')) {
      // Remove trailing zeros
      formattedNumber = formattedNumber.replaceAll(RegExp(r'0+$'), '');
      // Remove decimal point if it's the last character
      formattedNumber = formattedNumber.replaceAll(RegExp(r'\.$'), '');
    }
    
    return formattedNumber;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.results.isEmpty) {
      return _buildEmptyState(context);
    }
    
    return Scaffold(
      backgroundColor: colorScheme.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors:
                isDark
                ? [
                    colorScheme.surface,
                    colorScheme.surface.withOpacity(0.95),
                  ]
                : [
                    colorScheme.primary.withOpacity(0.05),
                    colorScheme.secondary.withOpacity(0.05),
                    colorScheme.tertiary.withOpacity(0.05),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  children: [
                    Container(
                      height: 72.h,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(36.r),
                        border: Border.all(
                          color: colorScheme.outline.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(36.r),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: _tabScrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Row(
                                children: [
                                  _buildTabItem(
                                    Icons.functions_rounded,
                                    'Function',
                                    0,
                                    colorScheme.primary,
                                  ),
                                  _buildTabItem(
                                    Icons.table_chart_rounded,
                                    'Steps',
                                    1,
                                    colorScheme.secondary,
                                  ),
                                  _buildTabItem(
                                    Icons.check_circle_outline_rounded,
                                    'Result',
                                    2,
                                    colorScheme.tertiary,
                                  ),
                                  _buildTabItem(
                                    Icons.bug_report_rounded,
                                    'Debug',
                                    3,
                                    colorScheme.error,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildFunctionView(context),
                    _buildStepsView(context),
                    _buildResultView(context),
                    _buildDebugView(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(IconData icon, String label, int index, Color color) {
    final isSelected = _currentTabIndex == index;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () {
          _tabController.index = index;
          setState(() {
            _currentTabIndex = index;
          });

          final tabWidth = 138.0; // 130 + 8 padding
          final screenWidth = MediaQuery.of(context).size.width;
          final tabPosition = tabWidth * index;
          final scrollOffset = tabPosition - (screenWidth / 2) + (tabWidth / 2);

          _tabScrollController.animateTo(
            scrollOffset.clamp(
              0.0,
              _tabScrollController.position.maxScrollExtent,
            ),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        },
        child: Container(
          width: 130.w,
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32.r),
              border: Border.all(
                color:
                    isSelected
                        ? Colors.transparent
                        : colorScheme.outline.withOpacity(0.2),
                width: 1.5,
              ),
              gradient:
                  isSelected
                      ? LinearGradient(
                        colors: [colorScheme.primary, colorScheme.secondary],
                      )
                      : null,
              boxShadow:
                  isSelected
                      ? [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  transform: Matrix4.identity()..scale(isSelected ? 1.2 : 1.0),
                  child: Icon(
                    icon,
                    size: isSelected ? 24.w : 20.w,
                    color: isSelected ? Colors.white : color.withOpacity(0.5),
                  ),
                ),
                SizedBox(width: 8.w),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: isSelected ? 16.sp : 14.sp,
                    color: isSelected ? Colors.white : color.withOpacity(0.5),
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            padding: EdgeInsets.all(24.w),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer.withOpacity(
                                0.2,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.warning_rounded,
                              size: 48.w,
                              color: colorScheme.error,
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 24.h),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutBack,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: Text(
                              'No Results Available',
                              style: Theme.of(
                                context,
                              ).textTheme.headlineSmall?.copyWith(
                                color: colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutBack,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: Text(
                              'There was an error computing the results.',
                              style: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Row(
        children: [
          Hero(
            tag: 'back_button',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16.r),
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: colorScheme.primary,
                    size: 24.w,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 20.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback:
                      (bounds) => LinearGradient(
                        colors: [colorScheme.primary, colorScheme.tertiary],
                  ).createShader(bounds),
                  child: Text(
                    'SECANT METHOD',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: Colors.white,
                    ).apply(fontSizeDelta: 2.sp),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Solution Steps',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16.w : 24.w,
        vertical: 8.h,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(bottom: isSmallScreen ? 24.h : 32.h),
                padding: EdgeInsets.all(isSmallScreen ? 20.w : 24.w),
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary.withOpacity(0.1),
                      colorScheme.secondary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.1),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 12.w : 16.w),
                      decoration: BoxDecoration(
                        color: isDark ? colorScheme.surface : Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.functions_rounded,
                        color: colorScheme.primary,
                        size: isSmallScreen ? 24.w : 32.w,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Iteration Function',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: isSmallScreen ? 24.sp : 28.sp,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Secant Method',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: isSmallScreen ? 14.sp : 16.sp,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                margin: EdgeInsets.only(bottom: isSmallScreen ? 24.h : 32.h),
                decoration: BoxDecoration(
                  color: isDark ? colorScheme.surface : Colors.white,
                  borderRadius: BorderRadius.circular(24.r),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.1),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 20.w : 24.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  colorScheme.primary.withOpacity(0.15),
                                  colorScheme.secondary.withOpacity(0.15),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: colorScheme.primary.withOpacity(0.2),
                                width: 1.5,
                              ),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 20.w : 24.w,
                                  vertical: isSmallScreen ? 16.h : 20.h,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isSmallScreen ? 12.w : 16.w,
                                        vertical: isSmallScreen ? 6.h : 8.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(10.r),
                                      ),
                                      child: Text(
                                        'f(x) =',
                                        style: GoogleFonts.robotoMono(
                                          fontSize: isSmallScreen ? 18.sp : 20.sp,
                                          color: colorScheme.primary
                                              .withOpacity(0.7),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16.w),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isSmallScreen ? 16.w : 20.w,
                                        vertical: isSmallScreen ? 8.h : 10.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isDark
                                                ? colorScheme.surface
                                                : Colors.white,
                                        borderRadius: BorderRadius.circular(12.r),
                                        boxShadow: [
                                          BoxShadow(
                                            color: colorScheme.primary
                                                .withOpacity(0.1),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        widget.function,
                                        style: GoogleFonts.robotoMono(
                                          fontSize: isSmallScreen ? 24.sp : 28.sp,
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 20.h : 24.h),

                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isSmallScreen ? 20.w : 24.w),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  colorScheme.secondaryContainer.withOpacity(
                                    0.5,
                                  ),
                                  colorScheme.tertiaryContainer.withOpacity(
                                    0.5,
                                  ),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(12.w),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14.r),
                                        boxShadow: [
                                          BoxShadow(
                                            color: colorScheme.shadow
                                                .withOpacity(0.1),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.info_outline_rounded,
                                        color: colorScheme.secondary,
                                        size: isSmallScreen ? 20.w : 24.w,
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Text(
                                        'Initial Values',
                                        style: TextStyle(
                                          color: colorScheme.secondary,
                                          fontSize: isSmallScreen ? 16.sp : 18.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16.h),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 16.w : 20.w,
                                    vertical: isSmallScreen ? 12.h : 16.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                    borderRadius: BorderRadius.circular(16.r),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colorScheme.shadow.withOpacity(0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(8.w),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8.r),
                                            ),
                                            child: Icon(
                                              Icons.location_on_outlined,
                                              size: isSmallScreen ? 16.w : 18.w,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                          SizedBox(width: 12.w),
                                          Text(
                                            'First Point (x-1): ',
                                            style: TextStyle(
                                              color: colorScheme.onSurface.withOpacity(0.8),
                                              fontSize: isSmallScreen ? 14.sp : 16.sp,
                                            ),
                                          ),
                                          Text(
                                            _formatNumber(widget.xMinus1),
                                            style: GoogleFonts.robotoMono(
                                              fontSize: isSmallScreen ? 14.sp : 16.sp,
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12.h),
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(8.w),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8.r),
                                            ),
                                            child: Icon(
                                              Icons.location_on_outlined,
                                              size: isSmallScreen ? 16.w : 18.w,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                          SizedBox(width: 12.w),
                                          Text(
                                            'Second Point (x₀): ',
                                            style: TextStyle(
                                              color: colorScheme.onSurface.withOpacity(0.8),
                                              fontSize: isSmallScreen ? 14.sp : 16.sp,
                                            ),
                                          ),
                                          Text(
                                            _formatNumber(widget.x0),
                                            style: GoogleFonts.robotoMono(
                                              fontSize: isSmallScreen ? 14.sp : 16.sp,
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                SizedBox(height: 16.h),
                                
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 16.w : 20.w,
                                    vertical: isSmallScreen ? 12.h : 16.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                    borderRadius: BorderRadius.circular(16.r),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colorScheme.shadow.withOpacity(0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(8.w),
                                            decoration: BoxDecoration(
                                              color: colorScheme.secondary.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8.r),
                                            ),
                                            child: Icon(
                                              Icons.auto_graph_rounded,
                                              size: isSmallScreen ? 16.w : 18.w,
                                              color: colorScheme.secondary,
                                            ),
                                          ),
                                          SizedBox(width: 12.w),
                                          Text(
                                            'Stopping Criteria: ',
                                            style: TextStyle(
                                              color: colorScheme.onSurface.withOpacity(0.8),
                                              fontSize: isSmallScreen ? 14.sp : 16.sp,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12.h),
                                      Row(
                                        children: [
                                          SizedBox(width: 36.w),
                                          if (widget.useError) ...[
                                            Text(
                                              'Relative Error (es): ',
                                              style: TextStyle(
                                                color: colorScheme.onSurface.withOpacity(0.8),
                                                fontSize: isSmallScreen ? 14.sp : 16.sp,
                                              ),
                                            ),
                                            Text(
                                              '${_formatNumber(widget.es)}%',
                                              style: GoogleFonts.robotoMono(
                                                fontSize: isSmallScreen ? 14.sp : 16.sp,
                                                fontWeight: FontWeight.w600,
                                                color: colorScheme.secondary,
                                              ),
                                            ),
                                          ] else ...[
                                            Text(
                                              'Maximum Iterations: ',
                                              style: TextStyle(
                                                color: colorScheme.onSurface.withOpacity(0.8),
                                                fontSize: isSmallScreen ? 14.sp : 16.sp,
                                              ),
                                            ),
                                            Text(
                                              widget.maxIterations.toString(),
                                              style: GoogleFonts.robotoMono(
                                                fontSize: isSmallScreen ? 14.sp : 16.sp,
                                                fontWeight: FontWeight.w600,
                                                color: colorScheme.secondary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: isSmallScreen ? 20.h : 24.h),
                          
                          Container(
                            padding: EdgeInsets.all(isSmallScreen ? 20.w : 24.w),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  colorScheme.secondaryContainer.withOpacity(
                                    0.5,
                                  ),
                                  colorScheme.tertiaryContainer.withOpacity(
                                    0.5,
                                  ),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(12.w),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14.r),
                                        boxShadow: [
                                          BoxShadow(
                                            color: colorScheme.shadow
                                                .withOpacity(0.1),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.info_outline_rounded,
                                        color: colorScheme.secondary,
                                        size: isSmallScreen ? 20.w : 24.w,
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Text(
                                        'About This Method',
                                        style: TextStyle(
                                          color: colorScheme.secondary,
                                          fontSize: isSmallScreen ? 16.sp : 18.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'The Secant Method approximates the derivative in Newton\'s method by using a finite difference instead of an analytical derivative. It requires two initial points to calculate the slope of the secant line.',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: isSmallScreen ? 14.sp : 16.sp,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(isSmallScreen ? 16.w : 20.w),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                    borderRadius: BorderRadius.circular(16.r),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colorScheme.shadow.withOpacity(0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Formula:',
                                        style: TextStyle(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: isSmallScreen ? 14.sp : 16.sp,
                                        ),
                                      ),
                                      SizedBox(height: 12.h),
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isSmallScreen ? 12.w : 16.w,
                                          vertical: isSmallScreen ? 10.h : 12.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(12.r),
                                          border: Border.all(
                                            color: colorScheme.primary.withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          'xi+1 = xi - f(xi) × (xi - x-1) ÷ (f(xi) - f(x-1))',
                                          style: GoogleFonts.robotoMono(
                                            fontSize: isSmallScreen ? 14.sp : 16.sp,
                                            fontWeight: FontWeight.w500,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 16.h),
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isSmallScreen ? 16.w : 20.w,
                                          vertical: isSmallScreen ? 8.h : 12.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.secondary.withOpacity(
                                            0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(14.r),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.tips_and_updates_outlined,
                                              size: isSmallScreen ? 16.w : 20.w,
                                              color: colorScheme.secondary,
                                            ),
                                            SizedBox(width: 8.w),
                                            Expanded(
                                              child: Text(
                                                'Generally faster convergence than bisection',
                                                style: TextStyle(
                                                  color: colorScheme.secondary,
                                                  fontSize: isSmallScreen ? 12.sp : 14.sp,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStepsView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.r),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surface,
                colorScheme.surface.withOpacity(0.95),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.secondary.withOpacity(0.2),
                                colorScheme.secondaryContainer.withOpacity(0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.table_chart_rounded,
                            color: colorScheme.secondary,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Text(
                            'ITERATION STEPS',
                            style: TextStyle(
                              color: colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    _buildPrecisionToggle(colorScheme, isSmallScreen),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.1),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20.r),
                  child: SingleChildScrollView(
                controller: _tableScrollController,
                scrollDirection: Axis.horizontal,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dataTableTheme: DataTableThemeData(
                      headingTextStyle: TextStyle(
                        color: colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                      dataTextStyle: GoogleFonts.robotoMono(
                        fontSize: 14.sp,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16.w : 24.w,
                      vertical: isSmallScreen ? 8.h : 16.h,
                    ),
                    child: DataTable(
                      headingRowHeight: isSmallScreen ? 56.h : 64.h,
                      dataRowHeight: isSmallScreen ? 52.h : 60.h,
                      columnSpacing: 0,
                      horizontalMargin: isSmallScreen ? 16.w : 24.w,
                      headingRowColor: MaterialStateProperty.all(
                        colorScheme.primary.withOpacity(0.1),
                      ),
                          border: TableBorder(
                            horizontalInside: BorderSide(
                          color: colorScheme.primary.withOpacity(0.1),
                              width: 1,
                        ),
                            verticalInside: BorderSide(
                              color: colorScheme.primary.withOpacity(0.1),
                              width: 1,
                          ),
                      ),
                      columns: [
                        _buildColumnHeader(
                              'Iteration',
                          Icons.format_list_numbered,
                          isSmallScreen,
                          colorScheme,
                        ),
                        _buildColumnHeader(
                              'xₙ₋₁',
                          Icons.functions,
                          isSmallScreen,
                          colorScheme,
                        ),
                        _buildColumnHeader(
                              'f(xₙ₋₁)',
                          Icons.calculate_outlined,
                          isSmallScreen,
                          colorScheme,
                        ),
                        _buildColumnHeader(
                              'xₙ',
                          Icons.functions,
                          isSmallScreen,
                          colorScheme,
                        ),
                        _buildColumnHeader(
                              'f(xₙ)',
                          Icons.calculate_outlined,
                          isSmallScreen,
                          colorScheme,
                        ),
                        _buildColumnHeader(
                              'Error %',
                          Icons.percent,
                          isSmallScreen,
                          colorScheme,
                        ),
                      ],
                      rows: widget.results.asMap().entries.map((entry) {
                        final result = entry.value;
                        final isRoot = result['isRoot'];
                        final isLastRow = result == widget.results.last;
                        
                        return DataRow(
                          color: MaterialStateProperty.resolveWith<Color?>((
                            Set<MaterialState> states,
                          ) {
                            if (isLastRow) {
                              return colorScheme.primaryContainer.withOpacity(0.1);
                            }
                            if (states.contains(MaterialState.hovered)) {
                              return colorScheme.surfaceVariant.withOpacity(0.5);
                            }
                            return null;
                          }),
                          cells: [
                            _buildDataCell(
                              context,
                                  (result['iteration'] + 1).toString(),
                              isLastRow || isRoot,
                            ),
                            _buildDataCell(
                              context,
                              _formatNumber(result['xi_minus1']),
                              isLastRow || isRoot,
                            ),
                            _buildDataCell(
                              context,
                              _formatNumber(result['fxi_minus1']),
                              isLastRow || isRoot,
                            ),
                            _buildDataCell(
                              context,
                              _formatNumber(result['xi']),
                              isLastRow || isRoot,
                            ),
                            _buildDataCell(
                              context,
                              _formatNumber(result['fxi']),
                              isLastRow || isRoot,
                            ),
                            _buildDataCell(
                              context,
                              result['ea'] != null
                                  ? '${_formatNumber(result['ea']!)}%'
                                  : '--',
                              isLastRow || isRoot,
                            ),
                          ],
                        );
                      }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DataColumn _buildColumnHeader(
    String text,
    IconData icon,
    bool isSmallScreen,
    ColorScheme colorScheme,
  ) {
    // Use rich text for complex subscripts
    Widget textWidget;
    
    if (text == 'xₙ₋₁') {
      textWidget = RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            TextSpan(
              text: 'x',
              style: GoogleFonts.robotoMono(
                color: colorScheme.secondary,
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 14.sp : 16.sp,
              ),
            ),
            TextSpan(
              text: 'i-1',
              style: GoogleFonts.robotoMono(
                color: colorScheme.secondary,
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 12.sp : 14.sp,
              ),
            ),
          ],
        ),
      );
    } else if (text == 'f(xₙ₋₁)') {
      textWidget = RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            TextSpan(
              text: 'f(x',
              style: GoogleFonts.robotoMono(
                color: colorScheme.secondary,
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 14.sp : 16.sp,
              ),
            ),
            TextSpan(
              text: 'i-1',
              style: GoogleFonts.robotoMono(
                color: colorScheme.secondary,
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 12.sp : 14.sp,
              ),
            ),
            TextSpan(
              text: ')',
              style: GoogleFonts.robotoMono(
                color: colorScheme.secondary,
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 14.sp : 16.sp,
              ),
            ),
          ],
        ),
      );
    } else if (text == 'xₙ') {
      textWidget = RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            TextSpan(
              text: 'x',
              style: GoogleFonts.robotoMono(
                color: colorScheme.secondary,
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 14.sp : 16.sp,
              ),
            ),
            TextSpan(
              text: 'i',
              style: GoogleFonts.robotoMono(
                color: colorScheme.secondary,
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 12.sp : 14.sp,
              ),
            ),
          ],
        ),
      );
    } else if (text == 'f(xₙ)') {
      textWidget = RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            TextSpan(
              text: 'f(x',
              style: GoogleFonts.robotoMono(
                color: colorScheme.secondary,
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 14.sp : 16.sp,
              ),
            ),
            TextSpan(
              text: 'i',
              style: GoogleFonts.robotoMono(
                color: colorScheme.secondary,
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 12.sp : 14.sp,
              ),
            ),
            TextSpan(
              text: ')',
              style: GoogleFonts.robotoMono(
                color: colorScheme.secondary,
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 14.sp : 16.sp,
              ),
            ),
          ],
        ),
      );
    } else {
      textWidget = Text(
        text,
        textAlign: TextAlign.center,
        overflow: TextOverflow.visible,
        style: GoogleFonts.robotoMono(
          color: colorScheme.secondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          fontSize: isSmallScreen ? 14.sp : 16.sp,
        ),
      );
    }
    
    return DataColumn(
      label: SizedBox(
        width: isSmallScreen ? 150.w : 180.w,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: isSmallScreen ? 16.w : 18.w,
                color: colorScheme.primary,
              ),
              SizedBox(width: 6.w),
              Flexible(
                child: textWidget,
              ),
            ],
          ),
        ),
      ),
    );
  }

  DataCell _buildDataCell(BuildContext context, String text, bool isHighlighted) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    
    // Calculate if this is the last column based on the content (ea column)
    final isLastColumn = text.contains('%') || text == '--';
    
    return DataCell(
      Container(
        width: isSmallScreen ? 150.w : 180.w,
        decoration: BoxDecoration(
          border: !isLastColumn
              ? Border(
                  right: BorderSide(
                    color: colorScheme.outline.withOpacity(0.1),
                    width: 1,
                  ),
                )
              : null,
        ),
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 8.w : 12.w,
            vertical: isSmallScreen ? 4.h : 6.h,
          ),
          child: Center(
            child: Text(
              text,
              style: GoogleFonts.robotoMono(
                fontSize: isSmallScreen ? 14.sp : 16.sp,
                color: isHighlighted ? colorScheme.primary : colorScheme.onSurface,
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrecisionToggle(ColorScheme colorScheme, bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Decimal Places Button
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: colorScheme.secondary.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.format_list_numbered,
                  size: 18.w,
                  color: colorScheme.secondary,
                ),
                SizedBox(width: 8.w),
                Text(
                  '${widget.decimalPlaces} decimals',
                  style: TextStyle(
                    color: colorScheme.secondary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          // Round Toggle Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12.r),
              onTap: () {
                setState(() {
                  _shouldRound = !_shouldRound;
                });
              },
              child: Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: _shouldRound
                      ? colorScheme.secondary.withOpacity(0.1)
                      : colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: _shouldRound
                        ? colorScheme.secondary.withOpacity(0.3)
                        : colorScheme.outline.withOpacity(0.1),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 300),
                      turns: _shouldRound ? 0.5 : 0,
                      child: Icon(
                        Icons.roundabout_right,
                        size: 18.w,
                        color: _shouldRound
                            ? colorScheme.secondary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Round',
                      style: TextStyle(
                        color: _shouldRound
                            ? colorScheme.secondary
                            : colorScheme.onSurfaceVariant,
                        fontSize: 14.sp,
                        fontWeight: _shouldRound ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lastResult = widget.results.last;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.r),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surface,
                colorScheme.surface.withOpacity(0.95),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.tertiary.withOpacity(0.2),
                            colorScheme.tertiaryContainer.withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        color: colorScheme.tertiary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'ROOT FOUND',
                      style: TextStyle(
                        color: colorScheme.tertiary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 16.w : 24.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.tertiaryContainer.withOpacity(0.2),
                        colorScheme.secondaryContainer.withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: colorScheme.tertiary.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Final Root',
                              style: TextStyle(
                                color: colorScheme.tertiary,
                                fontWeight: FontWeight.w500,
                                fontSize: isSmallScreen ? 14.sp : 16.sp,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Text(
                              _formatNumber(lastResult['xi_plus1']),
                              style: GoogleFonts.robotoMono(
                                fontSize: isSmallScreen ? 18.sp : 20.sp,
                                color: colorScheme.tertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (lastResult['ea'] != null) ...[
                        SizedBox(height: isSmallScreen ? 12.h : 16.h),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Final Error (ε%)',
                                style: TextStyle(
                                  color: colorScheme.tertiary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: isSmallScreen ? 14.sp : 16.sp,
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Text(
                                lastResult['ea'] != null
                                    ? '${_formatNumber(lastResult['ea']!)}%'
                                    : '--',
                                style: GoogleFonts.robotoMono(
                                  fontSize: isSmallScreen ? 18.sp : 20.sp,
                                  color: colorScheme.tertiary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(height: isSmallScreen ? 12.h : 16.h),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Function Value at Root',
                              style: TextStyle(
                                color: colorScheme.tertiary,
                                fontWeight: FontWeight.w500,
                                fontSize: isSmallScreen ? 14.sp : 16.sp,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Text(
                              _formatNumber(lastResult['fxi_plus1']),
                              style: GoogleFonts.robotoMono(
                                fontSize: isSmallScreen ? 18.sp : 20.sp,
                                color: colorScheme.tertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 12.h : 16.h),
                      Text(
                        'The solution converges when error is less than the tolerance',
                        style: TextStyle(
                          color: colorScheme.tertiary.withOpacity(0.8),
                          fontStyle: FontStyle.italic,
                          fontSize: isSmallScreen ? 12.sp : 14.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isSmallScreen ? 16.h : 24.h),
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 16.w : 24.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.tertiaryContainer.withOpacity(0.2),
                        colorScheme.secondaryContainer.withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: colorScheme.tertiary.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14.r),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.shadow.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              lastResult['isRoot'] || (lastResult['ea'] != null && lastResult['ea']! <= widget.es)
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                              color: lastResult['isRoot'] || (lastResult['ea'] != null && lastResult['ea']! <= widget.es)
                                ? colorScheme.tertiary
                                : colorScheme.primary,
                              size: isSmallScreen ? 20.w : 24.w,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              'Stopping Reason',
                              style: TextStyle(
                                color: colorScheme.secondary,
                                fontSize: isSmallScreen ? 16.sp : 18.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isSmallScreen ? 16.w : 20.w),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.shadow.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lastResult['isRoot']
                                ? 'Root found! The function value is approximately zero.'
                                : lastResult['ea'] != null && lastResult['ea']! <= widget.es
                                  ? 'Desired accuracy reached. The relative error is less than ${_formatNumber(widget.es)}%.'
                                  : 'Maximum number of iterations reached (${widget.maxIterations}).',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: isSmallScreen ? 14.sp : 16.sp,
                                height: 1.6,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 16.w : 20.w,
                                vertical: isSmallScreen ? 12.h : 16.h,
                              ),
                              decoration: BoxDecoration(
                                color: (lastResult['isRoot'] || (lastResult['ea'] != null && lastResult['ea']! <= widget.es))
                                  ? colorScheme.tertiary.withOpacity(0.1)
                                  : colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    lastResult['isRoot'] || (lastResult['ea'] != null && lastResult['ea']! <= widget.es)
                                      ? Icons.check_circle_outline
                                      : Icons.info_outline,
                                    size: isSmallScreen ? 16.w : 20.w,
                                    color: lastResult['isRoot'] || (lastResult['ea'] != null && lastResult['ea']! <= widget.es)
                                      ? colorScheme.tertiary
                                      : colorScheme.primary,
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Text(
                                      lastResult['isRoot']
                                        ? 'Convergence achieved with f(x) ≈ 0'
                                        : lastResult['ea'] != null && lastResult['ea']! <= widget.es
                                          ? 'Convergence achieved with acceptable error'
                                          : 'Iteration limit reached without convergence',
                                      style: TextStyle(
                                        color: lastResult['isRoot'] || (lastResult['ea'] != null && lastResult['ea']! <= widget.es)
                                          ? colorScheme.tertiary
                                          : colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: isSmallScreen ? 12.sp : 14.sp,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildErrorReduction() {
    if (widget.results.length < 2) {
      return '--';
    }

    // Get the first result with a non-null error
    Map<String, dynamic>? firstWithError;
    for (var result in widget.results) {
      if (result['ea'] != null) {
        firstWithError = result;
        break;
      }
    }

    final lastError = widget.results.last['ea'];
    if (firstWithError?['ea'] == null || lastError == null) {
      return '--';
    }

    return '${_formatNumber(firstWithError!['ea'])}% → ${_formatNumber(lastError)}%';
  }

  Widget _buildDebugView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.r),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surface,
                colorScheme.surface.withOpacity(0.95),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.error.withOpacity(0.2),
                            colorScheme.errorContainer.withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.bug_report_rounded,
                        color: colorScheme.error,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'DEBUG STEPS',
                      style: TextStyle(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.results.length,
                itemBuilder: (context, index) {
                  final result = widget.results[index];
                  if (result.containsKey('debugSteps') && result['debugSteps'].isNotEmpty) {
                    return _buildDebugStep(context, result, index + 1);
                  } else {
                    return const SizedBox();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebugStep(
    BuildContext context,
    Map<String, dynamic> result,
    int stepNumber,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    if (!result.containsKey('debugSteps') || result['debugSteps'].isEmpty) {
      return const SizedBox();
    }

    return Container(
      margin: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
      padding: EdgeInsets.all(isSmallScreen ? 16.w : 20.w),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: colorScheme.error.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calculate_outlined,
                      size: isSmallScreen ? 16.w : 18.w,
                      color: colorScheme.error,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Step $stepNumber',
                      style: TextStyle(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w600,
                        fontSize: isSmallScreen ? 14.sp : 16.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...(result['debugSteps'] as Map<String, dynamic>).entries.map((entry) {
            final label = entry.key.toUpperCase().replaceAll('_', ' ');
            final calculation = entry.value;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12.w : 16.w,
                    vertical: isSmallScreen ? 6.h : 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w500,
                      fontSize: isSmallScreen ? 12.sp : 14.sp,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isSmallScreen ? 16.w : 20.w),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _formatMathExpression(calculation.toString()),
                ),
                const SizedBox(height: 20),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _formatMathExpression(String text) {
    // Replace division operations with fraction representation
    text = text.replaceAll('/', ' ÷ ');
    
    // Replace sqrt with proper symbol
    text = text.replaceAll('sqrt', '√');
    
    // Regular expression to find patterns like x^2, x^3, etc.
    final RegExp powRegex = RegExp(r'(\w+)\^(\d+)');
    final matches = powRegex.allMatches(text);
    
    if (matches.isEmpty) {
      return SelectableText(
        text,
        style: GoogleFonts.robotoMono(
          fontSize: 16.sp,
          height: 1.5,
          color: Theme.of(context).colorScheme.onSurface,
          letterSpacing: 0.5,
        ),
      );
    }
    
    // Build rich text with superscripts
    final List<InlineSpan> spans = [];
    int lastEnd = 0;
    
    for (final match in matches) {
      // Add text before the match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: GoogleFonts.robotoMono(),
        ));
      }
      
      // Add the base
      final base = match.group(1)!;
      spans.add(TextSpan(
        text: base,
        style: GoogleFonts.robotoMono(),
      ));
      
      // Add the exponent as superscript
      final exponent = match.group(2)!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.top,
        child: Transform.translate(
          offset: Offset(0, -8.h),
          child: Text(
            exponent,
            textScaler: const TextScaler.linear(0.7),
            style: GoogleFonts.robotoMono(
              fontWeight: FontWeight.bold,
              fontSize: 14.sp,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ));
      
      lastEnd = match.end;
    }
    
    // Add any remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: GoogleFonts.robotoMono(),
      ));
    }
    
    return SelectableText.rich(
      TextSpan(
        children: spans,
        style: GoogleFonts.robotoMono(
          fontSize: 16.sp,
          height: 1.5,
          color: Theme.of(context).colorScheme.onSurface,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
} 