package com.snabbit.runner.shared.features.kavach.shield.data

/**
 * The YAMNet labels Remote Config is allowed to name as SOS triggers — a 1:1 port of Flutter's
 * `YamnetClass` enum (`lib/modules/snabbit_shield/yamnet_classes.dart`).
 *
 * Why an allow-list: the plugin matches a detected class against these with a case-insensitive
 * `contains()`, so a malformed or over-broad RC entry (a stray `"a"`, a typo, an injected value)
 * would match nearly every AudioSet class and flood SOS. Flutter validates and drops unknowns for
 * exactly this reason; KMP consumed `getStringList` raw.
 *
 * Keep in sync with the Dart enum — it is the source of truth.
 */
internal val YAMNET_KNOWN_LABELS: Set<String> = setOf(
    "Speech",
    "Child speech, kid speaking",
    "Conversation",
    "Narration, monologue",
    "Babbling",
    "Scream",
    "Shout",
    "Children shouting",
    "Screaming",
    "Crying, sobbing",
    "Baby cry, infant cry",
    "Whimper",
    "Wail, moan",
    "Groan",
    "Grunt",
    "Gasp",
    "Pant",
    "Roar",
    "Gunshot, gunfire",
    "Machine gun",
    "Explosion",
    "Cap gun",
    "Fireworks",
    "Firecracker",
    "Burst, pop",
    "Boom",
    "Bang",
    "Slap, smack",
    "Whack, thwack",
    "Smash, crash",
    "Breaking",
    "Wood",
    "Crack",
    "Glass",
    "Chink, clink",
    "Shatter",
    "Thump, thud",
    "Crunch",
    "Alarm",
    "Alarm clock",
    "Siren",
    "Civil defense siren",
    "Police car (siren)",
    "Ambulance (siren)",
    "Fire engine, fire truck (siren)",
    "Buzzer",
    "Smoke detector, smoke alarm",
    "Fire alarm",
    "Foghorn",
    "Crowd",
    "Traffic noise, roadway noise",
    "Train",
    "Train wheels squealing",
    "Wind",
    "Rustling leaves",
    "Rain",
    "Thunder",
    "Thunderstorm",
    "Telephone",
    "Telephone bell ringing",
    "Ringtone",
    "Television",
    "Radio",
    "Noise",
    "Environmental noise",
    "White noise",
    "Pink noise",
    "Sound effect",
)

/**
 * Safe high-severity distress classes, used when Remote Config supplies no valid list. Deliberately
 * narrow: genuine emergencies only, no everyday impact/percussive sounds — the plugin's own default
 * includes `Glass`, which dropped cutlery and a closing window both score on. Mirrors Flutter's
 * `_safeYamnetTargetClasses`. ("Scream" also matches "Screaming"; "Shout" also matches
 * "Children shouting" via the plugin's substring match.)
 */
internal val SAFE_YAMNET_TARGET_CLASSES: List<String> = listOf(
    "Screaming",
    "Scream",
    "Shout",
    "Gunshot, gunfire",
    "Machine gun",
    "Explosion",
)

/**
 * RC list → validated trigger classes. Unknown entries are dropped (typo/injection-safe); an empty
 * or fully-invalid list falls back to [SAFE_YAMNET_TARGET_CLASSES] rather than running wide open.
 */
internal fun resolveYamnetTargetClasses(raw: List<String>): List<String> {
    if (raw.isEmpty()) return SAFE_YAMNET_TARGET_CLASSES
    val valid = raw.filter { it in YAMNET_KNOWN_LABELS }
    return valid.ifEmpty { SAFE_YAMNET_TARGET_CLASSES }
}
