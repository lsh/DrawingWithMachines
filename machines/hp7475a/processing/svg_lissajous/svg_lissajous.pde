// Generate a Lissajous curve, and export it as an SVG file.
// For more information on the Processing SVG library, see:
// https://processing.org/reference/libraries/svg/index.html
import processing.svg.*;

void setup() {
  size(792, 612); // Letter 11"x8.5" @72dpi
  noLoop(); // just execute once.
}

void draw() {
  background(255); 
  stroke(0);
  noFill();

  beginRecord(SVG, "lissajous.svg");

  int nPoints = 100;
  float cx = width/2; 
  float cy = height/2; 
  float radius = width/4; 

  beginShape(); 
  for (int i=0; i<nPoints; i++) {
    float theta = map(i, 0, nPoints, 0, TWO_PI);
    float px = cx + radius * sin(2.0 * theta);
    float py = cy + radius * cos(3.0 * theta); 
    vertex(px, py);
  }
  endShape(CLOSE); 
  endRecord();
}