import 'package:flutter/material.dart';
import 'package:enjambre/models/torrents.dart';
import 'package:enjambre/screens/torrents/dialogs/filters.dart';
import 'package:provider/provider.dart';

class FilterLabelsButton extends StatelessWidget {
  const FilterLabelsButton({super.key});

  _handleButtonClick(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return const FiltersDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TorrentsModel>(builder: (context, torrentsModel, child) {
      return IconButton(
          onPressed: () => _handleButtonClick(context),
          icon: Icon(Icons.filter_alt_outlined,
              color: torrentsModel.filters.enabled ? Colors.lightBlue : null));
    });
  }
}
