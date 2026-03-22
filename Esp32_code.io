#include "esp_camera.h"
#include <WiFi.h>
#include "ESPAsyncWebServer.h"
#include <AsyncTCP.h>
#include <ESPAsyncWebServer.h>

// ======= AP MODE =======
const char* ssid = "ESP32_ROVER";
const char* password = "12345678";
unsigned long lastFrameTime = 0;
const int frameInterval = 50; // ~20 FPS

AsyncWebServer server(80);
AsyncWebSocket wsCamera("/camera");

// ======= MOTOR PINS =======
#define IN1 12
#define IN2 13
#define IN3 14
#define IN4 15

// ======= CAMERA PINS (AI Thinker ESP32-CAM) =======
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

// ========= MOVEMENT =========
void stopMotor() {
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, LOW);
  Serial.println("stop");
}

void moveUp() {
  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, HIGH);
  digitalWrite(IN4, LOW);
  Serial.print("up");
}

void moveDown() {
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, HIGH);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, HIGH);
  Serial.print("down");
}

void turnLeft() {
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, HIGH);
  digitalWrite(IN3, HIGH);
  digitalWrite(IN4, LOW);
  Serial.print("left");
}

void turnRight() {
  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, HIGH);
  Serial.print("right");
}

// ======== JOYSTICK CONTROL ========
void controlWithJoystick(float x, float y) {
  if (y > 0.4) moveUp();
  else if (y < -0.4) moveDown();
  else if (x > 0.4) turnRight();
  else if (x < -0.4) turnLeft();
  else stopMotor();
}

// ========= CAMERA INITIALIZATION =========
#define CAMERA_MODEL_AI_THINKER

void startCamera() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;

  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.frame_size = FRAMESIZE_QVGA;     // 320x240
  config.jpeg_quality = 12;
  config.fb_count = 2;

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed %d", err);
  }
}

// ========= WEBSOCKET CAMERA STREAM =========
void sendCameraFrame() {
  camera_fb_t* fb = esp_camera_fb_get();
  if (!fb) return;

  wsCamera.binaryAll(fb->buf, fb->len);
  esp_camera_fb_return(fb);
}

void onWsEvent(AsyncWebSocket *server, AsyncWebSocketClient *client,
               AwsEventType type, void *arg, uint8_t *data, size_t len) {
}

void setup() {
  Serial.begin(115200);

  pinMode(IN1, OUTPUT);
  pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT);
  pinMode(IN4, OUTPUT);
  stopMotor();

  WiFi.softAP(ssid, password);
  Serial.println(WiFi.softAPIP());

  startCamera();

  // ROUTES
  server.on("/up", HTTP_GET, [](AsyncWebServerRequest *req){ moveUp(); req->send(200, "text/plain", "OK"); });
  server.on("/down", HTTP_GET, [](AsyncWebServerRequest *req){ moveDown(); req->send(200, "text/plain", "OK"); });
  server.on("/left", HTTP_GET, [](AsyncWebServerRequest *req){ turnLeft(); req->send(200, "text/plain", "OK"); });
  server.on("/right", HTTP_GET, [](AsyncWebServerRequest *req){ turnRight(); req->send(200, "text/plain", "OK"); });
  server.on("/stop", HTTP_GET, [](AsyncWebServerRequest *req){ stopMotor(); req->send(200, "text/plain", "OK"); });
  
  server.on("/joystick", HTTP_GET, [](AsyncWebServerRequest *req){
    if (req->hasArg("x") && req->hasArg("y")) {
        float x = req->arg("x").toFloat();
        float y = req->arg("y").toFloat();
        controlWithJoystick(x, y);
        req->send(200, "text/plain", "OK");
    } else {
        req->send(400, "text/plain", "Missing x or y argument");
    }
  });

  wsCamera.onEvent(onWsEvent);
  server.addHandler(&wsCamera);

  server.begin();
}

void loop() {
  if(wsCamera.count() > 0 && millis() - lastFrameTime > frameInterval){
      sendCameraFrame();
      lastFrameTime = millis();
  }
}
