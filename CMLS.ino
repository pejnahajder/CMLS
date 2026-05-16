#include <SPI.h>
#include <WiFiNINA.h>
#include <WiFiUdp.h>
#include <OSCMessage.h>

char ssid[] = "MKR_OSC_AP";
char pass[] = "password123";

WiFiUDP Udp;

IPAddress remoteIP(192, 168, 4, 2);  // IP del ricevitore OSC
const unsigned int remotePort = 9000;

void setup() {
  Serial.begin(9600);
  while (!Serial);

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

  Udp.begin(8000); // porta locale qualsiasi
}

void loop() {
  OSCMessage msg("/test");

  msg.add(123);

  Udp.beginPacket(remoteIP, remotePort);
  msg.send(Udp);
  Udp.endPacket();

  msg.empty();

  Serial.println("Mandato OSC: /test 123");

  delay(1000);
}