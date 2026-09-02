class TrackingEvents {
  TrackingEvents._();

  // Attendance flow
  static const String attendanceMarked =
      "attendance_marked"; //marked as true or false and type current_day or provisional
  static const String attendanceChanged = "attendance_changed"; //changed to

  // Common widgets
  static const String referralBannerClicked = "referral_banner_clicked";
  static const String clickedOnMap = "clicked_on_map";
  static const String callCustomerButtonClicked =
      "call_customer_button_clicked";
  static const String speakAddressButtonClicked =
      "speak_address_button_clicked";
  static const String chatP2pclicked = "chatP2pclicked";
  static const String chatP2pCallClicked = "chatP2pCallclicked";
  static const String customerInfoCallCtaClick = "customerInfoCallCtaClick";
  static const String chatP2pCallInitiatedSuccessfully =
      "chatP2pCallInitiatedSuccessfully";

  // HOME
  static const String homeHelpButtonClicked = "home_help_button_clicked";
  static const String contactUsButtonClcked = "contact_us_button_clicked";
  // Fired with {cta_text: ...} — same event the KMP home fires for its CTAs.
  static const String homeScreenCtaClick = "home_screen_cta_click";
  // Lunch-slots banner impression, fired on the hidden→shown edge.
  static const String lunchBannerShown = "lunch_banner_shown";

  static const String lanugagePreferenceChanged =
      "language_preference_changed"; //language changed to

  static const String silentNotificationFeatureUsed =
      "silent_notification_feature_used";

  // Aadhaar re-KYC (re-verification) flow
  static const String aadhaarRekycStarted = "aadhaar_rekyc_started";
  static const String aadhaarRekycResult = "aadhaar_rekyc_result";

  //login
  static const String loginOtpSent = "login_otp_sent";
  static const String loginReferralCodeEntered = "login_referral_code_entered";
  static const String loginOtpVerified = "login_otp_verified";
  static const String otplessFailed = "otpless_failed";
  static const String snaFailed = "sna_failed";
  static const String otplessChannelSwitch = "otpless_channel_switch";

  static const String jobLoginLoginButtonClicked =
      "job_login_login_button_clicked";
  static const String runnerLogoutButtonClicked =
      "runner_logout_button_clicked";
  static const String selfieClicked = "selfie_clicked";
  static const String selfieSubmitted = "selfie_submitted";

  // Bifrost capture image
  static const String captureImageStarted = "capture_image_started";
  static const String captureImageCompleted = "capture_image_completed";
  static const String captureImageCancelled = "capture_image_cancelled";
  static const String captureImageBlocked = "capture_image_blocked";
  static const String captureImageCancelRequested =
      "capture_image_cancel_requested";
  static const String captureImagePermissionDenied =
      "capture_image_permission_denied";
  static const String captureImagePermissionShowingUi =
      "capture_image_permission_showing_ui";
  static const String capturePermissionSheetResult =
      "capture_permission_sheet_result";
  static const String capturePermissionSheetTimeout =
      "capture_permission_sheet_timeout";
  static const String getContactsPermissionDenied =
      "get_contacts_permission_denied";
  static const String getContactsPermissionShowingUi =
      "get_contacts_permission_showing_ui";
  static const String contactsPermissionSheetResult =
      "contacts_permission_sheet_result";
  static const String contactsPermissionSheetTimeout =
      "contacts_permission_sheet_timeout";
  static const String buildingGatePhotoClicked = "buildingGatePhoto_clicked";
  static const String buildingGatePhotoSubmitted =
      "buildingGatePhoto_submitted";
  static const String eventAudioCaptureStopped = "audio_capture_stopped";
  static const String acceptJobButtonViewed = "accept_job_button_viewed";
  static const String acceptJobButtonClicked = "accept_job_button_clicked";
  static const String denyJobButtonClicked = "deny_job_button_clicked";
  static const String markArrivalButtonClicked = "mark_arrival_button_clicked";
  static const String runnerCheckedIn = "runner_checked_in";

  //work in progress
  static const String checkoutButtonClicked = "checkout_button_clicked";
  static const String qrCodePaymentModeSelected =
      "qr_code_payment_mode_selected";
  static const String cashPaymentModeSelected = "cash_payment_mode_selected";
  static const String cashCollectedButtonClicked =
      "cash_collected_button_clicked";
  static const String checkPaymentStatusButtonUsed =
      "check_payment_status_button_used";
  static const String checkOutSubmitAfterCashCollection =
      "check_out_submit_after_cash_collection";

  static const String ratedCustomerSucessfully = "runner_rated_the_customer";

  static const String blockedCustomer = "blocked_customer";
  static const String unblockedCustomer = "unblocked_customer";
  // Lunch
  static const String homeBreakButtonClicked = "home_break_button_clicked";
  static const String breakStartButtonClicked = "break_start_button_clicked";
  static const String breakConfirmEndButtonClicked =
      "break_confirm_end_button_clicked";

  static const String claimInsuranceButtonTapped =
      "claim_insurance_button_tapped";

  // location
  static const String locationServiceOff = "location_service_off";
  static const String locationPermissionDenied = "location_permission_denied";
  static const String locationAlwaysDenied = "location_always_denied";

  // notification
  static const String notificationReceived = "notification_received";

  /// Emitted once per deeplink dispatch by `DeepLinkRouter`. Props: `path`,
  /// `source` (notification|clevertap|onelink), `result`
  /// (handled|queued|notHandled), `reason`.
  static const String deeplinkOpened = "deeplink_opened";
  static const String endQuickBreak = "end_quick_break";
  static const String eventNotificationDisplayFailed =
      "notification_display_failed";
  static const String eventNotificationActionNullCallback =
      "notification_action_null_callback";

  static const String notificationLoop = "notification_loop";
  static const String exitPip = "exit_pip";

  static const String shorebirdPatchApplied = "shorebird_patch_applied";
  static const String shorebirdPatchDownload = "shorebird_patch_download";
  static const String shiftPerformanceBottomSheetShown =
      "shift_performance_bottom_sheet_shown";
  static const String vpnWarningShown = "vpn_warning_shown";
  static const String vpnWarningDisabled = "vpn_warning_disabled";

  static const String earningPage = "earning_page";
  static const String earlyPayout = "early_payout";
  static const String earlyPayoutWithdrawClicked =
      "early_payout_withdraw_clicked";
  static const String withdrawSuccess = "withdraw_success";
  static const String withdrawFailed = "withdraw_failed";

  // Go Live V2
  static const String goLiveWorkSelectionLoad = "go_live_work_selection_load";
  static const String goLiveWorkSelectionCta = "go_live_work_selection_cta";
  static const String goLiveFlowBackPress = "go_live_flow_back_press";
  static const String goLiveShiftHoursSelectionLoad =
      "go_live_shift_hours_selection_load";
  static const String goLiveShiftHoursSelectionCta =
      "go_live_shift_hours_selection_cta";
  static const String goLiveStartTimeSelectionLoad =
      "go_live_start_time_selection_load";
  static const String goLiveStartTimeSelectionCta =
      "go_live_start_time_selection_cta";
  static const String goLiveRecommendationLoad = "go_live_recommendation_load";
  static const String goLiveRecommendationCta = "go_live_recommendation_cta";
  static const String goLiveRecommendationError =
      "go_live_recommendation_error";
  static const String goLiveWeekendPromptResponse =
      "go_live_weekend_prompt_response";
  static const String goLiveFinalConfirmationLoad =
      "go_live_final_confirmation_load";
  static const String goLiveFinalConfirmationCta =
      "go_live_final_confirmation_cta";
  static const String goLiveFinalConfirmationError =
      "go_live_final_confirmation_error";

  // Chat
  static const String chatScreenOpened = "chat_screen_opened";
  static const String chatInitSuccess = "chat_init_success";
  static const String chatInitFailed = "chat_init_failed";
  static const String chatScreenClosed = "chat_screen_closed";

  // Banners
  static const String bannerClicked = "banner_clicked";
  static const String bannerUrlLaunched = "banner_url_launched";
  static const String bannerUrlLaunchFailed = "banner_url_launch_failed";

  // Snabbit Shield — Banner & Lifecycle
  static const String expertShieldBannerVisible =
      "expert_shield_banner_visible";
  static const String expertShieldBannerHidden = "expert_shield_banner_hidden";
  static const String expertShieldBannerCta = "expert_shield_banner_cta";
  static const String expertShieldStarted = "expert_shield_started";
  static const String expertShieldStopped = "expert_shield_stopped";
  static const String expertShieldPaused = "expert_shield_paused";
  static const String expertShieldResumed = "expert_shield_resumed";
  static const String expertShieldError = "expert_shield_error";
  static const String expertShieldRcFallback = "expert_shield_rc_fallback";
  static const String expertShieldPermissionChanged =
      "expert_shield_permission_changed";
  static const String expertShieldMicPermanentlyDenied =
      "expert_shield_mic_permanently_denied";
  static const String expertShieldDegradedModeActive =
      "expert_shield_degraded_mode_active";

  // Snabbit Shield — Consent Bottom Sheet
  static const String expertShieldConsentBs = "expert_shield_consent_bs";
  static const String expertShieldConsentCta = "expert_shield_consent_cta";
  static const String expertShieldConsentSuccess =
      "expert_shield_consent_success";
  static const String expertShieldConsentGiven = "expert_shield_consent_given";
  static const String expertShieldConsentError = "expert_shield_consent_error";
  static const String expertShieldConsentDismiss =
      "expert_shield_consent_dismiss";

  // Snabbit Shield — Activation Info Sheet
  static const String expertShieldInfoBs = "expert_shield_info_bs";
  static const String expertShieldInfoCta = "expert_shield_info_cta";
  static const String expertShieldInfoDismiss = "expert_shield_info_dismiss";

  // Snabbit Shield — SOS
  static const String expertShieldSosAlertBs = "expert_shield_sos_alert_bs";
  static const String expertShieldSosAlertConfirmClick =
      "expert_shield_sos_alert_confirm_click";
  static const String expertShieldSosAlertDenyClick =
      "expert_shield_sos_alert_deny_click";
  static const String expertShieldSosActiveLoad =
      "expert_shield_sos_active_load";
  static const String expertShieldSosActiveCallTeamCta =
      "expert_shield_sos_active_call_team_cta";
  static const String expertShieldSosActiveEndSosCta =
      "expert_shield_sos_active_end_sos_cta";
  static const String expertShieldSosInitiated = "expert_shield_sos_initiated";
  static const String expertShieldSosInitiateFailed =
      "expert_shield_sos_initiate_failed";
  static const String expertShieldSosSheetSkipped =
      "expert_shield_sos_sheet_skipped";
  static const String expertShieldSosConfirmed = "expert_shield_sos_confirmed";
  static const String expertShieldSosSyncConfirmed =
      "expert_shield_sos_sync_confirmed";
  static const String expertShieldSosDenied = "expert_shield_sos_denied";
  static const String expertShieldSosSyncDenied =
      "expert_shield_sos_sync_denied";
  static const String expertShieldSosDenyApiFailed =
      "expert_shield_sos_deny_api_failed";
  static const String expertShieldSosConfirmApiFailed =
      "expert_shield_sos_confirm_api_failed";
  static const String expertShieldSosDeescalated =
      "expert_shield_sos_deescalated";
  static const String expertShieldSosDeescalateError =
      "expert_shield_sos_deescalate_error";
  static const String expertShieldSosSynced = "expert_shield_sos_synced";
  static const String expertShieldSosStateDesync =
      "expert_shield_sos_state_desync";
  static const String expertShieldSosNotificationConfirmTap =
      "expert_shield_sos_notification_confirm_tap";
  static const String expertShieldSosPushDrained =
      "expert_shield_sos_push_drained";
  static const String expertShieldSosConcurrentOverridden =
      "expert_shield_sos_concurrent_overridden";
  static const String expertShieldDeterrencePlayed =
      "expert_shield_deterrence_played";

  // Snabbit Shield — Upload
  static const String expertShieldUploadSuccess =
      "expert_shield_upload_success";
  static const String expertShieldUploadDropped =
      "expert_shield_upload_dropped";

  // Snabbit Shield — Storage
  static const String expertShieldStorageWarning =
      "expert_shield_storage_warning";
  static const String expertShieldStorageFull = "expert_shield_storage_full";

  // Snabbit Shield — Native instrumentation raw keys
  // Match the eventName strings emitted by SafetyMonitoringService.kt / SafetyShieldPlugin.kt.
  // Used in ShieldEventHandler to route to Coralogix (all) and CT/MP milestones (subset below).

  // Milestone subset — forwarded to CT/MP as expert_shield_native_* events:
  static const String nativeKeySosTriggered = 'sos_triggered';
  static const String nativeKeySosResolved = 'sos_resolved';
  static const String nativeKeyRecordingState = 'recording_state';
  static const String nativeKeyMonitoringState = 'monitoring_state';
  static const String nativeKeyBurstRecording = 'burst_recording';
  static const String nativeKeySessionLifecycle = 'session_lifecycle';
  static const String nativeKeyPluginLifecycle = 'plugin_lifecycle';
  static const String nativeKeyPermissionChanged = 'permission_changed';

  // Observability-only — Coralogix as shield_<key>, never forwarded to CT/MP:
  static const String nativeKeyClipEncrypted = 'clip_encrypted';
  static const String nativeKeyAudioCaptureStopped = 'audio_capture_stopped';
  static const String nativeKeyDetectionEvaluated = 'detection_evaluated';
  static const String nativeKeyDetectionSignal = 'detection_signal';
  static const String nativeKeyShakeMotionDetected = 'shake_motion_detected';
  static const String nativeKeyServiceStateChanged = 'service_state_changed';
  static const String nativeKeyNotificationDisplayFailed =
      'notification_display_failed';
  static const String nativeKeyNotificationActionNullCallback =
      'notification_action_null_callback';
  static const String nativeKeyModelLoadPartialFailure =
      'model_load_partial_failure';

  // Snabbit Shield — Native instrumentation → CT/MP product analytics
  // Milestone events only. Emitted debounced via ShieldEventHandler._nativeToProductEvent.
  static const String expertShieldNativeSosTriggered =
      'expert_shield_native_sos_triggered';
  static const String expertShieldNativeSosResolved =
      'expert_shield_native_sos_resolved';
  static const String expertShieldNativeRecordingState =
      'expert_shield_native_recording_state';
  static const String expertShieldNativeMonitoringState =
      'expert_shield_native_monitoring_state';
  static const String expertShieldNativeBurstRecording =
      'expert_shield_native_burst_recording';
  static const String expertShieldNativeSessionLifecycle =
      'expert_shield_native_session_lifecycle';
  static const String expertShieldNativePluginLifecycle =
      'expert_shield_native_plugin_lifecycle';
  static const String expertShieldNativePermissionChanged =
      'expert_shield_native_permission_changed';

  // Snabbit Shield — Battery
  static const String batteryPopupLoad = "battery_popup_load";
  static const String batteryPopupDismiss = "battery_popup_dismiss";
  static const String genericBannerImpression = "generic_banner_impression";

  // Vishwaas / switch RC
  static const String switchRcProfilePageBannerLoad =
      "switch_rc_profile_page_banner_load";
  static const String switchRcProfilePageBannerCtaClick =
      "switch_rc_profile_page_banner_cta_click";
  static const String switchRcBsBannerLoad = "switch_rc_bs_banner_load";
  static const String switchRcBsBannerClick = "switch_rc_bs_banner_click";

  //SOS
  static const String eventShakeMotionDetected = "shake_motion_detected";
  static const String sosTriggered = "sos_triggered";
  static const String sosFalseAlarmConfirmed = "sos_false_alarm_confirmed";
  static const String sosBlocked = "sos_blocked";
  static const String sosCallSupportClicked = "sos_call_support_clicked";
  static const String sosPopupViewed = "sos_popup_viewed";
  static const String failedToInitiateCallFromSOS =
      "failed_to_initiate_call_from_sos";
  static const String sosFalseAlarmClicked = "sos_false_alarm_clicked";
  static const String sosReturnedToPostSOS = "sos_returned_to_post_sos";
  static const String sosSuccessStateViewed = "sos_success_state_viewed";
  static const String sosTriggerFailed = "sos_trigger_failed";
  static const String sosPopUpDismiss = "sos_pop_up_dismiss";
  static const String sosFalseAlarmConfirmationViewed =
      "sos_false_alarm_confirmation_viewed";

  // SOS — Sources
  static const String sosFromSosTabFailed = "sos_from_sostab_failed";

  static const String expertWantsToJoinBack = "expert_wants_to_join_back";
  static const String sundayAttendanceNudgeViewed =
      "sunday_attendance_nudge_viewed";
  static const String sundayAttendanceNudgeAudioPlayClicked =
      "sunday_attendance_nudge_audio_play_clicked";
  static const String sundayAttendanceNudgeAudioPlayed =
      "sunday_attendance_nudge_audio_played";
  static const String sundayAttendanceNudgeWorkTomorrow =
      "sunday_attendance_nudge_work_tomorrow";
  static const String sundayAttendanceNudgeWorkSundayLeave =
      "sunday_attendance_nudge_sunday_leave";

  // Snabbit Seva
  static const String snabbitSevaDrawerClicked = "snabbit_seva_drawer_clicked";
  static const String snabbitSevaWebPageLoaded = "snabbit_seva_web_page_loaded";
  static const String snabbitSevaWebPageLoadFailed =
      "snabbit_seva_web_page_load_failed";
  static const String snabbitSevaExternalMapLinkClicked =
      "snabbit_seva_external_map_link_clicked";

  // Merch Store
  static const String merchStoreDrawerClicked = "merch_store_drawer_clicked";
  static const String merchStoreWebPageLoaded = "merch_store_web_page_loaded";
  static const String merchStoreWebPageLoadFailed =
      "merch_store_web_page_load_failed";
  static const String merchStoreExternalUrlOpened =
      "merch_store_external_url_opened";

  // Referral Header
  static const String referralHeaderBannerVisible =
      "referral_header_banner_visible";
  static const String referNowCtaClicked = "refer_now_cta_clicked";
  static const String addReferralSheetViewed = "add_referral_sheet_viewed";
  static const String referralSubmitted = "referral_submitted";
  static const String addReferralCallOptionClicked =
      "add_referral_call_option_clicked";
  static const String addReferralWhatsAppOptionClicked =
      "add_referral_whatsapp_option_clicked";
  static const String referralShortShiftInfoViewed =
      "referral_short_shift_info_viewed";
  static const String referralShiftCampaignLearnMoreTapped =
      "referral_shift_campaign_learn_more_tapped";
  static const String referralShortShiftInfoAudioRequested =
      "referral_short_shift_info_audio_requested";
  static const String requestToRejectJobViewed = "request_to_reject_job_viewed";
  static const String requestToRejectJobButtonClicked =
      "request_to_reject_job_button_clicked";
  static const String requestToRejectJobAccepted =
      "request_to_reject_job_accepted";
  static const String requestToRejectJobRejected =
      "request_to_reject_job_rejected";
  static const String rootedDevice = "rooted_device";
  static const String checkInWithoutOtpBtnDisplayed =
      "check_in_without_otp_btn_displayed";
  static const String checkInWithoutOtpBtnClicked =
      "check_in_without_otp_btn_clicked";
  static const String checkInWithoutOtpBottomSheetDisplayed =
      "check_in_without_otp_bottom_sheet_displayed";
  static const String checkInWithoutOtpBottomSheetDismissed =
      "check_in_without_otp_bottom_sheet_dismissed";
  static const String checkInWithoutOtpPhoneNumberInputDisplayed =
      "check_in_without_otp_phone_number_input_displayed";
  static const String checkInWithoutOtpPhoneNumberEntered =
      "check_in_without_otp_phone_number_entered";
  static const String checkInWithoutOtpVerifyPhoneNumberBtnClicked =
      "check_in_without_otp_verify_phone_number_btn_clicked";
  static const String checkInWithoutOtpSuccessStateDisplayed =
      "check_in_without_otp_success_state_displayed";
  static const String checkInWithoutOtpFailureStateDisplayed =
      "check_in_without_otp_failure_state_displayed";
  static const String checkInWithoutOtpLocationErrorRetryClicked =
      "check_in_without_otp_location_error_retry_clicked";
  static const String checkInWithoutOtpPhoneNumberErrorRetryClicked =
      "check_in_without_otp_phone_number_error_retry_clicked";

  // AWOL
  static const String expertHomePageViewed = "expert_home_page_viewed";
  static const String awolPopupViewed = "awol_popup_viewed";
  static const String awolCtaClicked = "awol_cta_clicked";
  static const String awolStateTransition = "awol_state_transition";

  // Delayed check-in penalty
  static const String delayedCheckinPenaltyPopupViewed =
      "delayed_checkin_penalty_popup_viewed";
  static const String jobSupportCtaClicked = "job_support_cta_clicked";
  static const String jobSupportConfigMissing = "job_support_config_missing";
  static const String jobSupportSubmitted = "job_support_submitted";
  static const String jobSupportSubmissionSuccess =
      "job_support_submission_success";
  static const String jobSupportSubmissionFailed =
      "job_support_submission_failed";
  static const String jobSupportCallInitiated = "job_support_call_initiated";

  // Job lifecycle instrumentation (Job Lifecycle sheet)
  // ECPO-982: a localized in-progress voice cue was played (cue = half_time / ten_minutes /
  // auto_checkout). Shared verbatim with the KMP AnalyticsRoutesConfig entry (CleverTap + Mixpanel).
  static const String jobInProgressAudioPlayed = "job_in_progress_audio_played";
  static const String hotspotScreenLoad = "hotspot_screen_load";
  static const String hotspotShowDirectionsCtaClick =
      "hotspot_show_directions_cta_click";
  static const String newJobAssignedLoad = "new_job_assigned_load";
  static const String acceptJobCtaClick = "accept_job_cta_click";
  static const String denyJobCtaClick = "deny_job_cta_click";
  static const String denyConfirmScreenLoad = "deny_confirm_screen_load";
  static const String denyAcceptJobCtaClick = "deny_accept_job_cta_click";
  static const String arrivalScreenLoad = "arrival_screen_load";
  static const String arrivalShowDirectionsCtaClick =
      "arrival_show_directions_cta_click";
  static const String arrivalCallCustomerCtaClick =
      "arrival_call_customer_cta_click";
  static const String arrivalChatCustomerCtaClick =
      "arrival_chat_customer_cta_click";
  static const String markArrivalCtaClick = "mark_arrival_cta_click";
  static const String checkInCtaClick = "check_in_cta_click";
  static const String checkInOtpModalDismissed = "check_in_otp_modal_dismissed";
  static const String jobCompletedScreenLoad = "job_completed_screen_load";
  static const String ratingEmojiSelect = "rating_emoji_select";
  static const String ratingCustomerBlockCta = "rating_customer_block_cta";
  static const String ratingCustomerUnblockCta = "rating_customer_unblock_cta";

  // Nudges instrumentation (Expert - Nudges sheet)
  static const String profileSectionSidebarLoad =
      "profile_section_sidebar_load";
  static const String profileSectionSidebarCtaClick =
      "profile_section_sidebar_cta_click";
  static const String changeAttendanceBsLoad = "change_attendance_bs_load";
  static const String changeAttendanceCtaClick = "change_attendance_cta_click";
  static const String periodLeaveSelectionCta = "period_leave_selection_cta";
  static const String homeLoginCountdownNudgeLoad =
      "home_login_countdown_nudge_load";
  static const String earlyLoginNudgeLoad = "early_Login_nudge_load";
  static const String loginCtaClick = "login_cta_click";
  static const String loginError = "login_error";
  static const String emergencyLogoutBsLoad = "emergency_logout_bs_load";
  static const String emergencyLogoutCtaClick = "emergency_logout_cta_click";
  static const String emergencyLogoutCtaClickError =
      "emergency_logout_cta_click_error";
  static const String takeCareBsLoad = "take_care_bs_load";

  // BCP — degraded service page
  static const String bcpDegradedPageLoad = "bcp_degraded_page_load";
  // Onboarding funnel
  static const String languageSelectionScreenLoad =
      "language_selection_screen_load";
  static const String languageSelected = "language_selected";
  static const String languageSelectionConfirmed =
      "language_selection_confirmed";
  static const String tncLinkClicked = "tnc_link_clicked";
  static const String phoneNumberScreenLoad = "phone_number_screen_load";
  static const String phoneNumberScreenCtaClick =
      "phone_number_screen_cta_click";
  static const String otpScreenLoad = "otp_screen_load";
  static const String otpScreenCtaClick = "otp_screen_cta_click";
  static const String otpVerificationSuccess = "otp_verification_success";
  static const String otpVerificationFailed = "otp_verification_failed";
  static const String otpResendCtaClick = "otp_resend_cta_click";
  static const String locationPermissionPromptShown =
      "location_permission_prompt_shown";
  static const String locationPermissionResponse =
      "location_permission_response";
  static const String locationDetected = "location_detected";
  static const String registrationDashboardScreenLoad =
      "registration_dashboard_screen_load";
  static const String registrationDashboardScreenCtaClick =
      "registration_dashboard_screen_cta_click";

  // Tiering (Snabbit Udaan) — home nudge, intro banner, drawer tier row.
  // Fired to Mixpanel + CleverTap via explicit targets (see TieringAnalytics).
  static const String tieringNudgeViewed = "tiering_nudge_viewed";
  static const String tieringNudgeClicked = "tiering_nudge_clicked";
  static const String tieringUdaanBannerViewed = "tiering_udaan_banner_viewed";
  static const String tieringUdaanBannerClicked =
      "tiering_udaan_banner_clicked";
  static const String tieringViewTierDrawerViewed =
      "tiering_view_tier_drawer_viewed";
  static const String tieringViewTierDrawerClicked =
      "tiering_view_tier_drawer_clicked";
}
