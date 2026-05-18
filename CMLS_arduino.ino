#include <SPI.h>
#include <WiFiNINA.h>
#include <WiFiUdp.h>
#include <OSCMessage.h>
#include <OSCBundle.h>

// -------------------- WiFi / OSC --------------------
char ssid[] = "MKR_OSC_AP";
char pass[] = "password123";

WiFiUDP Udp;

IPAddress remoteIP(192, 168, 4, 2);  // IP del ricevitore OSC
const unsigned int localPort = 8000;
const unsigned int remotePort = 9000;
const unsigned long SEND_INTERVAL_MS = 100;

// -------------------- Filtro passa-basso Gravity --------------------
// Valori più bassi = filtro più lento/stabile.
// Valori più alti = risposta più rapida ma più nervosa.
const float GRAVITY_LOWPASS_ALPHA = 0.10;

float gravity1FilteredNorm = 0.0;
float gravity2FilteredNorm = 0.0;
bool gravityFilterInitialized = false;

// -------------------- Pin sensori --------------------
#define GRAVITY_1_PIN A1
#define GRAVITY_2_PIN A2

#define MMA_X_PIN A3
#define MMA_Z_PIN A4

#define JOYSTICK_X A5
#define JOYSTICK_Y A6

#define HCSR04_TRIG_PIN 6
#define HCSR04_ECHO_PIN 7

// -------------------- Calibrazione --------------------
#define MAX_RANGE_CM 520.0
#define ADC_RESOLUTION 1023.0

#define MIN_DISTANCE_CM 5.0
#define MAX_DISTANCE_CLAMP_CM 150.0

#define MMA_X_MIN_RAW 300
#define MMA_X_MAX_RAW 700

unsigned long lastSendTime = 0;

float readGravityDistanceCm(int pin) {
  int rawValue = analogRead(pin);
  float distanceCm = rawValue * MAX_RANGE_CM / ADC_RESOLUTION;
  return distanceCm;
}

float lowPassFilter(float previousValue, float newValue, float alpha) {
  return previousValue + alpha * (newValue - previousValue);
}

