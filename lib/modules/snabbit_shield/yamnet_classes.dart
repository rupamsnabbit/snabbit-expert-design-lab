/// Distress‑relevant subset of YAMNet sound event labels used by Snabbit Shield.
///
/// Each enum value exposes a human‑readable [label] that matches the strings
/// from the official YAMNet class map CSV.
enum YamnetClass {
  // ── Core speech / voice ──────────────────────────────────────────────────
  speech('Speech'),
  childSpeechKidSpeaking('Child speech, kid speaking'),
  conversation('Conversation'),
  narrationMonologue('Narration, monologue'),
  babbling('Babbling'),

  // ── Vocal distress / aggression ──────────────────────────────────────────
  scream('Scream'),
  shout('Shout'),
  childrenShouting('Children shouting'),
  screaming('Screaming'),
  cryingSobbing('Crying, sobbing'),
  babyCryInfantCry('Baby cry, infant cry'),
  whimper('Whimper'),
  wailMoan('Wail, moan'),
  groan('Groan'),
  grunt('Grunt'),
  gasp('Gasp'),
  pant('Pant'),
  roar('Roar'),

  // ── Weapons / explosions ─────────────────────────────────────────────────
  gunshotGunfire('Gunshot, gunfire'),
  machineGun('Machine gun'),
  explosion('Explosion'),
  capGun('Cap gun'),
  fireworks('Fireworks'),
  firecracker('Firecracker'),
  burstPop('Burst, pop'),
  boom('Boom'),

  // ── Impacts / breaking / glass ───────────────────────────────────────────
  bang('Bang'),
  slapSmack('Slap, smack'),
  whackThwack('Whack, thwack'),
  smashCrash('Smash, crash'),
  breaking('Breaking'),
  wood('Wood'),
  crack('Crack'),
  glass('Glass'),
  chinkClink('Chink, clink'),
  shatter('Shatter'),
  thumpThud('Thump, thud'),
  crunch('Crunch'),

  // ── Sirens / alarms ──────────────────────────────────────────────────────
  alarm('Alarm'),
  alarmClock('Alarm clock'),
  siren('Siren'),
  civilDefenseSiren('Civil defense siren'),
  policeCarSiren('Police car (siren)'),
  ambulanceSiren('Ambulance (siren)'),
  fireEngineFireTruckSiren('Fire engine, fire truck (siren)'),
  buzzer('Buzzer'),
  smokeDetectorSmokeAlarm('Smoke detector, smoke alarm'),
  fireAlarm('Fire alarm'),
  foghorn('Foghorn'),

  // ── Environmental / context (still from YAMNet CSV) ─────────────────────
  crowd('Crowd'),
  hubbubSpeechNoiseSpeechBabble(
    'Hubbub, speech noise, speech babble',
  ),
  trafficNoiseRoadwayNoise('Traffic noise, roadway noise'),
  train('Train'),
  trainWheelsSquealing('Train wheels squealing'),
  wind('Wind'),
  rustlingLeaves('Rustling leaves'),
  rain('Rain'),
  thunder('Thunder'),
  thunderstorm('Thunderstorm'),

  // ── Media / devices ──────────────────────────────────────────────────────
  telephone('Telephone'),
  telephoneBellRinging('Telephone bell ringing'),
  ringtone('Ringtone'),
  television('Television'),
  radio('Radio'),

  // ── Generic noise / signal ───────────────────────────────────────────────
  noise('Noise'),
  environmentalNoise('Environmental noise'),
  whiteNoise('White noise'),
  pinkNoise('Pink noise'),
  soundEffect('Sound effect');

  final String label;

  const YamnetClass(this.label);
}

