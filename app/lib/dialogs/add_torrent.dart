import 'dart:convert';
import 'dart:io';

import 'package:content_resolver/content_resolver.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:enjambre/engine/engine.dart';
import 'package:enjambre/l10n/app_localizations.dart';
import 'package:enjambre/models/session.dart';
import 'package:enjambre/models/torrents.dart';
import 'package:enjambre/utils/device.dart';
import 'package:provider/provider.dart';

class AddTorrentDialog extends StatefulWidget {
  final String? initialMagnetLink;
  final String? initialContentPath;

  const AddTorrentDialog(
      {super.key, this.initialMagnetLink, this.initialContentPath});

  @override
  State<AddTorrentDialog> createState() => _AddTorrentDialogState();
}

class _AddTorrentDialogState extends State<AddTorrentDialog> {
  late TextEditingController _torrentLinkController;
  String? _filename;
  String? pickedDownloadDir;
  String _torrentLink = ''; // Track a state to trigger updates
  bool _isAdding = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _torrentLinkController = TextEditingController();

    _torrentLinkController.addListener(() {
      setState(() {
        _torrentLink = _torrentLinkController.text;
      });
    });

    if (widget.initialMagnetLink != null) {
      _torrentLinkController.text = widget.initialMagnetLink!;
    }

    setState(() {
      _filename = widget.initialContentPath;
    });
  }

  @override
  void dispose() {
    _torrentLinkController.dispose();
    super.dispose();
  }

  void _handleAddTorrent(BuildContext context) async {
    setState(() {
      _isAdding = true;
    });

    // Read everything that needs the context before the first await, so the
    // dialog can be closed at any point without using a stale context.
    final localizations = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final torrentsModel = Provider.of<TorrentsModel>(context, listen: false);

    try {
      TorrentAddedResponse status;

      if (_filename != null) {
        // From a .torrent file
        final String metainfo;
        if (_filename!.startsWith('content:')) {
          // Android
          final Content content =
              await ContentResolver.resolveContent(_filename!);
          metainfo = base64Encode(content.data);
        } else {
          final content = await File(_filename!).readAsBytes();
          metainfo = base64Encode(content);
        }

        // No filename: transmission reads the torrent from the metainfo.
        status =
            await torrentsModel.addTorrent(null, metainfo, pickedDownloadDir);
      } else {
        // From a link (magnet or .torrent url)
        final link = _torrentLinkController.text.trim();
        status = await torrentsModel.addTorrent(link, null, pickedDownloadDir);
      }

      messenger.showSnackBar(SnackBar(
        content: Text(status == TorrentAddedResponse.duplicated
            ? localizations.torrentAlreadyAdded
            : localizations.torrentAdded),
        backgroundColor: Colors.lightGreen,
      ));

      // The torrent is added at this point: nothing below can report a
      // failure anymore.
      try {
        await torrentsModel.fetchTorrents();
      } catch (e) {
        debugPrint('add_torrent: could not refresh the torrents: $e');
      }

      if (mounted) {
        navigator.pop();
      }
      // Errors keep the dialog open, so the link can be fixed.
    } on TorrentAddError catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.message ?? localizations.couldNotAddTorrent),
        backgroundColor: Colors.orange,
      ));
    } catch (e) {
      // A torrent file that cannot be read, a link that cannot be fetched:
      // without this the failure would be silent and the dialog would look
      // like it did nothing.
      debugPrint('add_torrent: could not add the torrent: $e');
      messenger.showSnackBar(SnackBar(
        content: Text(localizations.couldNotAddTorrent),
        backgroundColor: Colors.orange,
      ));
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  void _handleSelectTorrentFile(context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['torrent']);
    if (result == null || result.files.first.path == null) return;

    setState(() {
      _filename = result.files.first.path;
    });
  }

  void _handlePickDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: AppLocalizations.of(context)!.downloadDirectoryPicker);

    if (selectedDirectory == null) return;
    setState(() {
      pickedDownloadDir = selectedDirectory;
    });
  }

  Widget _buildTorrentLinkInput() {
    return TextFormField(
      enabled: _filename == null || _filename!.isEmpty,
      controller: _torrentLinkController,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.link),
        hintText: 'magnet:// or https://',
        label: Text(AppLocalizations.of(context)!.torrentLink),
        suffixIcon: _torrentLinkController.text.isNotEmpty
            ? IconButton(
                onPressed: () => _torrentLinkController.clear(),
                icon: const Icon(Icons.clear),
              )
            : null,
      ),
    );
  }

  Widget _buildFileInput(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
              onPressed: _torrentLink.isEmpty
                  ? () => _handleSelectTorrentFile(context)
                  : null,
              child: Text(
                _filename != null
                    ? _filename!
                    : AppLocalizations.of(context)!.selectTorrentFile,
                overflow: TextOverflow.ellipsis,
              )),
        ),
        if (_filename != null)
          Row(
            children: [
              const SizedBox(
                width: 8,
              ),
              IconButton(
                onPressed: () => {
                  setState(() {
                    _filename = null;
                  })
                },
                icon: const Icon(Icons.clear),
              ),
            ],
          )
      ],
    );
  }

  _buildInputsSeparator(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 16),
      Text(AppLocalizations.of(context)!.orSeparator),
      const SizedBox(height: 16)
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    var downloadDir = pickedDownloadDir ??
        Provider.of<SessionModel>(context, listen: true).session?.downloadDir ??
        '';

    var isValid = _filename != null || _torrentLink.isNotEmpty;

    return AlertDialog(
      title: Text(localizations.addTorrent),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTorrentLinkInput(),
              _buildInputsSeparator(context),
              _buildFileInput(context),
              if (!isMobile()) const SizedBox(height: 16),
              if (!isMobile())
                Row(
                  children: [
                    Text(localizations.destination),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextButton(
                          onPressed: _handlePickDirectory,
                          child: Text(
                            downloadDir,
                            overflow: TextOverflow.ellipsis,
                          )),
                    )
                  ],
                )
            ],
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
        TextButton(
          onPressed: isValid && !_isAdding
              ? () {
                  if (_formKey.currentState!.validate()) {
                    _handleAddTorrent(context);
                  }
                }
              : null,
          child: _isAdding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(localizations.download),
        ),
      ],
    );
  }
}