float readHCSR04DistanceCm() {
  digitalWrite(HCSR04_TRIG_PIN, LOW);
  delayMicroseconds(2);

  digitalWrite(HCSR04_TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(HCSR04_TRIG_PIN, LOW);

  unsigned long duration = pulseIn(HCSR04_ECHO_PIN, HIGH, 30000);

  if (duration == 0) {
    return -1;
  }

  float distanceCm = duration * 0.0343 / 2.0;
  return distanceCm;
}

float clampAndNormalizeDistance(float distanceCm) {
  if (distanceCm < 0) {
    return 1.0;
  }

  if (distanceCm < MIN_DISTANCE_CM) {
    distanceCm = MIN_DISTANCE_CM;
  }

  if (distanceCm > MAX_DISTANCE_CLAMP_CM) {
    distanceCm = MAX_DISTANCE_CLAMP_CM;
  }

  float normalized = (distanceCm - MIN_DISTANCE_CM) / (MAX_DISTANCE_CLAMP_CM - MIN_DISTANCE_CM);
  return normalized;
}

float clampAndNormalizeAccelerometerX(int rawValue) {
  if (rawValue < MMA_X_MIN_RAW) {
    rawValue = MMA_X_MIN_RAW;
  }

  if (rawValue > MMA_X_MAX_RAW) {
    rawValue = MMA_X_MAX_RAW;
  }

  float normalized = (rawValue - MMA_X_MIN_RAW) / float(MMA_X_MAX_RAW - MMA_X_MIN_RAW);
  return normalized;
}

float readSpeedFromJoystick() {
  int spd_raw_x = analogRead(JOYSTICK_X);
  int spd_raw_y = analogRead(JOYSTICK_Y);

  if (spd_raw_x > 1020) {
    return 2.5;
  }
  else if (spd_raw_y > 1020) {
    return 10.0;
  }
  else if (spd_raw_x < 10) {
    return 7.5;
  }
  else if (spd_raw_y < 10) {
    return 5.0;
  }

  return 0.0;
}

void sendSensorOSC(float pan, float width, float depth, float tilt, float speed) {
  OSCBundle bundle;

  bundle.add("/sensor/space/pan").add(pan);
  bundle.add("/sensor/space/width").add(width);
  bundle.add("/sensor/space/depth").add(depth);
  bundle.add("/sensor/position/tilt").add(tilt);
  bundle.add("/sensor/position/speed").add(speed);

  Udp.beginPacket(remoteIP, remotePort);
  bundle.send(Udp);
  Udp.endPacket();

  bundle.empty();
}

void setup() {
  Serial.begin(9600);
  while (!Serial);

  pinMode(HCSR04_TRIG_PIN, OUTPUT);
  pinMode(HCSR04_ECHO_PIN, INPUT);

  Serial.println("Avvio Access Point...");

  int status = WiFi.beginAP(ssid, pass);

  if (status != WL_AP_LISTENING) {
    Serial.println("Errore: Access Point non avviato");
    while (true);
  }

  delay(3000);

  Serial.print("Rete creata: ");
  Serial.println(ssid);

  Serial.print("IP Arduino: ");
  Serial.println(WiFi.localIP());

  Udp.begin(localPort);

  Serial.println("Invio OSC sensori attivo");
}

void loop() {
  if (millis() - lastSendTime < SEND_INTERVAL_MS) {
    return;
  }

  lastSendTime = millis();

  float gravity1 = readGravityDistanceCm(GRAVITY_1_PIN);
  float gravity1NormRaw = clampAndNormalizeDistance(gravity1);

  delay(5);

  float gravity2 = readGravityDistanceCm(GRAVITY_2_PIN);
  float gravity2NormRaw = clampAndNormalizeDistance(gravity2);

  if (!gravityFilterInitialized) {
    gravity1FilteredNorm = gravity1NormRaw;
    gravity2FilteredNorm = gravity2NormRaw;
    gravityFilterInitialized = true;
  }
  else {
    gravity1FilteredNorm = lowPassFilter(
      gravity1FilteredNorm,
      gravity1NormRaw,
      GRAVITY_LOWPASS_ALPHA
    );

    gravity2FilteredNorm = lowPassFilter(
      gravity2FilteredNorm,
      gravity2NormRaw,
      GRAVITY_LOWPASS_ALPHA
    );
  }

  float pan = gravity1FilteredNorm - gravity2FilteredNorm;
  float width = (gravity1FilteredNorm + gravity2FilteredNorm) / 2.0;

  delay(5);

  float hcsr04 = readHCSR04DistanceCm();
  float depth = clampAndNormalizeDistance(hcsr04);  // front

  delay(5);

  int mmaX = analogRead(MMA_X_PIN);
  float tilt = clampAndNormalizeAccelerometerX(mmaX);  // normX acc

  float speed = readSpeedFromJoystick();

  sendSensorOSC(pan, width, depth, tilt, speed);

  Serial.print("gravity1 raw/filtered ");
  Serial.print(gravity1NormRaw);
  Serial.print(" / ");
  Serial.println(gravity1FilteredNorm);

  Serial.print("gravity2 raw/filtered ");
  Serial.print(gravity2NormRaw);
  Serial.print(" / ");
  Serial.println(gravity2FilteredNorm);

  Serial.print("/sensor/space/pan ");
  Serial.println(pan);

  Serial.print("/sensor/space/width ");
  Serial.println(width);

  Serial.print("/sensor/space/depth ");
  Serial.println(depth);

  Serial.print("/sensor/position/tilt ");
  Serial.println(tilt);

  Serial.print("/sensor/position/speed ");
  Serial.println(speed);

  Serial.println("---");
}