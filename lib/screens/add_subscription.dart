import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../helpers/text_parser.dart';
import '../models/subscription_model.dart';
import '../helpers/notification_service.dart';
import '../helpers/ocr_service.dart';

class AddSubscriptionScreen extends StatefulWidget {
  final String? initialText;
  final String? initialImagePath;
  final Subscription? existingSubscription;

  const AddSubscriptionScreen({
    super.key,
    this.initialText,
    this.initialImagePath,
    this.existingSubscription,
  });

  @override
  State<AddSubscriptionScreen> createState() => _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends State<AddSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  String _currency = 'SEK';
  DateTime _renewalDate = DateTime.now().add(const Duration(days: 30));
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingSubscription != null) {
      _nameController.text = widget.existingSubscription!.name;
      _priceController.text = widget.existingSubscription!.price.toString();
      _currency = widget.existingSubscription!.currency;
      _renewalDate = widget.existingSubscription!.renewalDate;
    } else if (widget.initialText != null) {
      _parseSharedText(widget.initialText!);
    } else if (widget.initialImagePath != null) {
      _scanSharedImage(widget.initialImagePath!);
    }
  }

  void _parseSharedText(String text) {
    final data = TextParser.parse(text);
    setState(() {
      _nameController.text = data['name'];
      _priceController.text = data['price'] > 0 ? data['price'].toString() : '';
      _currency = data['currency'];
      _renewalDate = data['renewalDate'];
    });

    if (data['name'].isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✨ Detected: ${data['name']}!'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    }
  }

  Future<void> _scanSharedImage(String path) async {
    setState(() => _isScanning = true);

    // Import your OcrService
    final data = await OcrService.scanImage(path);

    if (mounted) {
      setState(() {
        _isScanning = false;
        // Populate fields
        _nameController.text = data['name'] ?? '';
        _priceController.text = (data['price'] ?? 0).toString();
        _currency = data['currency'] ?? 'SEK';

        // Show success/fail message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['name'] != null && data['name'].isNotEmpty
                  ? '✨ Found ${data['name']}!'
                  : '⚠️ Could not find service name. Manual entry needed.',
            ),
          ),
        );
      });
    }
  }

  Future<void> _saveSubscription() async {
    if (_formKey.currentState!.validate()) {
      final sub = Subscription(
        id: widget.existingSubscription?.id,
        name: _nameController.text,
        price: double.parse(_priceController.text),
        currency: _currency,
        renewalDate: _renewalDate,
      );

      int id;
      if (widget.existingSubscription != null) {
        await DatabaseHelper().updateSubscription(sub.id!, sub.toMap());
        id = sub.id!;
      } else {
        id = await DatabaseHelper().addSubscription(sub.toMap());
      }

      // 1. Primary Reminder (3 Days Before)
      DateTime reminderDate = _renewalDate.subtract(const Duration(days: 3));
      await NotificationService().scheduleNotification(
        id: id,
        title: '🔪 Kill ${sub.name}?',
        body: '${sub.name} renews in 3 days for ${sub.price} ${sub.currency}.',
        scheduledDate: reminderDate,
      );

      // 2. Fallback Auto-Renewed Alert (1 Day After Reminder = 2 Days Before)
      // This fires if they never open the app to trigger _processAutoRenewals()
      DateTime autoRenewDate = reminderDate.add(const Duration(days: 1));
      await NotificationService().scheduleNotification(
        id: id + 10000,
        title: '🔄 Auto-Renewed!',
        body: '${sub.name} wasn\'t cancelled. Renewal pushed 30 days.',
        scheduledDate: autoRenewDate,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingSubscription != null
              ? 'Edit Subscription ✏️'
              : 'Add Subscription ➕',
        ),
      ),
      body: _isScanning
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Service Name',
                        hintText: 'Netflix',
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter a name' : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            decoration: const InputDecoration(
                              labelText: 'Price',
                              hintText: '129',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) =>
                                value!.isEmpty ? 'Please enter price' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        DropdownButton<String>(
                          value: _currency,
                          items: ['SEK', 'USD', 'EUR', 'INR'].map((
                            String value,
                          ) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) =>
                              setState(() => _currency = newValue!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: const Color(0xFF1E1E1E),
                      title: Text(
                        "Renewal: ${_renewalDate.toString().split(' ')[0]}",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: Icon(
                        Icons.calendar_month,
                        color: Theme.of(context).primaryColor,
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _renewalDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365 * 5),
                          ),
                        );
                        if (picked != null) {
                          setState(() => _renewalDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed: _saveSubscription,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                      ),
                      child: const Text(
                        'Save Subscription',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
