// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:provider/provider.dart';
// import 'package:snabbit_runner/providers/documents_provider.dart';
// import 'package:snabbit_runner/providers/language_provider.dart';
// import 'package:snabbit_runner/providers/user_profile.dart';
// import 'package:snabbit_runner/utils/colors.dart';
// import 'package:snabbit_runner/utils/common_methods.dart';
// import 'package:snabbit_runner/utils/error_handler.dart';
// import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
// import 'package:snabbit_runner/widgets/upload_documents/pan_uploader.dart';
//
// import '../../services/globals.dart';
//
// class UploadPanModalSheet extends StatefulWidget {
//   const UploadPanModalSheet({super.key});
//
//   @override
//   State<UploadPanModalSheet> createState() => _UploadPanModalSheetState();
// }
//
// class _UploadPanModalSheetState extends State<UploadPanModalSheet> {
//   late UserProfileProvider userProfileProvider;
//   late LanguageProvider languageProvider;
//   late DocumentsProvider documentsProvider;
//   bool init = true;
//   Document? document;
//   bool loading = false;
//   String? error;
//   bool isEditing = false;
//
//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     if (init) {
//       userProfileProvider =
//           Provider.of<UserProfileProvider>(context, listen: true);
//       languageProvider = Provider.of<LanguageProvider>(context, listen: true);
//       documentsProvider = Provider.of<DocumentsProvider>(context, listen: true);
//       // document = userProfileProvider.getPanDocument();
//       init = false;
//     }
//   }
//
//   bool canContinue() {
//     return userProfileProvider.user?.panCardUnavailable == true ||
//         ((userProfileProvider.user?.panCardUnavailable ?? false) == false &&
//             (documentsProvider.panImage != null ||
//                 document?.presignedUrl != null) &&
//             (GlobalState().appConfig?.isPanEditable == false ||
//                 (document?.number ?? "").length == 10));
//   }
//
//   void onContinue() async {
//     setState(() {
//       error = null;
//       loading = true;
//     });
//     try {
//       await userProfileProvider.updatePanDoc(
//         context: context,
//         panImage: documentsProvider.panImage,
//         onSuccess: () {
//           userProfileProvider.runnersMeSetup();
//           Navigator.of(context).pop();
//         },
//         onError: (response) {
//           ErrorHandler.handleResponseError(
//             response: response,
//             context: context,
//             onError: (context, responseError) {
//               if (mounted) {
//                 setState(() {
//                   error = responseError.errors?.first.message;
//                 });
//               }
//             },
//           );
//         },
//       );
//
//       // if (result && error == null) {
//       //   // Navigator.of(context).pushNamed(BankDetails.routeName);
//       //   Navigator.pop(context);
//       // } else {
//       //   showSnackbar(context, "$error");
//       // }
//     } catch (e) {
//       // Handle any potential errors that might occur
//       // during the execution of onSuccessfulRegistration()
//       error = "Document upload failed. Try again!";
//       // showSnackbar(context,
//       //     ""); // Or provide a more user-friendly error message
//     } finally {
//       setState(() {
//         loading = false;
//         isEditing = false;
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return CommonBottomSheetSetup(
//       horizontalPadding: 0,
//       child: GlobalState().appConfig?.isPanEditable == true && !isEditing?
//       Padding(
//         padding: EdgeInsets.all(16.r),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             SizedBox(
//               height: 8.h,
//             ),
//             Text(
//               languageProvider.getMessage(
//                   "pan_card_details", "PAN card details"),
//               style: Theme.of(context).textTheme.headlineSmall,
//               textAlign: TextAlign.left,
//             ),
//             SizedBox(
//               height: 18.h,
//             ),
//             Column(
//               // The CSS `flex-direction: column` is the default for Column.
//               // The CSS `align-items: flex-start` translates to CrossAxisAlignment.start.
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // The CSS `gap: 16px` is implemented with a SizedBox between the children.
//                 Text(
//                   languageProvider.getMessage('pan_card_number','PAN card number'),
//                   style: Theme.of(context).textTheme.labelMedium?.copyWith(
//                     // Line height 18px / font size 13px = 1.38
//                     height: 18 / 13,
//                     // Letter spacing -0.24px translates to -0.24
//                     letterSpacing: -0.24,
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   document?.number ?? '',
//                   style: Theme.of(context).textTheme.bodyLarge?.copyWith(
//                     // Line height 20px / font size 15px = 1.333
//                     height: 20 / 15,
//                     // Letter spacing -0.24px translates to -0.24
//                     letterSpacing: -0.24,
//                   ),
//                 ),
//               ],
//             ),
//            SizedBox(height: 16.h,),
//             Text(
//               languageProvider.getMessage('pan_card','PAN card'),
//               style: Theme.of(context).textTheme.labelMedium?.copyWith(
//                 // Line height 18px / font size 13px = 1.38
//                 height: 18 / 13,
//                 // Letter spacing -0.24px translates to -0.24
//                 letterSpacing: -0.24,
//               ),
//             ),
//             const SizedBox(height: 8),
//             Container(
//               height: 115.h,
//               width: 168.w,
//               padding: EdgeInsets.all(10.r),
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(11.26.r),
//                 border: Border.all(color: AppColors.n30,)
//               ),
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(6.18.r),
//                 child: Image.network(
//                   document?.presignedUrl ?? '',
//                   fit: BoxFit.cover,
//                   // loadingBuilder: ,
//                   errorBuilder: (_, __, ___) => const Center(
//                       child: Text(
//                         "Image not found",
//                         textAlign: TextAlign.center,
//                       )),
//                 ),
//               ),
//             ),
//             //115x168 image padding of 10
//             SizedBox(
//               height: 20.h,
//             ),
//             SizedBox(
//               width: 1.sw,
//               child: OutlinedButton(
//                 style: OutlinedButton.styleFrom(foregroundColor: AppColors.brand,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8.r),
//                   side: BorderSide(color: AppColors.brand,width: 1.r,),
//                 ),
//                   side:  BorderSide(color: AppColors.brand,width: 1.r,),
//                 ),
//                 onPressed: () {
//                   setState(() {
//                     isEditing = true;
//                   });
//                 },
//                 child: loading
//                     ? const CupertinoActivityIndicator()
//                     : Text(
//                   languageProvider.getMessage(
//                     'update_details',
//                     "Update details",
//                   ),
//                 ),
//               ),
//             ),
//             SizedBox(height: 16.h,),
//             SizedBox(
//               width: 1.sw,
//               child: ElevatedButton(
//                 style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
//                 onPressed: canContinue() && !loading ? onContinue : null,
//                 child: loading
//                     ? const CupertinoActivityIndicator()
//                     : Text(
//                   languageProvider.getMessage(
//                     'ok',
//                     "OK",
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       )
//           :Column(
//         children: [
//           SizedBox(
//             height: 24.h,
//           ),
//           Text(
//             languageProvider.getMessage(
//                 "pan_card_details", "Enter PAN card details"),
//             style: Theme.of(context).textTheme.headlineSmall,
//           ),
//           SizedBox(
//             height: 18.h,
//           ),
//           const PanUploader(
//             disableTDSWarning: true,
//           ),
//           SizedBox(
//             height: 20.h,
//           ),
//           if (error != null)
//             Text('$error', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.r50),),
//           Container(
//             width: 1.sw,
//             margin: EdgeInsets.symmetric(horizontal: 16.w),
//             child: ElevatedButton(
//               style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
//               onPressed: canContinue() && !loading ? onContinue : null,
//               child: loading
//                   ? const CupertinoActivityIndicator()
//                   : Text(
//                       languageProvider.getMessage(
//                         'continue',
//                         "Continue",
//                       ),
//                     ),
//             ),
//           ),
//           SizedBox(
//             height: 16.h,
//           ),
//         ],
//       ),
//     );
//   }
// }
