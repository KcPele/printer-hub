import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/account/cubit/devices_cubit.dart';
import 'package:printerhub/errors/error_messages.dart';
import 'package:printerhub/l10n/l10n.dart';

/// Where the account is signed in, and the phones it sends notifications
/// to. Another device can be signed out, or forgotten, from here.
class DevicesPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = DevicesCubit(
          authRepository: context.read<AuthRepository>(),
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const DevicesView(),
    );
  }
}

class DevicesView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<DevicesCubit>();
    final state = context.watch<DevicesCubit>().state;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.devicesTitle)),
      body: SafeArea(
        child: switch (state.status) {
          DevicesStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          DevicesStatus.failed => EmptyState(
            illustration: AppIllustrations.private,
            title: l10n.devicesFailedTitle,
            message: errorMessage(l10n, state.error),
            action: FilledButton(
              onPressed: cubit.load,
              child: Text(l10n.loadingRetry),
            ),
          ),
          DevicesStatus.ready => RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                AppSpacing.xxl,
              ),
              children: [
                if (state.error != null) ...[
                  AppNotice(message: errorMessage(l10n, state.error)),
                  const SizedBox(height: AppSpacing.lg),
                ],
                _Heading(l10n.devicesSignedIn, l10n.devicesSignedInBody),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    children: [
                      for (final session in state.sessions)
                        _Row(
                          icon: Icons.login,
                          title:
                              state.deviceOf(session)?.label ??
                              session.userAgent ??
                              l10n.devicesUnknown,
                          subtitle: l10n.devicesLastUsed(
                            _date(context, session.lastUsedAt),
                          ),
                          isThisDevice: session.isCurrent,
                          action: l10n.devicesSignOut,
                          busy: state.busyId == session.id,
                          onAction: () => cubit.signOut(session),
                        ),
                    ],
                  ),
                ),
                if (state.devices.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _Heading(l10n.devicesPhones, l10n.devicesPhonesBody),
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Column(
                      children: [
                        for (final device in state.devices)
                          _Row(
                            icon: device.platform == 'android'
                                ? Icons.phone_android
                                : Icons.phone_iphone,
                            title: device.label,
                            subtitle: [
                              ?device.osVersion,
                              if (device.pushEnabled)
                                l10n.devicesNotificationsOn
                              else
                                l10n.devicesNotificationsOff,
                            ].join(' · '),
                            isThisDevice: device.isThisDevice,
                            action: l10n.devicesForget,
                            busy: state.busyId == device.id,
                            onAction: () => cubit.forget(device),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        },
      ),
    );
  }

  static String _date(BuildContext context, DateTime moment) {
    return MaterialLocalizations.of(context).formatMediumDate(moment.toLocal());
  }
}

class _Heading extends StatelessWidget {
  const new(this.title, this.body);

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// A session or a device: what it is, and either that it is this one or
/// the button that removes it.
class _Row extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isThisDevice,
    required this.action,
    required this.busy,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isThisDevice;
  final String action;
  final bool busy;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: isThisDevice
          ? StatusPill(
              status: AppStatus.success,
              label: context.l10n.devicesThisDevice,
            )
          : busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(onPressed: onAction, child: Text(action)),
    );
  }
}
