import 'package:flutter/material.dart';
import 'package:enjambre/l10n/app_localizations.dart';

/// Radio list of selectable player tracks.
///
/// Audio tracks and subtitles only differ in how a track is labelled, so both
/// share this dialog.
class TrackSelectorDialog<T> extends StatelessWidget {
  final String title;
  final List<T> tracks;
  final String currentValue;
  final String Function(T track) idOf;
  final String Function(T track, AppLocalizations localizations) labelOf;
  final void Function(T track) onSelected;

  const TrackSelectorDialog({
    super.key,
    required this.title,
    required this.tracks,
    required this.currentValue,
    required this.idOf,
    required this.labelOf,
    required this.onSelected,
  });

  void _handleChange(BuildContext context, String? id) {
    if (id == null) return;

    for (final track in tracks) {
      if (idOf(track) == id) {
        onSelected(track);
        break;
      }
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: RadioGroup<String>(
          groupValue: currentValue,
          onChanged: (id) => _handleChange(context, id),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: tracks
                .map((track) => RadioListTile<String>(
                      title: Text(labelOf(track, localizations)),
                      value: idOf(track),
                    ))
                .toList(),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text(localizations.cancel),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
