import 'package:flutter/material.dart';

class TipDialog extends StatefulWidget {
  final String? driverName;
  final void Function(double tipAmount) onSubmit;
  final VoidCallback onSkip;

  const TipDialog({
    super.key,
    required this.driverName,
    required this.onSubmit,
    required this.onSkip,
  });

  @override
  State<TipDialog> createState() => _TipDialogState();
}

class _TipDialogState extends State<TipDialog> {
  double? _selectedTip;
  final TextEditingController _customController = TextEditingController();
  bool _isCustom = false;

  static const _presets = [1.0, 2.0, 5.0, 10.0];

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  double? get _effectiveTip {
    if (_isCustom) {
      return double.tryParse(_customController.text.trim());
    }
    return _selectedTip;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.volunteer_activism,
                    color: Colors.amber, size: 44),
              ),
              const SizedBox(height: 16),
              Text(
                "Leave a Tip?",
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                widget.driverName != null
                    ? "Show ${widget.driverName} some appreciation"
                    : "Show your driver some appreciation",
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Preset tip amounts
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _presets.map((amount) {
                  final isSelected = !_isCustom && _selectedTip == amount;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedTip = amount;
                      _isCustom = false;
                      _customController.clear();
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 62,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.primaryColor
                            : theme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? theme.primaryColor
                              : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "\$${amount.toStringAsFixed(0)}",
                        style: TextStyle(
                          color: isSelected ? Colors.white : theme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              // Custom tip field
              TextField(
                controller: _customController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: "Custom amount",
                  prefixText: "\$ ",
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: theme.primaryColor, width: 2),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _isCustom = val.isNotEmpty;
                    if (_isCustom) _selectedTip = null;
                  });
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: theme.colorScheme.onPrimary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: theme.disabledColor,
                ),
                onPressed: _effectiveTip == null || _effectiveTip! <= 0
                    ? null
                    : () => widget.onSubmit(_effectiveTip!),
                child: Text(
                  _effectiveTip != null && _effectiveTip! > 0
                      ? "Tip \$${_effectiveTip!.toStringAsFixed(2)}"
                      : "Select a tip amount",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: widget.onSkip,
                child: Text("No thanks",
                    style: TextStyle(color: Colors.grey[600])),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
