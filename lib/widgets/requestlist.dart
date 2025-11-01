import 'package:flutter/material.dart';
import 'package:leisureryde/methods/driversmethod.dart';
import '../methods/commonmethods.dart';

CommonMethods cMethods = CommonMethods();

driverRequest(requests){
  return ListView.builder(
    padding: const EdgeInsets.all(12),
    itemCount: requests.length,
    itemBuilder: (context, index){
      final request = requests[index];
      return FutureBuilder(
          future: Future.wait([
              cMethods.getAddressFromCoordinates(request['pickup']['lat'],request['pickup']['lng']),
              cMethods.getAddressFromCoordinates(request['destination']['lat'],request['destination']['lng'])
          ]),
          builder: (context, AsyncSnapshot<List<String>> snapshot){
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }

            final pickup = snapshot.data?[0];
            final destination = snapshot.data?[1];

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ride Request',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Pickup:'),
                        Expanded(
                          child: Text(
                            "$pickup",
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Destination:'),
                        Expanded(
                          child: Text(
                            "$destination",
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Distance:'),
                        Text('${request['distance']} km'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Price:'),
                        Text('₦${request['price']}'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Rider Phone:'),
                        Text(request['phone'] ?? 'N/A'),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => {
                            Drivers().acceptRide("${request['rideId']}")
                          },
                          icon: const Icon(Icons.check_circle, color: Colors.white),
                          label: const Text('Accept'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => {
                            Drivers().rejectRide("${request['rideId']}")
                          },
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          label: const Text('Decline'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            foregroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
      );

    },
  );
}