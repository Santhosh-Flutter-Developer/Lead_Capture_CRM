import 'package:flutter/material.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/views/views.dart';

/// Asks for confirmation, then deletes [lead] (moved to trash + activity log).
///
/// Re-checks the "Leads" delete permission right before deleting so the
/// action can never run for a role without delete access, even if a caller
/// forgot to hide its button. Returns `true` only when the lead was deleted.
Future<bool> confirmAndDeleteLead(BuildContext context, LeadModel lead) async {
  final perm = await PermissionService.getPermissions('Leads');
  if (!(perm?.canDelete ?? false)) {
    if (context.mounted) {
      FlushBar.show(
        context,
        'You do not have permission to delete leads',
        isSuccess: false,
      );
    }
    return false;
  }
  if (!context.mounted) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => ConfirmDialog(
      title: 'Delete Lead',
      content: 'Are you sure you want to delete "${lead.leadName}"?',
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  try {
    futureLoading(context);
    await LeadService.deleteLead(uid: lead.uid ?? '');
    if (context.mounted && Navigator.canPop(context)) {
      Navigator.pop(context); // close loading
    }
    return true;
  } catch (e, st) {
    await ErrorService.recordError(e, st);
    if (context.mounted) {
      if (Navigator.canPop(context)) Navigator.pop(context); // close loading
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
    return false;
  }
}

/// Success toast with UNDO, shown by the screen that owns the lead list
/// after a lead was deleted. [onChanged] should reload the list.
void showLeadDeletedUndo(
  BuildContext context,
  LeadModel lead,
  VoidCallback onChanged,
) {
  FlushBar.show(
    context,
    'Lead deleted successfully',
    actionLabel: 'UNDO',
    onActionPressed: () async {
      await LeadService.restoreLead(lead);
      onChanged();
    },
  );
}