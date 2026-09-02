// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
//
// import '../utils/colors.dart';
//
// class CustomDropdown extends StatefulWidget {
//   final List<String> items;
//   final String hintText;
//   final Function(String) onSelected;
//
//   const CustomDropdown({
//     super.key,
//     required this.items,
//     required this.hintText,
//     required this.onSelected,
//   });
//
//   @override
//   CustomDropdownState createState() => CustomDropdownState();
// }
//
// class CustomDropdownState extends State<CustomDropdown> {
//   OverlayEntry? _overlayEntry;
//   String? _selectedItem;
//   final LayerLink _layerLink = LayerLink();
//
//   void _toggleDropdown() {
//     if (_overlayEntry == null) {
//       _overlayEntry = _createOverlay();
//       Overlay.of(context).insert(_overlayEntry!);
//     } else {
//       _overlayEntry?.remove();
//       _overlayEntry = null;
//     }
//     setState(() {});
//   }
//
//   OverlayEntry _createOverlay() {
//     RenderBox renderBox = context.findRenderObject() as RenderBox;
//     Offset offset = renderBox.localToGlobal(Offset.zero);
//
//     return OverlayEntry(
//       builder: (context) => Positioned(
//         width: renderBox.size.width,
//         top: offset.dy + renderBox.size.height + 5,
//         left: offset.dx,
//         child: Material(
//           elevation: 0,
//           borderRadius: BorderRadius.circular(10.r),
//           child: Container(
//             decoration: BoxDecoration(
//               color: AppColors.n0,
//               border: const Border(
//                 left: BorderSide(color: AppColors.n30),
//                 right: BorderSide(color: AppColors.n30),
//                 bottom: BorderSide(color: AppColors.n30),
//               ),
//               borderRadius: BorderRadius.circular(10.r),
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: widget.items.asMap().entries.map((entry) {
//                 int index = entry.key;
//                 String item = entry.value;
//                 return Column(
//                   children: [
//                     ListTile(
//                       title: Text(
//                         item,
//                       ),
//                       onTap: () {
//                         widget.onSelected(item);
//                         setState(() {
//                           _selectedItem = item;
//                           _toggleDropdown();
//                         });
//                       },
//                     ),
//                     if (index != widget.items.length - 1)
//                       const Divider(
//                         height: 1,
//                         color: AppColors.n30,
//                       ),
//                   ],
//                 );
//               }).toList(),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _overlayEntry?.remove();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return CompositedTransformTarget(
//       link: _layerLink,
//       child: GestureDetector(
//         onTap: _toggleDropdown,
//         child: Container(
//           padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 16.h),
//           decoration: BoxDecoration(
//             border: Border.all(
//                 color: _overlayEntry == null ? AppColors.n30 : AppColors.brand),
//             borderRadius: BorderRadius.circular(8.r),
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 _selectedItem ?? widget.hintText,
//                 style: Theme.of(context).textTheme.bodyLarge?.copyWith(
//                       color:
//                           _selectedItem == null ? AppColors.n50 : AppColors.n90,
//                     ),
//                 // style: TextStyle(
//                 //   fontSize: 16,
//                 //   color: _selectedItem == null ? Colors.grey : Colors.black,
//                 // ),
//               ),
//               Icon(
//                 _overlayEntry == null ? Icons.expand_more : Icons.expand_less,
//                 color: Colors.black54,
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../utils/colors.dart';

class CustomDropdown<T> extends StatefulWidget {
  final List<T> items;
  final String hintText;
  final Function(T) onSelected;
  final T? selectedItem;

  const CustomDropdown({
    super.key,
    required this.items,
    required this.hintText,
    required this.onSelected,
    this.selectedItem,
  });

  @override
  CustomDropdownState<T> createState() => CustomDropdownState<T>();
}

class CustomDropdownState<T> extends State<CustomDropdown<T>> {
  OverlayEntry? _overlayEntry;
  T? _selectedItem; // Change to T?
  final LayerLink _layerLink = LayerLink();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.selectedItem != null) {
      _selectedItem = widget.selectedItem;
      setState(() {});
    }
  }

  void _toggleDropdown() {
    if (_overlayEntry == null) {
      _overlayEntry = _createOverlay();
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
    setState(() {});
  }

  OverlayEntry _createOverlay() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    Offset offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (context) => Positioned(
        width: renderBox.size.width,
        top: offset.dy + renderBox.size.height + 5,
        left: offset.dx,
        child: Material(
          elevation: 0,
          borderRadius: BorderRadius.circular(10.r),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.n0,
              border: const Border(
                left: BorderSide(color: AppColors.n30),
                right: BorderSide(color: AppColors.n30),
                bottom: BorderSide(color: AppColors.n30),
              ),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 200.h, // Maximum height for the dropdown
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.items.asMap().entries.map((entry) {
                    int index = entry.key;
                    final item = entry.value;
                    return Column(
                      children: [
                        ListTile(
                          title: Text(
                            item.toString(),
                          ),
                          onTap: () {
                            widget.onSelected(item);
                            setState(() {
                              _selectedItem = item; // Assign T directly
                              _toggleDropdown();
                            });
                          },
                        ),
                        if (index != widget.items.length - 1)
                          const Divider(
                            height: 1,
                            color: AppColors.n30,
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
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 16.h),
          decoration: BoxDecoration(
            border: Border.all(
                color: _overlayEntry == null ? AppColors.n30 : AppColors.brand),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedItem != null
                    ? _selectedItem!.toString()
                    : widget.hintText, // Display T.name
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color:
                          _selectedItem == null ? AppColors.n50 : AppColors.n90,
                    ),
              ),
              Icon(
                _overlayEntry == null ? Icons.expand_more : Icons.expand_less,
                color: Colors.black54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
