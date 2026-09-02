import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/server_requests/calling_service.dart';
import 'package:snabbit_runner/services/server_requests/go_live_http.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/models/support_team_member.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/go_live/support_call_tile.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:snabbit_runner/utils/colors.dart';

class SupportTeamList extends StatefulWidget {
  final List<dynamic> membersJson;
  const SupportTeamList({super.key,required this.membersJson,});

  @override
  State<SupportTeamList> createState() => _SupportTeamListState();
}

class _SupportTeamListState extends State<SupportTeamList> {
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  bool init = true;
  bool loading = false;
  List<SupportTeamMember>? supportTeamMembers;
  bool hasError = false;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfileProvider = Provider.of<UserProfileProvider>(context, listen: true);
      _parseSupportDetails();
    }
    super.didChangeDependencies();
  }

  Future<void> _parseSupportDetails() async {
    setState(() => loading = true);
    try {
      if (widget.membersJson.isNotEmpty) {
        setState(() {
          supportTeamMembers = widget.membersJson
              .map((e) => SupportTeamMember.fromJson(e))
              .toList();
          hasError = false;
        });
      } else {
        setState(() => hasError = true);
      }
    } catch (e) {
      setState(() => hasError = true);
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    if (loading ||hasError || supportTeamMembers == null || supportTeamMembers!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: supportTeamMembers!
          .map((member) => SupportCallTile.defaultStyle(
                name: member.name ?? '',
                role: member.role ?? '',
                phoneNumber: member.phoneNumber ?? '',
                onTap: (phoneNumber) async {
                  await CallUtils.handleCallInitiation(
                      phoneNumber: phoneNumber,
                      context: context,
                      callSourceLabel: "SUPPORT_TEAM_LIST",
                      onFailure: ({e,st}) {
                        showSnackbar(
                          context,
                          languageProvider.getMessage(
                              'call_support_error', 'Error launching dialer'),
                        );
                      });
                },
              ))
          .toList(),
    );
  }
}
