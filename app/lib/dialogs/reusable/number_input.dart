import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:enjambre/l10n/app_localizations.dart';

class NumberInputDialog extends StatefulWidget {
  final void Function(int) onSave;
  final int currentValue;
  final String title;
  // Inclusive bounds of the accepted values, when there are any.
  final int? min;
  final int? max;

  const NumberInputDialog(
      {super.key,
      required this.onSave,
      required this.currentValue,
      required this.title,
      this.min,
      this.max});

  @override
  State<NumberInputDialog> createState() => _NumberInputDialogState();
}

class _NumberInputDialogState extends State<NumberInputDialog> {
  late TextEditingController number;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    number = TextEditingController.fromValue(
        TextEditingValue(text: widget.currentValue.toString()));
  }

  @override
  void dispose() {
    number.dispose();
    super.dispose();
  }

  void handleSave() {
    // Without validating first, an empty field throws in int.parse().
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop();
    widget.onSave(int.parse(number.text));
  }

  String? _validate(String? value, AppLocalizations localizations) {
    if (value == null || value.isEmpty) {
      return localizations.emptyNumber;
    }

    final parsed = int.tryParse(value);
    final min = widget.min;
    final max = widget.max;
    if (parsed == null ||
        (min != null && parsed < min) ||
        (max != null && parsed > max)) {
      return localizations.invalidNumber;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: number,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: localizations.enterNumber,
              ),
              validator: (value) => _validate(value, localizations),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text(localizations.cancel),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          onPressed: handleSave,
          child: Text(localizations.save),
        ),
      ],
    );
  }
}
