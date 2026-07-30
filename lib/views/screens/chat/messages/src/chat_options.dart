part of 'chat_messages.dart';

class ChatOptions extends StatelessWidget {
  final bool edit, delete;
  const ChatOptions({super.key, this.delete = false, this.edit = false});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 15, bottom: 15, right: 15),
        child: ListView(
          primary: false,
          shrinkWrap: true,
          children: [
            if (edit)
              ListTile(
                onTap: () => Navigator.pop(context, 1),
                title: Text(
                  "Edit",
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.black),
                ),
                leading: const Icon(Iconsax.edit),
              ),
            if (delete)
              ListTile(
                onTap: () => Navigator.pop(context, 2),
                title: Text(
                  "Delete",
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.black),
                ),
                leading: const Icon(Iconsax.trash),
              ),
            if (edit || delete) const Divider(),
            ListTile(
              onTap: () => Navigator.pop(context, 3),
              title: Text(
                "Quote in reply",
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.black),
              ),
              leading: const LineIcon.reply(),
            ),
            ListTile(
              onTap: () => Navigator.pop(context, 4),
              title: Text(
                "Copy Text",
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.black),
              ),
              leading: const Icon(Iconsax.copy),
            ),
          ],
        ),
      ),
    );
  }
}
