// http://armdz.com
// trace face edges, iterate and affects the vertex

import controlP5.*;
import processing.video.*;
import gab.opencv.*;
import java.awt.Rectangle;
import processing.pdf.*;
ControlP5  cp5;

Capture video_input;
PImage  captured_image = null;
boolean  capture = false;

OpenCV  opencv;
ArrayList<Contour> contours;
int  threshold = 70;
float min_canny = 100;
float max_canny = 255;
PImage  processed_img = null;
PImage  face_img = null;
Rectangle[] faces;

//  disort

float d_input_w = 0;
float d_input_h = 0;
float aprox_factor = 1;
boolean  do_render = false;


void  setup()
{
  size(1024, 500);
  background(255);
  cp5 = new ControlP5(this);
  float pos_x = 700;

  cp5.addButton("Capture")
    .setPosition(pos_x, 5)
    .setSize(50, 20)
    ;
  cp5.addSlider("min_canny")
    .setPosition(pos_x, 30)
    .setRange(0, 255)
    ;
  cp5.addSlider("max_canny")
    .setPosition(pos_x, 50)
    .setRange(0, 255)
    ;
  cp5.addButton("Process")
    .setPosition(pos_x, 70)
    .setSize(50, 20)
    ;

  cp5.addSlider("aprox_factor")
    .setPosition(pos_x, 100)
    .setSize(200, 20)
    .setRange(0, 4)
    .setValue(1.48)
    ;

  video_input = new Capture(this, 320, 240);
  video_input.start();
}

void  update()
{
  if (capture)
  {
    capture = false;
    captured_image = createImage(video_input.width, video_input.height, RGB);
    captured_image = video_input.get();
    captured_image.updatePixels();
    //faces
    opencv = new OpenCV(this, captured_image);
    opencv.loadCascade(OpenCV.CASCADE_FRONTALFACE);  
    faces = opencv.detect();
    if (faces != null && faces.length > 0) {
      face_img = captured_image.get(faces[0].x, (int)constrain(faces[0].y*.8, 0, 0), faces[0].width, (int)constrain(faces[0].height*2.2, 0, captured_image.height-1));
    } else {
      println("NO hay caras");
    }
    opencv=null;
  }
  if (face_img != null)
  {

    if (opencv == null) {
      opencv = new OpenCV(this, face_img);
    }
    opencv.gray();
    opencv.findCannyEdges((int)min_canny, (int)max_canny);
    opencv.threshold(threshold);
    processed_img = opencv.getOutput();
    contours = opencv.findContours();
    d_input_w = processed_img.width;
    d_input_h = processed_img.height;
  }
}

void  draw()
{
  //
  update();

  if (do_render)
  {
    do_render = false;

    background(255);
    distort(true);
    background(255);
    distort(false);
  }
  //  

  tint(255);
  image(video_input, 0, 0);
  if (captured_image != null)
  {
    image(captured_image, video_input.width, 0);
    // 

    if (face_img != null)
    {
      image(face_img, 0, video_input.height);
      image(processed_img, face_img.width, video_input.height);
      for (Contour contour : contours)
      {
        stroke(255, 0, 0);
        pushMatrix();
        translate(face_img.width, video_input.height);
        contour.draw();
        popMatrix();
      }
    }
  }
}

//

void  distort(boolean  _save)
{



  float posx = d_input_w*2;
  float posy = 240;

  int grid_x = 6;
  int grid_y = 1;
  float scale_x = 1.1;

  PVector[] disort_pts = null;
  disort_pts = new PVector[5];

  for (int i=0; i<disort_pts.length; i++)
  {
    disort_pts[i] = new PVector();
    disort_pts[i].set(d_input_w*.5+random(-d_input_w*.4, d_input_w*.4), d_input_h*.5+random(-d_input_h*.4, d_input_h*.4), -random(d_input_w*.1, d_input_w*.5));
  }

  if (_save)
  {
    beginRecord(PDF, "Output/caras_iteradas_"+unique_file_name()+".pdf");
  }
  pushMatrix();

  if (_save)
  {
    translate(50, 50);
  } else {
    translate(posx, posy);
  }

  for (int y=0; y<grid_y; y++)
  {
    for (int x=0; x<grid_x; x++)
    {

      float delta = y/grid_y;
      float nois = noise(x*.01, y*.002, (x+y)*.4);
      float angle = nois*PI;
      float delta_total = map((x+y), 0, (grid_x-1+grid_y-1), 0, 1);

      stroke(0);
      noFill();

      pushMatrix();
      translate(x*(d_input_w*scale_x), y*d_input_h);



      for (Contour contour : contours) {
        contour.setPolygonApproximationFactor(aprox_factor);
        int count = 0;
        float px = 0;
        float py = 0;
        stroke(0);
        beginShape(LINES);
        for (PVector point : contour.getPolygonApproximation().getPoints()) {

          for (int i=0; i<disort_pts.length; i++) {
            float d=dist(point.x, point.y, disort_pts[i].x, disort_pts[i].y);
            float md =abs(disort_pts[i].z);

            if (d < md)
            {
              float a = atan2(point.x-d_input_w*.5, point.x-d_input_h*.5);
              point.x+=(cos(a+angle+disort_pts[i].z*PI)*-(md-d))*delta_total;
              point.y+=(sin(a+angle+disort_pts[i].z*PI)*-(md-d))*delta_total;
            }
          }
          vertex(point.x, point.y);
          count++;
        }
        endShape();
      }

      popMatrix();

      for (int i=0; i<disort_pts.length; i++)
      {
        disort_pts[i].z*=1.02;
      }
    }
  }
  if (!_save)
  {
    noFill();
    rect(0, 0, grid_x*(d_input_w*scale_x), d_input_h);
  }



  popMatrix();

  if (_save)
  {
    endRecord();
  }
}

//  UI

public void Capture(boolean val) {
  capture = true;
}

public void Process(boolean val)
{
  if (val)
  {
    do_render = true;
  }
}


//  Video

void captureEvent(Capture _videoin) {
  _videoin.read();
}

//  Util


String unique_file_name()
{
  return Integer.toString(year()) +  Integer.toString(month()) + Integer.toString(day()) + Integer.toString(hour()) + Integer.toString(minute())+ Integer.toString(second())+ Integer.toString(millis());
}