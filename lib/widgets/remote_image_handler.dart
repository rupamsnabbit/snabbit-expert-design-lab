import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

class RemoteImage {
  String? url;
  double? height;
  double? width;
  Color? color;

  RemoteImage({
    this.url,
    this.height,
    this.width,
    this.color,
  });

  factory RemoteImage.fromJson(Map<String, dynamic> json) {
    return RemoteImage(
      url: json['url'],
      height: anyValueToDouble(json['height']),
      width: anyValueToDouble(json['width']),
      color: hexToColor(json['color']),
    );
  }
}

class RemoteImageHandler extends StatefulWidget {
  final String imageUrl;
  final Widget? errorWidget;
  final Widget? loadingWidget;
  final double? height;
  final double? width;
  final BoxFit? fit;
  final Function(bool)? onContentLoaded;
  final bool repeat;
  final bool animate;

  const RemoteImageHandler({
    super.key,
    required this.imageUrl,
    this.errorWidget,
    this.loadingWidget,
    this.height,
    this.width,
    this.fit,
    this.onContentLoaded,
    this.repeat = true,
    this.animate = true,
  });

  @override
  State<RemoteImageHandler> createState() => _RemoteImageHandlerState();
}

class _RemoteImageHandlerState extends State<RemoteImageHandler>
    with SingleTickerProviderStateMixin {
  bool _isContentLoaded = false;
  bool _showLoadingWidget = false;
  bool _hasError = false;
  Timer? _loadingTimer;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Start timer for loading widget delay
    _loadingTimer = Timer(const Duration(milliseconds: 500), () {
      if (!_isContentLoaded && mounted) {
        setState(() {
          _showLoadingWidget = true;
        });
      }
    });

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Create slide animation from top to bottom
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0), // Start from top
      end: Offset.zero, // End at normal position
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  String _getFileExtension(String url) {
    try {
      Uri uri = Uri.parse(url);
      String path = uri.path.toLowerCase();
      if (path.contains('.')) {
        return path.split('.').last.split('?').first;
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  bool _isLottieFormat(String extension) {
    return extension == 'json';
  }

  bool _isSvgFormat(String extension) {
    return extension == 'svg';
  }

  void _onContentLoaded() {
    if (!_isContentLoaded && mounted) {
      _loadingTimer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Check mounted again before setState to prevent null check operator crash
        if (!mounted) return;
        setState(() {
          _isContentLoaded = true;
        });
        try {
          widget.onContentLoaded?.call(_isContentLoaded);
        } catch (e) {
          // DO NOTHING
        }
        if (mounted) {
          _animationController.forward();
        }
      });
    }
  }

  void _handleError() {
    if (!_hasError && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Check mounted again before setState to prevent null check operator crash
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _isContentLoaded = false;
        });
        try {
          widget.onContentLoaded?.call(true);
        } catch (e) {
          // DO NOTHING
        }
      });
    }
  }

  Widget _buildErrorWidget() {
    return widget.errorWidget ?? const SizedBox();
  }

  Widget _buildLoadingWidget() {
    return widget.loadingWidget ?? const SizedBox();
  }

  Widget _buildLoadedContent() {
    final extension = _getFileExtension(widget.imageUrl);

    if (_isLottieFormat(extension)) {
      return Lottie.network(
        widget.imageUrl,
        height: widget.height,
        width: widget.width,
        fit: widget.fit ?? BoxFit.contain,
        onLoaded: (composition) {
          _onContentLoaded();
        },
        repeat: widget.repeat,
        errorBuilder: (context, error, stackTrace) {
          _handleError();
          return _buildErrorWidget();
        },
      );
    } else if (_isSvgFormat(extension)) {
      // For SVG, we need to trigger success manually since it doesn't have onLoaded
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onContentLoaded();
      });
      return SvgPicture.network(
        widget.imageUrl,
        height: widget.height,
        width: widget.width,
        fit: widget.fit ?? BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          _handleError();
          return _buildErrorWidget();
        },
      );
    } else {
      // Use CachedNetworkImage for regular images (PNG, JPG, GIF, etc.)
      return CachedNetworkImage(
        imageUrl: widget.imageUrl,
        height: widget.height,
        width: widget.width,
        fit: widget.fit ?? BoxFit.cover,
        fadeInDuration: Duration.zero,
        httpHeaders: const {
          'Connection': 'keep-alive',
        },
        errorWidget: (context, url, error) {
          // Catch HttpException and other network errors gracefully
          _handleError();
          return _buildErrorWidget();
        },
        imageBuilder: (context, imageProvider) {
          _onContentLoaded();
          return Image(
            image: imageProvider,
            height: widget.height,
            width: widget.width,
            fit: widget.fit ?? BoxFit.cover,
          );
        },
      );
    }
  }

  Widget _buildLoadingContent() {
    final extension = _getFileExtension(widget.imageUrl);

    if (_isLottieFormat(extension)) {
      return Stack(
        children: [
          Lottie.network(
            widget.imageUrl,
            height: widget.height,
            width: widget.width,
            fit: widget.fit ?? BoxFit.contain,
            onLoaded: (composition) {
              _onContentLoaded();
            },
            repeat: widget.repeat,
            errorBuilder: (context, error, stackTrace) {
              _handleError();
              return _buildErrorWidget();
            },
          ),
          if (_showLoadingWidget)
            Positioned.fill(
              child: _buildLoadingWidget(),
            ),
        ],
      );
    } else if (_isSvgFormat(extension)) {
      // For SVG, show loading overlay while it loads
      return Stack(
        children: [
          SvgPicture.network(
            widget.imageUrl,
            height: widget.height,
            width: widget.width,
            fit: widget.fit ?? BoxFit.contain,
            placeholderBuilder: (context) {
              // Don't show anything here, let the Stack handle the loading
              return const SizedBox();
            },
            errorBuilder: (context, error, stackTrace) {
              _handleError();
              return _buildErrorWidget();
            },
          ),
          if (_showLoadingWidget)
            Positioned.fill(
              child: _buildLoadingWidget(),
            ),
        ],
      );
    } else {
      // Use CachedNetworkImage for regular images (PNG, JPG, GIF, etc.)
      return CachedNetworkImage(
        imageUrl: widget.imageUrl,
        height: widget.height,
        width: widget.width,
        fit: widget.fit ?? BoxFit.cover,
        fadeInDuration: Duration.zero,
        httpHeaders: const {
          'Connection': 'keep-alive',
        },
        errorWidget: (context, url, error) {
          // Catch HttpException and other network errors gracefully
          _handleError();
          return _buildErrorWidget();
        },
        imageBuilder: (context, imageProvider) {
          _onContentLoaded();
          // Show loading widget if delay has passed
          if (_showLoadingWidget) {
            return _buildLoadingWidget();
          }
          return const SizedBox(); // Return empty widget, actual image will be shown by AnimatedSwitcher
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handle empty URLs
    if (widget.imageUrl.isEmpty) {
      return _buildErrorWidget();
    }

    // If error occurred, show error widget
    if (_hasError) {
      return _buildErrorWidget();
    }

    if (!widget.animate) {
      return _isContentLoaded
          ? _buildLoadedContent()
          : _buildLoadingContent();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        if (child.key == const ValueKey('loaded_content')) {
          // Use slide transition for the loaded content
          return SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        } else {
          // Use fade transition for the loading placeholder
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        }
      },
      child: _isContentLoaded
          ? Container(
              key: const ValueKey('loaded_content'),
              child: _buildLoadedContent(),
            )
          : Container(
              key: const ValueKey('loading_content'),
              child: _buildLoadingContent(),
            ),
    );
  }
}
