# Silt-Out Navigation for Cave Diving

## Use Case

- **Goal** <br>The project addresses the problem of spatial disorientation in cave diving during zero-visibility conditions (silt-out). The goal is to create an active guidance system: the diver is oriented in space and alerted to hazards through the synthesis and dynamic modulation of sound, perceived via bone conduction.
  <br>
  The prototype will be a Proof of Concept built with standard, non-waterproof technology, optimized for a "dry" demonstration.
- **Target Audience** <br> Cave divers involved in enviromentally hazardous expeditions with possible silt out conditions

## Task Division

- **Board and Sensors:** Acquisition, normalization and transmission of sensor's values from the board to JUCE.<br>Responsibles: Matteo and Giulio
- **JUCE and Processing:** Selection of personalized value range for sound control and mapping of the normalized sensor's values to those ranges.<br>Transmission of those values to Supercollider<br>Responsibles: Lorenzo and Mattia
- **SuperCollider:** Retrieval of the values from JUCE, creation and manipulation of actual sounds.<br>Responsibles: Daniel and Alessio

## Signals and Feedback

- **Input signals (Board [norm] --> Juce):**<br>
  - Lateral sensors: [0 ; 1]
  - Lateral sensors: [-1 ; 1]
  - Frontal sensor: [0 ; 1]
  - Accellerometer: [-1 ; 1]
  - Joystick: { 2.5, 5.0, 7.5, 10 }
- **Mapping (JUCE --> SC):**<br>
  Remapping of the sensor's values to the range selected by the user
- **Feedback (SC):**
  - Cave width: Reverb Amount
  - Lateral wall proximity: Panning (left - right)
  - Depth: BPM (The closer the higher)
  - Head tilt: Pitch (Up - Down)
  - Vertical speed: Alarm

## Networking

- **Protocol:** OSC over UDP
- **Network configuration:**
  - Board Access Point with fixed IP (192.168.4.1)
- **Data Flow:**
  - Board --> JUCE (192.168.4.1:9111)
  - Processing --> JUCE (127.0.0.1:9002)
  - JUCE --> Processing (127.0.0.1:9003)
  - JUCE --> SC (127.0.0.1:57120)

## Future developments

1. Hear a range preview before confirming
2. Start and Stop button (to control both JUCE and SC)
3. Alarm selection and preview
4. Substituting the joystick with a gyroscope + accelerometer to isolate the actual vertical component of the velocity
