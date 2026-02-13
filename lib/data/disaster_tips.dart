import '../models/emergency_type.dart';

/// One set of tips for a disaster type: Before, During, After.
class DisasterTipSet {
  final List<String> before;
  final List<String> during;
  final List<String> after;

  const DisasterTipSet({
    required this.before,
    required this.during,
    required this.after,
  });
}

/// Disaster types shown on the Disaster Tips screen (same order every time).
const List<EmergencyType> disasterTipsTypes = [
  EmergencyType.flood,
  EmergencyType.earthquake,
  EmergencyType.fire,
  EmergencyType.calamity,
];

/// Tips per disaster type. Text only; no emojis.
Map<EmergencyType, DisasterTipSet> get disasterTipsData => {
      EmergencyType.flood: const DisasterTipSet(
        before: [
          'Know evacuation routes and higher ground near you.',
          'Prepare an emergency kit with water, food, flashlight, and first aid.',
          'Monitor weather and flood advisories (e.g. PAGASA).',
          'Move valuables and important documents to higher floors.',
        ],
        during: [
          'Move to higher ground immediately. Do not wait.',
          'Avoid walking or driving through floodwater.',
          'Stay away from downed power lines and electrical equipment.',
          'If trapped, go to the highest level and signal for help.',
        ],
        after: [
          'Return only when authorities say it is safe.',
          'Avoid floodwater; it may be contaminated or hide hazards.',
          'Check for damage to utilities before using them.',
          'Report injuries and missing persons to authorities.',
        ],
      ),
      EmergencyType.earthquake: const DisasterTipSet(
        before: [
          'Secure heavy furniture and objects that can fall.',
          'Identify safe spots: under sturdy furniture, away from windows.',
          'Prepare an emergency kit and family meeting point.',
          'Know how to shut off gas, water, and electricity if needed.',
        ],
        during: [
          'Drop, cover, and hold on. Stay where you are.',
          'If indoors, stay inside. Do not run outside.',
          'If outdoors, move away from buildings, trees, and power lines.',
          'If in a vehicle, pull over and stay inside until shaking stops.',
        ],
        after: [
          'Check yourself and others for injuries. Give first aid if trained.',
          'Expect aftershocks. Drop, cover, and hold when they occur.',
          'Check for gas leaks and fire hazards. Evacuate if you smell gas.',
          'Listen to official updates and only use phone for emergencies.',
        ],
      ),
      EmergencyType.fire: const DisasterTipSet(
        before: [
          'Install smoke alarms and test them regularly.',
          'Plan two ways out of every room and a meeting point outside.',
          'Keep flammables away from heat sources.',
          'Know your local emergency number (e.g. 911).',
        ],
        during: [
          'Get out and stay out. Do not go back for belongings.',
          'Stay low under smoke; crawl if necessary.',
          'Close doors behind you to slow spread of fire.',
          'If trapped, seal gaps and signal at the window.',
        ],
        after: [
          'Meet at the agreed meeting point and account for everyone.',
          'Call emergency services and do not re-enter until cleared.',
          'Seek medical help for burns or smoke inhalation.',
          'Contact your insurance and avoid entering damaged structures.',
        ],
      ),
      EmergencyType.calamity: const DisasterTipSet(
        before: [
          'Secure loose objects outside. Reinforce doors and windows.',
          'Prepare emergency kit: water, food, flashlight, batteries, first aid.',
          'Know your evacuation route and shelter locations.',
          'Follow official advisories (e.g. PAGASA, NDRRMC).',
        ],
        during: [
          'Stay indoors, away from windows and glass.',
          'If in a sturdy shelter, stay in the strongest part of the building.',
          'If outdoors, seek shelter in a low-lying area; avoid trees and poles.',
          'Listen to radio or official updates for instructions.',
        ],
        after: [
          'Stay inside until authorities announce it is safe.',
          'Watch for downed power lines and damaged structures.',
          'Check for injuries and give first aid if trained.',
          'Report damage and follow official recovery guidance.',
        ],
      ),
    };
