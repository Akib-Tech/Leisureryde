import 'dart:math';

class DriveInfo{

      late final String pickup;
      late final String destination;


    String getPickup(){
      return pickup;
    }

    void setDriveInfo(pickup,destination){
      this.pickup = pickup;
      this.destination= destination;
    }

    String getDestination(){
      print(destination);
      return destination;
    }

}