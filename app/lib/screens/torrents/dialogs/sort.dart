import 'package:flutter/material.dart';
import 'package:enjambre/l10n/app_localizations.dart';
import 'package:enjambre/models/torrents.dart';
import 'package:provider/provider.dart';

class SortDialog extends StatefulWidget {
  const SortDialog({super.key});

  @override
  State<SortDialog> createState() => _SortDialogState();
}

class _SortDialogState extends State<SortDialog> {
  Sort selectedSort = Sort.addedDate;
  bool reverseSort = false;

  @override
  void initState() {
    super.initState();
    selectedSort = Provider.of<TorrentsModel>(context, listen: false).sort;
    reverseSort =
        Provider.of<TorrentsModel>(context, listen: false).reverseSort;
  }

  _handleChange(Sort? sort) {
    if (sort == null) return;
    setState(() {
      selectedSort = sort;
    });
  }

  void _handleReverseSortChange(bool value) {
    setState(() {
      reverseSort = value;
    });
  }

  _handleApply(context) {
    Provider.of<TorrentsModel>(context, listen: false)
        .setSort(selectedSort, reverseSort);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Consumer<TorrentsModel>(builder: (context, torrentsModel, child) {
      return AlertDialog(
        title: Text(localizations.sort),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            RadioGroup<Sort>(
              groupValue: selectedSort,
              onChanged: _handleChange,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  RadioListTile<Sort>(
                      title: Text(localizations.dateAdded),
                      value: Sort.addedDate),
                  RadioListTile<Sort>(
                      title: Text(localizations.progress),
                      value: Sort.progress),
                  RadioListTile<Sort>(
                      title: Text(localizations.size), value: Sort.size),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(localizations.reverseOrder),
                const SizedBox(width: 8),
                Switch(value: reverseSort, onChanged: _handleReverseSortChange),
              ],
            )
          ],
        ),
        actions: <Widget>[
          TextButton(
            child: Text(localizations.cancel),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text(localizations.apply),
            onPressed: () => _handleApply(context),
          ),
        ],
      );
    });
  }
}
