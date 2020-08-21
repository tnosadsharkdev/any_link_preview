import 'dart:async';
import 'dart:io';

import 'package:any_link_preview/ui/link_view_vertical.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ui/link_view_horizontal.dart';
import 'web_analyzer.dart';

enum UIDirection { UIDirectionVertical, UIDirectionHorizontal }

class AnyLinkPreview extends StatefulWidget {
  final Key key;

  /// Display direction. One among `UIDirectionVertical, UIDirectionHorizontal`
  /// By default it is `UIDirectionVertical`
  final UIDirection displayDirection;

  /// Web address (Url that need to be parsed)
  /// For IOS & Web, only HTTP and HTTPS are support
  /// For Android, all url's are supported
  final String link;

  /// Customize background colour
  /// Deaults to `Color.fromRGBO(235, 235, 235, 1)`
  final Color backgroundColor;

  /// Widget that need to be shown when
  /// plugin is trying to fetch metadata
  /// If not given anything then default one will be shown
  final Widget placeholderWidget;

  /// Widget that need to be shown if something goes wrong
  /// Defaults to plain container with given background colour
  /// If the issue is know then we will show customized UI
  /// Other options of error params are used
  final Widget errorWidget;

  /// Title that need to be shown if something goes wrong
  /// Deaults to `Something went wrong!`
  final String errorTitle;

  /// Body that need to be shown if something goes wrong
  /// Deaults to `Oops! Unable to parse the url. We have sent feedback to our developers & we will try to fix this in our next release. Thanks!`
  final String errorBody;

  /// Image that will be shown if something goes wrong
  /// & when multimedia enabled & no meta data is available
  /// Deaults to `A semi-soccer ball image that looks like crying`
  final String errorImage;

  /// Give the overflow type for body text (Description)
  /// Deaults to `TextOverflow.ellipsis`
  final TextOverflow bodyTextOverflow;

  /// Give the limit to body text (Description)
  /// Deaults to `3`
  final int bodyMaxLines;

  /// Cache result time, default cache `30 days`
  /// Works only for IOS & not for android
  final Duration cache;

  /// Customize body `TextStyle`
  final TextStyle titleStyle;

  /// Customize body `TextStyle`
  final TextStyle bodyStyle;

  /// Show or Hide image if available defaults to `true`
  final bool showMultimedia;

  AnyLinkPreview({
    this.key,
    @required this.link,
    this.cache = const Duration(days: 30),
    this.titleStyle,
    this.bodyStyle,
    this.displayDirection = UIDirection.UIDirectionVertical,
    this.showMultimedia = true,
    this.backgroundColor = const Color.fromRGBO(235, 235, 235, 1),
    this.bodyMaxLines = 3,
    this.bodyTextOverflow = TextOverflow.ellipsis,
    this.placeholderWidget,
    this.errorWidget,
    this.errorBody,
    this.errorImage,
    this.errorTitle,
  })  : assert(link != null),
        super(key: key);

  @override
  _AnyLinkPreviewState createState() => _AnyLinkPreviewState();
}

class _AnyLinkPreviewState extends State<AnyLinkPreview> {
  InfoBase _info;
  String _errorImage, _errorTitle, _errorBody, _url;
  bool _loading = false;
  final MethodChannel _channel = MethodChannel('any_link_preview');

  @override
  void initState() {
    _errorImage = widget.errorImage ??
        "https://firebasestorage.googleapis.com/v0/b/chant2019.appspot.com/o/giphy.gif?alt=media&token=875d7c29-f7fb-4d0e-a6d7-987f870e597f";
    _errorTitle = widget.errorTitle ?? "Something went wrong!";
    _errorBody = widget.errorBody ??
        "Oops! Unable to parse the url. We have sent feedback to our developers & we will try to fix this in our next release. Thanks!";
    _url = widget.link.trim();
    _info = WebAnalyzer.getInfoFromCache(_url);
    if (_info == null) {
      _loading = true;
      _getInfo();
    }
    super.initState();
  }

  Future<void> _getInfo() async {
    if (Platform.isAndroid) {
      var _meta = await _channel.invokeMethod('metaData', {'url': widget.link});
      WebInfo _i = WebInfo(
        description: _meta['desc'],
        title: _meta['title'],
        image: _meta['imageUrl'],
        icon: _meta['favicon'],
      );
      _info = _i;
      if (this.mounted)
        setState(() {
          _loading = false;
        });
    } else {
      if (_url.startsWith("http")) {
        _info = await WebAnalyzer.getInfo(
          _url,
          cache: widget.cache,
          multimedia: widget.showMultimedia,
        );
        if (this.mounted)
          setState(() {
            _loading = false;
          });
      } else {
        print("$_url is not starting with either http or https");
      }
    }
  }

  void _launchURL(url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  Widget _buildPlaceHolder(Color color, double defaultHeight) {
    return Container(
      height: defaultHeight,
      child: LayoutBuilder(builder: (context, constraints) {
        var layoutWidth = constraints.biggest.width;
        var layoutHeight = constraints.biggest.height;

        return Container(
          color: color,
          width: layoutWidth,
          height: layoutHeight,
        );
      }),
    );
  }

  Widget _buildLinkContainer(double _height,
      {String title = '', String desc = '', String image = ''}) {
    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.all(Radius.circular(12)),
        boxShadow: [BoxShadow(blurRadius: 3, color: Colors.grey)],
      ),
      height: _height,
      child: (widget.displayDirection == UIDirection.UIDirectionHorizontal)
          ? LinkViewHorizontal(
              key: widget.key,
              url: widget.link,
              title: title,
              description: desc,
              imageUri: image,
              onTap: _launchURL,
              titleTextStyle: widget.titleStyle,
              bodyTextStyle: widget.bodyStyle,
              bodyTextOverflow: widget.bodyTextOverflow,
              bodyMaxLines: widget.bodyMaxLines,
              showMultiMedia: widget.showMultimedia,
            )
          : LinkViewVertical(
              key: widget.key,
              url: widget.link,
              title: title,
              description: desc,
              imageUri: image,
              onTap: _launchURL,
              titleTextStyle: widget.titleStyle,
              bodyTextStyle: widget.bodyStyle,
              bodyTextOverflow: widget.bodyTextOverflow,
              bodyMaxLines: widget.bodyMaxLines,
              showMultiMedia: widget.showMultimedia,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final WebInfo info = _info;
    double _height =
        (widget.displayDirection == UIDirection.UIDirectionHorizontal ||
                !widget.showMultimedia)
            ? ((MediaQuery.of(context).size.height) * 0.15)
            : ((MediaQuery.of(context).size.height) * 0.25);

    if (_loading)
      return widget.placeholderWidget ??
          Container(
            height: _height,
            width: MediaQuery.of(context).size.width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[200],
            ),
            alignment: Alignment.center,
            child: Text('Fetching data...'),
          );

    if (_info is WebImageInfo) {
      String img = (_info as WebImageInfo).image;
      return _buildLinkContainer(
        _height,
        title: _errorTitle,
        desc: _errorBody,
        image: img.trim() == "" ? _errorImage : img,
      );
    }

    return _info == null
        ? widget.errorWidget ??
            _buildPlaceHolder(widget.backgroundColor, _height)
        : _buildLinkContainer(
            _height,
            title:
                WebAnalyzer.isNotEmpty(info.title) ? info.title : _errorTitle,
            desc: WebAnalyzer.isNotEmpty(info.description)
                ? info.description
                : _errorBody,
            image:
                WebAnalyzer.isNotEmpty(info.image) ? info.image : _errorImage,
          );
  }
}