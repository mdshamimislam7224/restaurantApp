import 'dart:ui';
class Recognition{
  String name;
  Rect location;
  List<double> embedding;
  double distance;
  Recognition(this.name,this.location,this.embedding,this.distance);

}