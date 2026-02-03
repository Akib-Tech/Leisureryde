import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:leisureryde/models/driver_profile.dart';
import 'package:leisureryde/viewmodel/account/account_view_model.dart';

class VehicleInfoScreen extends StatefulWidget {
  const VehicleInfoScreen({super.key});

  @override
  State<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<VehicleInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _carModelController;
  late final TextEditingController _licensePlateController;

  @override
  void initState() {
    super.initState();
    final driverProfile = context.read<AccountViewModel>().driverProfile;
    _carModelController = TextEditingController(text: driverProfile?.carModel ?? '');
    _licensePlateController = TextEditingController(text: driverProfile?.licensePlate ?? '');
  }

  @override
  void dispose() {
    _carModelController.dispose();
    _licensePlateController.dispose();
    super.dispose();
  }

  void _saveVehicleInfo() {
    if (_formKey.currentState!.validate()) {
      final viewModel = context.read<AccountViewModel>();
      viewModel.updateVehicleInformation(
        carModel: _carModelController.text.trim(),
        licensePlate: _licensePlateController.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle information saved!')),
      );
      FocusScope.of(context).unfocus(); // Hide keyboard
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AccountViewModel>();
    final driverProfile = viewModel.driverProfile;

    if (driverProfile == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Driver profile not found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Information'),
        actions: [
          if (viewModel.isUploading)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            TextButton(
              onPressed: _saveVehicleInfo,
              child: const Text('SAVE'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVehicleDetailsForm(driverProfile),
            const SizedBox(height: 32),
            _buildDocumentsSection(viewModel, driverProfile),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleDetailsForm(DriverProfile profile) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VEHICLE DETAILS', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _carModelController,
            decoration: const InputDecoration(labelText: 'Car Model (e.g., Toyota Camry 2021)', border: OutlineInputBorder()),
            validator: (value) => value!.isEmpty ? 'Please enter your car model' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _licensePlateController,
            decoration: const InputDecoration(labelText: 'License Plate Number', border: OutlineInputBorder()),
            validator: (value) => value!.isEmpty ? 'Please enter your license plate' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection(AccountViewModel viewModel, DriverProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('REQUIRED DOCUMENTS', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              _DocumentUploadTile(
                title: 'Driver\'s License',
                documentUrl: profile.licenseUrl,
                onTap: () => viewModel.pickAndUploadDocument(context, DocumentType.licenseUrl),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _DocumentUploadTile(
                title: 'Vehicle Registration',
                documentUrl: profile.vehicleRegistrationUrl,
                onTap: () => viewModel.pickAndUploadDocument(context, DocumentType.vehicleRegistrationUrl),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _DocumentUploadTile(
                title: 'Proof of Insurance',
                documentUrl: profile.proofOfInsuranceUrl,
                onTap: () => viewModel.pickAndUploadDocument(context, DocumentType.proofOfInsuranceUrl),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocumentUploadTile extends StatelessWidget {
  final String title;
  final String documentUrl;
  final VoidCallback onTap;

  const _DocumentUploadTile({required this.title, required this.documentUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool isUploaded = documentUrl.isNotEmpty;
    return ListTile(
      leading: Icon(isUploaded ? Icons.check_circle : Icons.error_outline, color: isUploaded ? Colors.green : Colors.orange),
      title: Text(title),
      subtitle: Text(isUploaded ? 'Document Uploaded' : 'Upload Required', style: TextStyle(color: isUploaded ? Colors.green : Colors.orange, fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}