import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';

void main() {
  runApp(MaterialApp(
    home: NfcCardApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class NfcCardApp extends StatefulWidget {
  @override
  _NfcCardAppState createState() => _NfcCardAppState();
}

class _NfcCardAppState extends State<NfcCardApp> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _nfcContent = "No data read yet";

  Future<void> writeToCard() async {
    if (_userIdController.text.isEmpty ||
        _nameController.text.isEmpty ||
        _titleController.text.isEmpty ||
        _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Please fill in all fields")),
      );
      return;
    }

    _showNfcDialog("Tap your NFC card", "Hold your NFC card near the device");

    NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
      var ndef = Ndef.from(tag);
      if (ndef == null || !ndef.isWritable) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ NFC card is not writable")),
        );
        NfcManager.instance.stopSession();
        return;
      }

      bool hasData = false;

      if (ndef.cachedMessage != null && ndef.cachedMessage!.records.isNotEmpty) {
        final record = ndef.cachedMessage!.records.first;

        int languageCodeLength = record.payload.first;
        String existingPayload = String.fromCharCodes(
          record.payload.sublist(1 + languageCodeLength),
        );

        if (existingPayload.trim().isNotEmpty) {
          hasData = true;
        }
      }

      if (hasData) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("⚠️ Data already exists on the card")),
        );
        NfcManager.instance.stopSession();
        return;
      }

      String data =
          "${_userIdController.text}|${_nameController.text}|${_titleController.text}|${_phoneController.text}";

      NdefMessage message = NdefMessage([
        NdefRecord.createText(data),
      ]);

      await ndef.write(message);

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Data written successfully!")),
      );

      NfcManager.instance.stopSession();
    });
  }


  Future<void> readFromCard() async {
    _showNfcDialog("Tap your NFC card", "Hold your NFC card near the device");

    NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
      var ndef = Ndef.from(tag);
      if (ndef == null || ndef.cachedMessage == null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ No NDEF data found")),
        );
        NfcManager.instance.stopSession();
        return;
      }

      try {
        final record = ndef.cachedMessage!.records.first;

        // Skip the language code (1st byte tells you how many bytes to skip)
        int languageCodeLength = record.payload.first;
        String payload = String.fromCharCodes(
          record.payload.sublist(1 + languageCodeLength),
        );

        List<String> parts = payload.split('|');

        Navigator.pop(context);

        setState(() {
          if (parts.length == 4) {
            _nfcContent =
            "User ID: ${parts[0]}\nName: ${parts[1]}\nTitle: ${parts[2]}\nPhone: ${parts[3]}";
          } else {
            _nfcContent = "Invalid data format";
          }
        });
      } catch (e) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error reading data")),
        );
      }

      NfcManager.instance.stopSession();
    });
  }


  Future<void> deleteDataFromCard() async {
    _showNfcDialog("Tap your NFC card", "Hold your NFC card near the device");

    NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
      var ndef = Ndef.from(tag);
      if (ndef == null || !ndef.isWritable) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ NFC card is not writable")),
        );
        NfcManager.instance.stopSession();
        return;
      }

      try {
        NdefMessage emptyMessage = NdefMessage([
          NdefRecord.createText(''), // Overwrites with empty string
        ]);

        await ndef.write(emptyMessage);

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Data deleted successfully!")),
        );

        _showSuccessDialog("Delete Successful", "All data has been deleted from the NFC card.");

        setState(() {
          _nfcContent = "No data read yet";
        });
      } catch (e) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed to delete data from the card")),
        );
      } finally {
        NfcManager.instance.stopSession();
      }
    });
  }


  void _showNfcDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.nfc, size: 50),
            SizedBox(height: 10),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _nameController.dispose();
    _titleController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("NFC Card Manager")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _userIdController,
                decoration: InputDecoration(labelText: "User ID"),
              ),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: "Name"),
              ),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(labelText: "Title"),
              ),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: "Phone"),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: writeToCard,
                icon: Icon(Icons.nfc),
                label: Text("Write to NFC Card"),
              ),
              SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: readFromCard,
                icon: Icon(Icons.nfc_rounded),
                label: Text("Read from NFC Card"),
              ),
              SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: deleteDataFromCard,
                icon: Icon(Icons.delete_forever),
                label: Text("Delete NFC Card Data"),
              ),
              SizedBox(height: 20),
              Text(
                "Stored Data:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_nfcContent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
